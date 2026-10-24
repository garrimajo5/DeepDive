class_name PowerScreen
## Экран пульта энергии по ART-050 (`docs/concept-art/pult-energii.md`): место панели, строки систем, шапка и нижняя
## зона по состоянию реактора. Числа макета — при высоте 1080 (панель 700×478, правый отступ 40, верх 190); на другой
## высоте всё множится на H/1080. Рисует `PowerPanel` (scripts/game/power_panel.gd), сам пульт правит `Reactor.Console`.

const W := 700.0
const H := 478.0
const RIGHT := 40.0
const TOP := 190.0
const RADIUS := 12.0
const ROW_Y := 62.0     ## первая строка
const ROW_STEP := 64.0
const ROW_H := 62.0   ## рамка выбора чуть ниже подписи (макет — 60)
const BAR_X := Vector2(442.0, 660.0)   ## полоса по x внутри панели
const BAR_Y := Vector2(43.0, 51.0)     ## по y внутри строки
const VALUE_X := 660.0                 ## правый край числа
const WORD_X := 442.0                  ## «ПРЕДЕЛ» / «ВЫКЛ.»
const HEAD_LINE := 54.0                ## черта под шапкой
const FOOT_LINE := 384.0               ## черта над нижней зоной
const FOOT_Y := Vector2(392.0, 432.0)  ## верх двух строк нижней зоны
const STEP_X := 326.0                  ## «Шаг 5 · предел доли 60»

const BG := Color("102B37")
const INK := Color("D5E4E8")
const SECOND := Color("9AD9E8")
const ACCENT := Color("67DDEB")
const FRAME := Color("32616D")
const DIM := Color("6E909A")
const HOT := Color("FFB259")
const SEL_FILL := Color("193E4D")

const TITLE := "ПУЛЬТ ЭНЕРГИИ"
const ROLE := "ИНЖЕНЕР"
const MARK := "И"
## Подсказка управления словами: стрелок в шрифте игры нет (#217).
const CONTROLS := "Вверх-вниз — система · влево-вправо — доля"
const HOT_DO := "Сбросьте долю или откройте вентиль"
const SCRAM_NOTE := "Подача 0 · настройки сохранены"
const MAX_WORD := "ПРЕДЕЛ"
const OFF_WORD := "ВЫКЛ."

enum Mode { NORMAL, HOT, SCRAM }


## Масштаб макета к экрану size; панель шире половины экрана не бывает (ползунки слева видны).
static func scale(size: Vector2) -> float:
	return minf(size.y / 1080.0, size.x * 0.5 / (W + RIGHT))


## Прямоугольник панели: по макету справа сверху; ниже кнопки noclip и выше кнопки действия раскладки (#349) —
## если не влезает между ними, панель целиком мельче (кегли вместе с ней).
static func box(size: Vector2, layout: Touch.Layout = null) -> Rect2:
	var s := scale(size)
	var top := TOP * s
	if layout:
		var gap := size.y * 0.012
		top = maxf(top, layout.noclip.c.y + layout.noclip.r + gap)
		var room := layout.action.c.y - layout.action.r - gap - top
		s = minf(s, room / H)
	return Rect2(size.x - (RIGHT + W) * s, top, W * s, H * s)


## Масштаб нарисованной панели (кегли и отступы — множить на него).
static func k(b: Rect2) -> float:
	return b.size.x / W


static func mode(r: Reactor) -> Mode:
	if r.scram > 0.0:
		return Mode.SCRAM
	return Mode.HOT if r.hot else Mode.NORMAL


## Цвет рамки, выбора и активной полосы: янтарь — только при перегреве (и при сбросе во время перегрева).
static func accent(r: Reactor) -> Color:
	return HOT if r.hot else ACCENT


## Правая надпись шапки: роль или «ПЕРЕГРЕВ N°» (перегрев важнее роли, в том числе при сбросе).
static func head_right(r: Reactor) -> String:
	return "ПЕРЕГРЕВ %d°" % roundi(r.heat) if r.hot else ROLE


## Слово у числа: «ПРЕДЕЛ» при доле MAX, «ВЫКЛ.» при нуле, иначе пусто.
static func word(v: int) -> String:
	if v >= Reactor.MAX:
		return MAX_WORD
	return OFF_WORD if v <= 0 else ""


## Отрезки полосы в долях её длины: три деления по 20 (разделители 20/40), заполненная часть — по доле v.
## [[начало, конец, заполнено до], …] — заполнено до ∈ [начало, конец].
static func segments(v: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := 3
	for i in n:
		var a := float(i) / n
		var b := float(i + 1) / n
		out.append(Vector3(a, b, clampf(float(v) / Reactor.MAX, a, b)))
	return out


## Строка панели по её верху: верх строки i внутри панели.
static func row_top(i: int) -> float:
	return ROW_Y + ROW_STEP * i


## Нижняя зона: две строки [текст, кегль, жирный, цвет] и третья справа в первой строке (пусто — нет).
## Сброс важнее перегрева: таймер, доли сохранены. Перегрев — нагрузка и что делать, янтарём.
static func foot(r: Reactor) -> Array:
	match mode(r):
		Mode.SCRAM:
			return [["АВАРИЙНЫЙ СБРОС · ещё %d с" % ceili(r.scram), 27, true, INK],
				[SCRAM_NOTE, 23, false, SECOND], ""]
		Mode.HOT:
			return [["Нагрузка %d / безопасно %d" % [r.used(), Reactor.SAFE], 25, true, HOT],
				[HOT_DO, 28, true, HOT], ""]
	return [["Резерв %d / %d" % [r.free_units(), Reactor.TOTAL], 27, true, INK],
		[CONTROLS, 24, false, SECOND], "Шаг %d · предел доли %d" % [Reactor.STEP, Reactor.MAX]]


## Цвета строки: [имя, подпись, число, полоса заполненная, полоса пустая]. При сбросе всё приглушено.
static func row_colors(r: Reactor, selected: bool) -> Array[Color]:
	if mode(r) == Mode.SCRAM:
		return [DIM, DIM, DIM, DIM.darkened(0.15), FRAME.darkened(0.45)]
	var fill := accent(r) if selected else FRAME.lightened(0.15)
	return [INK, SECOND, accent(r) if selected else INK, fill, BG.darkened(0.45)]
