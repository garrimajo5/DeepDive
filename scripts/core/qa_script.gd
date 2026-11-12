class_name QaScript
extends RefCounted
## Сценарий тестера: игра сама проходит шаги, снимает скриншоты и пишет лог — без тапов по координатам экрана.
## Сценарий — JSON-массив шагов (пример — tools/qa/scenario.json):
##   {"do": "wait", "s": 2}                          — подождать
##   {"do": "shot", "name": "01-start"}              — скриншот
##   {"do": "press", "what": "action"}               — нажать и отпустить (action, up, down, light;
##                                                     dive — «Погрузиться» в главном меню ART-037; в паузе ART-037:
##                                                     resume, map (схема ART-042, её «Назад» — map_back), new, exit, в подтверждении yes / no; в настройках
##                                                     graphics — страница «Графика» ART-044, на ней g0…g2 — уровень,
##                                                     fps — «Показывать кадры/с»; crew — «Экипаж»,
##                                                     journal — «Журнал экспедиции» ART-047 (закрывает back; в нём
##                                                     jcell0…jcell5 — ячейка вида, jprev / jnext, jclose,
##                                                     jtab0 / jtab1 — вкладка «Виды» / «Узнано», jlore0…2 — её строка),
##                                                     на экране «Войти по адресу» ART-039: join, last, клавиши
##                                                     key0…key9, key., keydel; brief — плашка брифинга прибытия)
##   {"do": "back"}                                  — системная «Назад» Android: пауза ART-037 (в паузе — закрыть)
##   {"do": "hold", "what": "pad", "dir": [0, 1], "s": 5} — держать (pad — с направлением [вправо, вперёд])
##   {"do": "swipe", "dx": 300, "dy": 0, "s": 0.6}   — свайп обзора, смещение в пикселях вьюпорта
##   {"do": "goto", "x": -2.2, "z": 17.2, "yaw": 90}  — перейти на палубе (дальние отсеки без ходьбы; yaw в градусах,
##                                                     "pitch" — наклон взгляда в градусах, вниз — минус; без него не меняется)
##   {"do": "hot", "heat": 80}                       — перегреть реактор (проверить вентиль и щиток машинного); heat 0 — остудить
##   {"do": "sample", "n": 8}                       — поставить корабль над образцом n (шлюз в 8 м над ним, корабль стоит)
##   {"do": "breach", "n": 0}                       — пробоина в месте n (0 мостик, 1 коридор, 2 лаборатория, 3 машинное),
##                                                     игрок встаёт у неё лицом к борту (кадр в другом месте — после
##                                                     него свой goto); "on": false — закрыть
##                                                     пробоину и убрать воду (чистый кадр после случайных ударов)
##   {"do": "route"}                                 — пройти выбранный маршрут разом (нет — первый) и открыть
##                                                     «глубже или наверх» (в слое его откроет переход у 10, #828)
##   {"do": "silt"}                                  — облако ила вокруг корабля (сонарная тьма); "on": false — убрать ил
##   {"do": "drain", "s": 4}                        — стеклоуст «на корпусе» s секунд: мир будто шлёт EcoLink.DRAIN
##                                                     (тревога и расход заряда без самого существа; указатель тревоги
##                                                     над люком — только в соло: товарищей сначала gone, #1361)
##   {"do": "hull", "pct": 30}                       — прочность корпуса, % (следы повреждений ART-049 снаружи)
##   {"do": "charge", "units": 100}                  — заряд корабля, ед. (разряд по шагам не зависит от длины прогона)
##   {"do": "pred", "n": 0, "bush": 0}             — серпохвост n проходит мимо куста огнецвета bush (EcoCoral.BASES)
##                                                     поперёк взгляда с корабля, в 2 м над вершиной, по PRED_SPAN м
##                                                     в обе стороны (#1401: гаснут кончики #1339, прячется ряд каменщиков #1337);
##                                                     "away": true — увести его от куста за 2·PRED_SPAN, остальных — ещё дальше (кадр «до»)
##   {"do": "dome", "t": 2.5}                        — купольник у гнезда 07 (EcoDome.stage): клип OpenPetal идёт t с
##                                                     (створка поднимается с 1,2 до 3,8 с, на 5 с — уходит в нишу; знание `PETAL07` забыто —
##                                                     строка створки выходит всегда, #837)
##   {"do": "zamer", "n": 0, "side": "nos"}         — фаза «замер» #1498: голодный серпохвост n в 26 м от корабля
##                                                     (`EcoPred.stage_spot`: nos — перед носом, bok — правый борт,
##                                                     korma — за кормой), прожектор включён, остальные хищники — за 400 м;
##                                                     длина замера и отход — как в игре (`alert`/`alert_leave` не меняет)
##   {"do": "ping"}                                  — импульс сонара (`Main.ping_sonar`, как с поста): у 08 — ритм поля
##   {"do": "ship", "x": 38, "y": -20, "z": -25}     — поставить корабль в точку мира (y — высота, глубина со знаком
##                                                     минус), корабль стоит: вид на дно под трещинами льда (#445)
##                                                     "yaw": 0 — ещё и курс (°, как у goto: 0 — нос к −Z), без него
##                                                     курс прежний
##   {"do": "floor"}                                 — опустить корабль на нижний предел хода над рельефом здесь
##                                                     (`Helm.Ship.floor_at` по курсу): корма и нос у грунта (#1481)
##   {"do": "outside", "at": 1.0}                    — камера с борта стоит в точке облёта at (0 — у носа, 1 — над
##                                                     кормой, `Flyby.hold_at`); "on": false — глаза на мостике;
##                                                     "lamp": true — ещё и свет тестера у камеры (`QaRunner.LAMP_*`):
##                                                     в глубине корпус и грунт иначе не видны (#1481)
##   {"do": "fly", "y": -8, "pitch": -55}            — тестовый полёт noclip: глаз на высоте y в осях корабля (над
##                                                     палубой — плюс), наклон взгляда в градусах; "on": false — на пол
##   {"do": "mate", "x": -1, "z": -2.5, "yaw": 90, "role": 2, "look": 1} — ещё один член экипажа на палубе (роль 0…3,
##                                                     внешность 0 — мужская модель, 1 — женская;
##                                                     "seated": true — сидит за штурвалом, x/z/yaw не нужны;
##                                                     "walk": [0, 1, 1.5] — идёт своим вводом: крестовина, секунды)
##   {"do": "act"}                                   — последний добавленный член экипажа жмёт свою кнопку действия
##                                                     (Crew.Pad.action: сесть за штурвал, к пульту, к голосованию; занят — встать)
##   {"do": "mate_hold", "on": true}                — последний добавленный член экипажа держит кнопку действия
##                                                     (Crew.Pad.hold: сварка пробоины, вентиль, лебёдка, сканер), false — отпустил
##   {"do": "gone"}                                  — последний добавленный член экипажа отключился, как гость сети:
##                                                     уходит с палубы, у хоста «… отключился» (HostNotice, ART-043)
##   {"do": "save"}                                  — место для гибели (#824): корабль сейчас — в память сохранения,
##                                                     как автосохранение; файл прогона не пишется ("on": false — забыть
##                                                     место: меню снова без «Продолжить»)
##   {"do": "wreck"}                                 — корпус разрушен: шторка ART-036 3,5 с, затем загрузка места
##                                                     последнего «save» (нет его — подъём к началу спуска)
##   {"do": "tutorial", "on": true}                 — подсказки первого забега ART-038 с первого шага (false — убрать;
##                                                     "step": n — сразу с шага n, 1…7)
##   {"do": "brief", "on": true}                    — брифинг прибытия TXT-001 (#827) с первого экрана, как в первом
##                                                     забеге (false — убрать); листать — press brief (касание плашки)
##   {"do": "cards", "on": true}                    — карточки ролей у постов ART-045 с нуля (false — убрать)
##   {"do": "voice", "role": 2, "text": "Сбросьте ход", "fake": false} — голос во внутренней связи ART-040, как
##                                                     событие мира EcoLink.VOICE ("silent": true — подделка молчит
##                                                     на «Спросить код», "ask": "ping"/"light"); кнопка плашки — press ask
##   {"do": "slow"}                                  — предложение «Экономно» ART-044, как после низких кадр/с
##                                                     (в прогоне само не открывается; ответ — lite_yes / lite_no)
##   {"do": "hud", "on": false}                     — спрятать крестовину и кнопки (кадры для магазина); true — вернуть
##   {"do": "luch_ten", "on": false}                — прожектор без тени (цена тени на «Обычно», #1400); true — тень
##                                                     по уровню графики (смена уровня тоже её возвращает)
##   {"do": "play", "n": 1}                          — кадр Google Play ART-046: снимок → kadr-1-snimok.png и кадр 1920×1080
##                                                     с подписью n-го шаблона (1…4, `PlayFrame.CAPTIONS`) → kadr-1.png
##   {"do": "log", "note": "после хода"}             — записать состояние игры в лог
##   {"do": "quit"}                                  — закрыть игру
## advance(dt) возвращает команды для сцены: ["begin", id, what, dir], ["move", id, delta], ["end", id],
## ["shot", name], ["goto", x, z, yaw°[, pitch°]], ["ship", x, y, z[, yaw°]], ["floor"], ["outside", on, at, lamp], ["fly", on, y, pitch°], ["hot", heat], ["sample", n], ["breach", n (−1 — закрыть)], ["mate", x, z, yaw°, role, look, seated[, walk x, walk y, s]], ["silt", on], ["drain", s], ["hull", pct], ["charge", units], ["ping"], ["pred", n, bush, away], ["zamer", n, side], ["dome", t], ["route"], ["act"], ["mate_hold", on], ["gone"], ["save", on], ["wreck"], ["back"], ["tutorial", on, шаг 1…7], ["brief", on], ["cards", on], ["voice", role, text, fake, ask, silent], ["slow"], ["hud", on], ["luch_ten", on], ["play", n], ["log", note], ["quit"], ["done"]. Сцена переводит what в точку экрана по раскладке.

