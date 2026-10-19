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
## Как быстро скорость догоняет желаемую (1/с): 1,1 обычно, 1,6 в броске.
var agility := 1.1
## Высота над дном, ниже которой не опускается.
var clearance := 1.8
## Потолок по Y (подо льдом).
var ceiling := -4.0
## Кого преследует или от кого бежит. Слабая ссылка: хищник и добыча смотрят друг на друга, а держит существ мир.
var target: EcoAgent:
	get:
		return _target.get_ref() if _target else null
	set(value):
		_target = weakref(value) if value else null

var _target: WeakRef


## Неизвестный вид (нет в Species) — предупреждение, существо сразу неживое: мир его не двигает.
func _init(species_id: String, pos: Vector3) -> void:
	species = species_id
	if not Species.has(species_id):
		push_warning("EcoAgent: нет вида «%s»" % species_id)
		alive = false
	p = pos
	home = pos
	goal = pos


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
	v = v.lerp(want, minf(1.0, dt * agility))
	p += v * dt
	confine(ground)


## Не под дном, не выше потолка, не за краем отмели (как после шага серпохвоста).
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
