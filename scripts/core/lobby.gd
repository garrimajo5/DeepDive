class_name Lobby
extends RefCounted
## Экран сбора экипажа перед кооп-забегом по ART-028 (`docs/concept-art/sbor-ekipazha.md`, `sbor-ekipazha.png`,
## `sbor-ekipazha-sostoyaniya.png`): комната хоста — четыре строки ролей П/С/И/Б, кто занял, кто готов; «Выбрать роль»
## у свободной, «Готов» / «Отменить готовность», «Начать погружение» только у хоста. Здесь — состояние комнаты,
## правила, строки и раскладка без узлов; рисует `scripts/game/lobby_panel.gd`.
## Правила: роль закрепляет хост (`act` — у хоста и для своих нажатий, и для запросов гостей), чужой выбор не
## перезаписывается, смена своей роли снимает готовность; старт — только хост, 2–4 игрока с ролями, все готовы,
## свободные места старту не мешают. Гость нажимает — запрос хосту (`press` → строка запроса), видит снимок
## комнаты хоста (`pack` / `unpack`). Макет 2400×1080 вписан в экран по центру (`scale`), текст не растягивается.
## У хоста — по ART-039 (`vhod-po-adresu.md`, `vhod-po-adresu-host.png`): «Ваш адрес» крупно над ролями (`address`,
## `address_text`), «Назад» вверху вместо «Создать забег» / «Подключиться», строки и кнопки ниже на `SHIFT` (`dy`).
## Вход (`entry`, по «Экипаж» из меню, пока нет поиска забегов): по макету «В сети никого нет» — «Создать забег»
## и «По адресу» на месте «Обновить список» (ART-039), «Подключиться» вверху погашена до поиска; итог прошлой
## попытки — `why` вместо заголовка.

const W := 2400.0
const H := 1080.0
const SEATS := 4
const HOST := 1   ## id хоста (как у ENet: сервер — 1)
const NAME_MAX := 18   ## длиннее — многоточие

const TITLE := "СБОР ЭКИПАЖА"
const TITLE_AT := Vector2(222, 74)     ## левый край и верх глифов
const TITLE_PX := 58.0
const SUB_AT := Vector2(222, 150)
const SUB_PX := 30.0
const RULE_Y := 222.0                  ## черта под заголовком, x 222…2190
const HEAD_AT := Vector2(380, 250)     ## «3 из 4 мест · …»
const SMALL_PX := 29.0
const CREATE := Rect2(1360, 76, 400, 104)
const SEARCH := Rect2(1790, 76, 400, 104)
const ROW := Rect2(380, 300, 1640, 112)   ## строка роли 0; следующие ниже на ROW_STEP
const ROW_STEP := 130.0
const PICK := Rect2(1540, 308, 468, 96)   ## «Выбрать роль» в строке 0
const READY := Rect2(520, 900, 580, 112)
const START := Rect2(1140, 900, 740, 112)
const NOTE := Rect2(504, 828, 1392, 58)   ## строка под ролями: «Готовы 2 из 3 · …»
const BACK := Rect2(800, 930, 800, 104)   ## «Назад к списку» — роль занята
const CIRCLE_X := 64.0                 ## центр кружка роли от левого края строки
const CIRCLE_R := 37.0
const NAME_X := 130.0                  ## названия и имени от левого края строки
const STATE_X := 1180.0                ## значок состояния от левого края строки; текст — правее на 50
const ROLE_PX := 34.0
const PNAME_PX := 30.0
const LETTER_PX := 39.0
const BUTTON_PX := 34.0
const RADIUS := 12.0

## Хост по ART-039: заголовок выше, «Назад» справа вверху, плашка адреса над ролями; всё ниже — на SHIFT.
const SHIFT := 20.0
const HOST_TITLE_AT := Vector2(380, 65)
const LEAVE := Rect2(1720, 52, 300, 112)     ## «Назад» хоста — выйти из комнаты
const ADDR := Rect2(380, 190, 1640, 100)     ## плашка «Ваш адрес»
const ADDR_LABEL_AT := Vector2(400, 222)
const ADDR_LABEL_PX := 34.0
const ADDR_AT := Vector2(650, 208)
const ADDR_PX := 64.0
const ADDR_HINT_AT := Vector2(1430, 230)
const ADDR_HINT_PX := 30.0
const NO_ADDR := "Нет адреса сети"

