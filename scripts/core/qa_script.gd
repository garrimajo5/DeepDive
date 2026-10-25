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
##                                                     jcell0…jcell5 — ячейка вида, jprev / jnext, jclose),
##                                                     на экране «Войти по адресу» ART-039: join, last, клавиши
##                                                     key0…key9, key., keydel)
##   {"do": "back"}                                  — системная «Назад» Android: пауза ART-037 (в паузе — закрыть)
##   {"do": "hold", "what": "pad", "dir": [0, 1], "s": 5} — держать (pad — с направлением [вправо, вперёд])
##   {"do": "swipe", "dx": 300, "dy": 0, "s": 0.6}   — свайп обзора, смещение в пикселях вьюпорта
##   {"do": "goto", "x": -2.2, "z": 17.2, "yaw": 90}  — перейти на палубе (дальние отсеки без ходьбы; yaw в градусах,
##                                                     "pitch" — наклон взгляда в градусах, вниз — минус; без него не меняется)
##   {"do": "hot", "heat": 80}                       — перегреть реактор (проверить вентиль и щиток машинного); heat 0 — остудить
##   {"do": "sample", "n": 8}                       — поставить корабль над образцом n (шлюз в 8 м над ним, корабль стоит)
##   {"do": "breach", "n": 0}                       — пробоина в месте n (0 мостик, 1 коридор, 2 лаборатория, 3 машинное),
##                                                     игрок встаёт у неё лицом к борту
##   {"do": "route"}                                 — пройти выбранный маршрут разом (нет — первый): «глубже или наверх»
##   {"do": "silt"}                                  — облако ила вокруг корабля (сонарная тьма); "on": false — убрать ил
##   {"do": "drain", "s": 4}                        — стеклоуст «на корпусе» s секунд: мир будто шлёт EcoLink.DRAIN
##                                                     (тревога и расход заряда без самого существа)
##   {"do": "hull", "pct": 30}                       — прочность корпуса, % (следы повреждений ART-049 снаружи)
##   {"do": "mate", "x": -1, "z": -2.5, "yaw": 90, "role": 2, "look": 1} — ещё один член экипажа на палубе (роль 0…3,
##                                                     внешность 0 — мужская модель, 1 — женская;
##                                                     "seated": true — сидит за штурвалом, x/z/yaw не нужны;
##                                                     "walk": [0, 1, 1.5] — идёт своим вводом: крестовина, секунды)
##   {"do": "act"}                                   — последний добавленный член экипажа жмёт свою кнопку действия
##                                                     (Crew.Pad.action: сесть за штурвал, к пульту, к голосованию; занят — встать)
##   {"do": "gone"}                                  — последний добавленный член экипажа отключился, как гость сети:
##                                                     уходит с палубы, у хоста «… отключился» (HostNotice, ART-043)
##   {"do": "wreck"}                                 — корпус разрушен: шторка ART-036 3,5 с, затем забег с начала
##   {"do": "tutorial", "on": true}                 — подсказки первого забега ART-038 с первого шага (false — убрать)
##   {"do": "cards", "on": true}                    — карточки ролей у постов ART-045 с нуля (false — убрать)
##   {"do": "slow"}                                  — предложение «Экономно» ART-044, как после низких кадр/с
##                                                     (в прогоне само не открывается; ответ — lite_yes / lite_no)
##   {"do": "log", "note": "после хода"}             — записать состояние игры в лог
##   {"do": "quit"}                                  — закрыть игру
## advance(dt) возвращает команды для сцены: ["begin", id, what, dir], ["move", id, delta], ["end", id],
## ["shot", name], ["goto", x, z, yaw°[, pitch°]], ["hot", heat], ["sample", n], ["breach", n], ["mate", x, z, yaw°, role, look, seated[, walk x, walk y, s]], ["silt", on], ["drain", s], ["hull", pct], ["route"], ["act"], ["gone"], ["wreck"], ["back"], ["tutorial", on], ["cards", on], ["slow"], ["log", note], ["quit"], ["done"]. Сцена переводит what в точку экрана по раскладке.

const KINDS := ["wait", "shot", "press", "hold", "swipe", "goto", "hot", "sample", "breach", "mate", "act", "silt", "drain", "hull", "route", "gone", "wreck", "back", "tutorial", "cards", "slow", "log", "quit"]
const BUTTONS := ["action", "up", "down", "light", "pad", "dive", "resume", "map", "map_back", "hint_map", "new", "exit", "yes", "no", "crew", "journal", "settings", "graphics", "g0", "g1", "g2", "fps", "lite_yes", "lite_no", "join", "last", "lobby_new", "lobby_addr", "lobby_refresh",
	"jcell0", "jcell1", "jcell2", "jcell3", "jcell4", "jcell5", "jprev", "jnext", "jclose",
	"key0", "key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8", "key9", "key.", "keydel"]
const PRESS_TIME := 0.15   ## сколько держать кнопку при «press», с
const FINGER := 900        ## номер пальца для касаний сценария (не пересекается с настоящими)
## После этих команд скриншот ждёт следующего шага: снимок берёт уже нарисованный кадр, и без кадра между ними
## на картинке было бы старое место (issue #216: 09g-tablo сразу после goto повторял 09e-eel-alarm).
const NEEDS_FRAME := ["goto", "sample", "breach", "mate", "act", "gone", "route", "silt", "hot"]

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
			if st["do"] == "shot" and _changed(out):
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
			out.append(["breach", int(st.get("n", 0))])
		"silt":
			out.append(["silt", bool(st.get("on", true))])
		"drain":
			out.append(["drain", float(st.get("s", 4.0))])
		"hull":
			out.append(["hull", clampf(float(st.get("pct", 100.0)), 0.0, 100.0)])
		"route":
			out.append(["route"])
		"act":
			out.append(["act"])
		"gone":
			out.append(["gone"])
		"wreck":
			out.append(["wreck"])
		"back":
			out.append(["back"])
		"tutorial":
			out.append(["tutorial", bool(st.get("on", true))])
		"cards":
			out.append(["cards", bool(st.get("on", true))])
		"slow":
			out.append(["slow"])
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
