class_name EcoAgent
extends RefCounted
## Существо в симуляции (Unity `Core/EcoAgent.cs`): место, скорость, цель, состояние и таймер. Движение — как у серпохвоста
## в js/creatures.js: скорость плавно (lerp) тянется к желаемой, у цели замедляется, существо не уходит под дно
## (clearance над рельефом), выше потолка (ceiling) и за край отмели (±EDGE). Оси мира Godot, как в браузере.

## Пять общих состояний, к которым сводятся слова видов в браузере.
enum State {
	GRAZE,  ## пасётся или бродит у дома (patrol, graze, walk, swim)
	SEEK,   ## идёт к цели: месту, кораблю, свету (investigate, curious, home, return, back)
	HUNT,   ## охотится: преследует добычу или бросается на неё (hunt, stalk, strike, charge)
	FLEE,   ## убегает от угрозы (flee, retreat)
	HIDE,   ## прячется и не двигается (hide, den, rock)
}

## Край отмели по X и Z (clampArea).
const EDGE := 290.0

var species: String
var p := Vector3.ZERO      ## место
var v := Vector3.ZERO      ## скорость
var goal := Vector3.ZERO   ## куда плывёт
var home := Vector3.ZERO   ## дом
var state: State = State.GRAZE
## Секунды до конца текущего состояния (уменьшается в tick, не ниже нуля).
var timer := 0.0
var alive := true
## Крупный вид (`EcoField.BIG`): у пограничного поля на западе разворачивается (#833).
var big := false
## Как быстро скорость догоняет желаемую (1/с): 1,1 обычно, 1,6 в броске.
var agility := 1.1
## Высота над дном, ниже которой не опускается.
var clearance := 1.8
## Потолок по Y (подо льдом).
var ceiling := -4.0
## На сколько секунд хода вперёд смотрит на дно (0 — не смотрит): подъём дна впереди — набирает высоту заранее
## (`climb_for`), а не взлетает по склону вплотную ко дну. Серпохвост — `EcoPred.LOOK`.
var look := 0.0
## Кого преследует или от кого бежит. Слабая ссылка: хищник и добыча смотрят друг на друга, а держит существ мир.
var target: EcoAgent:
	get:
		return _target.get_ref() if _target else null
	set(value):
		_target = weakref(value) if value else null

var _target: WeakRef

## Высота дна под существом запоминается: дно пересчитывается (ground.call — fbm Seabed.height, дорого), только когда
## существо отплыло дальше GROUND_STEP по горизонтали или сменился сам ground. Сетка дна в сцене — 5 м, отличие ≤ 0,15 м.
## Для мелких и многочисленных (светляки); confine смотрит дно точно — серпохвост не уходит под него ни на сантиметр.
const GROUND_STEP := 0.25
var _gx := INF
var _gz := INF
var _gh := 0.0
var _gcall: Callable


## Неизвестный вид (нет в Species) — предупреждение, существо сразу неживое: мир его не двигает.
func _init(species_id: String, pos: Vector3) -> void:
	species = species_id
	if not Species.has(species_id):
		push_warning("EcoAgent: нет вида «%s»" % species_id)
		alive = false
	p = pos
	home = pos
	goal = pos
	big = EcoField.is_big(species_id)


## Сменить состояние на t секунд.
func set_state(s: State, t: float = 0.0, who: EcoAgent = null) -> void:
	state = s
	timer = t
	target = who


## Таймер состояния истёк.
func expired() -> bool:
	return timer <= 0.0


func tick(dt: float) -> void:
	timer = maxf(0.0, timer - dt)


func distance_to(q: Vector3) -> float:
	return p.distance_to(q)


## Плыть к точке со скоростью speed; ближе к цели — медленнее (не проскакивает).
func steer_to(to: Vector3, speed: float, dt: float, ground: Callable = Callable()) -> void:
	goal = to
	var d := to - p
	var l := d.length()
	var want := d * (minf(speed, l * 1.5) / l) if l > 0.01 else Vector3.ZERO
	drive(want, dt, ground)