## Вход (`entry`): места по листу состояний ART-028, «02 · В сети никого нет».
const ENTRY_SUB := "Одна сеть Wi-Fi · создайте забег или войдите по адресу"
const ENTRY_HEAD := "Кооп-забег"
const ENTRY_HEAD_Y := 410.0          ## центр строки заголовка
const ENTRY_LINES := ["Подключитесь к одной сети Wi-Fi.", "Один создаёт забег, остальные входят по адресу."]
const ENTRY_LINE_Y := 506.0          ## центр первой строки; следующая ниже на ENTRY_LINE_STEP
const ENTRY_LINE_STEP := 66.0
const ENTRY_CX := 1192.0             ## ось текста — между нижними кнопками
const NEW := Rect2(512, 800, 660, 112)       ## «Создать забег» (главное действие)
const BY_ADDR := Rect2(1211, 800, 660, 112)  ## «По адресу» — на месте «Обновить список»
## Итог прошлой попытки на входе (`why`).
const WHY := {"port": "Забег не открылся: сеть занята", "lost": "Связь с хостом потеряна"}

## Палитра ART-028 (как `MainMenu`), красного нет.
const DIM := Color(0.043, 0.11, 0.141, 0.84)   ## затемнение мостика под экраном (#0B1C24)
const LETTERS := ["П", "С", "И", "Б"]
const RING := [Color("#E39E38"), Color("#45C2CC"), Color("#D5E4E8"), Color("#73BD5C")]   ## И — нейтральный до решения (#129)

## Что показывает строка роли.
enum Look { FREE, WAIT, READY, TAKEN }


## Игрок в комнате.
class Player:
	var id := 0
	var name := ""
	var role := -1      ## -1 — ещё без роли
	var ready := false

	func _init(i: int, n: String) -> void:
		id = i
		name = n


var open := false
var me := HOST                 ## свой id
var players: Array[Player] = []   ## по порядку входа; первый — хост
var started := false
var refused := -1              ## роль, в которой отказал хост (своя попытка) — «Занято» и подсказка; −1 — нет
var address := ""              ## у хоста: свой адрес в локальной сети ("" — нет сети)
var entry := false             ## вход: «Создать забег» / «По адресу» (комнаты ещё нет)
var why := ""                  ## на входе: чем кончилась прошлая попытка (ключ `WHY`), "" — ничего


## Комната хоста: хост — первый игрок; addr — свой адрес для гостей (`local_address`).
func host(name: String, addr := "") -> void:
	entry = false
	players.clear()
	me = HOST
	started = false
	refused = -1
	address = addr
	add(HOST, name)


## Вход по «Экипаж»: комнаты нет; w — итог прошлой попытки (`WHY`).
func show_entry(w := "") -> void:
	open = true
	entry = true
	why = w
	players.clear()
	started = false
	refused = -1
	address = ""


## Гость в комнате хоста: свой id и снимок придут от хоста (`LobbyLink.take`).
func guest() -> void:
	open = true
	entry = false
	why = ""
	players.clear()
	me = -1
	started = false
	refused = -1
	address = ""


## Заголовок входа: итог прошлой попытки или «Кооп-забег».
func entry_head() -> String:
	return WHY.get(why, ENTRY_HEAD)


## Адрес хоста из адресов устройства (локальная сеть IPv4, `AddressPad.host_address`).
static func local_address() -> String:
	return AddressPad.host_address(IP.get_local_addresses())


## Плашка адреса — только у хоста.
func shows_address() -> bool:
	return is_host() and not entry


## Сдвиг строк и кнопок вниз: у хоста плашка адреса (ART-039), у гостя — макет ART-028.
func dy() -> float:
	return SHIFT if shows_address() else 0.0


## Адрес крупно и подпись справа; нет сети — «Нет адреса сети» и «Подключитесь к сети».
func address_text() -> String:
	return address if address != "" else NO_ADDR


func address_hint() -> String:
	return "Скажите его товарищам" if address != "" else "Подключитесь к сети"


## Масштаб макета на экран size: вписан целиком, по центру.
static func scale(size: Vector2) -> float:
	return minf(size.x / W, size.y / H)


static func to_screen(p: Vector2, size: Vector2) -> Vector2:
	var s := scale(size)
	return p * s + (size - Vector2(W, H) * s) * 0.5


static func rect_to_screen(r: Rect2, size: Vector2) -> Rect2:
	return Rect2(to_screen(r.position, size), r.size * scale(size))


## Строка роли i и её кнопка «Выбрать роль» в макете; dy — сдвиг вниз (`dy()`).
static func row_rect(i: int, shift := 0.0) -> Rect2:
	return Rect2(ROW.position + Vector2(0.0, ROW_STEP * i + shift), ROW.size)


