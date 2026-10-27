class_name Settings
extends RefCounted
## Настройки ART-037 (`docs/concept-art/menyu.md`, `menyu-nastrojki.png`, сброс — `menyu-sostoyaniya.png`):
## громкость и чувствительность свайпа (ползунки), «Камера с борта в начале забега» (Вкл/Выкл), «Графика» — страница
## уровней ART-044 (`page`, числа и раскладка — `Graphics`), «Голос» — страница рации ART-041 (`page` = "golos",
## раскладка — `VoicePage`), «Звук» — громкости шин `SoundMix` (`page` = "zvuk", раскладка — `SoundPage`, доли — `buses`),
## «Сбросить сохранение»
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
const RESET := Rect2(1340, 842, 500, 112)
const GRAPHICS := Rect2(560, 842, 240, 112)   ## «Графика» — страница ART-044 (`Graphics`)
const GRAPHICS_LABEL := "Графика"
const ZVUK := Rect2(835, 842, 215, 112)       ## «Звук» — громкости шин (`SoundPage`)
const ZVUK_LABEL := "Звук"
const GOLOS := Rect2(1085, 842, 220, 112)     ## «Голос» — страница рации ART-041 (`VoicePage`)
const GOLOS_LABEL := "Голос"
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
var lite_no := false               ## отказ от предложения «Экономно» ART-044 (`LiteOffer`) — больше не предлагать
## Голос ART-041 (`VoicePage`, в рацию — `Main._apply_settings`): громкость товарищей, режим (`Radio.Mode`), приём и
## микрофон — независимо. mic_ok — разрешение микрофона Android сейчас (не хранится, ставит `Main._settings_show`).
var mates := VOLUME_DEFAULT
var voice_mode := Radio.Mode.HOLD
var hear := true
var mic_on := true
var mic_ok := true
## Звук: доля громкости каждой шины `SoundMix` 0…1 (шина → доля; нет записи — 100 %), `SoundPage`.
var buses := {}

var open := false
var ask := false    ## открыто подтверждение сброса
var grab := ""      ## ползунок под пальцем: "volume" / "swipe" / "mates"; "" — нет
var page := ""      ## "" — основная страница, "grafika" — «Настройки · Графика» ART-044, "golos" — «Голос» ART-041,
                    ## "zvuk" — «Звук» (громкости шин)


func set_volume(v: float) -> void:
	volume = clampf(snappedf(v, 0.01), VOLUME.x, VOLUME.y)


func set_swipe(v: float) -> void:
	swipe = clampf(snappedf(v, 0.1), SWIPE.x, SWIPE.y)


func set_mates(v: float) -> void:
	mates = clampf(snappedf(v, 0.01), VOLUME.x, VOLUME.y)


## Громкость шины name (`SoundMix.MUSIC`…) — доля 0…1 с шагом 1 %.
func set_bus(name: String, v: float) -> void:
	buses[name] = clampf(snappedf(v, 0.01), VOLUME.x, VOLUME.y)


func bus_k(name: String) -> float:
	return float(buses.get(name, SoundPage.DEFAULT))


func value(id: String) -> float:
	match id:
		"volume":
			return volume
		"mates":
			return mates
	var i := SoundPage.index(id)
	if i >= 0:
		return bus_k(SoundPage.bus(i))
	return swipe


## Значение ползунка id в долях дорожки 0…1.
func fraction(id: String) -> float:
	var r := range_of(id)
	return clampf((value(id) - r.x) / (r.y - r.x), 0.0, 1.0)


static func range_of(id: String) -> Vector2:
	return SWIPE if id == "swipe" else VOLUME


## Дорожка ползунка id в x макета: у «Громкости товарищей» — своя (`VoicePage.TRACK_X`), у шин — `SoundPage`.
static func track_of(id: String) -> Vector2:
	var i := SoundPage.index(id)
	if i >= 0:
		return SoundPage.track_x(i)
	return VoicePage.TRACK_X if id == "mates" else TRACK_X


## Подпись значения: «70 %», «1,0×».
func value_text(id: String) -> String:
	if id != "swipe":
		return "%d %%" % roundi(value(id) * 100.0)
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
		"zvuk":
			return Splash.rect_to_screen(ZVUK, size)
		"golos":
			return Splash.rect_to_screen(GOLOS, size)
		"yes":
			return Splash.rect_to_screen(Pause.YES, size)
		"no":
			return Splash.rect_to_screen(Pause.NO, size)
	var s := slider(id)
	return Splash.rect_to_screen(s[4], size) if not s.is_empty() else Rect2()


