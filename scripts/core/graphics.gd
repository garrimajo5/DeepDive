class_name Graphics
extends RefCounted
## Уровни графики ART-044 (`docs/concept-art/grafika.md`, `grafika.png`): «Экономно» / «Обычно» / «Красиво» — числа
## уровня (`LEVELS`), четыре строки словами по фактическому свойству (`rows`), раскладка страницы «Настройки · Графика»
## (макет 2400×1080 через `Splash`) и счётчик кадров `Fps`. Уровень меняет только картинку — не сонар, не мир, не сеть.
## Выбор и «Показывать кадры/с» хранит `Settings` (`graphics`, `fps`), страницу открывает `Settings.page`,
## применяет `Main._apply_graphics`, рисуют `SettingsPanel` и `scripts/game/fps_view.gd` (`main.fps_view`).

enum { ECONOMY, NORMAL, BEAUTY }
const DEFAULT := NORMAL
const NAMES := ["Экономно", "Обычно", "Красиво"]

## Числа уровня: far — дальность камеры, м (дальняя вода — `wall`); lite — «Экономно» у частиц, рельефа и пост
## (`Main._apply_graphics`); shadows — каскадов тени света сквозь лёд (0 — тени выключены, и у прожектора тоже);
## msaa — множитель сглаживания; scale — разрешение 3D-сцены (интерфейс — всегда полное); layers — сила слоёв воды
## ART-069. «Обычно» — то, что было до ART-044 (msaa 2× из `project.godot`, 2 каскада, слои 0,6).
const LEVELS := [
	{"far": 260.0, "wall": 250.0, "lite": true, "shadows": 0, "msaa": 0, "scale": 0.75, "layers": WaterLayers.GAIN_LITE},
	{"far": 400.0, "wall": 380.0, "lite": false, "shadows": 2, "msaa": 2, "scale": 1.0, "layers": WaterLayers.GAIN_NORMAL},
	{"far": 400.0, "wall": 380.0, "lite": false, "shadows": 4, "msaa": 4, "scale": 1.0,
		"layers": WaterLayers.GAIN_BEAUTIFUL},
]

## Страница «Настройки · Графика» (координаты макета по `grafika.md`).
const TITLE := "Настройки · Графика"
const TITLE_AT := Vector2(400, 72)   ## левый край и верх глифов
const TITLE_PX := 58.0
const BACK := Rect2(1690, 52, 300, 112)
const LEVEL_X := [400.0, 940.0, 1480.0]
const LEVEL_Y := 230.0
const LEVEL_SIZE := Vector2(510, 112)
const ROW_X := 430.0
const ROW_TOP := 430.0
const ROW_STEP := 90.0
const ROW_PX := 38.0
const VALUE_RIGHT := 1940.0
const FPS_LABEL := "Показывать кадры/с"
const FPS := Rect2(1510, 800, 430, 112)
const NOTE := "Надписи и кнопки остаются чёткими"
const NOTE_TOP := 975.0
const NOTE_PX := 28.0

## Счётчик в игре: плашка 300×54 у правого края (x W − 370, y 210 по высоте 1080), 34 px, раз в 0,5 с.
const COUNTER := Rect2(-370, 210, 300, 54)
const COUNTER_PX := 34.0
const COUNTER_EVERY := 0.5


## Автовыбор уровня при первом запуске (`Settings.pick_first`, `Main._ready`): по видеокарте и памяти телефона.
## Слабое — «Экономно», флагман с памятью от 8 ГБ — «Красиво», остальное и не телефон — «Обычно»; дальше в игре
## подстрахует `LiteOffer`, вручную — «Настройки · Графика». Имена — как отдаёт драйвер Vulkan («Adreno (TM) 740»).
const AUTO_LOW_MB := 4096    ## памяти меньше — «Экономно»
const AUTO_HIGH_MB := 8192   ## «Красиво» — только от этой памяти
const WEAK_GPU := ["adreno[^0-9]*[1-5][0-9][0-9]\\b", "adreno[^0-9]*6[0-3][0-9]\\b", "mali-t", "mali-g[3-6][0-9]\\b",
	"mali-4", "powervr", "swiftshader", "llvmpipe"]
