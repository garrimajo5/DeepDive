class_name QaRunner
extends Node
## Прогон сценария тестера внутри игры (docs/QA.md). Если при запуске есть файл user://qa/scenario.json,
## игра проходит его шаги через то же разбор касаний, что и пальцы, снимает скриншоты и пишет лог в user://qa/out/,
## в конце — user://qa/out/done.txt. Сценарий после прогона переименовывается в scenario.last.json, чтобы обычный
## запуск игры не был сценарным.

const DIR := "user://qa"
const SCENARIO := DIR + "/scenario.json"
const OUT := DIR + "/out"

var main: Main
var script_q: QaScript
var log_lines: PackedStringArray = []
var time := 0.0
var shots: Array[String] = []
var _look_at := Vector2.ZERO
## Худший кадр (настоящее время между шагами, мс) с прошлого скриншота: средние кадр/с прячут разовый провал
## (issue #50 — сборка шейдеров при первом показе). Кадр сразу после скриншота не считаем — его тормозит сам снимок.
var worst_ms := 0.0
## Где был худший кадр (issue #217): шаг сценария и сколько из кадра заняла отрисовка на процессоре (сборка шейдеров
## и выгрузка мешей идут здесь) — отличить её от тяжёлого кода (отрисовка мала, кадр долгий).
var worst_at := ""
var _step_label := ""
var _last_us := 0
var _skip_frame := true
## Кадры и их время (мкс) с прошлого скриншота — без кадра снимка и прогрева (issue #169): среднее движка
## за секунду считало и сам скриншот, и «05b-light-off» через 0,5 с после снимка показывал 3 к/с при худшем кадре 34 мс.
var frames := 0
var frames_us := 0
## Issue #435: кадры сразу после снимка на эмуляторе долгие (видеокарта догоняет после чтения кадра) — строка
## описания через 0,3 с после снимка показывала 1–18 к/с при 50–60 у скриншотов. В средние их не берём; худший кадр
## считается как раньше (рывок сразу после снимка не прячем). Своих кадров нет — у строки «—».
const SETTLE_FRAMES := 3
var _settle := 0
var _shot_taken := false
var _warm_frames := 0   ## кадры прогрева шейдеров при старте (Warmup) — в лог, когда он кончится
var _warm_from_us := 0
var _warm_last_us := 0
var _warm_ms: Array[int] = []   ## длительность каждого кадра прогрева, мс (issue #159: какой взгляд дорогой)
var drain_left := 0.0   ## шаг «drain»: столько секунд ещё слать в игру EcoLink.DRAIN от стеклоуста


## Есть ли сценарий для этого запуска.
static func pending() -> bool:
	return FileAccess.file_exists(SCENARIO)


## Загрузить сценарий из файла (или текста — для тестов) и подготовить папку результатов.
func start(m: Main, text: String = "") -> void:
	main = m
	if text.is_empty():
		text = FileAccess.get_file_as_string(SCENARIO)
		DirAccess.rename_absolute(SCENARIO, DIR + "/scenario.last.json")
	script_q = QaScript.parse(text)
	RenderingServer.viewport_set_measure_render_time(main.get_viewport().get_viewport_rid(), true)   # для worst_at
	_warm_from_us = Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(OUT)
	for f in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + "/" + f)
	_log("Сценарий: %d шагов, версия %s, %s" % [script_q.steps.size(), ProjectSettings.get_setting("application/config/version", "?"),
		OS.get_model_name()])
	for e in script_q.errors:
		_log("ОШИБКА СЦЕНАРИЯ: " + e)


