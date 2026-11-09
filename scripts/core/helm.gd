class_name Helm
## Ход «Ковчега-7» (js/ship.js, S.update) и течение отмели (js/creatures.js, currentUpdate).
## Оси Godot: нос корабля смотрит в (−sin yaw, 0, −cos yaw), как узел с rotation.y = yaw;
## yaw растёт — поворот влево. Поворот штурвала вправо (turn > 0) уменьшает yaw.


## Течение: 0,3 м/с, раз в 3 минуты меняет направление по кругу из шести и плавно к нему поворачивает.
class SeaCurrent:
	const SPEED := 0.3
	const PERIOD := 180.0
	const TURN_RATE := 0.08
	const DIRS: Array[float] = [0.7, 2.4, -1.9, 0.1, 2.9, -0.9]

	var angle := 0.0
	var target := 0.0
	var index := 0
	var timer := 0.0  ## секунд до смены направления

	signal changed(index: int)

	func _init() -> void:
		reset()

	func reset() -> void:
		index = 0
		angle = DIRS[0]
		target = DIRS[0]
		timer = PERIOD

	func vel() -> Vector3:
		return Vector3(sin(angle) * SPEED, 0.0, cos(angle) * SPEED)

	## Куда течение поворачивает (после смены `angle` догоняет `target` не сразу).
	func target_vel() -> Vector3:
		return Vector3(sin(target) * SPEED, 0.0, cos(target) * SPEED)

	func update(dt: float) -> void:
		timer -= dt
		if timer <= 0.0:
			timer += PERIOD
			index = (index + 1) % DIRS.size()
			target = DIRS[index]
			changed.emit(index)
		var da := wrapf(target - angle, -PI, PI)
		angle += da * minf(1.0, dt * TURN_RATE)