const KINDS := ["wait", "shot", "press", "hold", "swipe", "goto", "hot", "sample", "breach", "mate", "act", "mate_hold", "silt", "drain", "hull", "charge", "ping", "pred", "zamer", "dome", "ship", "floor", "outside", "fly", "route", "gone", "save", "wreck", "back", "tutorial", "brief", "cards", "voice", "slow", "hud", "luch_ten", "play", "log", "quit"]
const BUTTONS := ["action", "up", "down", "light", "pad", "dive", "resume", "map", "map_back", "hint_map", "new", "exit", "yes", "no", "crew", "journal", "settings", "graphics", "g0", "g1", "g2", "fps", "golos", "zvuk", "s0", "v_hold", "v_voice", "v_hear", "v_mic", "lite_yes", "lite_no", "ask", "brief", "join", "last", "lobby_new", "lobby_addr", "lobby_refresh",
	"jcell0", "jcell1", "jcell2", "jcell3", "jcell4", "jcell5", "jprev", "jnext", "jclose", "jtab0", "jtab1", "jlore0", "jlore1", "jlore2",
	"key0", "key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8", "key9", "key.", "keydel"]
## Шаг «pred»: полпути серпохвоста мимо куста (м) — с запасом за PRED_R огнецвета и HIDE_R каменщиков.
const PRED_SPAN := 30.0
const PRESS_TIME := 0.15   ## сколько держать кнопку при «press», с
const FINGER := 900        ## номер пальца для касаний сценария (не пересекается с настоящими)
## После этих команд скриншот ждёт следующего шага: снимок берёт уже нарисованный кадр, и без кадра между ними
## на картинке было бы старое место (issue #216: 09g-tablo сразу после goto повторял 09e-eel-alarm).
const NEEDS_FRAME := ["goto", "ship", "floor", "outside", "fly", "sample", "breach", "mate", "act", "gone", "route", "silt", "hot", "hud"]