## Шаг: выполнить команды сценария до шага игры (main.step зовёт его первым).
func tick(dt: float) -> void:
	if script_q == null or script_q.finished:
		return
	if main.warming():   # прогрев шейдеров при старте: шаги сценария ждут, кадры не считаем
		_warm_frames += 1
		_warm_tick(Time.get_ticks_usec())
		_skip_frame = true
		return
	if _warm_frames > 0:
		var now := Time.get_ticks_usec()
		_warm_tick(now)
		_log("прогрев шейдеров: %d кадров, %d мс" % [_warm_frames, (now - _warm_from_us) / 1000])
		_log("прогрев по кадрам, мс: " + warm_line(_warm_ms))
		_warm_frames = -1
	time += dt
	_measure(Time.get_ticks_usec())
	var r := main.overlay.router
	for c in script_q.advance(dt):
		match c[0]:
			"begin":
				var p := _point(c[2], c[3])
				_look_at = p
				r.begin(c[1], p)
			"move":
				_look_at += c[2]
				r.moved(c[1], _look_at)
			"end":
				r.end(c[1])
			"shot":
				_shot(c[1])
			"goto":
				if main.pilot.seated:
					main.stand_up()
				if main.at_power:
					main.close_power()
				if main.at_vote:
					main.close_vote()
				main.walker.x = c[1]
				main.walker.z = c[2]
				main.walker.yaw = deg_to_rad(c[3])
				if c.size() > 4:
					main.walker.pitch = deg_to_rad(c[4])
			"hot":
				main.reactor.start_hot(false)
				main.reactor.heat = c[1]
			"sample":
				main.park_over_sample(c[1])
			"breach":
				main.open_breach(c[1])
			"route":
				main.complete_route()
			"silt":
				if c[1]:
					main.open_silt()
				else:
					main.silt.reset()
			"drain":
				drain_left = c[1]
			"hull":
				main.vitals.hull = c[1]
			"wreck":   # корпус разрушен — как от удара (шторка ART-036)
				main.vitals.hull = 0.0
				main.vitals.destroyed.emit()
			"back":   # системная «Назад»: пауза ART-037
				main.back_pressed()
			"tutorial":   # подсказки первого забега ART-038: с первого шага или убрать
				main.tutorial.reset()
				main.tutorial.on = c[1]
			"cards":   # карточки ролей у постов ART-045: с нуля (ничего не прочитано) или убрать
				main.role_card.set_read([])
				main.role_card.reset_run()
				main.role_card.on = c[1]
			"mate":
				var mate: Crew.Member
				if c[6]:   # за штурвалом
					mate = main.add_mate(0.0, Deck.SEAT_Z, 0.0, clampi(c[4], 0, 3), clampi(c[5], 0, 1), true)
				else:
					mate = main.add_mate(c[1], c[2], deg_to_rad(c[3]), clampi(c[4], 0, 3), clampi(c[5], 0, 1))
				if c.size() > 9:   # идёт своим вводом (Crew.Pad), свой игрок стоит
					mate.pad.move = Vector2(c[7], c[8])
					mate.pad.left = c[9]
			"act":   # последний товарищ жмёт кнопку действия (свой ввод, Main._drive_mates)
				if main.crew.size() > 1:
					(main.crew[-1] as Crew.Member).pad.action = true
			"gone":   # последний товарищ отключился, как гость сети (Main.mate_gone)
				if main.crew.size() > 1:
					main.mate_gone(main.crew[-1])
			"log":
				_log("%s | %s" % [c[1], state()])
			"quit":
				_finish()
				main.get_tree().quit()
			"done":
				_finish()
	_step_label = step_label(script_q)   # этот кадр рисуется на этом шаге — к нему и отнесём его время
	if drain_left > 0.0:   # как присосавшийся стеклоуст: 3,2 ед./с (js/creatures.js), пока не истечёт шаг
		drain_left -= dt
		main.on_eco_event(EcoLink.drain("Стеклоуст", 3.2))


## Учесть кадр, начавшийся в момент now_us (мкс).
func _measure(now_us: int) -> void:
	if not _skip_frame and _last_us > 0:
		var ms := (now_us - _last_us) / 1000.0
		if ms > worst_ms:
			worst_ms = ms
			worst_at = worst_note(_step_label, render_ms(), code_ms(), gpu_ms())
		if _settle > 0:
			_settle -= 1
		else:
			frames += 1
			frames_us += now_us - _last_us
	_skip_frame = false
	_last_us = now_us


