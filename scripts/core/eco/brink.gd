class_name EcoBrink
extends EcoSystem
## Граница у Спуска 10 (#832, часть 3; место 10 слоя 1 — `LayerMap.POINTS["10"]`, схема #818): дно котловины склона
## `Seabed.Slope` к востоку меняет материал и свет — тёмная порода обрастает **кварцевой коркой**: друзы бледных
## кристаллов, к востоку гуще и крупнее, кончики слабо светятся холодным светом. Это готовит Кристальный лес
## («кристаллы обросли излучатели поля», `docs/world.md`) без его существ: минерал, не вид бестиария, — ни шага, ни
## целей сонара и сканера. Граница — волнистая линия поперёк котловины у `BORDER_X`; западнее (проход 60 м и склон)
## корки нет. Друзы ниже корабля: верх — не выше `MAX_H` над дном, у оси подхода к 10 — ниже `AXIS_H`.
## Расклад свой, от зерна мира не зависит; встаёт на дно при сбросе мира. Вид — `BrinkView` (один меш).

const ID := "brink"
## Середина места 10 (x, z) — та же точка, что `LayerMap.xz("10")`.
const CENTER := Vector2(560.0, 200.0)
## Граница корки: средняя линия x, волна ± `WAVE` м по z (шум, шаг `WAVE_SCALE`); к полной корке — за `FULL` м.
const BORDER_X := 525.0
const WAVE := 10.0
const WAVE_SCALE := 0.03
const FULL := 70.0
## Участок раскладки (x от, z от, ширина, глубина) и шаг сетки кандидатов, м; доля дна котловины не меньше `MASK`
## (на стенах котловины корки нет — там дно не по склону).
const AREA := Rect2(490.0, 110.0, 180.0, 180.0)
const STEP := 6.0
const MASK := 0.7
## Корка пятнами, не ровным ковром: шум шага `PATCH_SCALE`, пороги доли пятна (ниже первого — голая порода).
const PATCH_SCALE := 0.045
const PATCH := Vector2(0.38, 0.62)
## Сколько кандидатов при полной корке становятся друзами; предел числа друз.
const DENSITY := 0.9
const MAX := 400
## Размер друзы (м, высота кристаллов до ≈ 1,8 размера): у границы мелкие, к востоку до `SIZE.y`.
const SIZE := Vector2(0.6, 2.2)
## У оси подхода к 10 (|z − ось| < `AXIS_HALF`, x до `AXIS_TO`) друзы мельче — корабль спускается над ними.
const AXIS_HALF := 24.0
const AXIS_TO := 600.0
const AXIS_SIZE := 1.1
## Высота кристалла на единицу размера (наибольшая) и пределы верха над дном, м.
const TALL := 1.8
const MAX_H := 4.5
const AXIS_H := 2.2
## Свечение кончиков: у границы и при полной корке (доля альфы обрастания общего шейдера камня).
const GLOW := Vector2(0.2, 1.0)

## Высота дна (мир передаёт при сбросе; без дна — ровно −300 м).
var ground: Callable
## Друзы: (x, y дна, z, размер) и доля корки там (0…1) — по порядку раскладки.
var druses: Array[Vector4] = []
var shares := PackedFloat32Array()


func reset(world: EcoWorld) -> void:
	ground = world.ground
	_lay()


## Дно под (x, z): мир передаёт Seabed.height; без него — −300 м.
func floor_y(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else -300.0


## Линия границы корки при z: x (волнистая, ± WAVE).
static func border_x(z: float) -> float:
	return BORDER_X + WAVE * (HashNoise.fbm(z * WAVE_SCALE, 3.7, 2) * 2.0 - 1.0)


## Доля корки в (x, z): 0 — западнее границы, 1 — за `FULL` м к востоку.
static func share(x: float, z: float) -> float:
	var b := border_x(z)
	return HashNoise.smooth(b, b + FULL, x)


## Доля пятна корки в (x, z), 0…1 (порода между пятнами голая).
static func patch(x: float, z: float) -> float:
	return HashNoise.smooth(PATCH.x, PATCH.y, HashNoise.fbm(x * PATCH_SCALE + 5.1, z * PATCH_SCALE - 2.3, 2))


## Свечение кончиков друзы при доле корки s.
static func glow(s: float) -> float:
	return lerpf(GLOW.x, GLOW.y, s)


## У оси подхода к 10: друзы мельче.
static func on_axis(x: float, z: float) -> bool:
	return x <= AXIS_TO and absf(z - Seabed.Slope.GAP_Z) < AXIS_HALF


## Наибольший верх друзы размера r над дном, м.
static func top_of(r: float) -> float:
	return r * TALL


func _lay() -> void:
	druses.clear()
	shares = PackedFloat32Array()
	var rnd := EcoRandom.new(8321)
	var nx := int(AREA.size.x / STEP)
	var nz := int(AREA.size.y / STEP)
	for i in nx:
		for j in nz:
			var x := AREA.position.x + (i + rnd.range_f(0.15, 0.85)) * STEP
			var z := AREA.position.y + (j + rnd.range_f(0.15, 0.85)) * STEP
			var roll := rnd.next()
			var k := rnd.next()
			var s := share(x, z)
			if s <= 0.0 or roll >= s * patch(x, z) * DENSITY or Seabed.Slope.mask(x, z) < MASK:
				continue
			var r := lerpf(SIZE.x, SIZE.y, s * (0.45 + 0.55 * k))
			r = minf(r, MAX_H / TALL)
			if on_axis(x, z):
				r = minf(r, minf(AXIS_SIZE, AXIS_H / TALL))
			druses.append(Vector4(x, floor_y(x, z), z, r))
			shares.append(s)
			if druses.size() >= MAX:
				return
