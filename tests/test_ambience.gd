extends TestCase
## Фон забега SND-001 (#655): петли эмбиента и гула корабля, их шины и доли по глубине (Ambience, SoundMix).


func test_loops_imported_as_loops() -> void:
	for path in [SoundMix.SHELF_LOOP, SoundMix.HUM_LOOP]:
		var s := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamMP3
		ok(s != null, "%s — MP3" % path)
		if s == null:
			continue
		ok(s.loop, "%s — петля уже в импорте" % path)
		var len := s.get_length()
		ok(len > 24.0 and len < 26.0, "%s — петля 20–30 с по заказу (%.2f с)" % [path, len])


func test_shelf_covers_depth_until_deep_loop() -> void:
	var at_300 := Vector2(SoundMix.shelf_k(300.0), SoundMix.deep_k(300.0))
	eq(SoundMix.loop_k(at_300, false), Vector2(1.0, 0.0), "без петли глубины отмель звучит и на 300 м")
	eq(SoundMix.loop_k(at_300, true), at_300, "с петлёй глубины — доли по глубине")


func test_scene_plays_on_buses() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var a := main.ambience
	ok(a != null, "фон в сцене")
	eq(String(a.shelf.bus), SoundMix.AMBIENT, "эмбиент — на шине «Эмбиент»")
	eq(String(a.hum.bus), SoundMix.SHIP, "гул — на шине «Корабль»")
	ok(a.shelf.playing and a.hum.playing, "обе петли играют с начала забега")
	for i in 5:
		main.step(0.1)
	near(a.shelf.volume_db, SoundMix.AMBIENT_DB, 0.01, "на отмели эмбиент на своей громкости")
	near(a.hum.volume_db, SoundMix.HUM_DB, 0.01, "гул тише эмбиента")
	ok(SoundMix.HUM_DB < SoundMix.AMBIENT_DB, "гул поверх эмбиента, тише")
	if a.deep == null:
		a.set_pair(Vector2(0.0, 1.0))
		near(a.shelf.volume_db, SoundMix.AMBIENT_DB, 0.01, "глубоко без своей петли — та же петля отмели")
	main.queue_free()
	await frames(1)
