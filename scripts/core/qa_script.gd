class_name QaScript
extends RefCounted
## Сценарий тестера: игра сама проходит шаги, снимает скриншоты и пишет лог — без тапов по координатам экрана.
## Сценарий — JSON-массив шагов (пример — tools/qa/scenario.json):
##   {"do": "wait", "s": 2}                          — подождать
##   {"do": "shot", "name": "01-start"}              — скриншот
##   {"do": "press", "what": "action"}               — нажать и отпустить (action, up, down, light)
##   {"do": "hold", "what": "pad", "dir": [0, 1], "s": 5} — держать (pad — с направлением [вправо, вперёд])
##   {"do": "swipe", "dx": 300, "dy": 0, "s": 0.6}   — свайп обзора, смещение в пикселях вьюпорта
##   {"do": "goto", "x": -2.2, "z": 17.2, "yaw": 90}  — перейти на палубе (дальние отсеки без ходьбы; yaw в градусах)
##   {"do": "hot", "heat": 80}                       — перегреть реактор (проверить вентиль и щиток машинного)
##   {"do": "log", "note": "после хода"}             — записать состояние игры в лог
##   {"do": "quit"}                                  — закрыть игру
## advance(dt) возвращает команды для сцены: ["begin", id, what, dir], ["move", id, delta], ["end", id],
## ["shot", name], ["goto", x, z, yaw°], ["hot", heat], ["log", note], ["quit"], ["done"]. Сцена переводит what в точку экрана по раскладке.

const KINDS := ["wait", "shot", "press", "hold", "swipe", "goto", "hot", "log", "quit"]
const BUTTONS := ["action", "up", "down", "light", "pad"]
const PRESS_TIME := 0.15   ## сколько держать кнопку при «press», с
const FINGER := 900        ## номер пальца для касаний сценария (не пересекается с настоящими)

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
			out.append(["goto", float(st.get("x", 0.0)), float(st.get("z", 0.0)), float(st.get("yaw", 0.0))])
		"hot":
			out.append(["hot", float(st.get("heat", 80.0))])
		"log":
			out.append(["log", str(st.get("note", ""))])
		"quit":
			out.append(["quit"])


func _finish(st: Dictionary, out: Array) -> void:
	if st["do"] in ["press", "hold", "swipe"]:
		out.append(["end", FINGER])
