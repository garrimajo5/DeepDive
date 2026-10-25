extends TestCase
## Уровни графики ART-044: строки словами, страница «Настройки · Графика», файл, счётчик кадров, применение в сцене.

var main: Main


func after() -> void:
	Main.menu = false
	Main.intro = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_rows_follow_numbers() -> void:
	eq(Graphics.rows(Graphics.ECONOMY), [["Дальность обзора", "Ближе"], ["Морской снег и частицы", "Меньше"],
		["Тени", "Выключены"], ["Разрешение сцены", "Снижено"]], "«Экономно»")
	eq(Graphics.rows(Graphics.NORMAL), [["Дальность обзора", "Средняя"], ["Морской снег и частицы", "Умеренно"],
		["Тени", "Простые"], ["Разрешение сцены", "Полное"]], "«Обычно» — как до ART-044")
	eq(Graphics.rows(Graphics.BEAUTY)[2][1], "Подробные", "«Красиво» — 4 каскада тени")
	eq(Graphics.level(Graphics.NORMAL)["msaa"], int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")),
		"«Обычно» — сглаживание из project.godot")
	eq(Graphics.valid(7), Graphics.BEAUTY, "уровень в пределах")
	eq(Graphics.DEFAULT, Graphics.NORMAL, "по умолчанию — «Обычно»")


func test_layout_fits_phones() -> void:
	for size: Vector2 in [Vector2(2400, 1080), Vector2(1600, 720), Vector2(1920, 1080), Vector2(2340, 1080)]:
		var screen := Rect2(Vector2.ZERO, size)
		var ids := ["back", "g0", "g1", "g2", "fps"]
		for i in ids.size():
			var r := Graphics.screen_rect(ids[i], size)
			ok(r.size.x > 0.0 and screen.encloses(r), "%s на экране %s" % [ids[i], size])
			eq(Graphics.hit(r.get_center(), size), ids[i], "касание %s" % ids[i])
			for j in range(i + 1, ids.size()):
				ok(not r.intersects(Graphics.screen_rect(ids[j], size)), "%s и %s не налезают" % [ids[i], ids[j]])
		var g := Settings.screen_rect("graphics", size)
		ok(screen.encloses(g) and not g.intersects(Settings.screen_rect("reset", size)), "«Графика» рядом со сбросом")
		var c := Graphics.counter_rect(size)
		ok(screen.encloses(c), "счётчик на экране %s" % size)
	eq(Graphics.counter_rect(Vector2(2400, 1080)), Rect2(2030, 210, 300, 54), "плашка счётчика по макету")


func test_settings_page() -> void:
	var s := Settings.new()
	var size := Vector2(1600, 720)
	s.show()
	eq(s.hit(Settings.screen_rect("graphics", size).get_center(), size), "graphics", "кнопка «Графика»")
	eq(s.press("graphics"), "", "открыта страница")
	eq(s.page, "grafika", "страница «Графика»")
	eq(s.hit(Graphics.screen_rect("g0", size).get_center(), size), "g0", "на странице — уровни")
	eq(s.press("g1"), "", "тот же уровень — ничего")
	eq(s.press("g0"), "graphics", "«Экономно» — применить")
	eq(s.graphics, Graphics.ECONOMY, "уровень выбран")
	eq(s.press("fps"), "changed", "«Показывать кадры/с»")
	ok(s.fps, "счётчик включён")
	eq(s.back(), "", "системная «Назад» — к основной странице")
	ok(s.open and s.page == "", "настройки открыты")
	s.press("graphics")
	eq(s.press("back"), "", "«Назад» на странице — к основной")
	ok(s.open and s.page == "", "основная страница")
	s.press("graphics")
	s.close()
	s.show()
	eq(s.page, "", "настройки снова с основной страницы")


func test_file_roundtrip() -> void:
	var path := "user://test_grafika.cfg"
	var s := Settings.new()
	s.path = path
	s.graphics = Graphics.BEAUTY
	s.fps = true
	ok(s.write(), "записано")
	var t := Settings.new()
	t.path = path
	ok(t.read(), "прочитано")
	eq(t.graphics, Graphics.BEAUTY, "уровень")
	ok(t.fps, "счётчик")
	DirAccess.remove_absolute(path)


func test_fps_counter() -> void:
	var f := Graphics.Fps.new()
	var changed := 0
	for i in 30:
		if f.push(1.0 / 30.0):
			changed += 1
	eq(changed, 2, "два раза в секунду")
	eq(f.value, 30, "среднее за 0,5 с")
	for i in 15:
		f.push(1.0 / 15.0)
	ok(f.value < 30, "просадка видна")
	ok(not f.push(0.0), "нулевой кадр не считается")
	eq(Graphics.counter_text(58), "58 кадр/с", "надпись по макету")


