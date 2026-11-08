class_name Comms
extends RefCounted
## Внутренняя связь на мостике по ART-040 (`docs/concept-art/svyaz.md`): плашка внизу по центру — кружок с буквой
## роли, название роли, команда, нижняя строка «Код: <слово>» у своего и «Код: …» у подделки (вариант А), кнопка
## «Спросить код». Одна плашка, остальные сообщения — в очереди; показ не меньше 8 с (или речь + 2 с), вход и выход
## 0,15 с. При голосовании, итоге, меню, паузе и брифинге связь откладывается (`update(dt, hidden)`): плашка тает,
## часы стоят. Проверка одной кнопкой: «Ждём ответ…» / «Проверяем» → «Код совпал» (2 с) или ответ с чужим кодом,
## «Код не совпал» (1,5 с) → «Это был не наш», «Понятно» (4 с). Молчание — «Нет ответа», это не разоблачение, можно
## спросить снова. Проверяет логика события (подделку знает тот, кто её прислал), не игрок заявленной роли.
## Кодовое слово одно на забег (`reset_run`). Источник голосов — живой мир через `EcoLink.VOICE` (`Main.on_eco_event`).
## Здесь — очередь, часы, состояние проверки и места (макет 2400×1080, масштаб H/1080); рисует
## `scripts/game/comms_panel.gd` (`main.comms_panel`), касания — `OverlayFlow.comms_step` через `Touch.Router.taps`/`blocks`.
## Кооп: очередь и проверку ведёт хост, гостю едет снимок `pack` в кадре (`ev["c"]`), гость `follow` — ставит его
## `apply`, сам только тает; его «Спросить код» / «Понятно» — `asked` (номер сообщения) → `Crew.Pad.ask` → хост `press`.

enum Ask { NONE, WAIT, MATCH, WRONG, EXPOSED, SILENT }

const REF_H := 1080.0
const FADE := 0.15            ## вход и выход альфой, с
const MIN_SHOW := 8.0         ## показ сообщения не меньше, с
const AFTER_SPEECH := 2.0     ## после конца речи держать ещё, с
const ANSWER_TIME := 1.0      ## ответ источника на «Спросить код», с
const SILENT_TIME := 4.0      ## ждём ответа до «Нет ответа», с
const MATCH_TIME := 2.0       ## «Код совпал»
const WRONG_TIME := 1.5       ## ответ с чужим кодом, «Код не совпал»
const EXPOSED_TIME := 4.0     ## «Это был не наш» до «Понятно»
const QUEUE_MAX := 6          ## больше в очереди не держим — старые выпадают

## Короткие слова интерфейса (не названия сюжетных сущностей, `svyaz.md`).
const WORDS := ["Иней", "Пепел", "Маяк", "Компас", "Якорь", "Сокол", "Кедр", "Гранит", "Ветер", "Орион", "Багор",
	"Шквал", "Рубин", "Ковш", "Перо", "Кварц"]

const ROLE_NAMES := ["Пилот", "Сонарщик", "Инженер", "Биолог"]   ## как `Crew.ROLE_NAMES`
const LETTERS := ["П", "С", "И", "Б"]
const ROLE_RING := [Color("E39E38"), Color("45C2CC"), Color("D5E4E8"), Color("73BD5C")]   ## ART-028, И — нейтральный
const SUB := "· экипаж"
const EXPOSED_TITLE := "Связь"
const EXPOSED_TEXT := "Это был не наш"