## Точка экрана для кнопки сценария по текущей раскладке (координаты не зашиты в сценарий).
func _point(what: String, dir: Vector2) -> Vector2:
	var l := main.overlay.router.layout
	match what:
		"pad":
			return l.pad.c + Vector2(dir.x, -dir.y).limit_length(1.0) * l.pad.r * 0.7
		"action":
			return l.action.c
		"up":
			return l.up.c
		"down":
			return l.down.c
		"light":
			return l.light.c
		"dive":   # «Погрузиться» в главном меню ART-037
			return MainMenu.screen_rect("dive", main.get_viewport().get_visible_rect().size).get_center()
		"resume", "new", "exit", "yes", "no":   # пауза ART-037 и её подтверждение
			return Pause.screen_rect(what, main.get_viewport().get_visible_rect().size).get_center()
		"settings":   # «Настройки» паузы или главного меню ART-037
			var size := main.get_viewport().get_visible_rect().size
			return (Pause.screen_rect("settings", size, main.pause.mode) if main.pause.open
				else MainMenu.screen_rect("settings", size)).get_center()
		"lobby_new", "lobby_addr":   # вход сбора экипажа ART-028: «Создать забег» / «По адресу»
			return Lobby.screen_rect("new" if what == "lobby_new" else "address",
				main.get_viewport().get_visible_rect().size).get_center()
		"crew", "journal":   # «Экипаж» (вход сбора экипажа ART-028), «Журнал экспедиции» ART-047 в главном меню
			return MainMenu.screen_rect(what, main.get_viewport().get_visible_rect().size).get_center()
		"jprev":   # «Журнал экспедиции» ART-047: «Ранее» / «Далее», «Закрыть» карточки
			return Journal.prev_rect(main.get_viewport().get_visible_rect().size).get_center()
		"jnext":
			return Journal.next_rect(main.get_viewport().get_visible_rect().size).get_center()
		"jclose":
			return Journal.close_rect(main.get_viewport().get_visible_rect().size).get_center()
		"join", "last":
			return AddressScreen.screen_rect(what, main.get_viewport().get_visible_rect().size).get_center()
	if what.begins_with("jcell"):   # ячейка сетки видов журнала ART-047
		return Journal.cell_rect(int(what.substr(5)), main.get_viewport().get_visible_rect().size).get_center()
	if what.begins_with("key"):   # клавиша экрана адреса: key0…key9, key., keydel
		var k := what.substr(3)
		for r in AddressPad.KEYS.size():
			var c: int = AddressPad.KEYS[r].find(k)
			if c >= 0:
				return AddressPad.key_rect(c, r, main.get_viewport().get_visible_rect().size).get_center()
	return main.get_viewport().get_visible_rect().get_center()


## Средние кадр/с с прошлого скриншота по своим замерам. Среднее движка — только когда своих кадров нет: оно за секунду
## считает и сам снимок (issue #281: «14b-hold-shelves» через 0,3 с после снимка — 4 к/с при худшем кадре 172 мс).
## Issue #435: после снимка, пока своих кадров нет (SETTLE_FRAMES), — -1 («—» в строке), а не среднее движка со снимком.
func fps() -> int:
	if frames < 1 or frames_us <= 0:
		return -1 if _shot_taken else roundi(Engine.get_frames_per_second())
	return roundi(frames * 1000000.0 / frames_us)


## Кадр/с для строки лога: число или «—» (сразу после снимка замера нет, issue #435).
func fps_text() -> String:
	var f := fps()
	return "—" if f < 0 else str(f)


## Состояние игры одной строкой для лога.
func state() -> String:
	var h := main.helm
	return "t %.1f с · %s · свет %s · глубина %.1f м · ход %.2f м/с · курс %d° · корабль (%.1f, %.1f, %.1f) · игрок (%.2f, %.2f) · реактор %s · %s кадр/с" % [
		time, "за штурвалом" if main.pilot.seated else ("у пульта энергии" if main.at_power else "на ногах"), "вкл" if main.light_on else "выкл", h.depth(), h.speed, Status.course_deg(h.yaw),
		h.pos.x, h.pos.y, h.pos.z, main.walker.x, main.walker.z, "%s %d°%s" % [str(main.reactor.share), roundi(main.reactor.heat), " сброс" if main.reactor.scram > 0.0 else ""], fps_text()] + worst_text() + ("" if main.breach.status().is_empty() else " · " + main.breach.status()) \
		+ _run_state()


## Худший кадр с прошлого скриншота для строки состояния: « · худший кадр 726 мс (шаг 53 press, логика 9 мс)».
func worst_text() -> String:
	return " · худший кадр %d мс (%s)" % [roundi(worst_ms), worst_at] if worst_ms > 0.0 else ""


