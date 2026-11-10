class_name Wake
## След винтов и выпуски при всплытии по ART-063 (`docs/concept-art/sled-vintov.md`). Логика без узлов: пул частиц
## в мировых координатах (не едут с кораблём), рождение за кожухами роторов по тяге `HullMesh.Motion.spin`, выпуски
## у сервисных крышек при всплытии (`vent`). Рисует `scripts/game/wake_view.gd` одним MultiMesh (атлас
## `textures/sled/atlas.png`, шейдер `shaders/wake.gdshader`). Случайность — свой генератор с постоянным зерном.

const ATLAS := "res://textures/sled/atlas.png"
const GRID := 4                       ## атлас 4×4: 0–7 пузыри и пары, 8–11 группы, 12–15 завитки струи
const COLOR := Color("D5E4E8")        ## RGB атласа постоянный, форму несёт альфа

const LIMIT := 200                    ## общий предел живых карточек
const LIMIT_LITE := 96                ## «Экономно» (ART-044)
const PER_ROTOR := 80                 ## живых на ротор при полной тяге
const PER_ROTOR_LITE := 36
const PER_VENT := 36                  ## живых на выпуск
const PER_VENT_LITE := 12
const Q_MIN := 0.04                   ## тяга меньше — рождения нет, живые доживают

## Выходы струи в осях корабля (`HullPlan`): задний срез кожуха, при реверсе — передний.
const EXIT_Z := HullPlan.ENGINE_Z + HullPlan.SHROUD_L / 2.0 + 0.15      ## 27,75
const FRONT_Z := HullPlan.ENGINE_Z - HullPlan.SHROUD_L / 2.0 - 0.15     ## 25,25
const VENTS := [Vector3(-0.9, 4.79, 15.5), Vector3(0.9, 4.79, 19.0)]   ## сервисные крышки

const LIFE := Vector2(2.5, 3.8)       ## жизнь пузыря струи, с
const LIFE_LITE := 2.5
const JET := Vector2(1.0, 3.8)        ## скорость струи относительно воды, м/с — по тяге
const JET_FADE := 1.2                 ## струя гаснет за ~1,2 с
const INHERIT := Vector2(0.5, 0.9)    ## скорость корабля теряется за 0,5…0,9 с
const R0 := 0.2                       ## начальный радиус струи, м
const SPREAD := 1.3                   ## разлёт к концу жизни, м
const RISE := Vector2(0.12, 0.5)      ## подъём, м/с
const RISE_ACC := 0.06                ## небольшое ускорение подъёма, м/с²
const CARD := Vector2(0.35, 0.68)     ## сторона карточки, м
const CURL_CARD := Vector2(0.63, 1.22)
const CURL_SHARE := 1.0 / 11.0        ## завитки — ячейки 12–15
const SPIN := Vector2(6.0, 24.0)      ## вращение карточки, °/с (на «Экономно» нет)
const FADE_IN := 0.12                 ## появление, с
const FADE_OUT := 2.0 / 3.0           ## с этой доли жизни — угасание

const VENT_SERIES := 3                ## серий в начале продувки
const VENT_BURST := Vector2(0.5, 1.0) ## длина серии, с
const VENT_GAP := Vector2(0.3, 0.6)   ## пауза между сериями, с
const VENT_RATE := Vector2(12.0, 18.0)
const VENT_RISE := Vector2(0.6, 0.9)
const VENT_LIFE := Vector2(2.0, 4.0)
const ICE_FADE := 2.0                 ## у нижней поверхности льда гаснут за 2 м

enum Src { LEFT, RIGHT, VENT_A, VENT_B }


class Bubble:
	var pos := Vector3.ZERO
	var jet := Vector3.ZERO        ## скорость струи, гаснет
	var inherit := Vector3.ZERO    ## унаследованная скорость корабля, гаснет
	var inherit_tau := 0.7
	var radial := Vector3.ZERO     ## разлёт поперёк струи, м/с
	var rise := 0.3
	var age := 0.0
	var life := 3.0
	var cell := 0
	var size := 0.5
	var angle := 0.0               ## рад
	var spin := 0.0                ## рад/с
	var src := Src.LEFT


