class_name Samples
extends RefCounted
## Образцы на дне и лебёдка трюма (js/manip.js, Unity Core/Samples.cs; ART-010, модели MOD-010 — docs/concept-art/tryum.md).
## 14 образцов лежат там же, где в браузерной версии (у пятен мха, папоротников, станций огнецвета, норы кольчужника).
## Пост «Лебёдка» у опоры за кормовой кромкой проёма: при открытом шлюзе удержание кнопки 1,4 с — захват уходит
## к ближайшему образцу ниже шлюза не дальше 14 м и берёт его, ещё 1,2 с — подъём, образец ложится в трюм.
## Отпустил раньше — захват возвращается.

enum Kind { MOSS, SHELL, CORAL, SPINE }
enum State { IDLE, REACH, BACK }

const REACH := 14.0
const GRAB_TIME := 1.4
const BACK_TIME := 1.2
const NAMES := ["Светящийся мох", "Ракушка моллюска", "Ветка огнецвета", "Игла шипоежа"]
const COLORS := [Color("9dffd0"), Color("e8c9a8"), Color("ff8a3c"), Color("8cdcff")]

## Места из браузерной версии (оси Godot = оси прототипа): вид, x, z, подъём над дном.
const PLACES := [
	[Kind.MOSS, 31.63, 94.44, 0.15], [Kind.MOSS, -24.62, -79.71, 0.15], [Kind.MOSS, -111.67, 74.62, 0.15],
	[Kind.MOSS, -42.46, 34.77, 0.15], [Kind.MOSS, -24.08, 173.59, 0.15], [Kind.MOSS, 110.62, -20.3, 0.15],
	[Kind.MOSS, 19.51, 22.68, 0.15], [Kind.MOSS, 117.75, -47.64, 0.15],
	[Kind.SHELL, 13.33, 76.45, 0.1], [Kind.SHELL, -67.48, 83.59, 0.1],
	[Kind.CORAL, -55.35, 23.24, 0.15], [Kind.CORAL, 34.9, 57.2, 0.15], [Kind.CORAL, 56.48, -68.29, 0.15],
	[Kind.SPINE, -52.04, 84.95, 0.1],
]

## Лебёдка в осях корабля (tryum.md, MOD-010): опора у кормовой кромки проёма, барабан на конце стрелы над центром
## проёма, захват в покое висит в трюме над проёмом (pivot — крепление троса сверху).
const BASE := Vector3(-0.6, 0.0, 23.1)
const DRUM := Vector3(0.0, 2.4, Airlock.Z)
const DRUM_R := 0.18
const REST := Vector3(0.0, 1.1, Airlock.Z)
const COLUMN_R := 0.4                       ## колонна опоры — препятствие на полу
const POST_AT := Vector2(-0.6, 23.1)
const POST_R := 1.1

class Sample:
	var i := 0
	var kind := Kind.MOSS
	var pos := Vector3.ZERO     ## в мире
	var taken := false

	func _init(n: int, k: Kind, p: Vector3) -> void:
		i = n
		kind = k
		pos = p

	func title() -> String:
		return NAMES[kind]


var all: Array[Sample] = []
var cargo: Array = []          ## груз трюма: [вид, номер образца со дна или −1]
var got := {}                  ## номера образцов, поднятых со дна (даже если груз потрачен)
var state := State.IDLE
var target: Sample = null
var progress := 0.0            ## захват 0…1 за GRAB_TIME удержания
var version := 0               ## растёт при каждом изменении того, что лежит на дне (для перерисовки)
var cargo_rev := 0             ## растёт при каждом изменении груза и поднятых (экран журнала лаборатории, #847)
var stolen := {}               ## номера образцов, сорванных с захвата (EcoLink.STEAL): не на дне и не в грузе
var _ground: Callable
var _back := 0.0
var _holding := false

signal message(text: String)
signal changed                 ## груз или поднятые образцы — то, что сохраняется


func _init(ground: Callable = Callable()) -> void:
	if not ground.is_valid():
		ground = Seabed.height
	_ground = ground
	for n in PLACES.size():
		all.append(Sample.new(n, PLACES[n][0], _home(n)))


## Где образец n лежит с начала (PLACES).
func _home(n: int) -> Vector3:
	var p: Array = PLACES[n]
	var x: float = p[1]
	var z: float = p[2]
	return Vector3(x, float(_ground.call(x, z)) + float(p[3]), z)


## Корабль в мире: позиция и курс (как узел «Корабль»: rotation.y = yaw).
static func ship_xform(pos: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)


## Центр крышки шлюза в мире.
static func lock_point(ship: Transform3D) -> Vector3:
	return ship * Vector3(0.0, Airlock.Y, Airlock.Z)


## Ближайший образец ниже шлюза и не дальше REACH; null — дотянуться не до чего.
func find(lock: Vector3) -> Sample:
	var best: Sample = null
	var bd := REACH
	for s in all:
		if s.taken or s.pos.y >= lock.y:
			continue
		var d := s.pos.distance_to(lock)
		if d <= bd:
			bd = d
			best = s
	return best