## Ход: тяга крестовиной вперёд-назад, поворот штурвалом, всплытие и погружение кнопками.
## k — сила двигателей (доля реактора; 1 — штатно): полный ход ≈ 6,7 м/с, задний ≈ 3,6 м/с.
class Ship:
	const FORWARD := 3.0
	const REVERSE := 1.6
	const DRAG := 0.45
	const TURN_LAG := 2.5
	const TURN_RATE := 0.42
	const CLIMB := 2.6
	const CLIMB_LAG := 1.6
	const CEILING := -5.0      ## выше подо льдом не поднимаемся
	const DEEP := -310.0       ## ниже не уходим — дно склона за восточным краем (`Seabed.Slope.BOTTOM`, #822)
	const EDGE := 300.0        ## край отмели; на восток дальше — только в проход и котловину склона (`east_ok`)
	const EAST_END := 640.0    ## и не дальше этого x — у восточной стены котловины
	const CLEARANCE := 3.0     ## над ровным дном (самая низкая точка днища — на CLEARANCE + `bottom()` выше грунта)
	## Днище по всему корпусу (#1481): точки `foot()` под носом, кормой, бортами и кожухами держатся над грунтом
	## с тем же зазором, что днище под центром. Не только центр — иначе на склоне корма уходит в грунт.
	const FOOT_X: Array[float] = [-6.0, 0.0, 6.0]
	const FOOT_Z0 := -9.0      ## от носа (срез носа — `HullPlan.NOSE_CUT`, линза ниже)
	const FOOT_Z1 := 29.0      ## до кормы (`HullPlan.STERN_END`)
	const FOOT_DZ := 2.5
	## Стена: днище за шаг поднялось бы больше, чем пускает уклон GRADE (плюс STEP) на сдвиг дальней точки корпуса, —
	## корабль не вспрыгивает на скалу, а стоит или скользит вдоль, как у края отмели.
	const STEP := 0.5
	const GRADE := 1.5
	const REACH := 21.0        ## дальняя точка корпуса от центра, м (сдвиг при повороте — dyaw · REACH)
	const RUB_GAP := 0.15      ## м над нижним пределом — ещё трёмся о дно (rub)
	const START := Vector3(0.0, -30.0, 95.0)  ## место 00 `LayerMap` на 30 м (#827)

	var pos := START
	var yaw := 0.0
	var speed := 0.0
	var extra_drag := 0.0   ## добавка к DRAG от существ на корпусе (EcoLink.DRAG, присоски), ставит Main каждый шаг мира
	var vy := 0.0
	var turn := 0.0
	## Ввод пилота: тяга и поворот −1…1 (крестовина), вертикаль −1…1 (кнопки).
	var in_thrust := 0.0
	var in_turn := 0.0
	var in_vert := 0.0
	## На сколько метров дно подняло корабль в последнем шаге (для удара о дно — Vitals.scrape): только подъём самого
	## дна под кораблём, пока корабль на нём лежит; спуск на дно по кнопке «Вниз» ударом не считается.
	var bump := 0.0
	## Скорость вверх (м/с), с которой корабль в последнем шаге упёрся в лёд (CEILING); 0 — не упирался (удар о лёд —
	## `HullSound.ice_db`, звук без урона).
	var knock := 0.0
	## Скорость хода (м/с, по модулю), с которой корабль в последнем шаге тёрся о дно — лежит на нём (ближе RUB_GAP)
	## и идёт; 0 — над дном. Петля скрежета — `HullSound.rub_db`, `ShipSounds.set_rub`.
	var rub := 0.0
	var _last_floor := -INF
	## Высота дна под (x, z); днище всего корпуса держится над ним (`floor_at`). Пустой Callable — дна нет.
	var ground: Callable
	## Твёрдое над дном (`func(pos: Vector3, yaw: float) -> bool`): арка 07 `GateArch.hits` (#826), гротовик с рифом
	## (`EcoLink.solid`). Корабль скользит вдоль; уже застрял в твёрдом (загрузка, существо подошло) — выходит свободно.
	var solid: Callable

	func _init() -> void:
		reset()

	func reset() -> void:
		pos = START
		_last_floor = -INF
		yaw = 0.0
		speed = 0.0
		knock = 0.0
		rub = 0.0
		extra_drag = 0.0
		vy = 0.0
		turn = 0.0
		in_thrust = 0.0
		in_turn = 0.0
		in_vert = 0.0

	## Можно ли стоять в (x, z): на отмели — до `EDGE`, за ним — в проходе и котловине склона (`Seabed.Slope.open`).
	static func east_ok(x: float, z: float) -> bool:
		return x <= EDGE or Seabed.Slope.open(x, z)

	func _free(p: Vector3) -> bool:
		return east_ok(p.x, p.z) and not _in_solid(p)

	func _in_solid(p: Vector3) -> bool:
		return solid.is_valid() and bool(solid.call(p, yaw))

	func nose() -> Vector3:
		return Vector3(-sin(yaw), 0.0, -cos(yaw))

	static var _foot: Array[Vector3] = []
	static var _bottom := INF

	## Точки днища в осях корабля (нос в −Z): x, z и низ корпуса y — по `HullPlan.inside` (корпус, носовая оболочка,
	## кормовой переход), плюс кожухи двигателей и нижний стабилизатор (их формы `inside` не считает).
	static func foot() -> Array[Vector3]:
		if not _foot.is_empty():
			return _foot
		var z := FOOT_Z0
		while z <= FOOT_Z1 + 0.01:
			for x in FOOT_X:
				var y := -2.5
				while y < HullPlan.CENTER_Y + 0.01:
					if HullPlan.inside(Vector3(x, y, z)):
						_foot.append(Vector3(x, y, z))
						break
					y += 0.05
			z += FOOT_DZ
		var low := HullPlan.ENGINE_Y - HullPlan.SHROUD_D * 0.5
		for sx: float in [-1.0, 1.0]:
			for dz: float in [-1.0, 1.0]:
				_foot.append(Vector3(sx * HullPlan.ENGINE_X, low, HullPlan.ENGINE_Z + dz))
		for zz: float in [24.0, 26.0]:   # нижний стабилизатор: центр −0,8, размах 1,2
			_foot.append(Vector3(0.0, -1.4, zz))
		for q in _foot:
			_bottom = minf(_bottom, q.y)
		return _foot

	## Самая низкая точка днища в осях корабля (под носовой оболочкой, ≈ −1,6 м).
	static func bottom() -> float:
		foot()
		return _bottom

	## Нижний предел хода центра в p с курсом y: днище в каждой точке `foot()` — не ниже грунта + один зазор.
	## Без дна — `DEEP`. Над ровным грунтом g — g + CLEARANCE, как раньше (когда держался только центр).
	func floor_at(p: Vector3, y: float) -> float:
		var f := DEEP
		if not ground.is_valid():
			return f
		var c := cos(y)
		var sn := sin(y)
		var gap := CLEARANCE + bottom()
		for q in foot():
			# поворот на yaw вокруг Y: (x, z) → (x·cos + z·sin, −x·sin + z·cos)
			var wx := p.x + q.x * c + q.z * sn
			var wz := p.z - q.x * sn + q.z * c
			f = maxf(f, float(ground.call(wx, wz)) + gap - q.y)
		return f

	func depth() -> float:
		return -pos.y

	func update(dt: float, k: float = 1.0, current: Vector3 = Vector3.ZERO) -> void:
		var thrust := clampf(in_thrust, -1.0, 1.0)
		var tr := clampf(in_turn, -1.0, 1.0)
		var vert := clampf(in_vert, -1.0, 1.0)
		speed += (thrust * (REVERSE if thrust < 0.0 else FORWARD) * k - speed * (DRAG + extra_drag)) * dt
		turn += (tr - turn) * minf(1.0, dt * TURN_LAG)
		var yaw0 := yaw
		yaw = wrapf(yaw - turn * TURN_RATE * dt, -PI, PI)
		vy += (vert * CLIMB * k - vy) * minf(1.0, dt * CLIMB_LAG)
		var was := pos
		var was_yaw := yaw0
		pos += (nose() * speed + current) * dt
		pos.y += vy * dt
		pos.x = clampf(pos.x, -EDGE, EAST_END)
		pos.z = clampf(pos.z, -EDGE, EDGE)
		if not _free(pos) and not (east_ok(pos.x, pos.z) and _in_solid(was)):   # в стене за краем или в арке: скользим вдоль, иначе стоим
			var tries: Array[Vector3] = [Vector3(was.x, pos.y, pos.z), Vector3(pos.x, pos.y, was.z),
				Vector3(pos.x, was.y, pos.z), Vector3(was.x, pos.y, was.z), was]
			var moved := false
			for q in tries:
				if _free(q):
					if q.y != pos.y:
						vy = 0.0
					pos = q
					moved = true
					break
			if not moved:
				pos.x = minf(was.x, EDGE) if not east_ok(was.x, was.z) else was.x
				pos.z = was.z
		knock = 0.0
		if pos.y > CEILING:
			pos.y = CEILING
			if vy > 0.0:
				knock = vy
				vy = 0.0
		var floor_y := floor_at(pos, yaw)
		# Стена под корпусом: днище поднялось бы круче, чем пускает уклон, — горизонтальный сдвиг и поворот не идут
		# (скользим вдоль). Уже стояли в грунте (загрузка, дно поднялось) — выходим вверх свободно.
		var reach := Vector2(pos.x - was.x, pos.z - was.z).length() + absf(wrapf(yaw - was_yaw, -PI, PI)) * REACH
		var allow := STEP + reach * GRADE + maxf(0.0, -vy * dt)
		if floor_y - pos.y > allow:
			var stuck := floor_at(Vector3(was.x, pos.y, was.z), was_yaw) - pos.y
			if floor_y - pos.y > stuck + STEP:
				var opts: Array[Vector3] = [Vector3(was.x, pos.y, pos.z), Vector3(pos.x, pos.y, was.z),
					Vector3(was.x, pos.y, was.z)]
				var best := Vector3(was.x, pos.y, was.z)
				var best_yaw := was_yaw
				var found := false
				for yy: float in [yaw, was_yaw]:
					for q in opts:
						if found or not _free(q):
							continue
						if floor_at(q, yy) - pos.y <= maxf(allow, stuck + STEP * 0.5):
							best = q
							best_yaw = yy
							found = true
				if best_yaw != yaw:
					turn = 0.0
				pos = best
				yaw = best_yaw
				if not found:
					speed = 0.0
				floor_y = floor_at(pos, yaw)
		floor_y = maxf(floor_y, DEEP)
		bump = 0.0
		if pos.y < floor_y:
			bump = maxf(0.0, floor_y - _last_floor) if _last_floor > -INF else 0.0
			pos.y = minf(floor_y, CEILING)
			if vy < 0.0:
				vy = 0.0
		_last_floor = floor_y
		rub = absf(speed) if pos.y - floor_y < RUB_GAP else 0.0