var steps: Array = []
var errors: Array[String] = []
var index := 0
var elapsed := 0.0
var finished := false
var _started := false


## Разобрать JSON. Ошибки — в errors; плохие шаги пропускаются, чтобы прогон всё равно дал картинки.
static func parse(text: String) -> QaScript:
	var q := QaScript.new()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_ARRAY:
		q.errors.append("сценарий — не JSON-массив шагов")
		return q
	for i in data.size():
		var st = data[i]
		if typeof(st) != TYPE_DICTIONARY or not st.has("do") or not KINDS.has(st["do"]):
			q.errors.append("шаг %d: неизвестный шаг %s" % [i + 1, str(st)])
			continue
		if st["do"] in ["press", "hold"] and not BUTTONS.has(st.get("what", "")):
			q.errors.append("шаг %d: неизвестная кнопка «%s»" % [i + 1, str(st.get("what", ""))])
			continue
		if st["do"] == "press" and st["what"] == "pad":
			q.errors.append("шаг %d: крестовину не нажимают, а держат (hold)" % (i + 1))
			continue
		q.steps.append(st)
	return q


## Длительность шага, с.
static func duration(st: Dictionary) -> float:
	match st["do"]:
		"wait", "hold":
			return maxf(float(st.get("s", 1.0)), 0.0)
		"swipe":
			return maxf(float(st.get("s", 0.5)), 0.05)
		"press":
			return PRESS_TIME
	return 0.0


