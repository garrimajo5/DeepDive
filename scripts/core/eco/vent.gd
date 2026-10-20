class_name EcoVent
extends EcoSystem
## Чёрный курильщик — место 2 карты отмели (ART-012, docs/concept-art/kurilshchik.md; js/world.js «Чёрный курильщик»).
## Гидротермальный источник: главная труба — полый усечённый конус 9 м (основание Ø 8 м, верх Ø 3 м, просвет
## Ø 2,5 м), две малые трубы 4 м и 3 м, цоколь и две наплывные пластины. Кромки жерл светятся тёплым #FF8A3C,
## из жерл к самому льду идёт столб пузырей. Существ у источника нет (решение по ART-012); тёплая вода и перегрев
## реактора — у корабля (Reactor.near_vent, тот же центр). Геометрия неподвижна: мир только ставит её на дно
## и считает пузыри (одна формула здесь и в шейдере VentView — процессор пузыри не двигает).

const ID := "geyser"
## Центр главной трубы на карте отмели (karta-otmeli-mesta.json, место 2) — тот же, что Reactor.VENT_POS.
const CENTER := Vector2(-126.0, 45.0)
## Основания уходят в дно (цоколь заглублён на 0,5–1 м, чтобы не висеть на склоне).
const SINK := 0.6

## Труба: центр относительно CENTER (x, z), высота от дна под центром, радиус основания, радиус верха, глубина
## просвета под кромкой (внутренняя стенка и тёмное дно).
class Tube:
	extends RefCounted
	var at := Vector2.ZERO
	var height := 0.0
	var base_r := 0.0
	var top_r := 0.0
	var bore_r := 0.0
	var bore_depth := 0.0
	## Центр на дне (y — дно под центром) и середина жерла.
	var floor_c := Vector3.ZERO
	var mouth := Vector3.ZERO

## Главная труба 9 м (Ø 8 → Ø 3, просвет Ø 2,5) и малые — 4 м (Ø 4 → Ø 1,4) в (−5; −1), 3 м (Ø 3 → Ø 1) в (4; 3).
const TUBES: Array = [
	[Vector2(0, 0), 9.0, 4.0, 1.5, 1.25, 2.2],
	[Vector2(-5, -1), 4.0, 2.0, 0.7, 0.52, 0.9],
	[Vector2(4, 3), 3.0, 1.5, 0.5, 0.36, 0.7],
]
## Цоколь вокруг главной трубы: радиус снизу и сверху, высота над дном.
const PLINTH := [6.4, 4.4, 1.1]
## Наплывные пластины под малыми трубами: радиус и высота над дном.
const PLATES: Array = [[3.4, 0.6], [2.8, 0.5]]

## Пузыри: всего 180 (как в браузере), из главного жерла 150, малые — реже (по 15).
const BUBBLES := 180
const MAIN_BUBBLES := 150
## Скорость подъёма, м/с: главное жерло 2…5 (js: rr(2, 5)), малые — медленнее.
const MAIN_SPEED := Vector2(2.0, 5.0)
const SMALL_SPEED := Vector2(1.2, 2.5)
## Пузыри гаснут у льда (лёд — y 0).
const ICE_Y := -0.5
## Снос вбок у льда, м (у жерла — ноль, растёт с высотой).
const DRIFT := 1.6
## Размер пузыря у жерла и у льда, м (растёт с высотой).
const SIZE_LOW := 0.14
const SIZE_HIGH := 0.42
## Зерно пузырей (своё, чтобы не трогать случай мира).
const BUBBLE_SEED := 1261045

var tubes: Array[Tube] = []
## Высота дна (мир передаёт при сбросе; без дна — ровно −40 м).
var ground: Callable
## Пузыри: точка выхода (в жерле), скорость, фаза 0…1, высота столба до льда, своё число для сноса.
var b_origin := PackedVector3Array()
var b_speed := PackedFloat32Array()
var b_phase := PackedFloat32Array()
var b_height := PackedFloat32Array()
var b_seed := PackedFloat32Array()

var _center: Vector2


## center — своё место (для тестов), по умолчанию — с карты отмели.
func _init(center: Vector2 = CENTER) -> void:
	_center = center


