class_name Radio
extends RefCounted
## Рация экипажа по ART-041 (`docs/concept-art/raciya.md`): живой голос в коопе — не связь ART-040 (там роль, команда
## и код), а кнопка «Говорить» над «Светом», строка своего состояния над ней и список говорящих справа сверху (буква
## роли в кружке, имя, три штриха; своё имя в список не попадает, до трёх строк). Имя держится `HOLD` после последнего
## пакета голоса, вход и выход — `FADE`.
## Режимы: «Нажать и держать» — передача, пока палец на кнопке (отпускание, меню, пауза, выход из забега — сразу
## стоп); «По голосу» — кнопка включает и выключает микрофон, подпись «Микрофон».
## «Вас слышно» — только когда голос реально уходит (`link` ставит `VoiceIO` по `Voice.Station.link`; голоса
## товарищей — `heard` оттуда же). Разрешение микрофона Android — `MicPermit` (`mic`; нажали без доступа — `begged`,
## системный запрос делает `OverlayFlow.radio_step`); раскладка, состояния и список — здесь, рисует `scripts/game/radio_panel.gd` (`main.radio_panel`),
## удержание — `Touch.Router.held_in` по `blocks` (`OverlayFlow.radio_step`), снимок `shot.gd raciya=…`.

enum Mode { HOLD, VOICE }

## Рация на экране в коопе (#634: захват, сеть и разрешение микрофона готовы). Выключить — только снимки и тесты.
static var enabled := true

const REF_H := 1080.0
const HOLD := 0.4           ## имя держится после последнего пакета, с
const FADE := 0.15          ## вход и выход строки, с
const ROWS := 3             ## строк в списке не больше
const ASK_TIME := 4.0       ## «Разрешите микрофон» после нажатия без доступа, с

## Места при 2400×1080: x — от правого края (W − …), масштаб H/1080 (`raciya.md`).
const BUTTON := Rect2(370, 340, 300, 128)    ## кнопка «Говорить» над «Светом»
const STATE := Rect2(370, 280, 300, 48)      ## строка своего состояния над кнопкой
const LIST := Rect2(780, 280, 360, 72)       ## первая строка списка говорящих
const LIST_STEP := 84.0
const HEAD_UP := 46.0                        ## «Рация · игроки» над списком
const ASK := Rect2(1180, 340, 360, 128)      ## «Разрешите микрофон» / «В настройки» левее списка
const BUTTON_PX := 36.0
const STATE_PX := 28.0
const NAME_PX := 32.0
const LETTER_PX := 30.0
const HEAD_PX := 24.0
const SUB_PX := 22.0

const HEAD := "Рация · игроки"
const OUT_OF_VIEW := "Вне поля зрения"
const ASK_TEXT := "Разрешите микрофон"
const ASK_BUTTON := "В настройки"
const LETTERS := ["П", "С", "И", "Б"]   ## как `Comms.LETTERS`


## Говорящий товарищ: строка списка.
class Talker:
	extends RefCounted
	var id := 0
	var name := ""
	var role := 0
	var since := 0.0     ## с последнего пакета голоса, с
	var a := 0.0         ## альфа строки
	var level := 0.0     ## громкость последнего пакета 0…1 — высота штрихов
	var seen := true     ## виден в кадре; за стеной — строка с «Вне поля зрения»


var on := false          ## рация на экране (кооп, `enabled`)
var mode := Mode.HOLD
var mic := true          ## разрешение микрофона Android есть
var mic_on := true       ## переключатель «Микрофон» в настройках
var hear := true         ## переключатель «Звук товарищей»
var volume := 0.7        ## громкость товарищей 0…1 (страница «Голос» — `Settings.mates`; для проигрывателя голоса)
var link := false        ## голос реально уходит в сеть (`VoiceIO`: захват даёт пакеты и есть куда слать)
var held := false        ## «Нажать и держать»: палец на кнопке
var toggled := false     ## «По голосу»: микрофон включён кнопкой
var hidden := false      ## меню, пауза, шторки, вне забега — передачи нет
var ask := 0.0           ## сколько ещё держать «Разрешите микрофон»
var settings_wanted := false   ## нажали «В настройки» (забирает `OverlayFlow.radio_step` — снова спросить разрешение)
var begged := false      ## в этом шаге нажали кнопку без доступа — первый раз спросить разрешение (`MicPermit`)
var pinned := false      ## снимок `shot.gd raciya=…`: состояние держится как задано, `OverlayFlow.radio_step` только рисует
var talkers: Array[Talker] = []
var _was_down := false


