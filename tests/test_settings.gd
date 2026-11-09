extends TestCase
## Настройки ART-037: ползунки, облёт, сброс сохранения через подтверждение, файл отдельно от сохранения, «Назад».

var main: Main


func after() -> void:
	Main.menu = false
	Main.intro = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_runner_disables_file() -> void:
	eq(Settings.default_path, "", "раннер выключил файл настроек")
	ok(not Settings.new().write(), "без пути не пишет")


func test_layout_fits_phones() -> void:
	for size: Vector2 in [Vector2(2400, 1080), Vector2(1600, 720), Vector2(1920, 1080), Vector2(2340, 1080)]:
		var screen := Rect2(Vector2.ZERO, size)
		var ids := ["back", "volume", "swipe", "intro", "graphics", "golos", "reset"]
		for i in ids.size():
			var r := Settings.screen_rect(ids[i], size)
			ok(r.size.x > 0.0 and screen.encloses(r), "%s на экране %s" % [ids[i], size])
			for j in range(i + 1, ids.size()):
				ok(not r.intersects(Settings.screen_rect(ids[j], size)), "%s и %s не налезают" % [ids[i], ids[j]])
	eq(Settings.RESET.end.y, 954.0, "«Сбросить сохранение» по макету")
	near(Settings.track_k(Splash.to_screen(Vector2(580, 360), Vector2(1600, 720)), Vector2(1600, 720)), 0.0, 1e-5,
		"левый край дорожки — 0")
	near(Settings.track_k(Splash.to_screen(Vector2(1200, 360), Vector2(1600, 720)), Vector2(1600, 720)), 0.5, 1e-5,
		"середина дорожки — половина")


func test_values_and_text() -> void:
	var s := Settings.new()
	eq(s.value_text("volume"), "70 %", "громкость по умолчанию — как в макете")
	eq(s.value_text("swipe"), "1,0×", "свайп по умолчанию — 1,0×")
	ok(s.intro, "облёт по умолчанию включён")
	s.set_volume(1.7)
	eq(s.volume, 1.0, "громкость не выше 100 %")
	s.set_swipe(0.1)
	eq(s.swipe, 0.5, "свайп не ниже 0,5×")
	s.set_swipe(1.26)
	eq(s.value_text("swipe"), "1,3×", "шаг 0,1")
	eq(Settings.volume_db(0.0), Settings.MUTE_DB, "0 % — тишина")
	near(Settings.volume_db(1.0), 0.0, 1e-5, "100 % — 0 дБ")


func test_press_drag_reset_back() -> void:
	var s := Settings.new()
	var size := Vector2(1600, 720)
	eq(s.hit(Settings.screen_rect("back", size).get_center(), size), "", "закрытые касаний не берут")
	s.show()
	var right := Splash.to_screen(Vector2(1820, 360), size)
	eq(s.hit(right, size), "volume", "палец на дорожке громкости")
	eq(s.press("volume", right, size), "changed", "касание дорожки ставит значение")
	eq(s.volume, 1.0, "правый край — 100 %")
	eq(s.grab, "volume", "ползунок взят")
	ok(s.drag(Splash.to_screen(Vector2(580, 360), size), size), "палец ведёт ползунок")
	eq(s.volume, 0.0, "левый край — 0 %")
	s.grab = ""
	ok(not s.drag(right, size), "отпущенный не двигается")
	eq(s.press("intro"), "changed", "переключатель облёта")
	ok(not s.intro, "облёт выключен")
	eq(s.press("reset"), "", "сброс — сначала подтверждение")
	ok(s.ask, "подтверждение открыто")
	eq(s.hit(Settings.screen_rect("volume", size).get_center(), size), "", "под подтверждением ползунок не берётся")
	eq(s.press("no"), "", "«Нет» — назад")
	ok(not s.ask and s.open, "настройки открыты")
	s.press("reset")
	eq(s.back(), "", "«Назад» закрывает сначала подтверждение")
	ok(s.open, "настройки остались")
	s.press("reset")
	eq(s.press("yes"), "wipe", "«Да» — стереть сохранение")
	eq(s.press("back"), "back", "«Назад» на экране")
	ok(not s.open, "настройки закрыты")