func reset(world: EcoWorld) -> void:
	ground = world.ground
	tubes.clear()
	var y0 := floor_y(_center.x, _center.y)
	for t in TUBES:
		var tb := Tube.new()
		tb.at = t[0]
		tb.height = t[1]
		tb.base_r = t[2]
		tb.top_r = t[3]
		tb.bore_r = t[4]
		tb.bore_depth = t[5]
		var x := _center.x + tb.at.x
		var z := _center.y + tb.at.y
		tb.floor_c = Vector3(x, floor_y(x, z), z)
		# жерло главной трубы — над дном под центром места: столб пузырей и марево ровно над ним
		var base_y := (y0 if tubes.is_empty() else tb.floor_c.y) - SINK
		tb.mouth = Vector3(x, base_y + tb.height, z)
		tubes.append(tb)
	_place_bubbles()


## Дно под (x, z): мир передаёт Seabed.height; без него — −40 м.
func floor_y(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else -40.0


## Центр места на дне.
func center() -> Vector3:
	return Vector3(_center.x, floor_y(_center.x, _center.y), _center.y)


func _place_bubbles() -> void:
	var rnd := EcoRandom.new(BUBBLE_SEED)
	b_origin.resize(BUBBLES)
	b_speed.resize(BUBBLES)
	b_phase.resize(BUBBLES)
	b_height.resize(BUBBLES)
	b_seed.resize(BUBBLES)
	for i in BUBBLES:
		var tb := tubes[emitter(i)]
		var a := rnd.range_f(0.0, TAU)
		var r := sqrt(rnd.next()) * tb.bore_r * 0.8
		var o := tb.mouth + Vector3(cos(a) * r, -0.3, sin(a) * r)
		var sp := MAIN_SPEED if emitter(i) == 0 else SMALL_SPEED
		b_origin[i] = o
		b_speed[i] = rnd.range_f(sp.x, sp.y)
		b_phase[i] = rnd.next()
		b_height[i] = maxf(1.0, ICE_Y - o.y)
		b_seed[i] = rnd.next()


## Жерло, из которого выходит пузырь i: первые MAIN_BUBBLES — главное, остальные — малые через один.
static func emitter(i: int) -> int:
	return 0 if i < MAIN_BUBBLES else 1 + (i - MAIN_BUBBLES) % 2


## Доля пути пузыря i от жерла до льда в момент t (0…1, по кругу) — та же формула в шейдере VentView.
func bubble_f(i: int, t: float) -> float:
	return fposmod(b_phase[i] + t * b_speed[i] / b_height[i], 1.0)


## Где пузырь i в момент t: поднимается по столбу, у льда сносит вбок до DRIFT.
func bubble_pos(i: int, t: float) -> Vector3:
	var f := bubble_f(i, t)
	var s := b_seed[i] * TAU
	var o := b_origin[i]
	return Vector3(o.x + sin(t * 0.9 + s) * DRIFT * f, o.y + f * b_height[i], o.z + cos(t * 0.7 + s) * DRIFT * f)


## Размер пузыря на доле пути f: растёт с высотой.
static func bubble_size(f: float) -> float:
	return lerpf(SIZE_LOW, SIZE_HIGH, f)


## Непрозрачность на доле пути f: прозрачнее с высотой, появляется в жерле и гаснет у льда.
static func bubble_alpha(f: float) -> float:
	return 0.85 * (1.0 - 0.6 * f) * smoothstep(0.0, 0.03, f) * (1.0 - smoothstep(0.9, 1.0, f))


## Мерцание кромки жерла 0…1 в момент t: тёплое, с небольшой нерегулярной амплитудой (без вспышек) — так же в шейдере.
static func flicker(t: float) -> float:
	return 0.8 + 0.1 * sin(t * 2.3) + 0.06 * sin(t * 5.7 + 1.3) + 0.04 * sin(t * 13.1 + 0.4)


## Точка (в мире) внутри главной трубы или цоколя — грубо, по конусу (для существ и проверок).
func solid(p: Vector3) -> bool:
	for tb in tubes:
		var h := p.y - (tb.floor_c.y - SINK)
		if h < 0.0 or h > tb.height:
			continue
		var r := lerpf(tb.base_r, tb.top_r, h / tb.height)
		if Vector2(p.x - tb.floor_c.x, p.z - tb.floor_c.z).length() < r:
			return true
	return false
