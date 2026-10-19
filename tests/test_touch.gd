extends TestCase
## Крестовина, раскладка и разбор касаний.

const SCREEN := Rect2(0, 0, 2400, 1080)


func test_dpad_eight_ways() -> void:
	eq(Touch.dpad(Vector2(0, -50), 100), Vector2i(0, 1), "палец вверх — вперёд")
	eq(Touch.dpad(Vector2(0, 50), 100), Vector2i(0, -1), "вниз — назад")
	eq(Touch.dpad(Vector2(50, 0), 100), Vector2i(1, 0), "вправо")
	eq(Touch.dpad(Vector2(40, -40), 100), Vector2i(1, 1), "вперёд-вправо")
	eq(Touch.dpad(Vector2(10, 5), 100), Vector2i.ZERO, "центр — стоп")


func test_layout_inside_screen_without_overlaps() -> void:
	for safe in [SCREEN, Rect2(0, 0, 1280, 720), Rect2(90, 0, 2220, 1080)]:
		var l := Touch.Layout.new()
		l.compute(safe)
		var all := [l.pad, l.action, l.up, l.down, l.light]
		for c in all:
			ok(safe.has_point(c.c - Vector2(c.r, c.r)) and safe.has_point(c.c + Vector2(c.r, c.r) - Vector2(0.01, 0.01)),
				"круг внутри экрана %s" % str(safe))
		for i in all.size():
			for j in range(i + 1, all.size()):
				ok(all[i].c.distance_to(all[j].c) > all[i].r + all[j].r, "органы %d и %d не пересекаются" % [i, j])
		ok(l.pad.c.x < safe.get_center().x and l.action.c.x > safe.get_center().x, "крестовина слева, кнопка справа")


func test_fingers_work_together() -> void:
	var r := Touch.Router.new()
	r.layout.compute(SCREEN)
	r.begin(1, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.7))
	r.begin(2, r.layout.action.c)
	r.begin(3, Vector2(1200, 400))
	r.moved(3, Vector2(1230, 390))
	eq(r.move, Vector2i(0, 1), "идём вперёд")
	ok(r.action_down and r.action_pressed, "кнопка нажата")
	eq(r.look, Vector2(30, -10), "свайп обзора")
	r.end_frame()
	ok(not r.action_pressed and r.action_down, "нажатие одно, удержание остаётся")
	r.end(1)
	eq(r.move, Vector2i.ZERO, "отпустили крестовину — стоп")
	r.end(2)
	ok(not r.action_down, "отпустили кнопку")


func test_pad_finger_can_leave_pad() -> void:
	var r := Touch.Router.new()
	r.layout.compute(SCREEN)
	r.begin(1, r.layout.pad.c)
	r.moved(1, r.layout.pad.c + Vector2(r.layout.pad.r * 3, 0))
	eq(r.move, Vector2i(1, 0), "за краем крестовины всё ещё вправо")


func test_pilot_buttons_only_at_helm() -> void:
	var r := Touch.Router.new()
	r.layout.compute(SCREEN)
	r.begin(1, r.layout.up.c)
	eq(r.vert(), 0, "не за штурвалом — это свайп")
	r.clear()
	r.pilot_buttons = true
	r.begin(1, r.layout.up.c)
	eq(r.vert(), 1, "всплыть")
	r.end(1)
	r.begin(2, r.layout.down.c)
	eq(r.vert(), -1, "вниз")
	r.begin(3, r.layout.light.c)
	ok(r.light_pressed, "свет")
