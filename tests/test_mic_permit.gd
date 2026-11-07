extends TestCase
## Разрешение микрофона Android для рации (#634): ввод звука в проекте и RECORD_AUDIO в обоих пресетах; без
## разрешения на Android `Radio.mic` выключен («Нет доступа»), первое нажатие кнопки спрашивает один раз, дальше —
## только «В настройки»; выдали — микрофон доступен; не Android — разрешение не нужно.

const DT := 1.0 / 30.0
const SIZE := Vector2(2400, 1080)

var main: Main
var granted := PackedStringArray()
var requests := 0


func after() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(1)


func _list() -> PackedStringArray:
	return granted


func _phone() -> MicPermit:
	granted = PackedStringArray()
	var p := MicPermit.new()
	p.needed = true
	return p


func _presets() -> Dictionary:
	var cfg := ConfigFile.new()
	var out := {}
	if cfg.load("res://export_presets.cfg") != OK:
		return out
	for sec in cfg.get_sections():
		if cfg.get_value(sec, "platform", "") == "Android" and cfg.has_section(sec + ".options"):
			out[cfg.get_value(sec, "name", "")] = cfg.get_value(sec + ".options", "permissions/record_audio", false)
	return out


func test_project_input_and_presets() -> void:
	ok(VoiceIO.input_on(), "ввод звука в проекте включён — микрофон движком")
	var p := _presets()
	eq(p.size(), 2, "оба Android-пресета: телефон и эмулятор")
	for k: String in p:
		eq(p[k], true, "RECORD_AUDIO в пресете «%s»" % k)


func test_desktop_needs_nothing() -> void:
	var p := MicPermit.new()
	ok(p.ok(), "не Android — микрофон можно")
	ok(not p.step(DT, true, true, true, _list), "и не спрашиваем")


func test_first_press_asks_once() -> void:
	var p := _phone()
	ok(not p.ok(), "Android без разрешения — нельзя")
	ok(not p.step(DT, true, false, false, _list), "без нажатия не спрашиваем")
	ok(p.step(DT, true, true, false, _list), "первое нажатие — системный запрос")
	ok(not p.step(DT, true, true, false, _list), "второе нажатие — уже не навязываемся")
	ok(p.step(DT, true, false, true, _list), "«В настройки» — спросить снова")
	ok(not p.ok(), "отказ — всё ещё нельзя")


func test_grant_is_polled() -> void:
	var p := _phone()
	p.step(DT, true, true, false, _list)
	granted = PackedStringArray([MicPermit.NAME])
	p.step(DT, true, false, false, _list)
	ok(p.ok(), "разрешили — сразу на следующем шаге (опрос после запроса)")
	ok(not p.step(DT, true, true, true, _list), "с разрешением не спрашиваем")


func test_poll_is_rare() -> void:
	var p := _phone()
	var calls := [0]
	var list := func() -> PackedStringArray:
		calls[0] += 1
		return PackedStringArray()
	for i in 30:
		p.step(DT, true, false, false, list)
	ok(calls[0] <= 3, "список разрешений — раз в %.1f с, не каждый кадр (%d раз за секунду)" % [MicPermit.POLL, calls[0]])


## Одиночная игра: рации нет — список разрешений (запрос к системе, 20–40 мс на эмуляторе) не трогаем вовсе;
## без вызова здесь «интерфейс/рация» брала десятки мс раз в 0,5 с (отчёт тестера 2026-10-28-1915).
func test_solo_never_polls() -> void:
	var p := _phone()
	var calls := [0]
	var list := func() -> PackedStringArray:
		calls[0] += 1
		return PackedStringArray()
	for i in 300:
		ok(not p.step(DT, false, false, false, list), "без рации не спрашиваем")
	eq(calls[0], 0, "без рации список не читаем")
	p.step(DT, true, false, false, list)
	eq(calls[0], 1, "рация появилась — смотрим сразу")


## Без запроса — раз в IDLE; после запроса — часто, пока идёт WAIT.
func test_idle_poll_slow_after_ask_fast() -> void:
	var p := _phone()
	var calls := [0]
	var list := func() -> PackedStringArray:
		calls[0] += 1
		return PackedStringArray()
	for i in int(MicPermit.IDLE * 30.0) - 1:
		p.step(DT, true, false, false, list)
	eq(calls[0], 1, "за %.0f с без запроса — один раз" % MicPermit.IDLE)
	calls[0] = 0
	p.step(DT, true, true, false, list)
	for i in 30:
		p.step(DT, true, false, false, list)
	ok(calls[0] >= 2, "после запроса — раз в %.1f с (%d за секунду)" % [MicPermit.POLL, calls[0]])


func test_scene_solo_never_polls() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var permit := main.overlay_flow.mic_permit
	permit.needed = true   # телефон без разрешения, одиночная игра
	for i in 40:
		main.step(DT)
	ok(not main.radio.on, "в одиночной игре рации нет")
	ok(not permit.granted and permit._poll == 0.0, "и список разрешений не читали")


func test_radio_press_without_mic() -> void:
	var r := Radio.new()
	r.on = true
	r.mic = false
	r.update(DT, true, false)
	ok(r.begged, "нажали без доступа")
	ok(not r.wants(), "передача сама не включается")
	ok(r.ask > 0.0, "просьба «Разрешите микрофон»")
	r.update(DT, true, false)
	ok(not r.begged, "держит — это не новое нажатие")
	r.mic = true
	r.update(DT, false, false)
	r.update(DT, true, false)
	ok(not r.begged, "с доступом — не просим")
	ok(r.wants(), "говорит")


func test_scene_phone_without_permission() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var permit := main.overlay_flow.mic_permit
	ok(permit.ok(), "в тестах (не Android) микрофон доступен")
	permit.needed = true   # как на телефоне без разрешения
	main.net_mates[7] = main.add_mate(-1.0, 4.0, 0.0, Crew.Role.BIOLOGIST, 1)
	main.step(DT)
	ok(not main.radio.mic, "Android без разрешения — «Нет доступа»")
	eq(main.radio.state_text(), "Нет доступа", "строка состояния")
	var b := Radio.button_rect(main.get_viewport().get_visible_rect().size)
	main.overlay.router.begin(0, b.get_center())
	main.step(DT)
	ok(permit.asked, "первое нажатие — запрос разрешения")
	ok(not main.radio.wants(), "без разрешения не передаём")
	ok(main.radio.ask > 0.0, "просьба на экране")
	main.overlay.router.end(0)
	permit.granted = true
	main.step(DT)
	ok(main.radio.mic, "разрешили — микрофон доступен")
	main.net_mates.clear()
