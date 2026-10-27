class_name SoundPage
extends RefCounted
## Страница «Настройки · Звук» (эпик #641): громкость каждой шины звука `SoundMix` своим ползунком — музыка, океан за
## бортом (эмбиент), корабль, существа (мир), голоса в эфире, интерфейс. Шесть ползунков в две колонки по три строки.
## Значения хранит `Settings.buses` (шина → доля 0…1, по умолчанию 100 %), страницу открывает `Settings.page` =
## "zvuk", доля пользователя умножается на сведение шины в `SoundMix.apply` (`Main._sound`); общая громкость (Master)
## — ползунок «Громкость» основной страницы. Рисует `SettingsPanel`. Макет 2400×1080 через `Splash`; заголовок и
## «Назад» — на местах страницы «Графика» ART-044, подписи и дорожки — как у «Громкости товарищей» `VoicePage`.

const TITLE := "Настройки · Звук"
const LABEL_PX := 38.0
## Строки: шина и подпись. Ползунок i — id "s<i>", колонка i / 3, строка i % 3.
const ROWS := [
	[SoundMix.MUSIC, "Музыка"],
	[SoundMix.AMBIENT, "Океан за бортом"],
	[SoundMix.SHIP, "Корабль"],
	[SoundMix.WORLD, "Существа"],
	[SoundMix.VOICE, "Голоса в эфире"],
	[SoundMix.UI, "Интерфейс"],
]
const COLUMNS := [Vector2(420, 1140), Vector2(1220, 1940)]   ## колонка: левый и правый край (подпись и значение)
const KNOB_PAD := 20.0        ## дорожка — внутри колонки на столько с каждой стороны (ручка не вылезает)
const LABEL_TOP := 225.0      ## верх глифов подписи первой строки
const TRACK_DY := 105.0       ## от верха подписи до дорожки
const ROW_STEP := 250.0
const TOUCH_H := 96.0         ## полоса касания по высоте вокруг дорожки
const NOTE := "Общую громкость задаёт ползунок «Громкость» на основной странице"
const NOTE_TOP := 975.0
const NOTE_PX := 28.0

const DEFAULT := 1.0


static func count() -> int:
	return ROWS.size()


static func id_of(i: int) -> String:
	return "s%d" % i


## Номер ползунка по id "s<i>"; −1 — не ползунок этой страницы.
static func index(id: String) -> int:
	if not id.begins_with("s") or id.length() < 2 or not id.substr(1).is_valid_int():
		return -1
	var i := int(id.substr(1))
	return i if i >= 0 and i < ROWS.size() else -1


static func bus(i: int) -> String:
	return ROWS[i][0]


static func label(i: int) -> String:
	return ROWS[i][1]


static func label_top(i: int) -> float:
	return LABEL_TOP + ROW_STEP * (i % 3)


static func track_y(i: int) -> float:
	return label_top(i) + TRACK_DY


static func column(i: int) -> Vector2:
	return COLUMNS[floori(i / 3.0)]


## Дорожка ползунка i в x макета: от и до.
static func track_x(i: int) -> Vector2:
	var c := column(i)
	return Vector2(c.x + KNOB_PAD, c.y - KNOB_PAD)


static func layout_rect(id: String) -> Rect2:
	if id == "back":
		return Graphics.BACK
	var i := index(id)
	if i < 0:
		return Rect2()
	var c := column(i)
	return Rect2(c.x, track_y(i) - TOUCH_H * 0.5, c.y - c.x, TOUCH_H)


static func screen_rect(id: String, size: Vector2) -> Rect2:
	return Splash.rect_to_screen(layout_rect(id), size)


static func ids() -> Array[String]:
	var out: Array[String] = ["back"]
	for i in ROWS.size():
		out.append(id_of(i))
	return out


## Что под касанием p на странице ("" — ничего).
static func hit(p: Vector2, size: Vector2) -> String:
	return Splash.hit_ids(p, size, ids(), screen_rect)


## Доли пользователя по всем шинам: 100 %, кроме переданных в user (шина → доля), — в пределах 0…1.
static func gains(user: Dictionary) -> Dictionary:
	var out := {}
	for r: Array in ROWS:
		out[r[0]] = clampf(float(user.get(r[0], DEFAULT)), 0.0, 1.0)
	return out