static func pick_rect(i: int, shift := 0.0) -> Rect2:
	return Rect2(PICK.position + Vector2(0.0, ROW_STEP * i + shift), PICK.size)


## Имя одной строкой: пустое — «Игрок N», длинное — многоточие.
static func short(name: String, n: int) -> String:
	var s := name.strip_edges()
	if s == "":
		s = "Игрок %d" % n
	return s if s.length() <= NAME_MAX else s.substr(0, NAME_MAX - 1) + "…"


## Прийти в комнату. Мест четыре: пятому — false (`NetLink` — «Экипаж полон»).
func add(id: int, name: String) -> bool:
	if find(id) != null:
		return true
	if players.size() >= SEATS:
		return false
	players.append(Player.new(id, short(name, players.size() + 1)))
	return true


## Уйти: роль свободна.
func remove(id: int) -> void:
	var p := find(id)
	if p:
		players.erase(p)


func find(id: int) -> Player:
	for p in players:
		if p.id == id:
			return p
	return null


## Кто держит роль (null — свободна).
func holder(role: int) -> Player:
	for p in players:
		if p.role == role:
			return p
	return null


func mine() -> Player:
	return find(me)


func is_host() -> bool:
	return me == HOST


## Правило комнаты от игрока id (у хоста): "role:<i>" — занять роль, "ready" / "unready", "start" — только хост.
## Возвращает "" — принято, иначе причину: "taken" (роль занята другим), "no_role", "not_host", "not_all", "".
func act(id: int, what: String) -> String:
	var p := find(id)
	if p == null or started:
		return "gone"
	if what.begins_with("role:"):
		var r := int(what.substr(5))
		if r < 0 or r >= SEATS:
			return "bad"
		var h := holder(r)
		if h != null and h != p:
			return "taken"
		if p.role != r:
			p.role = r
			p.ready = false   # смена своей роли снимает готовность
		return ""
	match what:
		"ready":
			if p.role < 0:
				return "no_role"
			p.ready = true
		"unready":
			p.ready = false
		"start":
			if id != HOST:
				return "not_host"
			if not can_start():
				return "not_all"
			started = true
		_:
			return "bad"
	return ""


## Можно ли начать: 2–4 игрока, у каждого роль (разные — по правилу `act`), все готовы.
func can_start() -> bool:
	if players.size() < 2:
		return false
	for p in players:
		if p.role < 0 or not p.ready:
			return false
	return true


func ready_count() -> int:
	return players.filter(func(p: Player) -> bool: return p.ready).size()


## Что в строке роли i.
func look(i: int) -> Look:
	var h := holder(i)
	if h == null:
		return Look.FREE
	if i == refused and h.id != me:
		return Look.TAKEN
	return Look.READY if h.ready else Look.WAIT


## Вторая строка роли: «Игрок 1 · вы · хост», «Лена · хост», «Игорь», «Свободно».
func who(i: int) -> String:
	var h := holder(i)
	if h == null:
		return "Свободно"
	var s := h.name
	if h.id == me:
		s += " · вы"
	if h.id == HOST:
		s += " · хост"
	return s


## Есть ли «Выбрать роль» у строки i: роль свободна (своя роль занята — можно перейти на свободную).
func can_pick(i: int) -> bool:
	return holder(i) == null and mine() != null


func host_name() -> String:
	var h := find(HOST)
	return h.name if h else ""


## Подзаголовок: «Забег «Игрок 1» · вы — хост», у гостя — «· подключено» или «· выберите свободную роль».
func subtitle() -> String:
	var s := "Забег «%s»" % host_name()
	if is_host():
		return s + " · вы — хост"
	if refused >= 0:
		return s + " · выберите свободную роль"
	return s + " · подключено"


func head() -> String:
	return "%d из %d мест · все подключённые выбирают роль" % [players.size(), SEATS]


## Свободные роли буквами: «И или Б».
func free_letters() -> String:
	var l := []
	for i in SEATS:
		if holder(i) == null:
			l.append(LETTERS[i])
	return " или ".join(l)


## Строка под ролями — что ждём.
func note() -> String:
	var m := mine()
	if refused >= 0 and holder(refused) != null and (m == null or m.role < 0):
		return "%s уже занят: %s. Выберите %s." % [Crew.ROLE_NAMES[refused], holder(refused).name, free_letters()]
	if m == null or m.role < 0:
		return "Выберите свободную роль"
	var n := players.size()
	if can_start():
		var s := "Все %d игрока готовы" % n
		return s + (" · свободное место не мешает старту" if n < SEATS else "")
	if n < 2:
		return "Ждём товарищей · нужно от 2 до 4 игроков"
	if not m.ready:
		return "Готовы %d из %d · подтвердите готовность" % [ready_count(), n]
	return "Готовы %d из %d · ждём остальных" % [ready_count(), n]


