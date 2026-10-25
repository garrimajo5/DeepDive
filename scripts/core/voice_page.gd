class_name VoicePage
extends RefCounted
## Страница «Настройки · Голос» рации ART-041 (`docs/concept-art/raciya.md`, кадр 08 листа `raciya-sostoyaniya.png`):
## громкость товарищей (ползунок), микрофон — статус разрешения Android, режим «Нажать и держать» / «По голосу» с
## подписью, переключатели «Звук товарищей» и «Микрофон» (приём и микрофон независимы). Значения хранит `Settings`
## (`mates`, `voice_mode`, `hear`, `mic_on`), страницу открывает `Settings.page` = "golos", в рацию переносит
## `Main._apply_settings` (`Radio.mode`, `hear`, `mic_on`, `volume`), рисует `SettingsPanel`. Макет 2400×1080 через
## `Splash`; заголовок и «Назад» — на местах страницы «Графика» ART-044.

const TITLE := "Настройки · Голос"
const LABEL_X := 420.0
const LABEL_PX := 38.0
const VALUE_RIGHT := 1940.0
## Громкость товарищей: подпись и значение, дорожка, полоса касания.
const MATES_LABEL := "Громкость товарищей"
const MATES_TOP := 225.0
const TRACK_X := Vector2(440, 1920)
const TRACK_Y := 330.0
const MATES := Rect2(420, 282, 1520, 96)
## Микрофон: статус разрешения (не кнопка — разрешение спрашивает рация, «В настройки»).
const MIC_LABEL := "Микрофон"
const STATE := Rect2(1440, 404, 500, 106)
## Режим: две кнопки, выбранная — главная; под ними — что значит выбранный режим.
const MODE_LABEL := "Режим"
const HOLD := Rect2(820, 564, 640, 108)
const VOICE := Rect2(1500, 564, 440, 108)
const NOTE_TOP := 728.0
const NOTE_PX := 28.0
const NOTES := ["Нажать и держать: передача, пока палец на кнопке", "По голосу: передача при вашей речи"]
## Переключатели приёма и микрофона.
const HEAR := Rect2(420, 844, 700, 108)
const MIC := Rect2(1160, 844, 780, 108)

const IDS := ["back", "mates", "v_hold", "v_voice", "v_hear", "v_mic"]   ## что берёт касание (статус — нет)


static func layout_rect(id: String) -> Rect2:
	match id:
		"back":
			return Graphics.BACK
		"mates":
			return MATES
		"v_state":
			return STATE
		"v_hold":
			return HOLD
		"v_voice":
			return VOICE
		"v_hear":
			return HEAR
		"v_mic":
			return MIC
	return Rect2()


static func screen_rect(id: String, size: Vector2) -> Rect2:
	return Splash.rect_to_screen(layout_rect(id), size)


## Что под касанием p на странице ("" — ничего).
static func hit(p: Vector2, size: Vector2) -> String:
	for id: String in IDS:
		if screen_rect(id, size).has_point(p):
			return id
	return ""


## Верх глифов подписи, стоящей против кнопки r (по её середине).
static func label_top(r: Rect2) -> float:
	return r.position.y + (r.size.y - LABEL_PX * Splash.CAP_H) * 0.5


static func state_text(mic: bool) -> String:
	return "Разрешён" if mic else "Нет доступа"


static func hear_text(on: bool) -> String:
	return "Звук товарищей: %s" % ("вкл." if on else "выкл.")


static func mic_text(on: bool) -> String:
	return "Микрофон: %s" % ("вкл." if on else "выкл.")


static func note(mode: int) -> String:
	return NOTES[clampi(mode, 0, NOTES.size() - 1)]