## Места при 2400×1080 (верх видимых глифов для строк), `art/ART-040-svyaz/notes.md` в истории PR #310.
const LEFT := 520.0
const RIGHT_FROM := 620.0     ## правый край плашки W − 620
const TOP := 720.0
const HEIGHT := 310.0
const NARROW_W := 2200.0      ## уже — плашка выше (y 680, высота 350), без «· экипаж», код над кнопкой
const NARROW_UP := 40.0
const CIRCLE := Vector2(605, 797)   ## центр кружка роли (560,752,90×90)
const CIRCLE_D := 90.0
const LETTER_PX := 48.0
const ROLE_AT := Vector2(680, 744)
const ROLE_PX := 36.0
const SUB_AT := Vector2(900, 750)
const SUB_PX := 28.0
const TEXT_AT := Vector2(680, 810)
const TEXT_PX := 40.0
const CODE_AT := Vector2(680, 917)
const CODE_NARROW_Y := 834.0
const CODE_PX := 32.0
const BUTTON_FROM := 420.0    ## кнопка x = R − 420
const BUTTON := Rect2(0, 886, 380, 112)
const BUTTON_PX := 34.0
const BARS_FROM := 165.0      ## индикатор речи x = R − 165, ширина 114
const BARS := Rect2(0, 748, 114, 36)


class Msg:
	extends RefCounted
	var id := 0          ## номер сообщения за сеанс (гость нажимает именно его, `press`)
	var role := 2
	var text := ""
	var fake := false
	var ask := ""        ## просьба голоса: "ping" — импульс, "light" — свет, "" — нет (наказывает за неё мир)
	var reply := ""      ## что источник ответит на «Спросить код»: своё — кодовое слово; "" — молчит
	var t := 0.0         ## сколько уже показано (только видимое время)
	var speech := 0.0    ## длина речи, с (индикатор движется только пока она идёт)

	func show_time() -> float:
		return maxf(MIN_SHOW, speech + AFTER_SPEECH)


var code := WORDS[0]          ## кодовое слово забега
var queue: Array[Msg] = []
var cur: Msg = null           ## сообщение на плашке
var state := Ask.NONE
var st := 0.0                 ## время в состоянии проверки, с
var a := 0.0                  ## прозрачность плашки
var closing := false          ## плашка уходит — следом следующее из очереди
var shown := false            ## не отложено (`hidden` в этом кадре)
var exposed := 0              ## разоблачённых подделок за забег
var solo := true              ## одиночный забег: подпись «· экипаж»
var follow := false           ## гость сети: сообщение и проверка — из кадра хоста (`apply`), свои часы не идут
var asked := 0                ## гость: нажал кнопку сообщения с этим номером — уходит хосту (`Crew.Pad.ask`)
var next_id := 0


## Кодовое слово забега по числу (новый забег — новое слово).
static func pick(n: int) -> String:
	return WORDS[posmod(n, WORDS.size())]


## Новый забег: новое слово, связь с чистого листа.
func reset_run(n: int) -> void:
	code = pick(n)
	queue.clear()
	cur = null
	state = Ask.NONE
	st = 0.0
	a = 0.0
	closing = false
	exposed = 0
	asked = 0


## Сообщение в эфир. Своё отвечает кодом забега; подделка — чужим словом или молчит (`silent`).
func push(role: int, text: String, fake := false, ask := "", silent := false) -> Msg:
	var m := Msg.new()
	next_id += 1
	m.id = next_id
	m.role = clampi(role, 0, LETTERS.size() - 1)
	m.text = text
	m.fake = fake
	m.ask = ask
	m.speech = clampf(text.length() * 0.065, 1.5, 12.0)
	if silent:
		m.reply = ""
	elif fake:
		m.reply = wrong_word(text)
	else:
		m.reply = code
	queue.append(m)
	while queue.size() > QUEUE_MAX:
		queue.pop_front()
	return m


## Чужое слово подделки: не код забега, по тексту — одно и то же для одной реплики.
func wrong_word(text: String) -> String:
	var i := posmod(text.hash(), WORDS.size())
	if WORDS[i] == code:
		i = (i + 1) % WORDS.size()
	return WORDS[i]


func active() -> bool:
	return cur != null