## Доля дорожки ползунка id под точкой экрана p (0…1).
static func track_k(p: Vector2, size: Vector2, id := "volume") -> float:
	var x := (p.x + Splash.offset(size).x) / Splash.scale(size)
	var t := track_of(id)
	return clampf((x - t.x) / (t.y - t.x), 0.0, 1.0)


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
	if page == "golos":
		return VoicePage.hit(p, size)
	if page == "zvuk":
		return SoundPage.hit(p, size)
	var ids := ["yes", "no"] if ask else ["back", "volume", "swipe", "intro", "graphics", "zvuk", "golos", "reset"]
	return Splash.hit_ids(p, size, ids, screen_rect)


## Касание p по элементу id. Возвращает: "back" — настройки закрыты, "changed" — значение поменялось (сохранить и
## применить), "graphics" — уровень графики поменялся (применить и сохранить), "wipe" — подтверждён сброс сохранения;
## "" — ничего (открыт или закрыт диалог или страница, взят ползунок без сдвига).
func press(id: String, p: Vector2 = Vector2.ZERO, size: Vector2 = Vector2.ZERO) -> String:
	if not open:
		return ""
	if page == "grafika":
		return _press_graphics(id)
	if page == "golos":
		return _press_voice(id, p, size)
	if page == "zvuk":
		return _press_sound(id, p, size)
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
		"golos":
			page = "golos"
		"zvuk":
			page = "zvuk"
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


## Страница «Голос»: «Назад» — к основной, ползунок товарищей, режим, приём и микрофон — сразу в рацию.
func _press_voice(id: String, p: Vector2, size: Vector2) -> String:
	match id:
		"back":
			page = ""
			grab = ""
		"mates":
			grab = id
			return "changed" if drag(p, size) else ""
		"v_hold", "v_voice":
			var m := Radio.Mode.HOLD if id == "v_hold" else Radio.Mode.VOICE
			if m != voice_mode:
				voice_mode = m
				return "changed"
		"v_hear":
			hear = not hear
			return "changed"
		"v_mic":
			mic_on = not mic_on
			return "changed"
	return ""


## Страница «Звук»: «Назад» — к основной, ползунок шины — значение сразу в сведение.
func _press_sound(id: String, p: Vector2, size: Vector2) -> String:
	if id == "back":
		page = ""
		grab = ""
		return ""
	if SoundPage.index(id) >= 0:
		grab = id
		return "changed" if drag(p, size) else ""
	return ""


## Ползунок под пальцем — громкость: общая, товарищей или шины (на них звук откликается, пока палец ведёт).
static func is_volume(id: String) -> bool:
	return id in ["volume", "mates"] or SoundPage.index(id) >= 0


## Палец на взятом ползунке в точке p: новое значение; true — поменялось.
func drag(p: Vector2, size: Vector2) -> bool:
	if grab == "" or size == Vector2.ZERO:
		return false
	var r := range_of(grab)
	var before := value(grab)
	var v := lerpf(r.x, r.y, track_k(p, size, grab))
	match grab:
		"volume":
			set_volume(v)
		"mates":
			set_mates(v)
		"swipe":
			set_swipe(v)
		_:
			var i := SoundPage.index(grab)
			if i >= 0:
				set_bus(SoundPage.bus(i), v)
	return not is_equal_approx(before, value(grab))


## Системная «Назад»: закрыть подтверждение, иначе настройки. "back" — настройки закрыты.
func back() -> String:
	if ask:
		ask = false
		return ""
	if page != "":
		page = ""
		grab = ""
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
	cfg.set_value("nastrojki", "ekonomno_net", lite_no)
	cfg.set_value("nastrojki", "golos_gromkost", mates)
	cfg.set_value("nastrojki", "golos_rezhim", voice_mode)
	cfg.set_value("nastrojki", "golos_priem", hear)
	cfg.set_value("nastrojki", "golos_mikrofon", mic_on)
	cfg.set_value("nastrojki", "shiny", buses)
	return cfg.save(path) == OK


## Первый запуск ART-044: файла настроек ещё нет — уровень графики level (`Graphics.auto_here`) и сразу записать;
## false — файл уже есть или настройки выключены (тесты, снимки, прогон тестера).
func pick_first(level: int) -> bool:
	if not enabled() or FileAccess.file_exists(path):
		return false
	graphics = Graphics.valid(level)
	return write()


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
	lite_no = bool(cfg.get_value("nastrojki", "ekonomno_net", false))
	set_mates(float(cfg.get_value("nastrojki", "golos_gromkost", VOLUME_DEFAULT)))
	voice_mode = Radio.Mode.VOICE if int(cfg.get_value("nastrojki", "golos_rezhim", 0)) == Radio.Mode.VOICE \
		else Radio.Mode.HOLD
	hear = bool(cfg.get_value("nastrojki", "golos_priem", true))
	mic_on = bool(cfg.get_value("nastrojki", "golos_mikrofon", true))
	buses = {}
	var b: Variant = cfg.get_value("nastrojki", "shiny", {})
	if b is Dictionary:
		for name: String in SoundPage.gains({}):
			if b.has(name):
				set_bus(name, float(b[name]))
	return true
