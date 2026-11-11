extends SceneTree
## Замер по кадрам заданной последовательности (#1379, #519): шаг `Main.step`, отрисовка и остаток «вне шага и
## отрисовки» на каждый кадр — разбор провала кадра не с нуля.
## xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1600x720 -s tools/probe_frames.gd -- seq=surface [ключ=значение ...]
##
## Ключи:
## seq=surface — последовательность (`SEQS`): idle — ничего, surface — маршрут разом → «наверх» (вид с борта и продувка
##   `Wake.vent`, #519), start — облёт в начале забега, ping — импульс сонара, qa — кусок сценария тестера (ниже)
## warm=0 — без прогрева шейдеров (`Warmup.enabled`); сравнить с прогревом — два запуска, warm=0 и warm=1:
##   сборки шейдеров живут в процессе, второй цикл одного запуска их уже не собирает
## pre=10 — столько кадров с мостика до первого цикла, без замера: с warm=0 сцена с мостика уже собрана, и кадр 0
##   цикла показывает сборки только самого события (без pre — всей сцены)
## cycles=2 — сколько раз повторить последовательность (между циклами — новый забег)
## frames=60 — кадров на цикл (по умолчанию — пока идёт вид с борта и ещё `TAIL`, но не меньше 30)
## slow=50 — долгий кадр дольше стольких мс: в таблице, с частями шага `StepClock.note` (что тормозит в коде); по
##   умолчанию — в `SLOW_K` раз дольше среднего прошлых кадров цикла (в облаке отрисовка llvmpipe — сотни мс на кадр)
## out=probe.txt — таблицу ещё и в файл
## all=1 — печатать все кадры (по умолчанию — первые `HEAD`, долгие и итог цикла)
##
##
## seq=qa — кусок сценария тестера (#1350, для #803, #1317, #1511): шаги `scenario.json` идут как в прогоне тестера
##   (`QaRunner.tick`, без снимков и лога в user://qa/out), замер — от снимка from= до снимка to=; по кадрам — та же
##   таблица «шаг / отрис / остат» (событие — текущий шаг сценария; all=1 — все кадры, slow= — порог), итог — худший
##   кадр по частям кадра, максимум и среднее частей шага и подчастей `мир/…` (`StepClock`), худший шаг с подписью.
##   Только шаг — `godot --headless --path . -s tools/probe_frames.gd -- seq=qa from=36-ognecvet-do to=36a`
##   (отрисовка и остаток — под xvfb, как у других последовательностей)
## from=36-ognecvet-do — снимок, с которого замер: полное имя шага «shot» или префикс до «-» (`from=32i` —
##   32i-kurilshchik-znak; префикс двух снимков, как `32`, — ошибка со списком), номер шага с 0 — `#120` (или просто
##   число, если такого префикса нет); to=36a — снимок, на котором замер кончается (без to= — до конца сценария)
## start=35 — снимок или номер шага, с которого идут шаги до замера (постановка); по умолчанию — последний шаг «ship»
##   не позже from= (корабль в точке мира), без него — с начала сценария
## file=tools/qa/scenario.json — сценарий (путь от корня проекта или абсолютный); cycles= — сколько раз пройти кусок
##
## В облаке отрисовка — llvmpipe (программная), абсолютные мс с телефоном не сравнивать: смотреть разницу циклов
## и прогрева и где остаток. Vulkan-варианты шейдеров отсюда не видны.

const DT := 1.0 / 30.0
const SEQS := {
	"idle": "ничего: фон корабля и мира",
	"surface": "маршрут разом → «наверх»: вид с борта и продувка",
	"start": "облёт в начале забега",
	"ping": "импульс сонара",
	"qa": "кусок сценария тестера",
}
const QA_FILE := "res://tools/qa/scenario.json"
const QA_SKIP := ["shot", "play", "quit"]   ## шаги сценария, которых в замере нет: снимки и выход
const QA_MAX := 30 * 900                    ## кадров на кусок не больше (15 мин игры)
const QA_SHOW := 12                         ## подчастей мира в итоге
const TAIL := 15       ## кадров после конца вида с борта
const MIN_FRAMES := 30
const MAX_FRAMES := 600
const HEAD := 8        ## первых кадров цикла — всегда в таблице
const SLOW_K := 1.5   ## долгий кадр без slow= — во столько раз дольше среднего прошлых кадров цикла
const HEADER := "цикл кадр  событие      шаг  отрис  остат  всего"

