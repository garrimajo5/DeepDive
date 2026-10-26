extends TestCase
## Шины громкости и сведение звука (SoundMix, docs/zvuk.md).


func test_ensure_adds_buses_once() -> void:
	SoundMix.ensure()
	var n := AudioServer.bus_count
	SoundMix.ensure()
	eq(AudioServer.bus_count, n, "второй вызов шин не добавляет")
	for name in SoundMix.BUSES:
		var i := AudioServer.get_bus_index(name)
		ok(i > 0, "шина %s заведена" % name)
		eq(String(AudioServer.get_bus_send(i)), "Master", "%s идёт в Master" % name)


func test_apply_sets_db() -> void:
	SoundMix.ensure()
	SoundMix.apply({SoundMix.MUSIC: 0.5, SoundMix.UI: 0.0})
	near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(SoundMix.MUSIC)), linear_to_db(0.5), 0.01, "половина — −6 дБ")
	near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(SoundMix.UI)), SoundMix.MUTE_DB, 0.01, "ноль — тишина")
	SoundMix.apply({SoundMix.MUSIC: 1.0, SoundMix.UI: 1.0})


func test_targets_by_state() -> void:
	var m := SoundMix.Mix.new()
	var t := m.target()
	eq(t[SoundMix.MUSIC], 0.0, "в игре без тревоги музыки нет")
	eq(t[SoundMix.SHIP], 1.0, "корабль на полную")
	eq(t[SoundMix.WORLD], SoundMix.INSIDE_WORLD_K, "мир за обшивкой глуше")
	m.tension = true
	t = m.target()
	eq(t[SoundMix.MUSIC], 1.0, "тревога — музыка напряжения")
	eq(t[SoundMix.AMBIENT], SoundMix.TENSION_AMBIENT_K, "эмбиент уступает")
	m.tension = false
	m.outside = true
	t = m.target()
	eq(t[SoundMix.SHIP], SoundMix.OUTSIDE_SHIP_K, "снаружи корабль глуше")
	eq(t[SoundMix.WORLD], 1.0, "снаружи мир полностью")
	m.outside = false
	m.paused = true
	t = m.target()
	near(t[SoundMix.SHIP], SoundMix.PAUSE_K, 1e-6, "пауза — корабль тише")
	eq(t[SoundMix.UI], 1.0, "кнопки паузы слышны")
	m.menu = true
	t = m.target()
	eq(t[SoundMix.MUSIC], SoundMix.MENU_MUSIC_K, "меню — тема меню")
	eq(t[SoundMix.SHIP], 0.0, "в меню корабль молчит")
	eq(t[SoundMix.UI], 1.0, "кнопки меню слышны")


func test_fade_is_smooth() -> void:
	var m := SoundMix.Mix.new()
	m.tension = true
	m.update(SoundMix.FADE_S / 2.0)
	near(m.levels[SoundMix.MUSIC], 0.5, 1e-5, "за половину FADE_S — половина")
	m.update(SoundMix.FADE_S)
	near(m.levels[SoundMix.MUSIC], 1.0, 1e-5, "дальше — до цели, не выше")
	m.tension = false
	m.update(SoundMix.FADE_S * 0.1)
	near(m.levels[SoundMix.MUSIC], 0.9, 1e-5, "гаснет так же плавно")


func test_ambient_by_depth() -> void:
	near(SoundMix.shelf_k(20.0), 1.0, 1e-6, "на отмели — петля отмели")
	near(SoundMix.deep_k(300.0), 1.0, 1e-6, "глубже 250 м — петля глубины")
	var mid := SoundMix.DEEP_FROM * 0.5 + SoundMix.DEEP_TO * 0.5
	near(SoundMix.shelf_k(mid), 0.5, 1e-6, "посередине — поровну")
	for d in [0.0, 120.0, 180.0, 230.0, 400.0]:
		near(SoundMix.shelf_k(d) + SoundMix.deep_k(d), 1.0, 1e-6, "доли в сумме 1 на %d м" % d)


func test_scene_players_on_buses_and_breach_tension() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	eq(String(main.breach_view.siren.bus), SoundMix.SHIP, "сирена — на шине корабля")
	eq(String(main.breach_view.jet_sound.bus), SoundMix.SHIP, "струя — на шине корабля")
	eq(String(main.drain_sound.bus), SoundMix.SHIP, "шипение присоски — на шине корабля")
	for i in 20:
		main.step(0.1)
	near(main.sound_mix.levels[SoundMix.MUSIC], 0.0, 1e-6, "без тревоги музыка молчит")
	main.open_breach(0)
	for i in 20:
		main.step(0.1)
	ok(main.sound_mix.tension, "пробоина — напряжение")
	near(main.sound_mix.levels[SoundMix.MUSIC], 1.0, 1e-6, "музыка напряжения поднялась за 2 с")
	near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(SoundMix.MUSIC)), 0.0, 0.01, "шина музыки — 0 дБ")
	main.queue_free()
	await frames(1)
	SoundMix.apply(SoundMix.Mix.new().levels)
