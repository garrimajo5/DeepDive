extends TestCase
## Машины корабля SND-005 (#706): роторы, гул реактора, зуммер перегрева, пар вентиля (`MachineSound`, `MachineSounds`).


## Приёмка PR #712: варианты 1, петли WAV вперёд, длины по заказу (после обрезки краёв и кроссфейда стыка).
func test_files_are_forward_loops() -> void:
	var want := {MachineSound.ENGINES: [10.0, 20.0], MachineSound.REACTOR: [20.0, 30.0],
		MachineSound.BUZZ: [1.0, 2.0], MachineSound.STEAM: [4.0, 8.0]}
	for path: String in MachineSound.FILES:
		var s := load(path) as AudioStreamWAV
		ok(s != null, "петля загружается: %s" % path)
		if s:
			eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "петля вперёд: %s" % path)
			var r: Array = want[path]
			ok(s.get_length() >= r[0] and s.get_length() <= r[1], "длина по заказу: %s %.2f" % [path, s.get_length()])
			eq(s.mix_rate, 44100, "44,1 кГц: %s" % path)


func test_engines_follow_spin() -> void:
	ok(is_nan(MachineSound.engines_db(0.0)), "роторы стоят — молча")
	ok(is_nan(MachineSound.engines_db(0.03)), "чуть крутятся — молча")
	near(MachineSound.engines_db(MachineSound.SPIN_MIN), MachineSound.ENG_SOFT_DB, 0.01, "с порога — тихо")
	near(MachineSound.engines_db(1.0), MachineSound.ENG_DB, 0.01, "полный ход — в полную")
	near(MachineSound.engines_db(-1.0), MachineSound.ENG_DB, 0.01, "полный назад — так же")
	ok(MachineSound.engines_db(0.5) > MachineSound.engines_db(0.2), "громче с оборотами")
	ok(MachineSound.engines_pitch(1.0) > MachineSound.engines_pitch(0.2), "выше тон с оборотами")
	near(MachineSound.engines_pitch(1.0), MachineSound.PITCH_HIGH, 0.001, "тон на полном ходу")


func test_reactor_and_buzz() -> void:
	near(MachineSound.reactor_db(false, 30.0, 0.0), MachineSound.REACTOR_DB, 0.01, "спокойно — ровный гул")
	near(MachineSound.reactor_db(true, 100.0, 0.0), MachineSound.REACTOR_DB + MachineSound.REACTOR_HOT_DB, 0.01,
		"перегрев 100° — громче")
	ok(MachineSound.reactor_db(true, 80.0, 0.0) > MachineSound.reactor_db(true, 40.0, 0.0), "растёт с нагревом")
	ok(is_nan(MachineSound.reactor_db(true, 100.0, 3.0)), "аварийный сброс — реактор заглушён, молчит")
	ok(MachineSound.buzz_on(true, 0.0), "перегрев — зуммер")
	ok(not MachineSound.buzz_on(false, 0.0), "без перегрева — тихо")
	ok(not MachineSound.buzz_on(true, 2.0), "на сбросе зуммера нет")


func test_fade() -> void:
	near(MachineSound.fade(0.0, true, MachineSound.FADE / 2.0), 0.5, 0.001, "подъём за FADE")
	near(MachineSound.fade(0.5, false, 1.0), 0.0, 0.001, "спад до нуля, не ниже")


func test_scene_machines_play() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var m := main.machine_sounds
	ok(m != null and m.get_parent() == main.ship, "машины — в осях корабля")
	for p: Node in [m.engines, m.reactor, m.buzz, m.steam]:
		eq(String(p.get("bus")), SoundMix.SHIP, "на шине «Корабль»: %s" % p.name)
	eq(m.reactor.position, MachineSound.REACTOR_AT, "гул — от реактора")
	eq(m.steam.position, ValveSteam.NOZZLE, "пар — от сопла вентиля")
	main.step(0.3)
	ok(m.reactor.playing, "реактор гудит с начала")
	ok(not m.engines.playing, "роторы стоят — молча")
	ok(not m.buzz.playing and not m.steam.playing, "без перегрева и вентиля — тихо")
	main.hull_motion.spin = 1.0
	main.reactor.hot = true
	main.reactor.heat = 90.0
	main.debug_vent = true
	main.step(0.3)   # звук сводится в начале шага (`Main._sound`) — по прошлому шагу, отстаёт на шаг
	main.step(0.3)
	ok(m.engines.playing, "на ходу — роторы")
	ok(m.engines.pitch_scale > MachineSound.PITCH_LOW + 0.05, "тон выше на ходу (%.2f)" % m.engines.pitch_scale)
	ok(m.buzz.playing, "перегрев — зуммер")
	ok(m.steam.playing, "вентиль держат — пар")
	ok(m.reactor.volume_db > MachineSound.REACTOR_DB, "перегрев — гул громче (%.1f)" % m.reactor.volume_db)
	main.debug_vent = false
	main.reactor.scram = 5.0
	main.step(0.3)
	main.step(0.3)
	ok(not m.steam.playing, "отпустили вентиль — пар стих")
	ok(not m.buzz.playing, "сброс — зуммер стих")
	ok(not m.reactor.playing, "сброс — реактор молчит")
	main.queue_free()
	await frames(1)