var bubbles: Array[Bubble] = []
var lite := false
var rng := RandomNumberGenerator.new()
var _acc := [0.0, 0.0, 0.0, 0.0]          ## накопленные доли рождения по источникам
var _vent_plan: Array = [[], []]           ## серии выпусков: [начало, конец, частиц/с] от начала продувки
var _vent_t := -1.0                        ## время с начала продувки (< 0 — нет)
var _last_pos := Vector3.INF


func _init() -> void:
	rng.seed = 63


func reset() -> void:
	bubbles.clear()
	_acc = [0.0, 0.0, 0.0, 0.0]
	_vent_t = -1.0
	_last_pos = Vector3.INF


## Тяга по оборотам роторов: 0…1.
static func thrust(spin: float) -> float:
	return clampf(absf(spin), 0.0, 1.0)


func limit() -> int:
	return LIMIT_LITE if lite else LIMIT


## Сколько живых может быть от ротора при тяге q: round(80·q), на «Экономно» 36·q.
func rotor_cap(q: float) -> int:
	if q < Q_MIN:
		return 0
	return roundi((PER_ROTOR_LITE if lite else PER_ROTOR) * q)


## Сколько живых может быть от выпуска: остаток общего предела поровну, не больше 36 (12).
func vent_cap(rotor_alive: int) -> int:
	return clampi((limit() - rotor_alive) / 2, 0, PER_VENT_LITE if lite else PER_VENT)


func alive(src: int) -> int:
	var n := 0
	for b in bubbles:
		if b.src == src:
			n += 1
	return n


## Начало продувки: серии выпусков у обеих сервисных крышек.
func vent() -> void:
	_vent_t = 0.0
	for v in 2:
		var plan := []
		var t := rng.randf_range(0.0, 0.2)
		for i in VENT_SERIES:
			var d := rng.randf_range(VENT_BURST.x, VENT_BURST.y)
			plan.append([t, t + d, rng.randf_range(VENT_RATE.x, VENT_RATE.y)])
			t += d + rng.randf_range(VENT_GAP.x, VENT_GAP.y)
		_vent_plan[v] = plan


func venting() -> bool:
	if _vent_t < 0.0:
		return false
	for plan in _vent_plan:
		if not plan.is_empty() and _vent_t < plan[-1][1]:
			return true
	return false


## Шаг: ship — положение корабля в мире (`helm.pos`, yaw), spin — `HullMesh.Motion.spin`, current — течение.
func update(dt: float, ship: Transform3D, spin: float, current: Vector3 = Vector3.ZERO) -> void:
	if dt <= 0.0:
		return
	var ship_vel := Vector3.ZERO
	if _last_pos != Vector3.INF:
		ship_vel = (ship.origin - _last_pos) / dt
		if ship_vel.length() > 20.0:   # перенос корабля (снимок, новый забег) — не скорость
			ship_vel = Vector3.ZERO
	_last_pos = ship.origin
	_age(dt, current)
	var q := thrust(spin)
	var cap := rotor_cap(q)
	if cap > 0:
		var life_mean := LIFE_LITE if lite else (LIFE.x + LIFE.y) * 0.5
		for side in [Src.LEFT, Src.RIGHT]:
			_acc[side] += cap / life_mean * dt
			while _acc[side] >= 1.0:
				_acc[side] -= 1.0
				if alive(side) < cap and bubbles.size() < limit():
					_spawn_rotor(side, ship, ship_vel, spin, q)
	else:
		_acc[Src.LEFT] = 0.0
		_acc[Src.RIGHT] = 0.0
	if _vent_t >= 0.0:
		_vent_t += dt
		var vcap := vent_cap(alive(Src.LEFT) + alive(Src.RIGHT))
		for v in 2:
			var src: int = Src.VENT_A + v
			var rate := 0.0
			for s in _vent_plan[v]:
				if _vent_t >= s[0] and _vent_t < s[1]:
					rate = s[2]
			if rate <= 0.0:
				_acc[src] = 0.0
				continue
			_acc[src] += rate * dt
			while _acc[src] >= 1.0:
				_acc[src] -= 1.0
				if alive(src) < vcap and bubbles.size() < limit():
					_spawn_vent(v, ship, ship_vel)
		if not venting():
			_vent_t = -1.0