## Сколько секунд игры идёт весь сценарий — сумма длительностей шагов (#1379: от неё — предел шагов `test_qa`,
## а не число в цикле; снимки сверх этого ждут по кадру).
func total_time() -> float:
	var t := 0.0
	for st: Dictionary in steps:
		t += duration(st)
	return t


## Шаг времени: команды, которые сцена должна выполнить сейчас.
func advance(dt: float) -> Array:
	var out: Array = []
	if finished:
		return out
	var budget := dt
	while index < steps.size():
		var st: Dictionary = steps[index]
		var dur := duration(st)
		if not _started:
			if st["do"] in ["shot", "play"] and _changed(out):
				return out   # снимок — в следующем шаге, после кадра с новым местом
			_started = true
			elapsed = 0.0
			_begin(st, out)
		var take := minf(budget, dur - elapsed)
		if st["do"] == "swipe" and take > 0.0:
			var d := Vector2(float(st.get("dx", 0)), float(st.get("dy", 0)))
			out.append(["move", FINGER, d * (take / dur)])
		elapsed += take
		budget -= take
		if elapsed < dur - 1e-6:
			return out   # шаг ещё идёт
		_finish(st, out)
		index += 1
		_started = false
		if out.size() > 0 and out[-1][0] == "quit":
			finished = true
			return out
		if budget <= 0.0 and index < steps.size() and duration(steps[index]) > 0.0:
			return out
	finished = true
	out.append(["done"])
	return out


## В этом шаге уже есть команда, после которой нужен новый кадр.
static func _changed(out: Array) -> bool:
	for c in out:
		if c[0] in NEEDS_FRAME:
			return true
	return false


