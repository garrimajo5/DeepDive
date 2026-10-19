class_name Helm
## Ход «Ковчега-7» (archive/web/js/ship.js, S.update) и течение отмели (js/creatures.js, currentUpdate).
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
	const DEEP := -96.0
	const EDGE := 300.0
	const CLEARANCE := 3.0     ## над дном
	const START := Vector3(0.0, -20.0, 95.0)

	var pos := START
	var yaw := 0.0
	var speed := 0.0
	var vy := 0.0
	var turn := 0.0
	## Ввод пилота: тяга и поворот −1…1 (крестовина), вертикаль −1…1 (кнопки).
	var in_thrust := 0.0
	var in_turn := 0.0
	var in_vert := 0.0
	## Высота дна под (x, z); корабль держится на CLEARANCE выше. Пустой Callable — дна нет.
	var ground: Callable

	func _init() -> void:
		reset()

	func reset() -> void:
		pos = START
		yaw = 0.0
		speed = 0.0
		vy = 0.0
		turn = 0.0
		in_thrust = 0.0
		in_turn = 0.0
		in_vert = 0.0

	func nose() -> Vector3:
		return Vector3(-sin(yaw), 0.0, -cos(yaw))

	func depth() -> float:
		return -pos.y

	func update(dt: float, k: float = 1.0, current: Vector3 = Vector3.ZERO) -> void:
		var thrust := clampf(in_thrust, -1.0, 1.0)
		var tr := clampf(in_turn, -1.0, 1.0)
		var vert := clampf(in_vert, -1.0, 1.0)
		speed += (thrust * (REVERSE if thrust < 0.0 else FORWARD) * k - speed * DRAG) * dt
		turn += (tr - turn) * minf(1.0, dt * TURN_LAG)
		yaw = wrapf(yaw - turn * TURN_RATE * dt, -PI, PI)
		vy += (vert * CLIMB * k - vy) * minf(1.0, dt * CLIMB_LAG)
		pos += (nose() * speed + current) * dt
		pos.y += vy * dt
		pos.x = clampf(pos.x, -EDGE, EDGE)
		pos.z = clampf(pos.z, -EDGE, EDGE)
		if pos.y > CEILING:
			pos.y = CEILING
			if vy > 0.0:
				vy = 0.0
		var floor_y := DEEP
		if ground.is_valid():
			floor_y = maxf(floor_y, float(ground.call(pos.x, pos.z)) + CLEARANCE)
		if pos.y < floor_y:
			pos.y = minf(floor_y, CEILING)
			if vy < 0.0:
				vy = 0.0