func test_file_roundtrip() -> void:
	var path := "user://test_nastrojki.cfg"
	var s := Settings.new()
	s.path = path
	s.set_volume(0.35)
	s.set_swipe(1.7)
	s.intro = false
	ok(s.write(), "записано")
	var t := Settings.new()
	t.path = path
	ok(t.read(), "прочитано")
	near(t.volume, 0.35, 1e-5, "громкость")
	near(t.swipe, 1.7, 1e-5, "свайп")
	ok(not t.intro, "облёт выключен")
	ok(path != SaveGame.PATH, "отдельно от сохранения забега")
	DirAccess.remove_absolute(path)
	var u := Settings.new()
	u.path = path
	ok(not u.read(), "нет файла — по умолчанию")
	eq(u.volume, Settings.VOLUME_DEFAULT, "громкость по умолчанию")


func test_reset_save_clears_progress() -> void:
	var samples := Samples.new()
	var scanner := Scanner.new()
	samples.restore([1, 2], [[0, -1], [2, -1]])
	var sv := SaveGame.new()
	sv.path = ""
	sv.reset(samples, scanner)
	eq(samples.cargo.size(), 0, "трюм пуст")
	eq(samples.got.size(), 0, "поднятых нет")
	ok(not sv.dirty, "после сброса не перезаписывается")


func _tap(p: Vector2, finger: int) -> void:
	var r := main.overlay.router
	r.begin(finger, p)
	main.step(1.0 / 30.0)
	r.end(finger)
	main.step(1.0 / 30.0)


func test_scene_from_pause() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var size := main.get_viewport().get_visible_rect().size
	main.back_pressed()
	_tap(main.pause.rect("settings", size).get_center(), 1)
	ok(main.settings.open and main.settings_panel.visible, "настройки на экране")
	ok(main.pause.open and not main.pause_panel.visible, "пауза под настройками ждёт")
	var r := main.overlay.router
	r.begin(2, Splash.to_screen(Vector2(1820, 560), size))   # свайп — правый край
	main.step(1.0 / 30.0)
	r.moved(2, Splash.to_screen(Vector2(580 + (1820 - 580) / 3.0, 560), size))   # к 1,0×
	main.step(1.0 / 30.0)
	near(main.settings.swipe, 1.0, 1e-5, "палец ведёт ползунок")
	near(main.overlay.swipe, 1.0, 1e-5, "свайп в обзоре")
	r.end(2)
	main.step(1.0 / 30.0)
	eq(main.settings.grab, "", "палец отпущен")
	r.begin(3, Splash.to_screen(Vector2(580, 360), size))   # громкость 0
	main.step(1.0 / 30.0)
	r.end(3)
	main.step(1.0 / 30.0)
	near(AudioServer.get_bus_volume_db(0), Settings.MUTE_DB, 0.01, "громкость 0 — шина Master молчит")
	_tap(Settings.screen_rect("intro", size).get_center(), 4)
	ok(not main.settings.intro, "облёт выключен")
	main.samples.restore([3], [[1, -1]])
	_tap(Settings.screen_rect("reset", size).get_center(), 5)
	ok(main.settings.ask, "подтверждение сброса")
	eq(main.samples.cargo.size(), 1, "до «Да» груз цел")
	_tap(Settings.screen_rect("yes", size).get_center(), 6)
	eq(main.samples.cargo.size(), 0, "сохранение сброшено — трюм пуст")
	main.back_pressed()
	ok(not main.settings.open and main.pause.open and main.pause_panel.visible, "«Назад» — снова пауза")
	main.back_pressed()
	ok(not main.pause.open, "пауза закрыта")
	Main.intro = true
	main._begin_run()
	ok(main.flyby.kind != Flyby.Kind.START, "облёт выключен в настройках — забег без облёта")
	main.settings.intro = true
	main._begin_run()
	eq(main.flyby.kind, Flyby.Kind.START, "включён — облёт")
	main.settings.set_volume(Settings.VOLUME_DEFAULT)
	main._apply_settings()
