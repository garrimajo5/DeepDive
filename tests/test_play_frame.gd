extends TestCase
## Кадры Google Play ART-046: раскладка по шаблону, сборка из снимка и подписи, шаги тестера hud и play.


func _solid(size: Vector2i, c: Color) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func test_template_numbers() -> void:   # google-play.md: плашка 0…152, рамка 176/170 1568×882 (16:9), центр подписи
	eq(PlayFrame.SIZE, Vector2i(1920, 1080), "холст")
	eq(PlayFrame.BOX, Rect2i(176, 170, 1568, 882), "рамка снимка")
	near(float(PlayFrame.BOX.size.x) / PlayFrame.BOX.size.y, 16.0 / 9.0, 0.002, "рамка 16:9")
	eq(PlayFrame.BOX.position.x * 2 + PlayFrame.BOX.size.x, PlayFrame.SIZE.x, "рамка по центру")
	ok(PlayFrame.BOX.position.y >= PlayFrame.PLATE_H, "рамка под плашкой")
	eq(PlayFrame.TEXT_CENTER, Vector2i(960, 78), "центр подписи")
	eq(PlayFrame.CAPTIONS.size(), 4, "четыре кадра")
	eq(PlayFrame.caption(2), "Чините пробоины вместе", "подпись второго")
	eq(PlayFrame.caption(0), "", "нет нулевого")
	eq(PlayFrame.caption(5), "", "нет пятого")
	eq(PlayFrame.file_name(3), "kadr-3", "имя файла")


func test_fit_keeps_aspect_with_fields() -> void:   # 1600×720 (20:9) — целиком, полосы сверху и снизу, не растягивать
	var r := PlayFrame.fit(Vector2i(1600, 720))
	eq(r.size.x, 1568, "во всю ширину рамки")
	eq(r.size.y, 706, "высота по пропорции 20:9")
	eq(r.position, Vector2i(176, 258), "по центру рамки")
	ok(PlayFrame.BOX.encloses(r), "внутри рамки")
	eq(PlayFrame.fit(Vector2i(1920, 1080)), PlayFrame.BOX, "16:9 — ровно в рамку")
	var tall := PlayFrame.fit(Vector2i(1080, 1080))   # квадрат — поля слева и справа
	eq(tall.size, Vector2i(882, 882), "по высоте рамки")
	eq(tall.position.x, 176 + (1568 - 882) / 2, "по центру")
	eq(PlayFrame.fit(Vector2i(2400, 1080)).size, Vector2i(1568, 706), "телефон 2400×1080 — тоже 20:9")
	eq(PlayFrame.fit(Vector2i.ZERO).size, Vector2i.ZERO, "пустой снимок")


func test_compose_places_shot_and_caption() -> void:
	var shot := _solid(Vector2i(1600, 720), Color(1.0, 0.0, 0.0))
	var cap := _solid(Vector2i(400, 60), Color(0, 0, 0, 0))
	cap.fill_rect(Rect2i(190, 20, 20, 20), Color(0.0, 1.0, 0.0))   # пятно в центре подписи
	var out := PlayFrame.compose(shot, cap)
	eq(out.get_size(), PlayFrame.SIZE, "1920×1080")
	eq(out.get_format(), Image.FORMAT_RGB8, "без прозрачности")
	ok(_same(out.get_pixel(5, 5), PlayFrame.BG), "плашка цвета фона")
	ok(_same(out.get_pixel(5, 600), PlayFrame.BG), "фон вне рамки")
	ok(_same(out.get_pixel(960, 200), PlayFrame.FIELD), "поле над снимком — тёмное, снимок не растянут")
	ok(_same(out.get_pixel(960, 1030), PlayFrame.FIELD), "поле под снимком")
	ok(_same(out.get_pixel(960, 600), Color(1, 0, 0)), "снимок в центре рамки")
	ok(_same(out.get_pixel(177, 260), Color(1, 0, 0)), "снимок от левого края рамки")
	ok(_same(out.get_pixel(PlayFrame.TEXT_CENTER.x, PlayFrame.TEXT_CENTER.y), Color(0, 1, 0)), "подпись по центру плашки")
	ok(_same(out.get_pixel(PlayFrame.TEXT_CENTER.x - 150, PlayFrame.TEXT_CENTER.y), PlayFrame.BG), "прозрачное подписи — фон")
	eq(shot.get_size(), Vector2i(1600, 720), "исходный снимок не изменён")
	var bare := PlayFrame.compose(shot)
	ok(_same(bare.get_pixel(960, 78), PlayFrame.BG), "без подписи — пустая плашка")


func test_caption_rect_stays_in_plate() -> void:
	eq(PlayFrame.caption_rect(Vector2i(400, 60)), Rect2i(760, 48, 400, 60), "по центру (960, 78)")
	eq(PlayFrame.caption_rect(Vector2i(1920, 152)).position.y, 0, "во всю плашку — с верха, не ниже плашки")


func test_qa_steps() -> void:
	var q := QaScript.parse('[{"do": "hud", "on": false}, {"do": "play", "n": 3}, {"do": "play", "n": 9}, {"do": "hud"}]')
	eq(q.errors.size(), 0, "шаги hud и play известны")
	var first := q.advance(0.1)
	eq(first, [["hud", false]], "кадр после hud — следующим шагом, когда кнопки уже спрятаны")
	var second := q.advance(0.1)
	eq(second[0], ["play", 3], "кадр 3")
	eq(second[1], ["play", 4], "номер вне 1…4 — к краю")
	eq(second[2], ["hud", true], "вернуть кнопки")


func test_play_scenario_parses() -> void:   # сценарий четырёх кадров для телефона
	var text := FileAccess.get_file_as_string("res://tools/qa/play-kadry.json")
	var q := QaScript.parse(text)
	eq(q.errors.size(), 0, "без ошибок: %s" % ", ".join(q.errors))
	var plays := []
	for st in q.steps:
		if st["do"] == "play":
			plays.append(int(st["n"]))
	plays.sort()
	eq(plays, [1, 2, 3, 4], "каждый кадр по разу")
	eq(q.steps[-1], {"do": "hud", "on": true}, "в конце кнопки возвращаются")


func test_scene_hud_and_play() -> void:   # headless: кадра нет, но кнопки спрятаны и в логе — шаг
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var ver := main.overlay.get_parent().get_node("Версия") as CanvasItem
	var qa := main.start_qa('[{"do": "hud", "on": false}, {"do": "wait", "s": 0.1}, {"do": "play", "n": 2}]')
	for i in 6:
		main.step(1.0 / 30.0)
	ok(not main.overlay.visible, "крестовина и кнопки спрятаны")
	ok(not main.hint.visible, "строки приборов спрятаны")
	ok(not ver.visible, "плашка версии спрятана")
	ok("".join(qa.log_lines).contains("кадр kadr-2: нет картинки (headless)"), "шаг play дошёл до сцены")
	eq(qa.composing, 0, "в headless собирать нечего")
	main.set_hud(true)
	ok(main.overlay.visible and main.hint.visible and ver.visible, "кнопки вернулись")
	main.queue_free()
	await frames(1)
