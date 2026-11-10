extends TestCase
## Музыка SND-004 (#658): тема меню и напряжение — петли на шине «Музыка» (Music, SoundMix.Mix.music_pair).


func test_loops_imported_as_loops() -> void:
	for row in [[SoundMix.MENU_MUSIC, 90.0, 150.0], [SoundMix.TENSION_MUSIC, 45.0, 60.0]]:
		var s := ResourceLoader.load(row[0], "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamMP3
		ok(s != null, "%s — MP3" % row[0])
		if s == null:
			continue
		ok(s.loop, "%s — петля уже в импорте" % row[0])
		var len := s.get_length()
		ok(len > row[1] and len < row[2], "%s — длина по заказу (%.1f с)" % [row[0], len])


func test_menu_then_silence_keeps_theme() -> void:
	var m := SoundMix.Mix.new()
	eq(m.music_pair(), Vector2(0.0, 1.0), "в забеге — напряжение (шина молчит без тревоги)")
	m.menu = true
	m.update(0.1)
	eq(m.music_pair(), Vector2(1.0, 0.0), "шина молчала — тема меню сразу, без хвоста напряжения")
	for i in 20:
		m.update(0.1)
	m.menu = false
	m.update(0.5)
	ok(m.levels[SoundMix.MUSIC] > 0.0, "меню закрыли — музыка затихает плавно")
	eq(m.music_pair(), Vector2(1.0, 0.0), "затихает тема меню, напряжение на спаде не вступает")
	for i in 20:
		m.update(0.1)
	m.tension = true
	m.update(0.1)
	eq(m.music_pair(), Vector2(0.0, 1.0), "тревога после тишины — сразу напряжение")


func test_menu_over_tension_crossfades() -> void:
	var m := SoundMix.Mix.new()
	m.tension = true
	for i in 20:
		m.update(0.1)
	m.menu = true
	m.update(0.3)
	var p := m.music_pair()
	ok(p.x > 0.0 and p.x < 1.0, "звучащая шина: тема меню входит плавно (%s)" % p)
	near(p.x + p.y, 1.0, 1e-6, "доли в сумме — вся шина")
	for i in 20:
		m.update(0.1)
	eq(m.music_pair(), Vector2(1.0, 0.0), "через FADE_S — только тема меню")


func test_scene_breach_plays_tension() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var mu := main.music
	ok(mu != null, "музыка в сцене")
	eq(String(mu.menu.bus), SoundMix.MUSIC, "тема меню — на шине «Музыка»")
	eq(String(mu.tension.bus), SoundMix.MUSIC, "напряжение — на шине «Музыка»")
	for i in 5:
		main.step(0.1)
	ok(not Music.sounding(mu.menu), "в забеге тема меню не играет")
	main.open_breach(0)
	for i in 20:
		main.step(0.1)
	ok(Music.sounding(mu.tension), "пробоина — играет напряжение")
	ok(not Music.sounding(mu.menu), "тема меню молчит")
	near(mu.tension.volume_db, SoundMix.TENSION_DB, 0.01, "напряжение на своей громкости")
	main.queue_free()
	await frames(1)
	SoundMix.apply(SoundMix.Mix.new().levels)
