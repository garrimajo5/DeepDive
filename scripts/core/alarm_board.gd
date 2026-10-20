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