## Плыть прочь от точки по горизонтали со скоростью speed.
func steer_away(from: Vector3, speed: float, dt: float, ground: Callable = Callable()) -> void:
	var d := p - from
	d.y = 0.0
	if d.length_squared() < 1e-4:
		d = Vector3(1, 0, 0)
	d = d.normalized()
	goal = p + d * 20.0
	drive(d * speed, dt, ground)


## Стоять: скорость гаснет.
func hold(dt: float, ground: Callable = Callable()) -> void:
	drive(Vector3.ZERO, dt, ground)


## Скорость тянется к want, затем шаг и ограничения.
func drive(want: Vector3, dt: float, ground: Callable = Callable()) -> void:
	var need := climb_for(ground) if look > 0.0 and ground.is_valid() else -INF
	v = v.lerp(want, minf(1.0, dt * agility))
	if need > v.y:  # дно впереди выше: вверх — не быстрее LOOK_ACCEL, но не медленнее lerp
		v.y = minf(need, v.y + LOOK_ACCEL * dt)
	p += v * dt
	confine(ground)


## Как drive, но ход по горизонтали поворачивает, а не проходит через ноль (Б3, «плавность»): курс скорости
## догоняет курс want долей угла turn_k/с, не быстрее turn_max рад/с, величина тянется (lerp agility) к |want|,
## в крутом повороте — к |want| · cos угла, не меньше slow_min доли. Раньше lerp векторов на развороте (цель патруля
## за спиной) гасил ход до нуля и разгонял обратно: серпохвост ~1 с плыл хвостом вперёд, пока нос доворачивал.
## Вертикаль — как в drive (lerp и подъём перед дном). Почти стоит — курс сразу по want.
func swim(want: Vector3, dt: float, turn_k: float, turn_max: float, slow_min: float,
		ground: Callable = Callable()) -> void:
	var k := minf(1.0, dt * agility)
	var vf := Vector2(v.x, v.z)
	var wf := Vector2(want.x, want.z)
	var s_now := vf.length()
	var s_want := wf.length()
	var flat := Vector2.ZERO
	if s_want < 1e-4:
		flat = vf.lerp(Vector2.ZERO, k)
	elif s_now < SWIM_STILL:
		flat = vf.lerp(wf, k)
	else:
		var da := vf.angle_to(wf)
		var step := signf(da) * minf(absf(da) * minf(1.0, turn_k * dt), turn_max * dt)
		var dir := vf.rotated(step) / s_now
		var s_goal := s_want * maxf(cos(da), slow_min)
		flat = dir * lerpf(s_now, s_goal, k)
	# в повороте путь идёт дугой к курсу want: дно впереди смотрим и по нему, с нынешним ходом
	var turn := Vector3.ZERO
	if s_want >= 1e-4 and flat.length_squared() > 1e-6 and absf(flat.angle_to(wf)) > 0.05:
		turn = Vector3(wf.x, 0.0, wf.y) * (flat.length() / s_want)
	v = Vector3(flat.x, v.y, flat.y)
	var need := climb_for(ground, turn) if look > 0.0 and ground.is_valid() else -INF
	v.y = lerpf(v.y, want.y, k)
	if need > v.y:
		if need > v.y + LOOK_ACCEL * dt:  # вверх не успевает: и по горизонтали тормозит, как в drive lerp
			var fs := flat.length()
			if fs > SWIM_STILL:
				var slow := maxf(fs - LOOK_ACCEL * dt, SWIM_STILL) / fs
				v.x *= slow
				v.z *= slow
		v.y = minf(need, v.y + LOOK_ACCEL * dt)
	p += v * dt
	confine(ground)


## Медленнее этого (м/с) ход ещё не держит курс: swim тянет его к want, как drive.
const SWIM_STILL := 0.3


