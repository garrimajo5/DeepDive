class_name Pause
extends RefCounted
## Пауза одиночного забега по ART-037 (`docs/concept-art/menyu.md`, `menyu-pauza.png`, `menyu-sostoyaniya.png`):
## системная «Назад» в забеге — «Продолжить», «Новый забег», «Настройки» (погашена до своей части), «Выйти в меню»;
## «Новый забег» и «Выйти в меню» — через подтверждение, в нём выделено «Нет». «Назад» закрывает сначала диалог,
## потом паузу. Здесь — состояние, кнопки и раскладка без узлов; рисует `scripts/game/pause_panel.gd`
## (`main.pause_panel`), шаг — `Main._pause_step`, «Назад» — `Main.back_pressed`. Макет 2400×1080, масштаб и
## обрезка боков — `Splash`. Места текста — верх видимых глифов, по центру макета.

const TITLE := "Пауза"
const TITLE_TOP := 120.0
const TITLE_PX := 64.0
const BUTTON := Rect2(820, 310, 760, 112)   ## первая кнопка; следующие ниже на STEP
const STEP := 142.0
const BUTTON_PX := 38.0

## Подтверждение: окно, заголовок и строка (верх глифов), «Да» / «Нет».
const BOX := Rect2(590, 300, 1220, 490)
const ASK_TOP := 352.0
const ASK_PX := 48.0
const LINE_TOP := 432.0
const LINE_PX := 34.0
const YES := Rect2(780, 640, 380, 112)
const NO := Rect2(1240, 640, 380, 112)
## Тексты подтверждений: заголовок, строка (замечание приёмки — у выхода одна строка «Забег будет потерян.»).
const ASK := {
	"new": ["Начать новый забег?", "Текущий забег будет потерян."],
	"exit": ["Выйти в меню?", "Забег будет потерян."],
}
const DIM := 0.62   ## затемнение живой сцены под паузой

## Кнопки сверху вниз: id, подпись.
const ITEMS := [["resume", "Продолжить"], ["new", "Новый забег"], ["settings", "Настройки"], ["exit", "Выйти в меню"]]
const MAIN_ITEM := "resume"

var open := false
var ask := ""   ## открытое подтверждение: "new" / "exit"; "" — нет
## «Настройки» — следующей частью ART-037.
var enabled := {"resume": true, "new": true, "settings": false, "exit": true}


## Прямоугольник i-й кнопки в макете.
static func button_rect(i: int) -> Rect2:
	return Rect2(BUTTON.position + Vector2(0.0, STEP * i), BUTTON.size)


## Прямоугольник кнопки id на экране size (и «yes» / «no» подтверждения).
static func screen_rect(id: String, size: Vector2) -> Rect2:
	match id:
		"yes":
			return Splash.rect_to_screen(YES, size)
		"no":
			return Splash.rect_to_screen(NO, size)
	for i in ITEMS.size():
		if ITEMS[i][0] == id:
			return Splash.rect_to_screen(button_rect(i), size)
	return Rect2()


## Системная «Назад»: закрыть подтверждение, иначе закрыть паузу, иначе открыть её.
## Возвращает "pause" — пауза открылась, "resume" — закрылась, "" — закрыт диалог.
func back() -> String:
	if ask != "":
		ask = ""
		return ""
	open = not open
	return "pause" if open else "resume"


## Какая доступная кнопка под касанием p ("" — никакая). Пока открыто подтверждение — только «yes» / «no».
func hit(p: Vector2, size: Vector2) -> String:
	if not open:
		return ""
	if ask != "":
		for id: String in ["yes", "no"]:
			if screen_rect(id, size).has_point(p):
				return id
		return ""
	for it: Array in ITEMS:
		if enabled.get(it[0], false) and screen_rect(it[0], size).has_point(p):
			return it[0]
	return ""


## Нажатие кнопки id. Возвращает, что сделать игре: "resume" — играть дальше, "new" — новый забег, "exit" — в главное
## меню (пауза закрыта); "" — ничего (открыто или закрыто подтверждение).
func press(id: String) -> String:
	if not open:
		return ""
	if ask != "":
		match id:
			"yes":
				var what := ask
				ask = ""
				open = false
				return what
			"no":
				ask = ""
		return ""
	if not enabled.get(id, false):
		return ""
	match id:
		"resume":
			open = false
			return "resume"
		"new", "exit":
			ask = id
	return ""


func close() -> void:
	open = false
	ask = ""