const STRONG_GPU := ["adreno[^0-9]*7[3-9][0-9]\\b", "adreno[^0-9]*8[0-9][0-9]\\b", "immortalis",
	"mali-g7[1-9][0-9]\\b", "mali-g9[0-9][0-9]\\b", "xclipse[^0-9]*9[0-9][0-9]\\b"]


## Уровень по видеокарте adapter, памяти memory_mb (≤ 0 — неизвестно) и телефон ли это.
static func auto(adapter: String, memory_mb: int, mobile := true) -> int:
	if not mobile:
		return DEFAULT
	var name := adapter.to_lower()
	if _matches(name, WEAK_GPU) or (memory_mb > 0 and memory_mb < AUTO_LOW_MB):
		return ECONOMY
	if _matches(name, STRONG_GPU) and memory_mb >= AUTO_HIGH_MB:
		return BEAUTY
	return NORMAL


static func _matches(name: String, patterns: Array) -> bool:
	for p: String in patterns:
		if RegEx.create_from_string(p).search(name) != null:
			return true
	return false


## Что знаем о своём устройстве: "adapter", "memory_mb", "mobile".
static func device() -> Dictionary:
	var mem: int = OS.get_memory_info().get("physical", -1)
	return {"adapter": RenderingServer.get_video_adapter_name(), "memory_mb": mem / 1048576 if mem > 0 else -1,
		"mobile": OS.has_feature("mobile")}


static func auto_here() -> int:
	var d := device()
	return auto(d["adapter"], d["memory_mb"], d["mobile"])


static func level(i: int) -> Dictionary:
	return LEVELS[clampi(i, ECONOMY, BEAUTY)]


static func valid(i: int) -> int:
	return clampi(i, ECONOMY, BEAUTY)


## Четыре строки страницы: [подпись, значение словами] — по числам уровня, а не по названию.
static func rows(i: int) -> Array:
	var l := level(i)
	var n := level(NORMAL)
	var far: float = l["far"]
	var dist := "Средняя" if is_equal_approx(far, n["far"]) else ("Ближе" if far < n["far"] else "Дальше")
	var snow := "Меньше" if l["lite"] else "Умеренно"
	var sh: int = l["shadows"]
	var shadows := "Выключены" if sh == 0 else ("Простые" if sh <= 2 else "Подробные")
	var sc: float = l["scale"]
	var res := "Полное" if sc >= 0.999 else ("Среднее" if sc >= 0.85 else "Снижено")
	return [["Дальность обзора", dist], ["Морской снег и частицы", snow], ["Тени", shadows],
		["Разрешение сцены", res]]


## Прямоугольник макета: "back", "g0"…"g2" (уровни), "fps".
static func layout_rect(id: String) -> Rect2:
	match id:
		"back":
			return BACK
		"fps":
			return FPS
	if id.begins_with("g") and id.length() == 2:
		return Rect2(Vector2(LEVEL_X[valid(int(id.substr(1)))], LEVEL_Y), LEVEL_SIZE)
	return Rect2()


static func screen_rect(id: String, size: Vector2) -> Rect2:
	return Splash.rect_to_screen(layout_rect(id), size)


## Что под касанием p на странице ("" — ничего).
static func hit(p: Vector2, size: Vector2) -> String:
	for id: String in ["back", "g0", "g1", "g2", "fps"]:
		if screen_rect(id, size).has_point(p):
			return id
	return ""


## Плашка счётчика на экране size: от правого края, масштаб по высоте.
static func counter_rect(size: Vector2) -> Rect2:
	var s := size.y / Splash.H
	return Rect2(Vector2(size.x + COUNTER.position.x * s, COUNTER.position.y * s), COUNTER.size * s)


static func counter_text(fps: int) -> String:
	return "%d кадр/с" % fps


## Счётчик кадров: среднее за последние 0,5 с, обновляется два раза в секунду (`push` с настоящим временем кадра).
class Fps:
	extends RefCounted
	var value := 0
	var _frames := 0
	var _time := 0.0

	## true — значение обновилось.
	func push(dt: float) -> bool:
		if dt <= 0.0:
			return false
		_frames += 1
		_time += dt
		if _time < COUNTER_EVERY - 1e-4:
			return false
		value = roundi(_frames / _time)
		_frames = 0
		_time = 0.0
		return true

	func reset() -> void:
		value = 0
		_frames = 0
		_time = 0.0