## Кадр удержания кнопки у лебёдки: захват тянется к образцу; на полном захвате образец поднимается.
func hold(lock: Vector3, dt: float) -> void:
	if state == State.BACK:
		return
	var s := target if state == State.REACH and target else find(lock)
	if s == null:
		return
	if target != s:
		target = s
		progress = 0.0
	state = State.REACH
	_holding = true
	progress = minf(1.0, progress + dt / GRAB_TIME)
	if progress >= 1.0:
		state = State.BACK
		_back = BACK_TIME
		s.taken = true
		version += 1
		message.emit("Образец захвачен")


func update(dt: float) -> void:
	if state == State.REACH and not _holding:
		progress = maxf(0.0, progress - dt * 2.0)
		if progress <= 0.0:
			state = State.IDLE
			target = null
	elif state == State.BACK:
		_back -= dt
		if _back <= 0.0:
			_stow()
	_holding = false


func _stow() -> void:
	var s := target
	state = State.IDLE
	target = null
	progress = 0.0
	_back = 0.0
	cargo.append([s.kind, s.i])
	got[s.i] = true
	cargo_rev += 1
	changed.emit()
	message.emit("В трюме: %s (образцов %d)" % [s.title().to_lower(), cargo.size()])


func carrying() -> bool:
	return state == State.BACK


## Доля подъёма от дна (0) до трюма (1).
func lift() -> float:
	return 1.0 - maxf(0.0, _back) / BACK_TIME if state == State.BACK else 0.0


## Насколько захват ушёл к образцу: 0 — в трюме, 1 — у образца.
func reach_k() -> float:
	if target == null:
		return 0.0
	return progress if state == State.REACH else 1.0 - lift()


## Захват (крепление троса) в осях корабля.
func hook_local(ship: Transform3D) -> Vector3:
	if target == null:
		return REST
	return REST.lerp(ship.affine_inverse() * (target.pos + Vector3(0.0, 0.35, 0.0)), reach_k())


## Подпись на кнопке у лебёдки.
func label() -> String:
	match state:
		State.BACK:
			return "Поднимаю…"
		State.REACH:
			return "Захват %d%%" % int(progress * 100.0)
	return "Лебёдка"


## Нажатие у лебёдки: почему захват не пойдёт (пустая строка — пойдёт, держать кнопку).
func why_not(lock_open: bool, lock: Vector3) -> String:
	if state != State.IDLE:
		return ""
	if not lock_open:
		return "Сначала открыть шлюз"
	if find(lock) == null:
		return "Под шлюзом нет образцов ближе %d м" % int(REACH)
	return ""


## Все образцы снова на дне, трюм пуст.
func reset() -> void:
	for s in all:
		s.taken = false
		s.pos = _home(s.i)
	stolen.clear()
	cargo.clear()
	got.clear()
	state = State.IDLE
	target = null
	progress = 0.0
	_back = 0.0
	_holding = false
	version += 1
	cargo_rev += 1
	changed.emit()


## Из сохранения (как M.restore в js/manip.js): поднятые образцы убраны со дна; груз — по порядку, образец со дна
## принимается, только если номер есть, вид совпадает и он ещё не лежит в трюме.
func restore(got_list: Array, cargo_list: Array) -> void:
	for s in all:
		s.taken = false
		s.pos = _home(s.i)
	stolen.clear()
	cargo.clear()
	got.clear()
	state = State.IDLE
	target = null
	progress = 0.0
	_back = 0.0
	for n in got_list:
		if typeof(n) in [TYPE_INT, TYPE_FLOAT] and int(n) >= 0 and int(n) < all.size():
			all[int(n)].taken = true
			got[int(n)] = true
	var used := {}
	for c in cargo_list:
		if not (c is Array) or c.size() < 2 or int(c[0]) < 0 or int(c[0]) >= NAMES.size():
			continue
		var k := int(c[0])
		var n := int(c[1])
		if n >= 0:
			if n >= all.size() or all[n].kind != k or used.has(n):
				continue
			used[n] = true
			all[n].taken = true
			got[n] = true
		cargo.append([k, n if n >= 0 else -1])
	version += 1
	cargo_rev += 1


## Захват (крепление троса) в мире — для живого мира (EcoLink.ShipState.claw).
func hook_world(ship: Transform3D) -> Vector3:
	return ship * hook_local(ship)


## Образец n сорван с захвата на подъёме (EcoLink.STEAL, js/manip.js M.steal): захват пуст, образец не в груз,
## на дне его нет. false — захват не поднимает этот образец (событие опоздало).
func steal(n: int) -> bool:
	if state != State.BACK or target == null or target.i != n:
		return false
	stolen[n] = true
	state = State.IDLE
	target = null
	progress = 0.0
	_back = 0.0
	version += 1
	return true


## Унесённый образец n брошен в точке at (EcoLink.DROP, M.drop): снова лежит на дне, 0,15 м над ним.
func drop(n: int, at: Vector3) -> bool:
	if not stolen.has(n):
		return false
	stolen.erase(n)
	var s := all[n]
	s.taken = false
	s.pos = Vector3(at.x, float(_ground.call(at.x, at.z)) + 0.15, at.z)
	version += 1
	return true


## Колонна опоры лебёдки на полу трюма.
static func blocks(x: float, z: float, r: float) -> bool:
	return Vector2(x, z).distance_to(Vector2(BASE.x, BASE.z)) < COLUMN_R + r
