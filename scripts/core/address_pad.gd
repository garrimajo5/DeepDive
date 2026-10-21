class_name AddressPad
## Вход в забег по адресу (ART-039, `docs/concept-art/vhod-po-adresu.md`): своя цифровая клавиатура вместо системной,
## поле адреса хоста (IPv4, до 15 знаков, порт не показываем — `NetLink.PORT`), проверка адреса, последний удачный
## адрес и адрес хоста для экрана сбора. Логика без узлов: экран рисует её позже (меню ART-037).

const MAX_LEN := 15
## Клавиши по строкам: «.», «0», «Стереть» — нижний ряд.
const KEYS := [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0", "del"]]
const KEY_TEXT := {"del": "Стереть"}
## Клавиша 224×128 px с зазором 24 px: столбец c, строка r — x = 1260 + 248c, y = 270 + 152r при 2400×1080.
const KEY_SIZE := Vector2(224, 128)
const KEY_ORIGIN := Vector2(1260, 270)
const KEY_STEP := Vector2(248, 152)
const BASE := Vector2(2400, 1080)

const BAD_TEXT := "Проверьте адрес"
const NO_ADDRESS := "Нет адреса сети"
const NO_ADDRESS_HINT := "Подключитесь к сети"

enum Check { EMPTY, PARTIAL, BAD, OK }


## Подпись на клавише.
static func key_text(key: String) -> String:
	return KEY_TEXT.get(key, key)


## Прямоугольник клавиши (столбец c, строка r) на экране size: масштаб H/1080, по ширине — по центру
## (19,5:9 — x на 30 px левее, 16:9 — на 240, как в заметке ART-039).
static func key_rect(c: int, r: int, size: Vector2) -> Rect2:
	var s := size.y / BASE.y
	var dx := (size.x / s - BASE.x) * 0.5
	var at := KEY_ORIGIN + KEY_STEP * Vector2(c, r) + Vector2(dx, 0.0)
	return Rect2(at * s, KEY_SIZE * s)


## Клавиша под точкой экрана или "".
static func key_at(p: Vector2, size: Vector2) -> String:
	for r in KEYS.size():
		for c in KEYS[r].size():
			if key_rect(c, r, size).has_point(p):
				return KEYS[r][c]
	return ""


## Что с адресом: пусто, неполный (можно дописать), неверный, годный — четыре группы 0…255.
static func check(text: String) -> Check:
	if text.is_empty():
		return Check.EMPTY
	var groups := text.split(".")
	if groups.size() > 4:
		return Check.BAD
	for i in groups.size():
		var g: String = groups[i]
		if g.is_empty():
			if i == groups.size() - 1 and i > 0:
				continue   # точка в конце — дальше следующая группа
			return Check.BAD
		if g.length() > 3 or not g.is_valid_int() or int(g) > 255:
			return Check.BAD
	if groups.size() < 4 or groups[3].is_empty():
		return Check.PARTIAL
	return Check.OK


## Адрес хоста для экрана сбора: из адресов устройства (`IP.get_local_addresses()`) — локальная сеть IPv4,
## 192.168.* раньше 10.* и 172.16–31.*; петля, 169.254.* и IPv6 не годятся. "" — адреса нет (NO_ADDRESS).
static func host_address(addrs: PackedStringArray) -> String:
	var best := ""
	var best_rank := 99
	for a in addrs:
		if check(a) != Check.OK:
			continue
		var p := a.split(".")
		var rank := 99
		if p[0] == "192" and p[1] == "168":
			rank = 0
		elif p[0] == "10":
			rank = 1
		elif p[0] == "172" and int(p[1]) >= 16 and int(p[1]) <= 31:
			rank = 2
		if rank < best_rank:
			best = a
			best_rank = rank
	return best


## Поле адреса гостя: нажатия клавиш, подключение, последний удачный адрес.
class Field:
	extends RefCounted
	var text := ""
	var connecting := false   ## идёт подключение: клавиши неактивны, «Войти» — «Отмена»
	var last := ""            ## последний удачный адрес ("" — кнопки «последний» нет)

	## Нажатие клавиши; во время подключения ничего не меняет. Возвращает true, если поле изменилось.
	func press(key: String) -> bool:
		if connecting:
			return false
		if key == "del":
			if text.is_empty():
				return false
			text = text.left(-1)
			return true
		if text.length() >= AddressPad.MAX_LEN or not (key == "." or (key.length() == 1 and key.is_valid_int())):
			return false
		text += key
		return true

	func state() -> AddressPad.Check:
		return AddressPad.check(text)

	## Подпись под полем: неверный адрес — «Проверьте адрес», иначе пусто.
	func hint() -> String:
		return AddressPad.BAD_TEXT if state() == AddressPad.Check.BAD else ""

	## «Войти» активна только с годным адресом и не во время подключения.
	func can_join() -> bool:
		return not connecting and state() == AddressPad.Check.OK

	## Подпись главной кнопки.
	func join_text() -> String:
		return "Отмена" if connecting else "Войти"

	## «Войти»: начать подключение (true — можно звать `NetLink.Client.join(text)`).
	func begin() -> bool:
		if not can_join():
			return false
		connecting = true
		return true

	## Подключение кончилось: удачно — адрес запоминается как последний; нет — адрес в поле остаётся.
	func finish(joined: bool) -> void:
		connecting = false
		if joined:
			last = text

	## «Отмена» или «Назад» во время подключения.
	func cancel() -> void:
		connecting = false

	## Кнопка «последний адрес»: заполняет поле, но не подключает.
	func recall() -> bool:
		if connecting or last.is_empty():
			return false
		text = last
		return true