func _begin(st: Dictionary, out: Array) -> void:
	match st["do"]:
		"press", "hold":
			var dir := Vector2.ZERO
			if st.has("dir") and st["dir"] is Array and st["dir"].size() == 2:
				dir = Vector2(float(st["dir"][0]), float(st["dir"][1]))
			out.append(["begin", FINGER, st["what"], dir])
		"swipe":
			out.append(["begin", FINGER, "look", Vector2.ZERO])
		"shot":
			out.append(["shot", str(st.get("name", "shot-%02d" % (index + 1)))])
		"goto":
			var g := ["goto", float(st.get("x", 0.0)), float(st.get("z", 0.0)), float(st.get("yaw", 0.0))]
			if st.has("pitch"):
				g.append(float(st["pitch"]))
			out.append(g)
		"hot":
			out.append(["hot", float(st.get("heat", 80.0))])
		"sample":
			out.append(["sample", int(st.get("n", 0))])
		"breach":
			out.append(["breach", int(st.get("n", 0)) if bool(st.get("on", true)) else -1])
		"silt":
			out.append(["silt", bool(st.get("on", true))])
		"drain":
			out.append(["drain", float(st.get("s", 4.0))])
		"hull":
			out.append(["hull", clampf(float(st.get("pct", 100.0)), 0.0, 100.0)])
		"ping":
			out.append(["ping"])
		"pred":
			out.append(["pred", int(st.get("n", 0)), int(st.get("bush", 0)), bool(st.get("away", false))])
		"zamer":
			out.append(["zamer", int(st.get("n", 0)), String(st.get("side", "nos"))])
		"dome":
			out.append(["dome", clampf(float(st.get("t", 0.0)), 0.0, EcoDome.OPEN_TIME)])
		"charge":
			out.append(["charge", clampf(float(st.get("units", Vitals.MAX)), 0.0, Vitals.MAX)])
		"ship":
			var sh := ["ship", float(st.get("x", 0.0)), float(st.get("y", -20.0)), float(st.get("z", 0.0))]
			if st.has("yaw"):   # курс корабля, как у goto: 0 — нос к −Z, плюс — поворот влево
				sh.append(float(st["yaw"]))
			out.append(sh)
		"floor":
			out.append(["floor"])
		"outside":
			out.append(["outside", bool(st.get("on", true)), clampf(float(st.get("at", 1.0)), 0.0, 1.0),
				bool(st.get("lamp", false))])
		"fly":
			out.append(["fly", bool(st.get("on", true)), float(st.get("y", Deck.Walker.EYE)),
				float(st.get("pitch", 0.0))])
		"route":
			out.append(["route"])
		"act":
			out.append(["act"])
		"mate_hold":
			out.append(["mate_hold", bool(st.get("on", true))])
		"gone":
			out.append(["gone"])
		"save":
			out.append(["save", bool(st.get("on", true))])
		"wreck":
			out.append(["wreck"])
		"back":
			out.append(["back"])
		"tutorial":
			out.append(["tutorial", bool(st.get("on", true)), clampi(int(st.get("step", 1)), 1, Tutorial.STEPS.size())])
		"brief":
			out.append(["brief", bool(st.get("on", true))])
		"cards":
			out.append(["cards", bool(st.get("on", true))])
		"slow":
			out.append(["slow"])
		"hud":
			out.append(["hud", bool(st.get("on", true))])
		"luch_ten":
			out.append(["luch_ten", bool(st.get("on", true))])
		"play":
			out.append(["play", clampi(int(st.get("n", 1)), 1, PlayFrame.CAPTIONS.size())])
		"voice":
			out.append(["voice", int(st.get("role", 2)), str(st.get("text", "")), bool(st.get("fake", false)),
				str(st.get("ask", "")), bool(st.get("silent", false))])
		"mate":
			out.append(["mate", float(st.get("x", 0.0)), float(st.get("z", 0.0)), float(st.get("yaw", 0.0)),
				int(st.get("role", 1)), int(st.get("look", 1)), bool(st.get("seated", false))])
			var w: Array = st.get("walk", [])
			if w.size() == 3:   # идёт своим вводом: крестовина (x вправо, y вперёд) столько секунд
				out[-1].append_array([float(w[0]), float(w[1]), float(w[2])])
		"log":
			out.append(["log", str(st.get("note", ""))])
		"quit":
			out.append(["quit"])


func _finish(st: Dictionary, out: Array) -> void:
	if st["do"] in ["press", "hold", "swipe"]:
		out.append(["end", FINGER])
