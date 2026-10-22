class_name AlarmBoard
extends RefCounted
## Табло тревог над носовым окном мостика (ART-025, `docs/concept-art/tablo-trevog.md`): блок 7,2 × 0,25 × 0,08 м,
## пять полей в строку — «ПРОБОИНА», «СТЕКЛОУСТ НА КОРПУСЕ», «ПЕРЕГРЕВ», «ИЛ — СОНАР СЛЕП», «МАЛО ЗАРЯДА»
## (порядок — как у `Status.alarm`). Поле погашено / горит / мигает: горят все активные тревоги, мигает (углы рамки
## поля, 1 Гц; буквы горят) только первая по порядку — главная. Здесь — числа и геометрия без узлов;
## рисует `scripts/game/alarm_board_view.gd`. Оси корабля: нос в −Z, лицо табло смотрит в +Z (в мостик).

enum Field { BREACH, DRAIN, HEAT, SILT, CHARGE }
const WORDS: Array[String] = ["ПРОБОИНА", "СТЕКЛОУСТ НА КОРПУСЕ", "ПЕРЕГРЕВ", "ИЛ — СОНАР СЛЕП", "МАЛО ЗАРЯДА"]
const WIDTHS: Array[float] = [1.05, 2.25, 1.15, 1.65, 1.10]   ## ширины полей слева (−X) направо, сумма — SIZE.x
const SIZE := Vector3(7.2, 0.25, 0.08)
const CENTER := Vector3(0.0, 2.675, -5.60)
const FRAME := 0.025          ## толщина бруска рамки и разделителя (по лицу), м
const FRAME_OUT := 0.02       ## насколько рамка выступает перед лицевой плоскостью, м
const BRACKET := Vector3(0.06, 0.06, 0.13)   ## кронштейн от задней стенки к верхней раме окна (z −5,77)
const BRACKET_X: Array[float] = [-2.6, 2.6]
const BLINK_HZ := 1.0
## Цвета (палитра ART-002/ART-013, ничего красного — #129).
const BACK := Color("0B1C24")
const WORD_OFF := Color("66747A")
const WORD_ON := Color("FFB259")


## Левая и правая граница поля i по x.
static func field_span(i: int) -> Vector2:
	var x := -SIZE.x * 0.5
	for k in i:
		x += WIDTHS[k]
	return Vector2(x, x + WIDTHS[i])


static func field_x(i: int) -> float:
	var s := field_span(i)
	return (s.x + s.y) * 0.5


## Активные поля по строкам тревог корабля (как в `Main.status_parts`): пробоина, стеклоуст, перегрев реактора
## или аварийный сброс, сонарная тьма, мало заряда.
static func active(breach: String, drain: String, heat: String, silt: String, low_charge: bool) -> Array[bool]:
	return [not breach.is_empty(), not drain.is_empty(), not heat.is_empty(), not silt.is_empty(), low_charge]


## Главная тревога — первое активное поле (её подсказка ведёт к посту), −1 — тревог нет.
static func main_field(on: Array[bool]) -> int:
	return on.find(true)