var _draw_from := 0
var _draw_us := 0


## Ключи из аргументов: «ключ=значение» → словарь; неизвестная последовательность — ошибка.
static func parse(args: PackedStringArray) -> Dictionary:
	var kv := {"seq": "surface", "warm": "1", "cycles": "2", "all": "0"}
	for a in args:
		if a.contains("="):
			var p := a.split("=", true, 1)
			kv[p[0]] = p[1]
	if not SEQS.has(kv["seq"]):
		kv["error"] = "нет последовательности seq=%s; есть: %s" % [kv["seq"], ", ".join(SEQS.keys())]
	return kv


## Остаток кадра вне шага и отрисовки, мс (не меньше нуля: часы шага и кадра идут с разных мест).
static func rest_ms(total: float, step: float, draw: float) -> float:
	return maxf(0.0, total - step - draw)


## Строка таблицы.
static func row(cycle: int, frame: int, ev: String, step: float, draw: float, total: float, note := "") -> String:
	var s := "%4d %4d  %-10s %6.1f %6.1f %6.1f %6.1f" % [cycle, frame, ev.left(10), step, draw,
		rest_ms(total, step, draw), total]
	return s + ("  " + note if note != "" else "")


## Итог цикла по кадрам `{step, draw, total}`: худший кадр и максимум каждой части. Кадр 0 — кадр события (его
## вызов — в остатке, как в игре, где событие идёт внутри шага): сборки шейдеров без прогрева — здесь.
static func summary(cycle: int, frames: Array) -> String:
	var worst := -1
	var m_step := 0.0
	var m_draw := 0.0
	var m_rest := 0.0
	var sum := 0.0
	for i in frames.size():
		var f: Dictionary = frames[i]
		m_step = maxf(m_step, f["step"])
		m_draw = maxf(m_draw, f["draw"])
		m_rest = maxf(m_rest, rest_ms(f["total"], f["step"], f["draw"]))
		sum += f["total"]
		if worst < 0 or f["total"] > frames[worst]["total"]:
			worst = i
	if worst < 0:
		return "цикл %d: нет кадров" % cycle
	return "цикл %d: %d кадров, среднее %.1f мс, худший — кадр %d %.1f мс; максимум: шаг %.1f, отрисовка %.1f, остаток %.1f" % [
		cycle, frames.size(), sum / frames.size(), worst, frames[worst]["total"], m_step, m_draw, m_rest]


## Порог долгого кадра, мс: slow= из ключей или SLOW_K × среднее прошлых кадров цикла (без первого; нет их — ∞).
static func slow_ms(kv: Dictionary, frames: Array) -> float:
	if kv.has("slow"):
		return float(kv["slow"])
	if frames.size() < 2:
		return INF
	var sum := 0.0
	for i in range(1, frames.size()):
		sum += frames[i]["total"]
	return SLOW_K * sum / (frames.size() - 1)


## Показывать ли кадр в таблице.
static func shown(frame: int, total: float, slow: float, all: bool) -> bool:
	return all or frame < HEAD or total >= slow


func _initialize() -> void:
	SaveGame.default_path = ""
	AddressScreen.default_path = ""
	Settings.default_path = ""
	RunTimeline.default_path = ""
	Main.intro = false
	Main.menu = false
	Main.hints = false
	Main.offer = false
	_go.call_deferred()