func test_scene_applies_level() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var vp := main.get_viewport()
	ok(main.ocean.sun.shadow_enabled, "«Обычно» — тени")
	main.settings.graphics = Graphics.ECONOMY
	main._apply_settings()
	eq(main.graphics_level, Graphics.ECONOMY, "уровень применён")
	ok(not main.ocean.sun.shadow_enabled and not main.searchlight.spot.shadow_enabled, "тени выключены")
	near(main.camera.far, 260.0, 1e-3, "дальность ближе")
	near(vp.scaling_3d_scale, 0.75, 1e-5, "разрешение сцены снижено")
	eq(vp.msaa_3d, Viewport.MSAA_DISABLED, "без сглаживания")
	ok(main.wake.lite and main.glints.lite, "частицы и блики — «Экономно»")
	ok(EcoShaders.sway_lite and EcoRim.lite, "живой мир — «Экономно»: флора не колышется, ободка нет (#598)")
	near(main.ocean.layers_level, WaterLayers.GAIN_LITE, 1e-5, "слоёв воды нет")
	main.settings.graphics = Graphics.BEAUTY
	main._apply_settings()
	ok(main.ocean.sun.shadow_enabled and main.searchlight.spot.shadow_enabled, "тени вернулись")
	eq(main.ocean.sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "подробные")
	eq(vp.msaa_3d, Viewport.MSAA_4X, "4× MSAA")
	ok(not main.wake.lite and not main.glints.lite, "частицы как обычно")
	ok(not EcoShaders.sway_lite and not EcoRim.lite, "живой мир как обычно")
	near(main.ocean.layers_level, WaterLayers.GAIN_BEAUTIFUL, 1e-5, "слои — «Красиво»")
	main.settings.graphics = Graphics.NORMAL
	main._apply_settings()
	near(main.camera.far, 400.0, 1e-3, "дальность средняя")
	near(vp.scaling_3d_scale, 1.0, 1e-5, "полное разрешение")
	eq(vp.msaa_3d, Viewport.MSAA_2X, "2× MSAA")
	ok(not main.fps_view.visible, "счётчик скрыт по умолчанию")
	main.settings.fps = true
	main._apply_settings()
	ok(main.fps_view.visible, "«Показывать кадры/с» — виден")
	main.settings.fps = false
	main._apply_settings()


func _tap(p: Vector2, finger: int) -> void:
	var r := main.overlay.router
	r.begin(finger, p)
	main.step(1.0 / 30.0)
	r.end(finger)
	main.step(1.0 / 30.0)


func test_scene_page_by_taps() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var size := main.get_viewport().get_visible_rect().size
	main.back_pressed()
	_tap(main.pause.rect("settings", size).get_center(), 1)
	_tap(Settings.screen_rect("graphics", size).get_center(), 1)
	eq(main.settings.page, "grafika", "страница «Графика» с касания")
	_tap(Graphics.screen_rect("g0", size).get_center(), 1)
	eq(main.graphics_level, Graphics.ECONOMY, "касание уровня — сразу в сцену")
	main.back_pressed()
	ok(main.settings.open and main.settings.page == "", "«Назад» — к основной странице настроек")
	main.back_pressed()
	ok(not main.settings.open and main.pause.open, "ещё «Назад» — пауза")
	main.settings.graphics = Graphics.NORMAL
	main._apply_settings()
	main.back_pressed()


func test_auto_by_phone() -> void:
	eq(Graphics.auto("Adreno (TM) 740", 12288), Graphics.BEAUTY, "флагман с 12 ГБ — «Красиво»")
	eq(Graphics.auto("Adreno (TM) 740", 6144), Graphics.NORMAL, "флагман с 6 ГБ — «Обычно»")
	eq(Graphics.auto("Mali-G715-Immortalis MC11", 8192), Graphics.BEAUTY, "Immortalis")
	eq(Graphics.auto("Adreno (TM) 650", 8192), Graphics.NORMAL, "средний — «Обычно»")
	eq(Graphics.auto("Mali-G610 MC6", 8192), Graphics.NORMAL, "G610 — не слабый")
	eq(Graphics.auto("Adreno (TM) 619", 8192), Graphics.ECONOMY, "Adreno 6xx младший — «Экономно»")
	eq(Graphics.auto("Mali-G57 MC2", 8192), Graphics.ECONOMY, "Mali-G57")
	eq(Graphics.auto("PowerVR Rogue GE8320", 4096), Graphics.ECONOMY, "PowerVR")
	eq(Graphics.auto("Adreno (TM) 740", 3072), Graphics.ECONOMY, "мало памяти — «Экономно»")
	eq(Graphics.auto("Adreno (TM) 740", -1), Graphics.NORMAL, "память неизвестна — не «Красиво»")
	eq(Graphics.auto("Что-то новое", -1), Graphics.NORMAL, "неизвестное — «Обычно»")
	eq(Graphics.auto("Mali-G57", 2048, false), Graphics.DEFAULT, "не телефон — по умолчанию")
	var d := Graphics.device()
	ok(d.has("adapter") and d.has("memory_mb") and d.has("mobile"), "сведения об устройстве")


func test_pick_first_once() -> void:
	var path := "user://test_grafika_pervyj.cfg"
	DirAccess.remove_absolute(path)
	var s := Settings.new()
	s.path = path
	ok(s.pick_first(Graphics.ECONOMY), "первый запуск — выбран и записан")
	var t := Settings.new()
	t.path = path
	ok(t.read(), "файл есть")
	eq(t.graphics, Graphics.ECONOMY, "уровень сохранён")
	t.graphics = Graphics.BEAUTY
	t.write()
	var u := Settings.new()
	u.path = path
	ok(not u.pick_first(Graphics.ECONOMY), "второй запуск — выбор игрока не трогаем")
	u.read()
	eq(u.graphics, Graphics.BEAUTY, "ручной выбор остался")
	var off := Settings.new()
	off.path = ""
	ok(not off.pick_first(Graphics.ECONOMY), "настройки выключены (тесты, тестер) — без автовыбора")
	eq(off.graphics, Graphics.DEFAULT, "уровень не тронут")
	DirAccess.remove_absolute(path)