## Доли look, на которых смотрит дно впереди, и запас над clearance там.
const LOOK_AT := [0.1, 0.2, 0.3, 0.45, 0.6, 0.8, 1.0]
const LOOK_GAP := 0.6
## Разгон вверх перед подъёмом дна, м/с².
const LOOK_ACCEL := 8.0

## Вертикальная скорость, с которой к каждой точке пути впереди (горизонтальный ход за долю LOOK_AT от look) существо
## уже будет на clearance + LOOK_GAP над дном. Отрицательная — вниз не быстрее её: в нырке к дну тормозит заранее.
## Высоко над дном (дальше, чем подъём 1:1 на всём пути и запас) — не смотрит: −INF без лишних вызовов дна.
## turn — ход, к которому поворачивает (`swim`): путь дугой смотрит и по нему.
func climb_for(ground: Callable, turn := Vector3.ZERO) -> float:
	var flat := Vector3(v.x, 0.0, v.z)
	var need := -INF
	if p.y - ground_y(ground) - clearance > flat.length() * look + 2.0 - minf(v.y, 0.0) * look:
		return need
	for f: float in LOOK_AT:
		var t := look * f
		var q := p + flat * t
		var top: float = float(ground.call(q.x, q.z)) + clearance + LOOK_GAP
		need = maxf(need, (top - p.y) / t)
	if turn != Vector3.ZERO:
		for f: float in LOOK_AT:
			var t := look * f
			var q := p + turn * t
			var top: float = float(ground.call(q.x, q.z)) + clearance + LOOK_GAP
			need = maxf(need, (top - p.y) / t)
	return need


## Высота дна под существом (ground — (x, z) -> float, должен быть задан): из запомненной, пока не отплыло
## дальше GROUND_STEP.
func ground_y(ground: Callable) -> float:
	var dx := p.x - _gx
	var dz := p.z - _gz
	if dx * dx + dz * dz > GROUND_STEP * GROUND_STEP or ground != _gcall:
		_gx = p.x
		_gz = p.z
		_gh = ground.call(p.x, p.z)
		_gcall = ground
	return _gh


## Не под дном, не выше потолка, не за краем отмели (как после шага серпохвоста); крупные — не в поясе поля (#833).
func confine(ground: Callable = Callable()) -> void:
	if ground.is_valid():
		var floor_y: float = ground.call(p.x, p.z) + clearance
		if p.y < floor_y:
			p.y = floor_y
			if v.y < 0.0:
				v.y *= -0.3
	if p.y > ceiling:
		p.y = ceiling
	p.x = clampf(p.x, -EDGE, EDGE)
	p.z = clampf(p.z, -EDGE, EDGE)
	if big and p.x < EcoField.BELT_IN:
		EcoField.turn_back(self)


## Курс по дну from доворачивает к want за dt вокруг вертикали: доля угла k/с, не быстрее max_rate рад/с
## (донные — кольчужник, скальник). Ровно назад — разворот в одну сторону, а не через ноль: lerp векторов
## навстречу проходил через нулевой курс, и тело щёлкало носом. Без вертикали; нулевой want — курс тот же.
static func turn_flat(from: Vector3, want: Vector3, dt: float, k: float, max_rate: float) -> Vector3:
	var w := Vector3(want.x, 0.0, want.z)
	if w.length_squared() < 1e-8:
		return from
	w = w.normalized()
	var f := Vector3(from.x, 0.0, from.z)
	if f.length_squared() < 1e-8:
		return w
	f = f.normalized()
	var ang := atan2(f.cross(w).y, f.dot(w))   # со знаком: + — влево (вокруг +Y)
	if absf(ang) < 1e-4:
		return w
	var step := signf(ang) * minf(absf(ang) * minf(1.0, k * dt), max_rate * dt)
	return f.rotated(Vector3.UP, step).normalized()
