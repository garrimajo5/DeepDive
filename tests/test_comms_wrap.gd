extends TestCase
## Длинная реплика связи ART-040 — перенос по словам в две строки, плашка растёт вверх (#1557): шапка и первая строка
## выше на 52 ед., код и кнопка на месте; не влезло и в две — «…» в конце, а не немая обрезка.

const WIDE := Vector2(2400, 1080)    ## 20:9
const NARROW := Vector2(1920, 1080)  ## 16:9
const LONG := "Один импульс сонара, пожалуйста. Дайте импульс."
const DT := 1.0 / 30.0

var main: Main


func after() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(1)


func _font() -> Font:
	return ThemeDB.fallback_font


func _rows(text: String, size: Vector2) -> PackedStringArray:
	var c := Comms.new()
	c.push(2, text)
	c.update(DT, false)
	return c.rows(size, _font())


func _width(t: String, size: Vector2) -> float:
	return _font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(Comms.TEXT_PX * Comms.scale(size))).x


## Все реплики голоса TXT-002: ложные и настоящие.
func _lines() -> Array[String]:
	var out: Array[String] = []
	for ask: String in EcoEcho.FAKES:
		for v: Array in EcoEcho.FAKES[ask]:
			out.append(v[2])
	for v: Array in EcoEcho.REALS:
		out.append(v[2])
	return out


func test_voice_lines_fit() -> void:
	var lines := _lines()
	ok(lines.size() >= 26, "все реплики TXT-002")
	var two := 0
	for t in lines:
		var w := _rows(t, WIDE)
		eq(w.size(), 1, "20:9 — одна строка: %s" % t)
		var n := _rows(t, NARROW)
		ok(n.size() <= 2, "16:9 — не больше двух: %s" % t)
		ok(not n[-1].ends_with(Comms.CUT) and not w[-1].ends_with(Comms.CUT), "без «…»: %s" % t)
		eq(" ".join(n), t, "перенос не теряет слов: %s" % t)
		for r in n:
			ok(_width(r, NARROW) <= Comms.text_width(NARROW), "строка в ширине: %s" % r)
		if n.size() == 2:
			two += 1
	ok(two > 0, "на 16:9 есть реплики в две строки (без переноса их резало, #1557)")


func test_long_example_two_rows() -> void:
	var n := _rows(LONG, NARROW)
	eq(n.size(), 2, "образец из issue на 16:9 — две строки")
	ok(n[0].begins_with("Один импульс сонара"), "первая строка — начало реплики")
	eq(_rows(LONG, WIDE).size(), 1, "на 20:9 — одна")


func test_sixty_chars_cut() -> void:
	var t := "Слышу удары по корпусу у кормы, проверьте трюм и шлюз, пока не"
	ok(t.length() >= 60, "строка в 60 знаков")
	var c := Comms.new()
	c.push(2, t, false, "", false, "RADIO_TEST")
	c.update(DT, false)
	var n := c.rows(NARROW, _font())
	eq(n.size(), 2, "две строки")
	ok(n[1].ends_with(Comms.CUT), "конец второй — «…»")
	ok(_width(n[1], NARROW) <= Comms.text_width(NARROW), "с «…» — в ширине")
	eq(c.cut_logged, 1, "обрезка — в лог")
	c.rows(NARROW, _font())
	eq(c.cut_logged, 1, "один раз, не каждый кадр")


func test_one_word_wider_than_row() -> void:
	var r := Comms.wrap_rows("Ааааааааааааааааааааааааааааааааааааааааааааааааааааааааааааааааа", 300.0,
		func(x: String) -> float: return x.length() * 20.0)
	eq(r.size(), 2, "длинное слово — по буквам на две строки")
	ok(r[0].length() * 20.0 <= 300.0 and r[1].ends_with(Comms.CUT), "в ширине и с «…»")


func test_two_rows_layout() -> void:
	for size: Vector2 in [WIDE, NARROW, Vector2(1600, 720), Vector2(1280, 720)]:
		var s := Comms.scale(size)
		var one := Comms.plate_rect(size)
		var two := Comms.plate_rect(size, 2)
		near(two.position.y, one.position.y - Comms.LINE_STEP * s, 0.01, "%s: верх выше на 52" % size)
		near(two.end.y, one.end.y, 0.01, "%s: низ на месте" % size)
		eq(two.position.x, one.position.x, "%s: ширина та же" % size)
		near(Comms.at(Comms.TEXT_AT, size, 1).y, Comms.at(Comms.TEXT_AT, size).y, 0.01, "%s: вторая строка — на месте прежней" % size)
		near(Comms.at(Comms.ROLE_AT, size, 2).y, Comms.at(Comms.ROLE_AT, size).y - Comms.LINE_STEP * s, 0.01,
			"%s: роль выше" % size)
		near(Comms.bars_rect(size, 2).position.y, Comms.bars_rect(size).position.y - Comms.LINE_STEP * s, 0.01,
			"%s: индикатор выше" % size)
		ok(two.encloses(Comms.button_rect(size)), "%s: кнопка внутри" % size)
		ok(two.position.y / s >= 620.0, "%s: плашка в нижней половине, мимо табло тревог и строки приборов" % size)
	near(Comms.plate_rect(NARROW, 2).position.y, 628.0, 0.01, "16:9 — верх 628 ед.")
	eq(Comms.plate_rect(NARROW, 3), Comms.plate_rect(NARROW, 2), "третьей строки нет")


func test_scene_two_rows_clear_of_status() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var safe := Rect2(0, 0, 1280, 720)
	main.overlay.router.layout.compute(safe)
	main.comms.reset_run(0)
	main.on_eco_event(EcoLink.voice(Crew.Role.SONAR, LONG))
	for i in 10:
		main.step(DT)
	eq(main.comms.cur.text, LONG, "реплика на плашке")
	var area: Rect2 = main.comms_area()
	eq(main.comms.rows(area.size, _font()).size(), 2, "1280×720 — две строки")
	var plate := Comms.plate_rect(area.size, 2)
	plate.position += area.position
	var st: Rect2 = main.status_rect()
	ok(not st.has_area() or not st.intersects(plate), "плашка не на строке приборов")
	var b := Comms.button_rect(area.size)
	b.position += area.position
	ok(main.overlay.router.blocks.has(b), "кнопка держит касания на прежнем месте")