## Подпись своей кнопки готовности.
func ready_text() -> String:
	var m := mine()
	return "Отменить готовность" if m and m.ready else "Готов"


## Подпись кнопки старта: у гостя — «Ждём начала от хоста» (не кнопка).
func start_text() -> String:
	return "Начать погружение" if is_host() else "Ждём начала от хоста"


## Видна ли «Назад к списку» (роль занята — вместо «Готов» и старта).
func shows_back() -> bool:
	var m := mine()
	return refused >= 0 and (m == null or m.role < 0)


## Работает ли кнопка id: "ready", "start", "back", "leave" («Назад» хоста), "pick<i>"; «Создать забег»
## и «Подключиться» в комнате погашены (у хоста их нет — на их месте «Назад»).
func enabled(id: String) -> bool:
	if not open or started:
		return false
	if entry:
		return id in ["create", "new", "address"]
	var m := mine()
	if id.begins_with("pick"):
		return can_pick(int(id.substr(4)))
	match id:
		"leave":
			return shows_address()
		"back":
			return shows_back()
		"ready":
			return not shows_back() and m != null and m.role >= 0
		"start":
			return not shows_back() and is_host() and can_start()
	return false


## Кнопка id на экране; shift — сдвиг строк и нижних кнопок (`dy()`), верхние кнопки не сдвигаются.
static func screen_rect(id: String, size: Vector2, shift := 0.0) -> Rect2:
	if id.begins_with("pick"):
		return rect_to_screen(pick_rect(int(id.substr(4)), shift), size)
	var r: Rect2 = {"create": CREATE, "search": SEARCH, "new": NEW, "address": BY_ADDR, "leave": LEAVE, "ready": READY, "start": START, "back": BACK,
		"note": NOTE}.get(id, Rect2())
	if id in ["ready", "start", "back", "note"]:
		r.position.y += shift
	return rect_to_screen(r, size)


## Кнопка id этой комнаты на экране (со сдвигом хоста).
func rect(id: String, size: Vector2) -> Rect2:
	return screen_rect(id, size, 0.0 if entry else dy())


## Какая работающая кнопка под касанием p ("" — никакая).
func hit(p: Vector2, size: Vector2) -> String:
	var ids := ["create", "new", "address", "leave", "ready", "start", "back"]
	for i in SEATS:
		ids.append("pick%d" % i)
	for id: String in ids:
		if enabled(id) and rect(id, size).has_point(p):
			return id
	return ""


## Нажатие кнопки id. Возвращает запрос хосту для `act` ("role:<i>", "ready", "unready", "start"), "back" — выйти
## из комнаты, "" — ничего. У хоста запрос сразу применён (отказ — «Занято» в строке).
func press(id: String) -> String:
	if not enabled(id):
		return ""
	if entry:   # вход: «Создать забег» (вверху или внизу) — комната хоста, «По адресу» — экран адреса ART-039
		why = ""
		return "address" if id == "address" else "create"
	var q := ""
	if id.begins_with("pick"):
		q = "role:" + id.substr(4)
	elif id == "ready":
		q = "unready" if mine().ready else "ready"
	else:
		q = id
	if q == "back" or q == "leave":
		return back()
	if is_host():
		answer(act(me, q), q)
	return q


## Ответ хоста на свой запрос q: отказ в роли — «Занято» в её строке, принят — отказ забыт.
func answer(why: String, q: String) -> void:
	if why == "taken" and q.begins_with("role:"):
		refused = int(q.substr(5))
	elif why == "" and q.begins_with("role:"):
		refused = -1


## Выйти из комнаты (кнопка или системная «Назад»).
func back() -> String:
	open = false
	return "back"


## Снимок комнаты для гостей: [[id, имя, роль, готов], …] и старт.
func pack() -> Dictionary:
	var l := []
	for p in players:
		l.append([p.id, p.name, p.role, p.ready])
	return {"p": l, "go": started}


## Снимок хоста у гостя (свой id — `me`); своя попытка с отказом остаётся, пока роль не стала своей.
func unpack(d: Dictionary) -> void:
	players.clear()
	for a: Array in d.get("p", []):
		var p := Player.new(int(a[0]), str(a[1]))
		p.role = int(a[2])
		p.ready = bool(a[3])
		players.append(p)
	started = bool(d.get("go", false))
	var m := mine()
	if m and m.role >= 0 and m.role == refused:
		refused = -1
