extends TestCase
## Заставка прогрева по ART-034 (`Splash`, `WarmSplash`): обрезка фона, надписи, полоса, подсказки, пустые нижние углы.


func test_crop() -> void:
	# 19,5:9 при высоте 1080: обрезано по 30 px макета с каждого бока
	var phone := Vector2(2340, 1080)
	near(Splash.scale(phone), 1.0, 1e-6, "подгонка по высоте")
	near(Splash.offset(phone).x, 30.0, 1e-4, "19,5:9 — по 30 px с боков")
	near(Splash.offset(phone).y, 0.0, 1e-4, "верх и низ не обрезаны")
	var wide := Vector2(1920, 1080)
	near(Splash.offset(wide).x, 240.0, 1e-4, "16:9 — по 240 px с боков")
	var small := Vector2(1600, 720)
	near(Splash.scale(small), 720.0 / 1080.0, 1e-6, "1600×720 — по высоте")
	var p := Splash.to_screen(Vector2(360, 416), small)
	near(p.x, 360.0 * 720.0 / 1080.0 - (2400.0 * 720.0 / 1080.0 - 1600.0) / 2.0, 1e-4, "x по формуле заметки")
	near(p.y, 416.0 * 720.0 / 1080.0, 1e-4, "y по формуле заметки")
	# шире макета — подгонка по ширине, фон всё равно закрывает экран
	var ultra := Vector2(2600, 1080)
	ok(Splash.scale(ultra) * Splash.H >= ultra.y and Splash.scale(ultra) * Splash.W >= ultra.x - 1e-3, "21:9 закрыт целиком")


func test_texts() -> void:
	eq(Splash.status(0.5), "Подготовка погружения")
	eq(Splash.status(1.0), "Готово к погружению")
	eq(Splash.percent(0.0), "0 %")
	eq(Splash.percent(0.5), "50 %")
	eq(Splash.percent(1.2), "100 %")
	eq(Splash.hint(0.0), Splash.HINTS[0])
	eq(Splash.hint(7.9), Splash.HINTS[0], "подсказка держится 8 с")
	eq(Splash.hint(8.0), Splash.HINTS[1])
	eq(Splash.hint(Splash.HINT_EVERY * Splash.HINTS.size()), Splash.HINTS[0], "по кругу")
	ok(ResourceLoader.exists(Splash.BG), "фон заставки в проекте: %s" % Splash.BG)


func test_scene_splash() -> void:
	var s := WarmSplash.new()
	tree.root.add_child(s)
	await frames(1)
	ok(s.bg.texture != null and s.bg.texture.get_width() == 2400, "фон 2400×1080 загружен")
	eq(s.layer, 100, "поверх крестовины и кнопки")
	near(s.fill.size.x, s.fill.size.y, 1e-3, "в начале полоса не шире скругления")
	ok(not s.fill.visible, "0 % — заполнения нет")
	s.set_progress(0.5)
	eq(s.percent.text, "50 %")
	near(s.fill.size.x, s.track.size.x * 0.5, 1e-3, "полоса — доля прогрева")
	near(s.fill.position.x, s.track.position.x, 1e-6, "заполнение слева")
	var size := s.get_viewport().get_visible_rect().size
	var k := Splash.scale(size)
	near(s.percent.position.x + s.percent.size.x, Splash.to_screen(Splash.PERCENT_RIGHT, size).x, 1e-3, "проценты к правому краю полосы")
	ok(s.title.get_theme_font_size("font_size") == roundi(Splash.TITLE_PX * k), "кегль названия по высоте экрана")
	# нижние углы (y > 760, x < 360 и x > 2040 макета) пусты: крестовина и кнопка
	var corner_y := Splash.to_screen(Vector2(0, 760), size).y
	var left := Splash.to_screen(Vector2(360, 0), size).x
	var right := Splash.to_screen(Vector2(2040, 0), size).x
	for c: Control in [s.title, s.line, s.percent, s.hint, s.track]:
		var r := c.get_global_rect()
		if r.end.y > corner_y:
			ok(r.position.x >= left - 1.0 and r.end.x <= right + 1.0, "%s не в нижних углах: %s" % [c.name, r])
	ok(s.hint.get_global_rect().end.y <= size.y, "подсказка на экране")
	var font := s.hint.get_theme_font("font")
	for h: String in Splash.HINTS:
		var w := font.get_string_size(h, HORIZONTAL_ALIGNMENT_LEFT, -1, s.hint.get_theme_font_size("font_size")).x
		ok(w <= s.hint.size.x, "подсказка в одну строку: %s" % h)
	s._process(Splash.HINT_EVERY + 0.1)
	eq(s.hint.text, Splash.HINTS[1], "подсказка сменилась через 8 с")
	s.set_progress(1.0)
	eq(s.line.text, "Готово к погружению")
	s.queue_free()
	await frames(1)


## #766: общий поиск кнопки под пальцем — первая подходящая, выключенная не отвечает, мимо — "".
func test_hit_ids() -> void:
	var rects := {"a": Rect2(0, 0, 10, 10), "b": Rect2(5, 5, 10, 10)}
	var rect_of := func(id: String, _size: Vector2) -> Rect2: return rects[id]
	var size := Vector2(100, 100)
	eq(Splash.hit_ids(Vector2(7, 7), size, ["a", "b"], rect_of), "a", "первая в списке")
	eq(Splash.hit_ids(Vector2(7, 7), size, ["b", "a"], rect_of), "b", "порядок списка решает")
	eq(Splash.hit_ids(Vector2(12, 12), size, ["a", "b"], rect_of), "b")
	eq(Splash.hit_ids(Vector2(50, 50), size, ["a", "b"], rect_of), "", "мимо кнопок")
	var only_b := func(id: String) -> bool: return id == "b"
	eq(Splash.hit_ids(Vector2(7, 7), size, ["a", "b"], rect_of, only_b), "b", "выключенная не отвечает")
	eq(Splash.hit_ids(Vector2(2, 2), size, ["a", "b"], rect_of, only_b), "")
	# Тот же поиск в экранах: центр каждой кнопки меню и графики попадает в неё.
	var screen := Vector2(1600, 720)
	for id: String in ["back", "g0", "g1", "g2", "fps"]:
		eq(Graphics.hit(Graphics.screen_rect(id, screen).get_center(), screen), id)
	var m := MainMenu.new()
	m.open = true
	for it: Array in MainMenu.ITEMS:
		if m.enabled.get(it[0], false):
			eq(m.hit(MainMenu.screen_rect(it[0], screen).get_center(), screen), it[0])
