class_name Settings
extends RefCounted
## Настройки ART-037 (`docs/concept-art/menyu.md`, `menyu-nastrojki.png`, сброс — `menyu-sostoyaniya.png`):
## громкость и чувствительность свайпа (ползунки), «Камера с борта в начале забега» (Вкл/Выкл), «Графика» — страница
## уровней ART-044 (`page`, числа и раскладка — `Graphics`), «Сбросить сохранение»
## через подтверждение (выделено «Нет»), «Назад» — туда, откуда открыты (главное меню или пауза). Хранятся отдельно от
## сохранения забега — `user://nastrojki.cfg` (тесты, снимки и прогон тестера не читают и не пишут: `path` = "").
## Здесь — значения, файл, кнопки и раскладка без узлов; рисует `scripts/game/settings_panel.gd`
## (`main.settings_panel`), шаг — `Main._settings_step`, применяет — `Main._apply_settings` (громкость шины Master,
## `TouchOverlay.swipe`, облёт `Flyby.Kind.START`). Макет 2400×1080, масштаб и обрезка боков — `Splash`.

const PATH := "user://nastrojki.cfg"
const VERSION := 1
static var default_path := PATH   ## тесты и снимки выключают ("")

const TITLE := "Настройки"
const TITLE_AT := Vector2(560, 100)   ## левый край и верх глифов
const TITLE_PX := 64.0
const BACK := Rect2(1540, 80, 300, 104)
const BUTTON_PX := 38.0
const LABEL_X := 560.0
const LABEL_PX := 40.0
const VALUE_PX := 38.0
const VALUE_RIGHT := 1840.0   ## правый край значения
const TRACK_X := Vector2(580, 1820)   ## дорожка ползунка от и до
const TRACK_H := 10.0
const KNOB_R := 22.0
## Ползунки сверху вниз: id, подпись, верх глифов подписи, середина дорожки, полоса касания.
const SLIDERS := [
	["volume", "Громкость", 270.0, 360.0, Rect2(560, 317, 1280, 96)],
	["swipe", "Чувствительность свайпа", 470.0, 560.0, Rect2(560, 517, 1280, 96)],
]
const INTRO_LABEL := "Камера с борта в начале забега"
const INTRO_TOP := 690.0
const INTRO := Rect2(1580, 655, 260, 112)
const RESET := Rect2(1220, 842, 620, 112)
const GRAPHICS := Rect2(560, 842, 620, 112)   ## «Графика» — страница ART-044 (`Graphics`)
const GRAPHICS_LABEL := "Графика"
const RESET_LABEL := "Сбросить сохранение"
## Подтверждение сброса — окно и кнопки как у паузы (`Pause.BOX`, `YES`, `NO`).
const ASK := ["Сбросить сохранение?", "Сохранение будет удалено.", "Отменить это действие нельзя."]

## Диапазоны: громкость 0…100 % (шаг 1 %), свайп 0,5…2,0× (шаг 0,1); в макете 70 % и 1,0× — по умолчанию.
const VOLUME := Vector2(0.0, 1.0)
const SWIPE := Vector2(0.5, 2.0)
const VOLUME_DEFAULT := 0.7
const SWIPE_DEFAULT := 1.0
const MUTE_DB := -80.0

var path := default_path   ## пустой — настройки не читаются и не пишутся
var volume := VOLUME_DEFAULT
var swipe := SWIPE_DEFAULT
var intro := true   ## облёт с борта в начале забега
var hints_done := false   ## подсказки первого забега ART-038 пройдены — больше не показывать (`Tutorial`)
var cards: Array = []     ## прочитанные карточки ролей ART-045 — посты (`RoleCard.read_list`)
var graphics := Graphics.DEFAULT   ## уровень графики ART-044
var fps := false                   ## «Показывать кадры/с» ART-044

var open := false
var ask := false    ## открыто подтверждение сброса
var grab := ""      ## ползунок под пальцем: "volume" / "swipe"; "" — нет
var page := ""      ## "" — основная страница, "grafika" — «Настройки · Графика» ART-044


func set_volume(v: float) -> void:
	volume = clampf(snappedf(v, 0.01), VOLUME.x, VOLUME.y)


func set_swipe(v: float) -> void:
	swipe = clampf(snappedf(v, 0.1), SWIPE.x, SWIPE.y)


func value(id: String) -> float:
	return volume if id == "volume" else swipe


## Значение ползунка id в долях дорожки 0…1.
func fraction(id: String) -> float:
	var r := range_of(id)
	return clampf((value(id) - r.x) / (r.y - r.x), 0.0, 1.0)


static func range_of(id: String) -> Vector2:
	return VOLUME if id == "volume" else SWIPE


## Подпись значения: «70 %», «1,0×».
func value_text(id: String) -> String:
	if id == "volume":
		return "%d %%" % roundi(volume * 100.0)
	return ("%.1f×" % swipe).replace(".", ",")


## Громкость шины Master в дБ: 0 — тишина.
static func volume_db(v: float) -> float:
	return MUTE_DB if v <= 0.001 else maxf(MUTE_DB, linear_to_db(v))


static func slider(id: String) -> Array:
	for s: Array in SLIDERS:
		if s[0] == id:
			return s
	return []


