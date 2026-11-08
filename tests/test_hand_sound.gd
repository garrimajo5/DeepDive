extends TestCase
## Руки экипажа SND-006 (#719): сварка, сканер, «вид изучен» (`HandSound`, `HandSounds`), импульс в иле (`HullSound.JAM`).


## Приёмка PR #722: сварка 1 (пересобрана: равномощный стык), сканер 2, «изучено» 1, сонар в иле 1.
func test_files() -> void:
	var want := {HandSound.WELD: [3.0, 5.0], HandSound.SCAN: [2.0, 4.0]}
	for path: String in HandSound.LOOPS:
		var s := load(path) as AudioStreamWAV
		ok(s != null, "петля загружается: %s" % path)
		if s:
			eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "петля вперёд: %s" % path)
			var r: Array = want[path]
			ok(s.get_length() >= r[0] and s.get_length() <= r[1], "длина по заказу: %s %.2f" % [path, s.get_length()])
	for path: String in [HandSound.DONE, HullSound.JAM]:
		var s := load(path) as AudioStreamWAV
		ok(s != null, "разовый загружается: %s" % path)
		if s:
			eq(s.loop_mode, AudioStreamWAV.LOOP_DISABLED, "разовый, не петля: %s" % path)
			ok(s.get_length() >= 0.8 and s.get_length() <= 2.2, "длина: %s %.2f" % [path, s.get_length()])


func test_scanner_busy_and_done() -> void:
	var sc := Scanner.new()
	var sp: String = Species.ids()[0]
	sc.target = {"species": sp, "dist": 5.0}
	sc.hold(0.1)
	sc.update(0.1)
	ok(sc.busy, "держали на цели — сканер работает")
	sc.update(0.1)
	ok(not sc.busy, "отпустили — стих")
	eq(sc.done, 0, "ещё не изучен")
	for i in 20:
		sc.hold(0.1)
		sc.update(0.1)
	eq(sc.done, 1, "изучен — счётчик вырос")
	sc.hold(0.1)
	sc.update(0.1)
	ok(not sc.busy, "изученный вид не сканируется — тихо")
	sc.scanned["другой"] = true   # из сохранения — не «изучено» заново
	eq(sc.done, 1, "сохранение не звенит")


func test_weld_point() -> void:
	var a := Crew.Member.new()
	var b := Crew.Member.new()
	eq(HandSound.weld_point([a, b]), Vector3.INF, "никто не варит")
	b.weld(Vector3(1, 2, 8), Vector3.LEFT)
	eq(HandSound.weld_point([a, b]), Vector3(1, 2, 8), "звук — у шва того, кто варит")


func test_jam_ping_has_own_file() -> void:
	var s := ShipSounds.new()
	tree.root.add_child(s)
	s.play_ping(true)
	eq(s.last, HullSound.JAM, "импульс в иле — свой глухой файл")
	near(s.ping.volume_db, HullSound.JAM_DB, 0.01, "своей громкостью")
	s.play_ping()
	eq(s.last, HullSound.PING, "чистый — обычный пинг")
	s.queue_free()
	await frames(1)


func test_nodes_follow_state() -> void:
	SoundMix.ensure()
	var h := HandSounds.new()
	tree.root.add_child(h)
	for p: AudioStreamPlayer3D in [h.weld, h.scan, h.done]:
		eq(String(p.bus), SoundMix.SHIP, "на шине «Корабль»: %s" % p.name)
	eq(h.scan.position, HandSound.SCAN_AT, "сканер — у поста")
	h.update(0.1, Vector3.INF, false, 0)
	ok(not h.weld.playing and not h.scan.playing and not h.done.playing, "тишина")
	h.update(0.1, Vector3(0, 1, 9), true, 0)
	ok(h.weld.playing, "варят — сварка")
	eq(h.weld.position, Vector3(0, 1, 9), "у шва")
	ok(h.scan.playing, "сканируют — прибор работает")
	h.update(0.1, Vector3.INF, false, 1)
	ok(h.done.playing, "вид изучен — сигнал")
	for i in 3:
		h.update(0.1, Vector3.INF, false, 1)
	ok(not h.weld.playing and not h.scan.playing, "отпустили — стихло за FADE")
	h.done.stop()
	h.update(0.1, Vector3.INF, false, 1)
	ok(not h.done.playing, "сигнал один раз")
	h.queue_free()
	await frames(1)


func test_scene_weld_sounds_at_breach() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var h := main.hand_sounds
	ok(h != null and h.get_parent() == main.ship, "руки — в осях корабля")
	main.open_breach(0)
	var at: Vector3 = main.breach.active.p
	main.debug_weld = true
	main.step(0.1)
	main.step(0.1)   # звук сводится в начале шага — по прошлому шагу
	ok(h.weld.playing, "варят пробоину — сварка звучит")
	eq(h.weld.position, at, "у шва пробоины")
	main.debug_weld = false
	for i in 4:
		main.step(0.1)
	ok(not h.weld.playing, "отпустили — стихло")
	main.queue_free()
	await frames(1)
