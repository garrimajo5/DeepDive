extends TestCase
## Страница «Настройки · Звук»: громкости шин SoundMix — раскладка, ползунки, файл, сведение в сцене.

var main: Main


func after() -> void:
	Main.menu = false
	Main.intro = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_rows_cover_all_buses() -> void:
	eq(SoundPage.count(), SoundMix.BUSES.size(), "ползунок на каждую шину")
	for name in SoundMix.BUSES:
		var found := false
		for i in SoundPage.count():
			found = found or SoundPage.bus(i) == name
		ok(found, "шина %s на странице" % name)
	eq(SoundPage.index("s3"), 3, "id → номер")
	eq(SoundPage.index("swipe"), -1, "свайп — не шина")
	eq(SoundPage.index("s9"), -1, "нет такого ползунка")
	eq(SoundPage.index("mates"), -1, "товарищи — не шина")


func test_layout_fits_phones() -> void:
	for size: Vector2 in [Vector2(2400, 1080), Vector2(1600, 720), Vector2(1920, 1080), Vector2(2340, 1080)]:
		var screen := Rect2(Vector2.ZERO, size)
		var ids := SoundPage.ids()
		for i in ids.size():
			var r := SoundPage.screen_rect(ids[i], size)
			ok(r.size.x > 0.0 and screen.encloses(r), "%s на экране %s" % [ids[i], size])
			for j in range(i + 1, ids.size()):
				ok(not r.intersects(SoundPage.screen_rect(ids[j], size)), "%s и %s не налезают" % [ids[i], ids[j]])
	ok(SoundPage.NOTE_TOP > SoundPage.layout_rect("s2").end.y, "подпись — под нижней строкой")
	var main_ids := ["graphics", "zvuk", "golos", "reset"]
	for i in main_ids.size():
		for j in range(i + 1, main_ids.size()):
			ok(not Settings.screen_rect(main_ids[i], Vector2(1600, 720)).intersects(
				Settings.screen_rect(main_ids[j], Vector2(1600, 720))), "%s и %s не налезают" % [main_ids[i], main_ids[j]])


func test_press_drag_and_back() -> void:
	var s := Settings.new()
	var size := Vector2(1600, 720)
	s.show()
	eq(s.hit(Settings.screen_rect("zvuk", size).get_center(), size), "zvuk", "«Звук» на основной странице")
	eq(s.press("zvuk"), "", "открыть страницу")
	eq(s.page, "zvuk", "страница «Звук»")
	eq(s.value_text("s0"), "100 %", "по умолчанию шина — 100 %")
	var mid := SoundPage.screen_rect("s0", size).get_center()
	eq(s.hit(mid, size), "s0", "касание ползунка «Музыка»")
	eq(s.press("s0", mid, size), "changed", "касание ставит значение")
	near(s.bus_k(SoundMix.MUSIC), 0.5, 1e-5, "середина — 50 %")
	var t := SoundPage.track_x(4)
	ok(s.press("s4", Splash.to_screen(Vector2(t.x, SoundPage.track_y(4)), size), size) == "changed", "левый край")
	eq(s.bus_k(SoundMix.VOICE), 0.0, "голоса — 0 %")
	ok(s.drag(Splash.to_screen(Vector2(lerpf(t.x, t.y, 0.25), SoundPage.track_y(4)), size), size), "палец ведёт")
	near(s.bus_k(SoundMix.VOICE), 0.25, 1e-5, "четверть дорожки — 25 %")
	near(s.bus_k(SoundMix.MUSIC), 0.5, 1e-5, "другая шина не тронута")
	near(s.volume, Settings.VOLUME_DEFAULT, 1e-5, "общая громкость не тронута")
	ok(Settings.is_volume("s4") and not Settings.is_volume("swipe"), "шины — громкость, свайп — нет")
	eq(s.back(), "", "системная «Назад» — к основной странице")
	ok(s.open and s.page == "" and s.grab == "", "основная, ползунок отпущен")


func test_file_roundtrip() -> void:
	var path := "user://test_zvuk.cfg"
	var s := Settings.new()
	s.path = path
	s.set_bus(SoundMix.MUSIC, 0.3)
	s.set_bus(SoundMix.UI, 0.0)
	ok(s.write(), "записано")
	var u := Settings.new()
	u.path = path
	ok(u.read(), "прочитано")
	near(u.bus_k(SoundMix.MUSIC), 0.3, 1e-5, "музыка")
	eq(u.bus_k(SoundMix.UI), 0.0, "интерфейс выключен")
	eq(u.bus_k(SoundMix.SHIP), 1.0, "нетронутая шина — 100 %")
	DirAccess.remove_absolute(path)


func test_gain_multiplies_mix() -> void:
	near(SoundMix.gain({SoundMix.MUSIC: 0.5}, {SoundMix.MUSIC: 0.5}, SoundMix.MUSIC), 0.25, 1e-6, "сведение × настройка")
	eq(SoundMix.gain({SoundMix.SHIP: 0.8}, {}, SoundMix.SHIP), 0.8, "без настройки — сведение как есть")
	eq(SoundMix.gain({SoundMix.SHIP: 0.8}, {SoundMix.SHIP: 0.0}, SoundMix.SHIP), 0.0, "0 % — тишина")
	SoundMix.ensure()
	SoundMix.apply({SoundMix.UI: 1.0}, {SoundMix.UI: 0.5})
	near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(SoundMix.UI)), linear_to_db(0.5), 0.01, "−6 дБ")
	SoundMix.apply({SoundMix.UI: 1.0})


func _tap(p: Vector2, finger: int) -> void:
	var r := main.overlay.router
	r.begin(finger, p)
	main.step(1.0 / 30.0)
	r.end(finger)
	main.step(1.0 / 30.0)


func test_scene_slider_sets_bus() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var size := main.get_viewport().get_visible_rect().size
	main.back_pressed()
	_tap(main.pause.rect("settings", size).get_center(), 1)
	_tap(Settings.screen_rect("zvuk", size).get_center(), 2)
	eq(main.settings.page, "zvuk", "страница «Звук» открыта")
	ok(main.settings_panel.visible, "на экране")
	var ui := AudioServer.get_bus_index(SoundMix.UI)
	near(AudioServer.get_bus_volume_db(ui), 0.0, 0.01, "интерфейс — 0 дБ до ползунка")
	var t := SoundPage.track_x(5)
	var r := main.overlay.router
	r.begin(3, Splash.to_screen(Vector2(t.x, SoundPage.track_y(5)), size))
	main.step(1.0 / 30.0)
	main.step(1.0 / 30.0)
	eq(main.settings.bus_k(SoundMix.UI), 0.0, "ползунок «Интерфейс» на нуле")
	near(AudioServer.get_bus_volume_db(ui), SoundMix.MUTE_DB, 0.01, "шина умолкла, пока палец ведёт")
	r.end(3)
	main.step(1.0 / 30.0)
	eq(main.settings.grab, "", "палец отпущен")
	main.back_pressed()
	ok(main.settings.open and main.settings.page == "", "«Назад» — к основной странице")
	main.settings.buses = {}
	main.step(1.0 / 30.0)
	near(AudioServer.get_bus_volume_db(ui), 0.0, 0.01, "100 % — снова 0 дБ")