## Прямоугольник элемента id на экране size: "back", "volume", "swipe" (полоса касания), "intro", "reset", "yes", "no".
static func screen_rect(id: String, size: Vector2) -> Rect2:
	match id:
		"back":
			return Splash.rect_to_screen(BACK, size)
		"intro":
			return Splash.rect_to_screen(INTRO, size)
		"reset":
			return Splash.rect_to_screen(RESET, size)
		"graphics":
			return Splash.rect_to_screen(GRAPHICS, size)
		"yes":
			return Splash.rect_to_screen(Pause.YES, size)
		"no":
			return Splash.rect_to_screen(Pause.NO, size)
	var s := slider(id)
	return Splash.rect_to_screen(s[4], size) if not s.is_empty() else Rect2()


## Доля дорожки под точкой экрана p (0…1).
static func track_k(p: Vector2, size: Vector2) -> float:
	var x := (p.x + Splash.offset(size).x) / Splash.scale(size)
	return clampf((x - TRACK_X.x) / (TRACK_X.y - TRACK_X.x), 0.0, 1.0)


func show() -> void:
	open = true
	ask = false
	grab = ""
	page = ""


func close() -> void:
	open = false
	ask = false
	grab = ""
	page = ""


## Что под касанием p ("" — ничего). Под подтверждением — только «yes» / «no».
func hit(p: Vector2, size: Vector2) -> String:
	if not open:
		return ""
	if page == "grafika":
		return Graphics.hit(p, size)
	var ids := ["yes", "no"] if ask else ["back", "volume", "swipe", "intro", "graphics", "reset"]
	for id: String in ids:
		if screen_rect(id, size).has_point(p):
			return id
	return ""


## Касание p по элементу id. Возвращает: "back" — настройки закрыты, "changed" — значение поменялось (сохранить и
## применить), "graphics" — уровень графики поменялся (применить и сохранить), "wipe" — подтверждён сброс сохранения;
## "" — ничего (открыт или закрыт диалог или страница, взят ползунок без сдвига).
func press(id: String, p: Vector2 = Vector2.ZERO, size: Vector2 = Vector2.ZERO) -> String:
	if not open:
		return ""
	if page == "grafika":
		return _press_graphics(id)
	if ask:
		match id:
			"yes":
				ask = false
				return "wipe"
			"no":
				ask = false
		return ""
	match id:
		"back":
			close()
			return "back"
		"intro":
			intro = not intro
			return "changed"
		"reset":
			ask = true
		"graphics":
			page = "grafika"
		"volume", "swipe":
			grab = id
			return "changed" if drag(p, size) else ""
	return ""


## Страница «Графика»: «Назад» — к основной странице, уровень — применить, «Показывать кадры/с» — Вкл./Выкл.
func _press_graphics(id: String) -> String:
	match id:
		"back":
			page = ""
		"fps":
			fps = not fps
			return "changed"
		"g0", "g1", "g2":
			var g := int(id.substr(1))
			if g != graphics:
				graphics = g
				return "graphics"
	return ""


## Палец на взятом ползунке в точке p: новое значение; true — поменялось.
func drag(p: Vector2, size: Vector2) -> bool:
	if grab == "" or size == Vector2.ZERO:
		return false
	var r := range_of(grab)
	var before := value(grab)
	var v := lerpf(r.x, r.y, track_k(p, size))
	if grab == "volume":
		set_volume(v)
	else:
		set_swipe(v)
	return not is_equal_approx(before, value(grab))


## Системная «Назад»: закрыть подтверждение, иначе настройки. "back" — настройки закрыты.
func back() -> String:
	if ask:
		ask = false
		return ""
	if page != "":
		page = ""
		return ""
	close()
	return "back"


func enabled() -> bool:
	return not path.is_empty()


func write() -> bool:
	if not enabled():
		return false
	var cfg := ConfigFile.new()
	cfg.set_value("nastrojki", "v", VERSION)
	cfg.set_value("nastrojki", "volume", volume)
	cfg.set_value("nastrojki", "swipe", swipe)
	cfg.set_value("nastrojki", "intro", intro)
	cfg.set_value("nastrojki", "podskazki", hints_done)
	cfg.set_value("nastrojki", "kartochki", cards)
	cfg.set_value("nastrojki", "grafika", graphics)
	cfg.set_value("nastrojki", "kadry", fps)
	return cfg.save(path) == OK


## Прочитать файл; false — его нет, он чужой или настройки выключены (тогда значения по умолчанию).
func read() -> bool:
	if not enabled() or not FileAccess.file_exists(path):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or int(cfg.get_value("nastrojki", "v", 0)) != VERSION:
		return false
	set_volume(float(cfg.get_value("nastrojki", "volume", VOLUME_DEFAULT)))
	set_swipe(float(cfg.get_value("nastrojki", "swipe", SWIPE_DEFAULT)))
	intro = bool(cfg.get_value("nastrojki", "intro", true))
	hints_done = bool(cfg.get_value("nastrojki", "podskazki", false))
	var c: Variant = cfg.get_value("nastrojki", "kartochki", [])
	cards = c if c is Array else []
	graphics = Graphics.valid(int(cfg.get_value("nastrojki", "grafika", Graphics.DEFAULT)))
	fps = bool(cfg.get_value("nastrojki", "kadry", false))
	return true
