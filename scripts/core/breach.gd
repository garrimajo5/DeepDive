class_name Breach
extends RefCounted
## Событие «пробоина» (js/breach.js; концепт ART-013, модели MOD-013 — docs/concept-art/proboina.md).
## Сильный удар по корпусу (от 10 %) пробивает борт в одном из четырёх мест: из отверстия бьёт струя, пол отсека
## заливает (до 0,45 м — по колено), корпус слабеет 0,6 %/с (не ниже 15 %), плафоны отсека пульсируют янтарём.
## Заваривают удержанием кнопки действия у пробоины (28 %/с — около 3,6 с): заплатка растёт с прогрессом, после —
## шов #F18A3D остывает за 4 с. Воду потом откачивают насосы: 0,02 м/с × доля «Жизнеобеспечение».
## Следующая пробоина — не раньше чем через 45 с после прошлой.

const HIT_MIN := 10           ## удар слабее (в %) борт не пробивает
const COOLDOWN := 45.0
const WELD_RATE := 0.28       ## доля шва в секунду удержания
const WATER_RISE := 0.016     ## м/с
const WATER_MAX := 0.45       ## по колено (ART-013)
const PUMP := 0.02            ## м/с при полной доле жизнеобеспечения
const HULL_DRAIN := 0.6       ## %/с, пока открыта
const HULL_FLOOR := 15.0
const SEAM_COOL := 4.0        ## с — шов остывает после сварки
const SLOW_WATER := 0.2       ## вода выше — идти тяжелее
const SLOW := 0.55
const POST_R := 1.0
## Щиток сварщика (ART-014, `ekipazh-inzhener.jpg`): свой игрок, пока варит, смотрит сквозь опущенный щиток —
## экран затемнён цветом тени #0B1C24, искры и свет сварки сквозь него видны: яркое (самый сильный канал выше
## VISOR_KNEE.x) затемняется слабее, выше VISOR_KNEE.y — не затемняется и не тонируется (по issue #530 — раньше
## щиток ровно смешивал весь кадр с тенью, и янтарные искры ART-072 становились бледными и белёсыми).
## Двойник шейдера `shaders/visor.gdshader` — `visor_pass`.
const VISOR := Color(0.043, 0.11, 0.141, 0.6)
const VISOR_KNEE := Vector2(0.75, 0.95)
## Струя (BreachView): из отверстия по нормали со скоростью JET_V, чуть вверх (JET_UP), падает с ускорением JET_G.
const JET_V := 3.6
const JET_UP := 0.15
const JET_G := 6.0

## Место пробоины в осях корабля: точка на внутренней поверхности борта (y = 1 м), нормаль внутрь отсека,
## где стоять со сваркой, имя для приборов и пол отсека, который заливает (x0, z0, x1, z1).
class Spot:
	var room := 0
	var name := ""
	var p := Vector3.ZERO
	var n := Vector3.ZERO
	var at := Vector2.ZERO
	var floor := Rect2()

	func _init(r: int, nm: String, pos: Vector3, nrm: Vector3, stand: Vector2, fl: Rect2) -> void:
		room = r
		name = nm
		p = pos
		n = nrm
		at = stand
		floor = fl


## Места — из issue #5 и js/breach.js: мостик (левый борт), коридор (правый), лаборатория (носовая переборка),
## машинное (левый борт).
static func spots() -> Array[Spot]:
	var r := ShipLayout.ROOMS
	var cor: Array = r[ShipLayout.Room.CORRIDOR]
	var lab: Array = r[ShipLayout.Room.LAB]
	var eng: Array = r[ShipLayout.Room.ENGINE]
	return [
		Spot.new(ShipLayout.Room.BRIDGE, "мостик", Vector3(-4.9, 1.0, -3.4), Vector3.RIGHT, Vector2(-4.0, -3.4),
			Rect2(-4.9, -5.8, 9.8, 7.7)),
		Spot.new(ShipLayout.Room.CORRIDOR, "коридор", Vector3(1.0, 1.0, 5.0), Vector3.LEFT, Vector2(0.2, 5.0),
			_room_floor(cor)),
		Spot.new(ShipLayout.Room.LAB, "лаборатория", Vector3(-2.6, 1.0, 8.1), Vector3.BACK, Vector2(-2.6, 8.9),
			_room_floor(lab)),
		Spot.new(ShipLayout.Room.ENGINE, "машинное отделение", Vector3(-2.9, 1.0, 18.6), Vector3.RIGHT, Vector2(-2.1, 18.6),
			_room_floor(eng)),
	]


static func _room_floor(a: Array) -> Rect2:
	var hw: float = a[2]
	return Rect2(-hw + 0.1, float(a[0]) + 0.1, 2.0 * hw - 0.2, float(a[1]) - float(a[0]) - 0.2)


var all: Array[Spot] = spots()
var active: Spot = null       ## открытая пробоина
var last: Spot = null         ## где была последняя (там заплатка и шов)
var count := 0
var cd := 0.0
var weld := 0.0               ## 0…1
var welding := false          ## в этот шаг держат кнопку
var water := 0.0              ## м над полом
var water_spot: Spot = null   ## чей отсек залит
var seam_heat := 0.0          ## 1 — шов только что заварен, 0 — остыл
var time := 0.0