func _go() -> void:
	var kv := parse(OS.get_cmdline_user_args())
	if kv.has("error"):
		push_error(kv["error"])
		quit(1)
		return
	Warmup.enabled = kv["warm"] != "0" and kv["seq"] != "qa"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	while main.warming():
		await process_frame
	main.set_process(false)   # шаг ведёт замер: ровный DT, своё время
	RenderingServer.frame_pre_draw.connect(func() -> void: _draw_from = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: _draw_us += Time.get_ticks_usec() - _draw_from)
	if kv["seq"] == "qa":
		await _go_qa(main, kv)
		return
	for p in int(kv.get("pre", "0")):
		main.step(DT)
		await process_frame
	var lines: Array[String] = ["seq=%s (%s), прогрев %s" % [kv["seq"], SEQS[kv["seq"]], "да" if Warmup.enabled else "нет"], HEADER]
	for c in int(kv["cycles"]):
		var frames: Array = []
		var n := _frames(kv)
		var t_prev := Time.get_ticks_usec()
		var i := 0
		while i < n:
			var ev := event(main, kv["seq"], i)
			_draw_us = 0
			var t0 := Time.get_ticks_usec()
			main.step(DT)
			var step := (Time.get_ticks_usec() - t0) / 1000.0
			await process_frame   # между ними — отрисовка этого кадра (frame_pre_draw → frame_post_draw)
			var t1 := Time.get_ticks_usec()
			var f := {"step": step, "draw": _draw_us / 1000.0, "total": (t1 - t_prev) / 1000.0}
			t_prev = t1
			var slow := slow_ms(kv, frames)
			frames.append(f)
			if shown(i, f["total"], slow, kv["all"] != "0"):
				var note: String = main.clock.note() if f["total"] >= slow or i < HEAD else ""
				lines.append(row(c + 1, i, ev, f["step"], f["draw"], f["total"], note))
				print(lines[-1])
			i += 1
			if not kv.has("frames") and i >= n - TAIL and main.flyby.active():
				n += 1   # вид с борта ещё идёт: кадры до его конца и ещё TAIL
				n = mini(n, MAX_FRAMES)
		lines.append(summary(c + 1, frames))
		print(lines[-1])
		reset(main)
	if kv.has("out"):
		var file := FileAccess.open(kv["out"], FileAccess.WRITE)
		file.store_string("\n".join(lines) + "\n")
	quit()


func _frames(kv: Dictionary) -> int:
	return clampi(int(kv["frames"]), 1, MAX_FRAMES) if kv.has("frames") else MIN_FRAMES


## Событие последовательности на кадре i цикла (до шага); подпись для таблицы.
static func event(main: Node, seq: String, i: int) -> String:
	if i != 0:
		return ""
	match seq:
		"surface":
			main.complete_route()
			main.open_vote()
			main.decide("up")
			return "наверх"
		"start":
			main.flyby.start(Flyby.Kind.START)
			return "облёт"
		"ping":
			main.ping_sonar()
			return "импульс"
	return "фон"


## Между циклами: новый забег, вид с борта погашен.
static func reset(main: Node) -> void:
	main.flyby.stop()
	if main.at_vote:
		main.close_vote()   # после «наверх» — новый забег у начала спуска


## Номер шага сценария steps по снимку или номеру; -1 — нет такого или неоднозначно (причина — `qa_match`).
static func qa_find(steps: Array, key: String) -> int:
	return int(qa_match(steps, key).get("i", -1))


## Шаг по ключу: полное имя снимка «shot», префикс имени до «-» (один снимок), «#N» или число N — номер шага с 0.
## {i} или {error}.
static func qa_match(steps: Array, key: String) -> Dictionary:
	var names: Array[String] = []
	var at: Array[int] = []
	for i in steps.size():
		if steps[i] is Dictionary and steps[i].get("do", "") == "shot":
			var nm := str(steps[i].get("name", ""))
			if nm == key:
				return {"i": i}
			if key != "" and nm.begins_with(key + "-"):
				names.append(nm)
				at.append(i)
	if key.begins_with("#") or (names.is_empty() and key.is_valid_int()):
		var num := key.trim_prefix("#")
		var n := int(num)
		if num.is_valid_int() and n >= 0 and n < steps.size():
			return {"i": n}
		return {"error": "нет шага %s (шагов %d)" % [key, steps.size()]}
	if names.size() == 1:
		return {"i": at[0]}
	if names.size() > 1:
		return {"error": "%s — несколько снимков: %s (номер шага — #%s)" % [key, ", ".join(names), key]}
	return {"error": "нет снимка %s" % key}