## Шаг: `down` — палец держит кнопку (`Touch.Router.held_in`), `hidden` — рация под меню/паузой/шторкой.
func update(dt: float, down: bool, is_hidden: bool) -> void:
	hidden = is_hidden or not on
	if hidden:
		down = false
		toggled = false
	var pressed := down and not _was_down
	_was_down = down
	begged = pressed and not mic
	if begged:
		ask = ASK_TIME   # доступа нет — просим разрешение, передачу сами не включаем
	match mode:
		Mode.HOLD:
			held = down and mic
			toggled = false
		Mode.VOICE:
			held = false
			if pressed and mic:
				toggled = not toggled
	ask = maxf(0.0, ask - dt)
	if mic:
		ask = 0.0
	for t in talkers:
		t.since += dt
		var want := 1.0 if t.since <= HOLD and hear else 0.0
		t.a = move_toward(t.a, want, dt / FADE)
	talkers = talkers.filter(func(t: Talker) -> bool: return t.a > 0.0 or (t.since <= HOLD and hear))


## Хочет ли игрок говорить (кнопка держится или микрофон включён).
func wants() -> bool:
	return not hidden and mic and mic_on and (held if mode == Mode.HOLD else toggled)


## Голос реально уходит — только тогда «Вас слышно» и светлая кнопка.
func sending() -> bool:
	return wants() and link


## Пакет голоса товарища (`id` — место в экипаже; своё имя сюда не передают).
func heard(id: int, who: String, role: int, level := 1.0, seen := true) -> void:
	for t in talkers:
		if t.id == id:
			t.since = 0.0
			t.level = clampf(level, 0.0, 1.0)
			t.seen = seen
			t.name = who
			t.role = role
			return
	var n := Talker.new()
	n.id = id
	n.name = who
	n.role = role
	n.level = clampf(level, 0.0, 1.0)
	n.seen = seen
	talkers.append(n)


## Над кем табличка ART-033 в «активности» (контур ярче, три штриха): места в экипаже товарищей, чей голос идёт
## (`HOLD` после пакета), если звук товарищей включён и товарищ в поле зрения (`seen`) — сквозь стены нет, за стеной
## остаётся только строка списка. Пакеты голоса приходят только в коопе — без них никого.
func voice() -> Array[int]:
	var out: Array[int] = []
	if not hear:
		return out
	for t in talkers:
		if t.since <= HOLD and t.seen:
			out.append(t.id)
	return out


## Строки списка сверху вниз: первые `ROWS` по порядку, в котором заговорили; при выключенном звуке — пусто.
func rows() -> Array[Talker]:
	var out: Array[Talker] = []
	for t in talkers:
		if t.a > 0.0 and out.size() < ROWS:
			out.append(t)
	return out


## Строка своего состояния над кнопкой.
func state_text() -> String:
	if not mic:
		return "Нет доступа"
	if not hear:
		return "Звук выкл."
	if sending():
		return "Вас слышно"
	if wants():
		return "Нет передачи"   # голос не уходит — «Вас слышно» не пишем
	if mode == Mode.VOICE:
		return "Микрофон выкл." if not mic_on else "Нажмите"
	return "Удерживайте"


func button_text() -> String:
	return "Микрофон" if mode == Mode.VOICE else "Говорить"


## Три штриха активности строки: высоты 0…1 (движутся, пока пакеты идут).
static func bars(t: Talker, time: float) -> Array[float]:
	var out: Array[float] = []
	var live := t.since <= HOLD
	for i in 3:
		var w := 0.5 + 0.5 * sin(time * 9.0 + i * 2.1)
		out.append(lerpf(0.35, 0.35 + 0.65 * w, t.level) if live else 0.35)
	return out


## Касание «В настройки» (только пока просим разрешение).
func tap(p: Vector2, size: Vector2) -> bool:
	if hidden or ask <= 0.0:
		return false
	if ask_button_rect(size).has_point(p):
		settings_wanted = true
		ask = 0.0
		return true
	return false


## Где касание берёт рация, а не взгляд: кнопка и, пока просим разрешение, «В настройки».
func blocks(size: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if hidden:
		return out
	out.append(button_rect(size))
	if ask > 0.0:
		out.append(ask_button_rect(size))
	return out


static func scale(size: Vector2) -> float:
	return size.y / REF_H


static func _from_right(r: Rect2, size: Vector2) -> Rect2:
	var s := scale(size)
	return Rect2(size.x - r.position.x * s, r.position.y * s, r.size.x * s, r.size.y * s)


static func button_rect(size: Vector2) -> Rect2:
	return _from_right(BUTTON, size)


static func state_rect(size: Vector2) -> Rect2:
	return _from_right(STATE, size)


static func row_rect(i: int, size: Vector2) -> Rect2:
	var r := _from_right(LIST, size)
	r.position.y += LIST_STEP * scale(size) * i
	return r


static func head_at(size: Vector2) -> Vector2:
	var r := _from_right(LIST, size)
	return Vector2(r.position.x, r.position.y - HEAD_UP * scale(size))


static func ask_rect(size: Vector2) -> Rect2:
	return _from_right(ASK, size)


## «В настройки» — нижняя половина места просьбы.
static func ask_button_rect(size: Vector2) -> Rect2:
	var r := ask_rect(size)
	var s := scale(size)
	return Rect2(r.position.x + 20.0 * s, r.position.y + 56.0 * s, r.size.x - 40.0 * s, 64.0 * s)
