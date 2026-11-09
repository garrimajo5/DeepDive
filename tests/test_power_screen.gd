extends TestCase
## Экран пульта энергии по ART-050 (`PowerScreen`): место панели по макету, слова «ПРЕДЕЛ»/«ВЫКЛ.», деления
## полосы, состояния нижней зоны (резерв, перегрев, аварийный сброс), янтарь только при перегреве.


func test_box_matches_mockup() -> void:
	var b := PowerScreen.box(Vector2(2400, 1080))
	near(b.position.x, 1660.0, 0.5, "панель с x = 1660 (правый отступ 40)")
	near(b.position.y, 190.0, 0.5, "верх 190")
	near(b.size.x, 700.0, 0.5, "ширина 700")
	near(b.size.y, 478.0, 0.5, "высота 478")
	var n := PowerScreen.box(Vector2(1920, 1080))
	near(n.position.x, 1180.0, 0.5, "16:9 — x 1180, тот же размер")
	near(n.size.x, 700.0, 0.5, "кегли на 16:9 не мельче")
	var small := PowerScreen.box(Vector2(1600, 720))
	near(PowerScreen.k(small), 720.0 / 1080.0, 1e-3, "на другой высоте — масштаб H/1080")
	near(small.end.x, 1600.0 - 40.0 * 720.0 / 1080.0, 0.5, "правый отступ 40×масштаб")
	ok(PowerScreen.box(Vector2(1440, 1080)).size.x <= 720.0, "на 4:3 не шире половины экрана")


func test_box_between_buttons() -> void:
	for size: Vector2 in [Vector2(2400, 1080), Vector2(1920, 1080), Vector2(1600, 720), Vector2(1280, 960)]:
		var l := Touch.Layout.new()
		l.compute(Rect2(Vector2.ZERO, size))
		var b := PowerScreen.box(size, l)
		for c: Touch.Circle in [l.noclip, l.action]:
			ok(not b.intersects(NameTag.circle_rect(c.c, c.r)), "%s: панель %s не задевает кнопку у %s" % [size, b, c.c])
		ok(b.size.y > size.y * 0.35, "%s: пять строк помещаются (%.0f px)" % [size, b.size.y])


func test_words_and_segments() -> void:
	eq(PowerScreen.word(Reactor.MAX), "ПРЕДЕЛ", "60 — «ПРЕДЕЛ»")
	eq(PowerScreen.word(0), "ВЫКЛ.", "0 — «ВЫКЛ.»")
	eq(PowerScreen.word(30), "", "обычная доля — без слова")
	var s := PowerScreen.segments(30)
	eq(s.size(), 3, "три деления: 20/40 — разделители")
	near(s[0].z, s[0].y, 1e-6, "первое деление полное")
	near(s[1].z, 0.5, 1e-6, "второе — до половины шкалы")
	near(s[2].z, s[2].x, 1e-6, "третье пустое")
	near(PowerScreen.segments(Reactor.MAX)[2].z, 1.0, 1e-6, "60 — полная полоса")
	near(PowerScreen.segments(0)[0].z, 0.0, 1e-6, "0 — пустая")


func test_states() -> void:
	var r := Reactor.new()
	eq(PowerScreen.mode(r), PowerScreen.Mode.NORMAL, "обычный режим")
	eq(PowerScreen.head_right(r), "ИНЖЕНЕР", "в шапке роль")
	eq(PowerScreen.accent(r), PowerScreen.ACCENT, "выбор голубой")
	var f: Array = PowerScreen.foot(r)
	eq(f[0][0], "Резерв 0 / 100", "резерв")
	eq(f[1][0], PowerScreen.CONTROLS, "подсказка управления словами")
	eq(f[2], "Шаг 5 · предел доли 60", "шаг и предел")
	r.set_share(Reactor.Sys.SONAR, 0)
	eq(PowerScreen.foot(r)[0][0], "Резерв 20 / 100", "обесточили сонар — свободно 20")
	r.set_share(Reactor.Sys.SONAR, 20)
	r.start_hot(false)
	r.heat = 90.0
	eq(PowerScreen.mode(r), PowerScreen.Mode.HOT, "перегрев")
	eq(PowerScreen.head_right(r), "ПЕРЕГРЕВ 90°", "в шапке перегрев")
	eq(PowerScreen.accent(r), PowerScreen.HOT, "янтарь только при перегреве")
	f = PowerScreen.foot(r)
	eq(f[0][0], "Нагрузка 100 / безопасно 60", "нагрузка")
	eq(f[1][0], PowerScreen.HOT_DO, "что делать")
	eq(f[0][3], PowerScreen.HOT, "нижняя зона янтарём")
	eq(f[2], "", "подсказка управления уступает предупреждению")
	r.scram = 7.2
	eq(PowerScreen.mode(r), PowerScreen.Mode.SCRAM, "сброс важнее перегрева в нижней зоне")
	eq(PowerScreen.head_right(r), "ПЕРЕГРЕВ 90°", "при сбросе во время перегрева — янтарный заголовок")
	f = PowerScreen.foot(r)
	eq(f[0][0], "АВАРИЙНЫЙ СБРОС · ещё 8 с", "таймер сброса")
	eq(f[1][0], "Подача 0 · настройки сохранены", "доли сохранены")
	r.hot = false
	eq(PowerScreen.accent(r), PowerScreen.ACCENT, "сброс без перегрева — без янтаря")
	eq(PowerScreen.row_colors(r, false)[0], PowerScreen.DIM, "при сбросе строки приглушены")
	eq(r.share[Reactor.Sys.ENGINES], 30, "доли при сбросе не обнулены")


func test_texts_fit() -> void:   # кегли макета при высоте 1080: строки не вылезают за свои места
	var f := ThemeDB.fallback_font
	var bold := FontVariation.new()
	bold.base_font = f
	bold.variation_embolden = 0.7
	for i in Reactor.Sys.size():
		var w := bold.get_string_size(Reactor.NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var room := PowerScreen.WORD_X - 41.0   # имя не доходит до «ПРЕДЕЛ»
		ok(w < room, "%s: %d px из %d" % [Reactor.NAMES[i], w, room])
		ok(f.get_string_size(Reactor.HINTS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x < PowerScreen.BAR_X.x - 40.0,
			"подпись %s не под полосой" % Reactor.HINTS[i])
	ok(bold.get_string_size(PowerScreen.HOT_DO, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x < PowerScreen.W - 40.0,
		"«Сбросьте долю…» в ширине панели")
	var reserve := bold.get_string_size("Резерв 100 / 100", HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x
	ok(20.0 + reserve < PowerScreen.STEP_X - 10.0, "резерв не наезжает на «Шаг 5…»: %d" % reserve)
	ok(PowerScreen.STEP_X + f.get_string_size("Шаг 5 · предел доли 60", HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x
		< PowerScreen.W - 16.0, "«Шаг 5…» в ширине панели")