## Кусок сценария для замера: шаги от постановки до снимка to= без `QA_SKIP` и окно замера в этом куске —
## {steps, w0, w1}: кадр замеряется, пока номер идущего шага в [w0, w1). Ошибка — {error}.
static func qa_plan(steps: Array, kv: Dictionary) -> Dictionary:
	if not kv.has("from"):
		return {"error": "seq=qa: нужен from=<снимок>"}
	var m_from := qa_match(steps, kv["from"])
	if m_from.has("error"):
		return {"error": "seq=qa: from=: " + m_from["error"]}
	var i_from: int = m_from["i"]
	var i_to := steps.size()
	if kv.has("to"):
		var m_to := qa_match(steps, kv["to"])
		if m_to.has("error"):
			return {"error": "seq=qa: to=: " + m_to["error"]}
		i_to = m_to["i"]
		if i_to <= i_from:
			return {"error": "seq=qa: to=%s раньше from=%s" % [kv["to"], kv["from"]]}
	var i_start := 0
	if kv.has("start"):
		i_start = qa_find(steps, kv["start"])
		if i_start < 0 or i_start > i_from:
			return {"error": "seq=qa: start=%s — нет такого шага или он позже from=" % kv["start"]}
	else:
		for i in range(i_from, -1, -1):
			if steps[i] is Dictionary and steps[i].get("do", "") == "ship":
				i_start = i
				break
	var out: Array = []
	var w0 := 0
	var w1 := 0
	for i in range(i_start, i_to):
		if i == i_from:
			w0 = out.size()
		var st = steps[i]
		if st is Dictionary and not QA_SKIP.has(st.get("do", "")):
			out.append(st)
	w1 = out.size()
	return {"steps": out, "w0": w0, "w1": w1, "start": i_start, "from": i_from, "to": i_to}


## Кадр замера в сводку acc: части шага parts и подчасти мира subs (мс), шаг step_ms, подпись note.
static func qa_add(acc: Dictionary, step_ms: float, parts: Dictionary, subs: Dictionary, note: String) -> void:
	var n: int = acc.get("n", 0)
	if n == 0 or step_ms > float(acc["worst"]):
		acc["worst"] = step_ms
		acc["worst_at"] = n
		acc["note"] = note
	acc["sum"] = float(acc.get("sum", 0.0)) + step_ms
	for pair in [["parts", parts], ["subs", subs]]:
		var into: Dictionary = acc.get(pair[0], {})
		for k in pair[1].keys():
			var row: Array = into.get(k, [0.0, 0.0, 0])   # максимум, сумма, кадр максимума
			var ms := float(pair[1][k])
			if ms > row[0]:
				row[0] = ms
				row[2] = n
			row[1] += ms
			into[k] = row
		acc[pair[0]] = into
	acc["n"] = n + 1


## Строки итога куска: шаг, части шага и подчасти мира по убыванию максимума (среднее — по всем кадрам замера,
## кадр без подчасти — 0 мс).
static func qa_lines(cycle: int, acc: Dictionary, show := QA_SHOW) -> Array[String]:
	var n: int = acc.get("n", 0)
	if n == 0:
		return ["цикл %d: нет кадров в окне замера" % cycle] as Array[String]
	var out: Array[String] = ["цикл %d: %d кадров, шаг в среднем %.2f мс, худший — кадр %d %.1f мс: %s" % [
		cycle, n, float(acc["sum"]) / n, acc["worst_at"], acc["worst"], acc["note"]]]
	out.append("  часть / подчасть                    макс   средн  кадр")
	for pair in [["parts", ""], ["subs", "мир/"]]:
		var of: Dictionary = acc.get(pair[0], {})
		var keys: Array = of.keys()
		keys.sort_custom(func(a, b): return of[a][0] > of[b][0] or (of[a][0] == of[b][0] and str(a) < str(b)))
		if pair[0] == "subs":
			keys = keys.slice(0, show)
		for k in keys:
			var row: Array = of[k]
			out.append("  %-34s %6.2f %6.2f %5d" % [(pair[1] + str(k)).left(34), row[0], row[1] / n, row[2]])
	return out