## Шаг: `hidden` — связь отложена (голосование, итог, меню, пауза, брифинг): плашка тает, часы стоят.
func update(dt: float, hidden: bool) -> void:
	shown = not hidden
	if follow:
		_follow(dt, hidden)
		return
	if cur == null:
		if queue.is_empty():
			a = 0.0
			return
		cur = queue.pop_front()
		state = Ask.NONE
		st = 0.0
		closing = false
	var want := 0.0 if hidden or closing else 1.0
	a = move_toward(a, want, dt / FADE)
	if closing:
		if a <= 0.0:
			cur = null
			closing = false
		return
	if hidden or a <= 0.0:
		return
	cur.t += dt
	st += dt
	match state:
		Ask.WAIT:
			if cur.reply == "":
				if st >= SILENT_TIME:
					_go(Ask.SILENT)
			elif st >= ANSWER_TIME:
				if cur.reply == code:
					_go(Ask.MATCH)
				else:
					_go(Ask.WRONG)
		Ask.WRONG:
			if st >= WRONG_TIME:
				_go(Ask.EXPOSED)
				exposed += 1
		Ask.EXPOSED:
			if st >= EXPOSED_TIME:
				closing = true
		Ask.MATCH:
			if st >= MATCH_TIME and cur.t >= cur.show_time():
				closing = true
		Ask.SILENT:   # «Нет ответа» — время спросить снова
			if st >= SILENT_TIME and cur.t >= cur.show_time():
				closing = true
		_:
			if cur.t >= cur.show_time():
				closing = true


func _go(s: Ask) -> void:
	state = s
	st = 0.0


## Речь идёт: индикатор движется.
func speaking() -> bool:
	return cur != null and cur.t < cur.speech and state != Ask.EXPOSED


## Кнопку можно нажать.
func button_live() -> bool:
	return cur != null and not closing and state in [Ask.NONE, Ask.SILENT, Ask.EXPOSED]


## Касание: кнопка «Спросить код» / «Понятно». true — касание взяла плашка.
func tap(p: Vector2, size: Vector2) -> bool:
	if cur == null or a < 0.5 or not shown:
		return false
	if not button_rect(size).has_point(p):
		return false
	if follow:   # гость: решает хост, кнопка — его сообщению
		if button_live():
			asked = cur.id
	else:
		press(cur.id)
	return true


## Кнопка сообщения номер id (своя или гостя сети): «Спросить код» / снова после «Нет ответа» / «Понятно».
## Старое нажатие (сообщение уже сменилось) не действует. true — нажатие принято.
func press(id: int) -> bool:
	if cur == null or cur.id != id or not button_live():
		return false
	if state in [Ask.NONE, Ask.SILENT]:
		_go(Ask.WAIT)
	else:
		closing = true
	return true


## ---- Сеть: снимок хоста для гостя ----

const TEXT_MAX := 120   ## реплика в кадре не длиннее (плашка столько и не вместит)


## Снимок для кадра гостям: код забега и сообщение на плашке с ходом проверки. Ответ источника едет, только когда
## он уже показан («Код: <чужое>» и разоблачение) — до вопроса гость его не знает, как и хост.
func pack() -> Dictionary:
	var d := {"k": code}
	if cur != null:
		var reply := cur.reply if state in [Ask.WRONG, Ask.EXPOSED] else ""
		d["m"] = [cur.id, cur.role, cur.text.left(TEXT_MAX), cur.fake, reply, cur.t, cur.speech, int(state), st,
			closing, exposed]
	return d


## Гость ставит снимок хоста. Сообщения нет — плашка тает (`_follow`); новое — с начала.
func apply(d: Variant) -> void:
	if not d is Dictionary:
		return
	code = str(d.get("k", code))
	var m: Variant = d.get("m")
	if not (m is Array and m.size() == 11):
		if cur != null:
			closing = true
		return
	var id := int(m[0])
	if cur == null or cur.id != id:
		cur = Msg.new()
		cur.id = id
		a = 0.0
	cur.role = clampi(int(m[1]), 0, LETTERS.size() - 1)
	cur.text = str(m[2])
	cur.fake = bool(m[3])
	cur.reply = str(m[4])
	cur.t = float(m[5])
	cur.speech = float(m[6])
	state = clampi(int(m[7]), 0, Ask.SILENT) as Ask
	st = float(m[8])
	closing = bool(m[9])
	exposed = int(m[10])