func _age(dt: float, current: Vector3) -> void:
	var keep: Array[Bubble] = []
	for b in bubbles:
		b.age += dt
		if b.age >= b.life or b.pos.y > Seabed.ICE_Y:
			continue
		b.rise += RISE_ACC * dt
		b.jet *= exp(-dt / JET_FADE)
		b.inherit *= exp(-dt / b.inherit_tau)
		b.pos += (b.jet + b.inherit + b.radial + current + Vector3(0.0, b.rise, 0.0)) * dt
		b.angle += b.spin * dt
		keep.append(b)
	bubbles = keep


func _pick_cell(curls: bool) -> int:
	if curls and not lite and rng.randf() < CURL_SHARE:
		return 12 + rng.randi_range(0, 3)
	return rng.randi_range(0, 11)


func _spawn_rotor(side: int, ship: Transform3D, ship_vel: Vector3, spin: float, q: float) -> void:
	var b := Bubble.new()
	var sx := -1.0 if side == Src.LEFT else 1.0
	var back := spin >= 0.0                    # вперёд — струя назад (+Z корабля), реверс — вперёд
	var local := Vector3(sx * HullPlan.ENGINE_X, HullPlan.ENGINE_Y, EXIT_Z if back else FRONT_Z)
	var a := rng.randf() * TAU
	var off := Vector3(cos(a), sin(a), 0.0)    # поперёк струи — в плоскости XY корабля
	var r := rng.randf() * R0
	b.pos = ship * (local + off * r)
	var axis := ship.basis * Vector3(0.0, 0.0, 1.0 if back else -1.0)
	b.jet = axis * lerpf(JET.x, JET.y, q) * rng.randf_range(0.85, 1.15)
	b.inherit = ship_vel
	b.inherit_tau = rng.randf_range(INHERIT.x, INHERIT.y)
	b.life = LIFE_LITE if lite else rng.randf_range(LIFE.x, LIFE.y)
	b.radial = ship.basis * off * (SPREAD - R0) / b.life * rng.randf_range(0.3, 1.0)
	b.rise = rng.randf_range(RISE.x, RISE.y)
	b.cell = _pick_cell(true)
	var card := CURL_CARD if b.cell >= 12 else CARD
	b.size = rng.randf_range(card.x, card.y)
	b.angle = rng.randf() * TAU
	b.spin = 0.0 if lite else deg_to_rad(rng.randf_range(SPIN.x, SPIN.y)) * (1.0 if rng.randf() < 0.5 else -1.0)
	b.src = side
	bubbles.append(b)


func _spawn_vent(v: int, ship: Transform3D, ship_vel: Vector3) -> void:
	var b := Bubble.new()
	var a := rng.randf() * TAU
	var off := Vector3(cos(a), 0.0, sin(a)) * rng.randf() * R0
	b.pos = ship * (VENTS[v] + off)
	b.inherit = ship_vel
	b.inherit_tau = rng.randf_range(INHERIT.x, INHERIT.y)
	b.life = LIFE_LITE if lite else rng.randf_range(VENT_LIFE.x, VENT_LIFE.y)
	b.radial = ship.basis * off.normalized() * rng.randf_range(0.05, 0.25)
	b.rise = rng.randf_range(VENT_RISE.x, VENT_RISE.y)
	b.cell = _pick_cell(false)
	b.size = rng.randf_range(CARD.x, CARD.y)
	b.angle = rng.randf() * TAU
	b.spin = 0.0 if lite else deg_to_rad(rng.randf_range(SPIN.x, SPIN.y)) * (1.0 if rng.randf() < 0.5 else -1.0)
	b.src = Src.VENT_A + v
	bubbles.append(b)


## Видимость: появление 0,12 с, угасание в последнюю треть жизни, у льда — к нулю.
static func alpha(age: float, life: float, y: float = -100.0) -> float:
	var a := clampf(age / FADE_IN, 0.0, 1.0)
	var fo := life * FADE_OUT
	if age > fo:
		a *= clampf(1.0 - (age - fo) / maxf(life - fo, 1e-4), 0.0, 1.0)
	return a * clampf((Seabed.ICE_Y - y) / ICE_FADE, 0.0, 1.0)


## UV угла ячейки в атласе (размер ячейки — 1/GRID).
static func cell_uv(cell: int) -> Vector2:
	return Vector2(cell % GRID, cell / GRID) / float(GRID)