## Подпись кадра в таблице seq=qa: текущий шаг сценария (его «do»; «ship», «wait», «ping»…).
static func qa_event(script_q: QaScript) -> String:
	if script_q.finished or script_q.index >= script_q.steps.size():
		return "конец"
	var st = script_q.steps[script_q.index]
	return str(st.get("do", "?")) if st is Dictionary else "?"


## Прогон сценария без снимков и без лога в user://qa/out — только шаги (`QaRunner.tick`).
class QuietRunner extends QaRunner:
	func _log(line: String) -> void:
		log_lines.append(line)

	func _finish() -> void:
		pass

	func _shot(_name: String) -> void:
		pass


## Кусок сценария: постановка без замера, затем кадры окна [w0, w1) — части шага и подчасти мира.
func _go_qa(main: Node, kv: Dictionary) -> void:
	var path: String = kv.get("file", QA_FILE)
	if not path.begins_with("res://") and not path.begins_with("/"):
		path = "res://" + path
	var steps = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(steps) != TYPE_ARRAY:
		push_error("seq=qa: %s — не JSON-массив шагов" % path)
		quit(1)
		return
	var plan := qa_plan(steps, kv)
	if plan.has("error"):
		push_error(plan["error"])
		quit(1)
		return
	var text := JSON.stringify(plan["steps"])
	var lines: Array[String] = ["seq=qa: %s, постановка с шага %d, замер от шага %d (from=%s) до %s; шагов в куске %d" % [
		path, plan["start"], plan["from"], kv["from"],
		("шага %d (to=%s)" % [plan["to"], kv["to"]]) if kv.has("to") else "конца", plan["steps"].size()]]
	print(lines[0])
	for c in int(kv["cycles"]):
		var q := QuietRunner.new()
		q.name = "Замер сценария"
		q.main = main
		q.script_q = QaScript.parse(text)
		for e in q.script_q.errors:
			push_error("seq=qa: " + e)
		main.add_child(q)
		main.qa = q
		var acc := {}
		var frames: Array = []
		var k := 0
		var t_prev := Time.get_ticks_usec()
		while not q.script_q.finished and q.script_q.index < plan["w1"] and k < QA_MAX:
			var inside: bool = q.script_q.index >= plan["w0"]
			var ev := qa_event(q.script_q)
			_draw_us = 0
			var t0 := Time.get_ticks_usec()
			main.step(DT)
			var step := (Time.get_ticks_usec() - t0) / 1000.0
			var clock: StepClock = main.clock
			var note := clock.note()
			if inside:
				qa_add(acc, step, clock.parts, clock.subs.get("мир", {}), note)
			await process_frame   # отрисовка этого кадра — как у других последовательностей
			var t1 := Time.get_ticks_usec()
			var f := {"step": step, "draw": _draw_us / 1000.0, "total": (t1 - t_prev) / 1000.0}
			t_prev = t1
			if inside:
				var slow := slow_ms(kv, frames)
				frames.append(f)
				if shown(k, f["total"], slow, kv["all"] != "0"):
					if k == 0:
						lines.append(HEADER)
						print(HEADER)
					lines.append(row(c + 1, k, ev, step, f["draw"], f["total"],
						note if f["total"] >= slow or k < HEAD else ""))
					print(lines[-1])
				k += 1
		main.qa = null
		q.queue_free()
		lines.append(summary(c + 1, frames))
		print(lines[-1])
		for l in qa_lines(c + 1, acc):
			lines.append(l)
			print(l)
	if kv.has("out"):
		var file := FileAccess.open(kv["out"], FileAccess.WRITE)
		file.store_string("\n".join(lines) + "\n")
	quit()