signal message(text: String)


func reset() -> void:
	active = null
	last = null
	count = 0
	cd = 0.0
	weld = 0.0
	welding = false
	water = 0.0
	water_spot = null
	seam_heat = 0.0


## Удар по корпусу на percent %: пробьёт ли борт. Возвращает true, если пробоина открылась.
func on_hit(percent: int, hull: float) -> bool:
	if percent < HIT_MIN or active != null or cd > 0.0 or hull <= 0.0:
		return false
	start(all[count % all.size()])
	return true


func start(spot: Spot) -> void:
	active = spot
	last = spot
	count += 1
	weld = 0.0
	welding = false
	seam_heat = 0.0
	cd = COOLDOWN
	if water_spot != spot:
		water = 0.0
		water_spot = spot
	message.emit("Пробоина: %s — держите «Сварка» у пробоины" % spot.name)


## Кадр удержания кнопки у пробоины: шов прирастает; на 100 % пробоина закрыта.
func hold(dt: float) -> void:
	if active == null:
		return
	welding = true
	weld = minf(1.0, weld + dt * WELD_RATE)
	if weld >= 1.0:
		var s := active
		active = null
		welding = false
		seam_heat = 1.0
		message.emit("Шов заварен: %s. Насосы откачивают воду" % s.name)


## Шаг: вода, корпус, остывание шва. k_life — доля «Жизнеобеспечение» (насосы). Возвращает новую прочность корпуса.
func update(dt: float, k_life: float, hull: float) -> float:
	time += dt
	cd = maxf(0.0, cd - dt)
	if active:
		water = minf(WATER_MAX, water + dt * WATER_RISE)
		if hull > HULL_FLOOR:
			hull = maxf(HULL_FLOOR, hull - dt * HULL_DRAIN)
	else:
		water = maxf(0.0, water - dt * PUMP * k_life)
		seam_heat = maxf(0.0, seam_heat - dt / SEAM_COOL)
	if water <= 0.0 and active == null:
		water_spot = null
	return hull


## Сколько в этот шаг держали сварку — сбросить (держат кнопку — выставят снова в следующем шаге).
func end_step() -> void:
	welding = false


## Множитель шага: по щиколотку и выше в залитом отсеке идти тяжелее.
func slow(room: int) -> float:
	return SLOW if water_spot and water_spot.room == room and water > SLOW_WATER else 1.0


## Тревога: 0…1, мягкая пульсация плафонов (0,5 с туда-обратно), пока пробоина открыта.
func alarm() -> float:
	if active == null:
		return 0.0
	return 0.5 + 0.5 * sin(time * TAU / 1.0)


## Часть строки приборов: «ПРОБОИНА · МОСТИК · вода 12 см» или «Вода: мостик 8 см».
func status() -> String:
	if active:
		return "ПРОБОИНА · %s · вода %d см" % [active.name.to_upper(), roundi(water * 100.0)]
	if water_spot and water > 0.005:
		return "Вода: %s %d см" % [water_spot.name, roundi(water * 100.0)]
	return ""


## Куда бьёт струя: расстояние от борта по нормали (м) до точки, где она падает на воду (или на пол), не дальше
## противоположной стены отсека. Там — брызги у кромки воды.
static func jet_reach(s: Spot, water_h: float) -> float:
	var d := Vector3(0.0, JET_UP, 1.0).normalized() * JET_V
	var drop := s.p.y - water_h
	var t := (d.y + sqrt(d.y * d.y + 2.0 * JET_G * drop)) / JET_G
	return minf(d.z * t, _across(s) - 0.15)


## Ширина отсека от точки пробоины по нормали до противоположной кромки пола.
static func _across(s: Spot) -> float:
	var f := s.floor
	var n := Vector2(s.n.x, s.n.z)
	var p := Vector2(s.p.x, s.p.z)
	var best := 100.0
	if absf(n.x) > 1e-4:
		best = minf(best, ((f.end.x if n.x > 0.0 else f.position.x) - p.x) / n.x)
	if absf(n.y) > 1e-4:
		best = minf(best, ((f.end.y if n.y > 0.0 else f.position.y) - p.y) / n.y)
	return best


## Подпись на кнопке у пробоины.
func label() -> String:
	return "Сварка %d%%" % int(weld * 100.0) if weld > 0.0 else "Сварка"


## Пост у открытой пробоины (id "breach"): где стоять.
func post_at() -> Vector2:
	return active.at if active else Vector2(1e6, 1e6)


## Цвет пикселя сквозь щиток сварщика (двойник `shaders/visor.gdshader`): тёмное — к тени VISOR с её долей,
## яркое (искры, вспышка электрода, шов) проходит как есть.
static func visor_pass(c: Color) -> Color:
	var l := maxf(c.r, maxf(c.g, c.b))
	var t := clampf((l - VISOR_KNEE.x) / (VISOR_KNEE.y - VISOR_KNEE.x), 0.0, 1.0)
	var keep := t * t * (3.0 - 2.0 * t)
	return c.lerp(Color(VISOR.r, VISOR.g, VISOR.b), VISOR.a * (1.0 - keep))
