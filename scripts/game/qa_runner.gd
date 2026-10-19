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
	time += dt
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
			"log":
				_log("%s | %s" % [c[1], state()])
			"quit":
				_finish()
				main.get_tree().quit()
			"done":
				_finish()


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


## Состояние игры одной строкой для лога.
func state() -> String:
	var h := main.helm
	return "t %.1f с · %s · свет %s · глубина %.1f м · ход %.2f м/с · курс %.0f° · корабль (%.1f, %.1f, %.1f) · игрок (%.2f, %.2f) · реактор %s · %d кадр/с" % [
		time, "за штурвалом" if main.pilot.seated else ("у пульта энергии" if main.at_power else "на ногах"), "вкл" if main.light_on else "выкл", h.depth(), h.speed, rad_to_deg(h.yaw),
		h.pos.x, h.pos.y, h.pos.z, main.walker.x, main.walker.z, str(main.reactor.share), Engine.get_frames_per_second()]


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
