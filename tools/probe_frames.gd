extends SceneTree
## Замер по кадрам заданной последовательности (#1379, #519): шаг `Main.step`, отрисовка и остаток «вне шага и
## отрисовки» на каждый кадр — разбор провала кадра не с нуля.
## xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1600x720 -s tools/probe_frames.gd -- seq=surface [ключ=значение ...]
##
## Ключи:
## seq=surface — последовательность (`SEQS`): idle — ничего, surface — маршрут разом → «наверх» (вид с борта и продувка
##   `Wake.vent`, #519), start — облёт в начале забега, ping — импульс сонара
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
## В облаке отрисовка — llvmpipe (программная), абсолютные мс с телефоном не сравнивать: смотреть разницу циклов
## и прогрева и где остаток. Vulkan-варианты шейдеров отсюда не видны.

const DT := 1.0 / 30.0
const SEQS := {
	"idle": "ничего: фон корабля и мира",
	"surface": "маршрут разом → «наверх»: вид с борта и продувка",
	"start": "облёт в начале забега",
	"ping": "импульс сонара",
}
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
	Warmup.enabled = kv["warm"] != "0"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	while main.warming():
		await process_frame
	main.set_process(false)   # шаг ведёт замер: ровный DT, своё время
	RenderingServer.frame_pre_draw.connect(func() -> void: _draw_from = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: _draw_us += Time.get_ticks_usec() - _draw_from)
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