## Подпись к худшему кадру: шаг, код (шаг игры `Main.step` с живым миром), отрисовка на процессоре и, если драйвер умеет
## замерять, на видеокарте, мс (issue #217, #281). Код и отрисовка малы, а кадр долгий — ждали видеокарту или драйвер.
static func worst_note(step: String, draw_ms: float, code: float = -1.0, gpu: float = 0.0) -> String:
	var d := "отрисовка %d мс" % roundi(draw_ms)
	if code >= 0.0:
		d = "код %d мс, %s" % [roundi(code), d]
	if gpu > 0.0:
		d += ", видеокарта %d мс" % roundi(gpu)
	return step + ", " + d if not step.is_empty() else d


## Отрисовка прошлого кадра на процессоре, мс.
func render_ms() -> float:
	if main == null or not main.is_inside_tree():
		return 0.0
	return RenderingServer.viewport_get_measured_render_time_cpu(main.get_viewport().get_viewport_rid()) \
		+ RenderingServer.get_frame_setup_time_cpu()


## Код прошлого кадра: шаг игры `Main.step` (корабль, живой мир, виды), мс. Performance.TIME_PROCESS не годится —
## в него входит и отрисовка, и он обновляется не каждый кадр.
func code_ms() -> float:
	return main.step_ms if main != null else 0.0


## Отрисовка прошлого кадра на видеокарте, мс (0 — драйвер не замеряет).
func gpu_ms() -> float:
	if main == null or not main.is_inside_tree():
		return 0.0
	return RenderingServer.viewport_get_measured_render_time_gpu(main.get_viewport().get_viewport_rid())


## Шаг сценария, который сейчас идёт: «шаг 53 press».
static func step_label(q: QaScript) -> String:
	if q == null or q.steps.is_empty():
		return ""
	var i := mini(q.index, q.steps.size() - 1)
	return "шаг %d %s" % [i + 1, str((q.steps[i] as Dictionary).get("do", "?"))]


## Забег в логе: спуск, маршрут, решение у голостола.
func _run_state() -> String:
	var r := main.run
	if r.route < 0 and r.depth == 0:
		return ""
	var s := " · спуск %d" % (r.depth + 1)
	if r.route >= 0:
		s += " · " + r.status(main.helm.pos.x, main.helm.pos.z)
	if main.at_vote:
		s += " · итог забега" if r.ended else " · решение у голостола"
	return s


func _shot(name: String) -> void:
	var img: Image = null
	if DisplayServer.get_name() != "headless":
		img = main.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_log("скриншот %s: нет картинки (headless)" % name)
		return
	img.save_png("%s/%s.png" % [OUT, name])
	shots.append(name)
	_log("скриншот %s | %s" % [name, state()])
	after_shot()


## Сброс замеров после скриншота: кадр снимка не считается совсем, следующие SETTLE_FRAMES — только в худший кадр.
func after_shot() -> void:
	worst_ms = 0.0
	worst_at = ""
	frames = 0
	frames_us = 0
	_skip_frame = true
	_settle = SETTLE_FRAMES
	_shot_taken = true


## Отметка кадра прогрева: сколько прошло с прошлой (первая — от начала сценария).
func _warm_tick(now_us: int) -> void:
	_warm_ms.append((now_us - (_warm_last_us if _warm_last_us > 0 else _warm_from_us)) / 1000)
	_warm_last_us = now_us


## Строка лога «по кадрам»: ms[0] — от запуска сценария до первого кадра прогрева (сборка сцены, не кадр), дальше —
## кадры прогрева с единицы; самый долгий — номером в конце. Так чисел кадров столько же, сколько в заголовке
## «прогрев шейдеров: N кадров» (отчёт qa/2026-10-21-2310: 15 чисел при 14 кадрах).
static func warm_line(ms: Array[int]) -> String:
	if ms.is_empty():
		return "—"
	var head := "до первого кадра %d" % ms[0]
	if ms.size() < 2:
		return head
	var worst := 1
	var parts := PackedStringArray()
	for k in range(1, ms.size()):
		parts.append(str(ms[k]))
		if ms[k] > ms[worst]:
			worst = k
	return "%s; кадры: %s; худший — кадр %d из %d" % [head, ", ".join(parts), worst, ms.size() - 1]


func _log(line: String) -> void:
	log_lines.append(line)
	print("QA ", line)
	var f := FileAccess.open(OUT + "/log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines) + "\n")


func _finish() -> void:
	_log("Готово | " + state())
	var f := FileAccess.open(OUT + "/done.txt", FileAccess.WRITE)
	if f:
		f.store_string("ok\n")
