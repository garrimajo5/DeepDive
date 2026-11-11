class_name AddressScreen
extends RefCounted
## Экран гостя «Войти по адресу» по ART-039 (`docs/concept-art/vhod-po-adresu.md`, `vhod-po-adresu.png`,
## `vhod-po-adresu-sostoyaniya.png`): поле адреса и своя цифровая клавиатура (`AddressPad`), подпись под полем,
## «Последний удачный адрес», «Войти» / «Отмена», «Назад». Ошибки — тексты `NetLink` («Нет ответа», «Другая версия
## игры», «Экипаж полон»), адрес в поле остаётся. Последний удачный адрес — в своём файле `PATH`, отдельно от
## сохранения забега. Здесь — состояние, кнопки и раскладка без узлов; рисует `scripts/game/address_panel.gd`
## (`main.address_panel`), шаг и подключение — `LobbyFlow.address_step`. Пока нет экрана сбора ART-028, экран
## открывает «Экипаж» главного меню. Макет 2400×1080, масштаб и обрезка боков — `Splash`; места текста — левый
## край и верх видимых глифов.

const PATH := "user://adres.cfg"
static var default_path := PATH   ## тесты и снимки выключают ("")

const TITLE := "Войти по адресу"
const TITLE_AT := Vector2(400, 86)
const TITLE_PX := 64.0
const BACK := Rect2(1722, 65, 278, 110)
const BACK_PX := 34.0
const LABEL := "Адрес товарища"
const LABEL_AT := Vector2(400, 212)
const SMALL_PX := 26.0
const FIELD := Rect2(400, 271, 730, 126)
const FIELD_PX := 52.0
const FIELD_PAD := 30.0    ## текст поля от левого края
const PLACEHOLDER := "Адрес"
const HINT_AT := Vector2(400, 432)
const HINT_PX := 34.0
const LAST_LABEL := "Последний удачный адрес"
const LAST_LABEL_AT := Vector2(400, 526)
const LAST := Rect2(400, 572, 730, 110)
const LAST_PX := 36.0
const JOIN := Rect2(400, 738, 730, 127)
const JOIN_PX := 42.0
const ASK := "Попросите адрес у хоста"
const ASK_AT := Vector2(400, 912)
const KEY_PX := 52.0
const KEY_SMALL_PX := 34.0   ## «Стереть»
const RADIUS := 12.0

## Подписи под полем по состоянию.
const EMPTY_TEXT := "Введите адрес хоста"
const GOOD_TEXT := "В одной сети с хостом"
const CONNECTING_TEXT := "Подключаемся…"
const NO_ANSWER := "Нет ответа"   ## «Хост не отвечает» `NetLink` на этом экране — как на листе состояний ART-039

## Палитра ART-028 (`MainMenu`), красного нет.
const DIM := 0.6   ## затемнение фона заставки под экраном

var open := false
var field := AddressPad.Field.new()
var error := ""   ## причина последней неудачи (до следующего нажатия клавиши); "" — нет
var path := default_path


## Прямоугольник кнопки id ("back", "field", "last", "join") на экране size.
static func screen_rect(id: String, size: Vector2) -> Rect2:
	var r: Rect2 = {"back": BACK, "field": FIELD, "last": LAST, "join": JOIN}.get(id, Rect2())
	return Splash.rect_to_screen(r, size)


## Открыть экран: поле с прошлого раза, ошибки нет.
func show() -> void:
	open = true
	error = ""


## Подпись под полем: пустое — «Введите адрес хоста» (основным цветом), дальше — бирюзовым.
func hint() -> String:
	if field.connecting:
		return CONNECTING_TEXT
	if error != "":
		return error
	match field.state():
		AddressPad.Check.EMPTY:
			return EMPTY_TEXT
		AddressPad.Check.BAD:
			return AddressPad.BAD_TEXT
	return GOOD_TEXT


## Видна ли кнопка «последний адрес» (адреса ещё нет — скрыта, остальное не двигается).
func has_last() -> bool:
	return field.last != ""


## Что под касанием p: "back", "last", "join", клавиша AddressPad.KEYS ("1"…"9", ".", "del") или "".
## Неактивное не отвечает: клавиши и «последний» во время подключения, «Войти» с негодным адресом.
func hit(p: Vector2, size: Vector2) -> String:
	if not open:
		return ""
	if screen_rect("back", size).has_point(p):
		return "back"
	if screen_rect("join", size).has_point(p):
		return "join" if field.connecting or field.can_join() else ""
	if field.connecting:
		return ""
	if has_last() and screen_rect("last", size).has_point(p):
		return "last"
	return AddressPad.key_at(p, size)


## Нажатие id. Возвращает, что сделать игре: "join" — подключаться к `field.text`, "cancel" — бросить попытку,
## "back" — закрыть экран (в главное меню; попытка, если шла, брошена), "" — только сам экран.
func press(id: String) -> String:
	if not open:
		return ""
	match id:
		"back":
			return back()
		"join":
			if field.connecting:
				field.cancel()
				return "cancel"
			if field.begin():
				error = ""
				return "join"
		"last":
			if field.recall():
				error = ""
		"":
			pass
		_:
			if field.press(id):
				error = ""
	return ""


## «Назад» (кнопка или системная): во время подключения — отмена попытки, иначе — закрыть экран.
func back() -> String:
	if field.connecting:
		field.cancel()
		return "cancel"
	open = false
	return "back"


## Итог попытки по состоянию клиента: true — на борту (адрес запомнен и сохранён, экран закрыт); отказ или
## тишина — причина под полем, адрес остаётся. Пока подключается — false.
func result(state: NetLink.State, why: String) -> bool:
	if not field.connecting:
		return false
	match state:
		NetLink.State.JOINED:
			field.finish(true)
			save_last()
			open = false
			return true
		NetLink.State.REFUSED, NetLink.State.LOST, NetLink.State.OFF:
			field.finish(false)
			error = NO_ANSWER if why == "timeout" or why == "" else NetLink.WHY.get(why, "Отказ хоста")
	return false


## Попытку не начать (адрес не открылся сокетом): та же «Нет ответа».
func failed() -> void:
	field.finish(false)
	error = NO_ANSWER


## Последний удачный адрес из файла (`path` пустой — ничего).
func load_last() -> void:
	if path.is_empty():
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var a := str(cfg.get_value("net", "last", ""))
	if AddressPad.check(a) == AddressPad.Check.OK:
		field.last = a


func save_last() -> void:
	if path.is_empty() or field.last.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("net", "last", field.last)
	cfg.save(path)
