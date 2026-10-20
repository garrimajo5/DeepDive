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
var _last_us := 0
var _skip_frame := true
## Кадры и их время (мкс) с прошлого скриншота — без кадра снимка и прогрева (issue #169): среднее движка
## за секунду считало и сам скриншот, и «05b-light-off» через 0,5 с после снимка показывал 3 к/с при худшем кадре 34 мс.
var frames := 0
var frames_us := 0
var _warm_frames := 0   ## кадры прогрева шейдеров при старте (Warmup) — в лог, когда он кончится
var _warm_from_us := 0
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
		_skip_frame = true
		return
	if _warm_frames > 0:
		_log("прогрев шейдеров: %d кадров, %d мс" % [_warm_frames, (Time.get_ticks_usec() - _warm_from_us) / 1000])
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
			"mate":
				main.add_mate(c[1], c[2], deg_to_rad(c[3]), clampi(c[4], 0, 3), clampi(c[5], 0, 1))
			"log":
				_log("%s | %s" % [c[1], state()])
			"quit":
				_finish()
				main.get_tree().quit()
			"done":
				_finish()
	if drain_left > 0.0:   # как присосавшийся стеклоуст: 3,2 ед./с (js/creatures.js), пока не истечёт шаг
		drain_left -= dt
		main.on_eco_event(EcoLink.drain("Стеклоуст", 3.2))


## Учесть кадр, начавшийся в момент now_us (мкс).
func _measure(now_us: int) -> void:
	if not _skip_frame and _last_us > 0:
		worst_ms = maxf(worst_ms, (now_us - _last_us) / 1000.0)
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
	return main.get_viewport().get_visible_rect().get_center()


## Средние кадр/с с прошлого скриншота по своим замерам; пока кадров мало — среднее движка.
func fps() -> int:
	if frames < 5 or frames_us <= 0:
		return roundi(Engine.get_frames_per_second())
	return roundi(frames * 1000000.0 / frames_us)


## Состояние игры одной строкой для лога.
func state() -> String:
	var h := main.helm
	return "t %.1f с · %s · свет %s · глубина %.1f м · ход %.2f м/с · курс %d° · корабль (%.1f, %.1f, %.1f) · игрок (%.2f, %.2f) · реактор %s · %d кадр/с" % [
		time, "за штурвалом" if main.pilot.seated else ("у пульта энергии" if main.at_power else "на ногах"), "вкл" if main.light_on else "выкл", h.depth(), h.speed, Status.course_deg(h.yaw),
		h.pos.x, h.pos.y, h.pos.z, main.walker.x, main.walker.z, "%s %d°%s" % [str(main.reactor.share), roundi(main.reactor.heat), " сброс" if main.reactor.scram > 0.0 else ""], fps()] + (" · худший кадр %d мс" % roundi(worst_ms) if worst_ms > 0.0 else "") + ("" if main.breach.status().is_empty() else " · " + main.breach.status()) \
		+ _run_state()


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
	worst_ms = 0.0
	frames = 0
	frames_us = 0
	_skip_frame = true


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