## Яркость полей в момент t: [буквы 0…1, углы рамки 0…1] на поле. Погашено — 0/0; горит — 1/1; главная мигает
## углами (первая половина периода — горят), буквы не гаснут.
static func levels(on: Array[bool], t: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var m := main_field(on)
	var blink := 1.0 if fposmod(t * BLINK_HZ, 1.0) < 0.5 else 0.0
	for i in on.size():
		if not on[i]:
			out.append(Vector2.ZERO)
		else:
			out.append(Vector2(1.0, blink if i == m else 1.0))
	return out


## Бруски табло в осях корабля (`BridgePlan.Part`, краска METAL/SEAM): рамка (4), разделители полей (4), задняя
## стенка, кронштейны к верхней раме окна (2) — 11 брусков, 132 треугольника. Лицевая плоскость с надписями —
## отдельно (face_rect), рисует шейдер.
static func boxes() -> Array[BridgePlan.Part]:
	var c := CENTER
	var hw := SIZE.x * 0.5
	var hh := SIZE.y * 0.5
	var fz := c.z + FRAME_OUT * 0.5            # рамка: от задней стенки до FRAME_OUT перед лицом
	var fd := SIZE.z + FRAME_OUT
	var metal := BridgePlan.Paint.METAL
	var seam := BridgePlan.Paint.SEAM
	var out: Array[BridgePlan.Part] = []
	for s in [-1.0, 1.0]:
		out.append(BridgePlan.Part.new("Табло: рама", metal, Vector3(SIZE.x, FRAME, fd),
			Vector3(c.x, c.y + s * (hh - FRAME * 0.5), fz)))
		out.append(BridgePlan.Part.new("Табло: торец", metal, Vector3(FRAME, SIZE.y - 2.0 * FRAME, fd),
			Vector3(c.x + s * (hw - FRAME * 0.5), c.y, fz)))
	for i in range(1, WIDTHS.size()):
		out.append(BridgePlan.Part.new("Табло: разделитель", seam, Vector3(FRAME * 0.6, SIZE.y - 2.0 * FRAME, 0.01),
			Vector3(field_span(i).x, c.y, c.z + SIZE.z * 0.5 + 0.005)))
	out.append(BridgePlan.Part.new("Табло: стенка", seam, Vector3(SIZE.x - 2.0 * FRAME, SIZE.y - 2.0 * FRAME, SIZE.z * 0.5),
		Vector3(c.x, c.y, c.z - SIZE.z * 0.25)))
	for x in BRACKET_X:
		out.append(BridgePlan.Part.new("Табло: кронштейн", seam, BRACKET,
			Vector3(x, c.y + hh - BRACKET.y * 0.5, c.z - SIZE.z * 0.5 - BRACKET.z * 0.5)))
	return out


## Лицевая плоскость с надписями: центр и размер (в плоскости XY, смотрит в +Z), внутри рамки.
static func face_rect() -> Array:
	return [Vector3(CENTER.x, CENTER.y, CENTER.z + SIZE.z * 0.5), Vector2(SIZE.x - 2.0 * FRAME, SIZE.y - 2.0 * FRAME)]


## Доля табло по x для границы поля (для шейдера и текстуры надписей): 0 — левый край лица, 1 — правый.
static func u_of(x: float) -> float:
	var r: Vector2 = face_rect()[1]
	return (x - CENTER.x + r.x * 0.5) / r.x


## Плашка строки состояния и табло (#376): вблизи носового окна табло по перспективе уходит в верхнюю полосу экрана,
## под строки приборов. Тогда плашку опускаем под нижний край табло (STATUS_GAP) — оба читаются. Если для этого
## пришлось бы опустить её больше STATUS_MAX_SHIFT (смотрим на табло снизу, оно на полэкрана), плашка остаётся на месте.
const STATUS_GAP := 6.0
const STATUS_MAX_SHIFT := 140.0


## Прямоугольник табло на экране по проекциям углов (`face_corners`); пусто, если угол за камерой или табло вне кадра.
static func screen_rect(points: PackedVector2Array, behind: bool, view: Rect2) -> Rect2:
	if behind or points.is_empty():
		return Rect2()
	var r := Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	r = r.intersection(view)
	return r if r.has_area() else Rect2()


## Углы табло (по внешней рамке) в осях корабля.
static func corners() -> Array[Vector3]:
	var hw := SIZE.x * 0.5
	var hh := SIZE.y * 0.5
	var z := CENTER.z + SIZE.z * 0.5
	return [Vector3(CENTER.x - hw, CENTER.y - hh, z), Vector3(CENTER.x + hw, CENTER.y - hh, z),
		Vector3(CENTER.x - hw, CENTER.y + hh, z), Vector3(CENTER.x + hw, CENTER.y + hh, z)]


## Верх плашки строки состояния: plate — плашка на своём месте, board — табло на экране (`screen_rect`).
static func status_y(plate: Rect2, board: Rect2) -> float:
	if not board.has_area() or not board.intersects(plate):
		return plate.position.y
	var y := board.end.y + STATUS_GAP
	if y - plate.position.y > STATUS_MAX_SHIFT:
		return plate.position.y
	return maxf(y, plate.position.y)


## Подсказка к посту главной тревоги (ART-025, «таблица тревога → пост»): одна янтарная рамка у поста, который
## снимает главную тревогу. Стеклоуст — щиток разряда (`Zap.PANEL_POS`), мало заряда — пульт энергии, пробоина —
## место сварки (`Breach.active`; вода после заплатки откачивается сама — рамки нет), перегрев — кормовой люк мостика
## (вентиль в машинном, сквозь борт не указываем), ил — штурвал. Рамка в плоскости XY своих осей, лицом в normal.
class Hint:
	var center := Vector3.ZERO
	var size := Vector2.ZERO     ## ширина и высота по внешней кромке, м
	var normal := Vector3.BACK   ## куда смотрит рамка (в отсек)

	func _init(c: Vector3, s: Vector2, n: Vector3) -> void:
		center = c
		size = s
		normal = n


const HINT_BAR := 0.035     ## ширина бруска рамки, м
const HINT_GAP := 0.03      ## рамка перед поверхностью, м
const HINT_DIM := 0.35      ## яркость рамки, пока углы главной тревоги погашены (рамку видно всегда)
## Щиток разряда 0,45 × 0,60 м, лицо в +X (`razryad.md`); пульт энергии 1,2 × 1,6 м у стены x −4,9 (`BridgeProps`).
const HINT_ZAP_SIZE := Vector2(0.65, 0.80)
const HINT_ENERGY_SIZE := Vector2(1.40, 1.75)
const HINT_ENERGY_GAP := 0.1   ## перед рёбрами борта (выступают на 0,08 м у z −2,75 и −1,25)
const HINT_HATCH_SIZE := Vector2(2.0, 2.45)   ## проём люка 1,4 × 2,1 м, рама модели — до 1,8 м
const HINT_HATCH_GAP := 0.05
const HINT_WHEEL_SIZE := Vector2(0.95, 0.85)
const HINT_BREACH_SIZE := Vector2(1.0, 1.0)


## Рамка для главного поля main (−1 — нет тревог) или null. breach_spot — открытая пробоина (`Breach.active`).
static func hint(main: int, breach_spot: Breach.Spot) -> Hint:
	match main:
		Field.BREACH:
			if breach_spot == null:
				return null
			return Hint.new(breach_spot.p + breach_spot.n * HINT_GAP, HINT_BREACH_SIZE, breach_spot.n)
		Field.DRAIN:
			return Hint.new(Vector3(Zap.PANEL_POS.x + HINT_GAP, 1.17, Zap.PANEL_POS.z), HINT_ZAP_SIZE, Vector3.RIGHT)
		Field.HEAT:
			var h := BridgeProps.HATCH_POS
			return Hint.new(Vector3(h.x, HINT_HATCH_SIZE.y * 0.5, h.z - HINT_HATCH_GAP), HINT_HATCH_SIZE, Vector3.FORWARD)
		Field.SILT:
			return Hint.new(Vector3(0.0, BridgeProps.WHEEL_Y, BridgeProps.WHEEL_Z + 0.2), HINT_WHEEL_SIZE, Vector3.BACK)
		Field.CHARGE:
			var e := BridgeProps.ENERGY_POS
			return Hint.new(Vector3(e.x + HINT_ENERGY_GAP, 0.05 + HINT_ENERGY_SIZE.y * 0.5, e.z), HINT_ENERGY_SIZE,
				Vector3.RIGHT)
	return null


## Яркость рамки 0…1: в такт углам главного поля (`levels`), погашенные углы — HINT_DIM.
static func hint_glow(on: Array[bool], t: float) -> float:
	var m := main_field(on)
	if m < 0:
		return 0.0
	return 1.0 if levels(on, t)[m].y > 0.5 else HINT_DIM


## Бруски рамки в её осях (x вправо, y вверх, лицо +Z): 4 прямоугольника [центр, размер] по внешней кромке size.
static func hint_bars(size: Vector2) -> Array:
	var b := HINT_BAR
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	return [
		[Vector2(0.0, hh - b * 0.5), Vector2(size.x, b)],
		[Vector2(0.0, -hh + b * 0.5), Vector2(size.x, b)],
		[Vector2(-hw + b * 0.5, 0.0), Vector2(b, size.y - 2.0 * b)],
		[Vector2(hw - b * 0.5, 0.0), Vector2(b, size.y - 2.0 * b)],
	]