## Гость между кадрами хоста: только прозрачность и индикатор речи.
func _follow(dt: float, hidden: bool) -> void:
	var want := 0.0 if hidden or closing or cur == null else 1.0
	a = move_toward(a, want, dt / FADE)
	if cur == null:
		return
	if closing and a <= 0.0:
		cur = null
		closing = false
		return
	if not hidden:
		cur.t += dt
		st += dt


## Где касание не крутит взгляд: кнопка видимой плашки. Вне кнопки плашка пропускает касания и свайпы.
func blocks(size: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if cur != null and shown and a > 0.0:
		out.append(button_rect(size))
	return out


## ---- Строки плашки ----

func title() -> String:
	if cur == null:
		return ""
	return EXPOSED_TITLE if state == Ask.EXPOSED else ROLE_NAMES[cur.role]


func line() -> String:
	if cur == null:
		return ""
	return EXPOSED_TEXT if state == Ask.EXPOSED else cur.text


## Нижняя строка: код или ход проверки.
func code_line() -> String:
	if cur == null:
		return ""
	match state:
		Ask.WAIT:
			return "Ждём ответ…"
		Ask.MATCH:
			return "Код совпал"
		Ask.WRONG:
			return "Код: %s" % cur.reply
		Ask.EXPOSED:
			return "Код не совпал"
		Ask.SILENT:
			return "Нет ответа"
	return "Код: …" if cur.fake else "Код: %s" % code


func button_text() -> String:
	match state:
		Ask.WAIT:
			return "Проверяем"
		Ask.MATCH:
			return "Проверено"
		Ask.WRONG:
			return "Код не совпал"
		Ask.EXPOSED:
			return "Понятно"
	return "Спросить код"


## Подпись «· экипаж»: широкий экран, не разоблачение.
func sub_wanted(size: Vector2) -> bool:
	return solo and logical_w(size) >= NARROW_W and state != Ask.EXPOSED


## ---- Места (пиксели экрана) ----

static func scale(size: Vector2) -> float:
	return size.y / REF_H


## Ширина экрана в единицах макета.
static func logical_w(size: Vector2) -> float:
	return size.x / scale(size)


static func narrow(size: Vector2) -> bool:
	return logical_w(size) < NARROW_W


## Правый край плашки в единицах макета.
static func right(size: Vector2) -> float:
	return logical_w(size) - RIGHT_FROM


static func plate_rect(size: Vector2) -> Rect2:
	var s := scale(size)
	var top := TOP - NARROW_UP if narrow(size) else TOP
	var h := HEIGHT + NARROW_UP if narrow(size) else HEIGHT
	return Rect2(LEFT * s, top * s, (right(size) - LEFT) * s, h * s)


static func button_rect(size: Vector2) -> Rect2:
	var s := scale(size)
	return Rect2((right(size) - BUTTON_FROM) * s, BUTTON.position.y * s, BUTTON.size.x * s, BUTTON.size.y * s)


static func bars_rect(size: Vector2) -> Rect2:
	var s := scale(size)
	var y := BARS.position.y - (NARROW_UP if narrow(size) else 0.0)
	return Rect2((right(size) - BARS_FROM) * s, y * s, BARS.size.x * s, BARS.size.y * s)


## Точка макета с подъёмом на узком экране (кружок, роль, подпись, команда).
static func at(p: Vector2, size: Vector2) -> Vector2:
	var up := NARROW_UP if narrow(size) else 0.0
	return Vector2(p.x, p.y - up) * scale(size)


static func code_at(size: Vector2) -> Vector2:
	var y := CODE_NARROW_Y if narrow(size) else CODE_AT.y
	return Vector2(CODE_AT.x, y) * scale(size)


## Высоты штрихов индикатора речи 0…1 (11 штрихов): движутся только пока идёт речь.
func bars(time: float) -> Array[float]:
	var out: Array[float] = []
	var live := speaking()
	for i in 11:
		var base := 0.25 + 0.2 * absf(sin(i * 1.7))
		if live:
			base = 0.2 + 0.8 * absf(sin(time * (5.0 + i * 0.9) + i * 2.3)) * (0.6 + 0.4 * absf(sin(i * 0.8 + time)))
		out.append(clampf(base, 0.1, 1.0))
	return out
