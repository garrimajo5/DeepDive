extends TestCase
## Состояния таблички игрока (ART-033): нажал кнопку — контур ярче и три штриха, вход и выход 0,15 с;
## без связи — всё приглушено и строка «Нет связи». Флаги едут в кадре хоста.

var main: Main


func before() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)


func after() -> void:
	main.queue_free()
	await frames(1)


func test_glow_fades_in_and_out() -> void:
	near(NameTag.glow_step(0.0, true, NameTag.FADE_T * 0.5), 0.5, 1e-6, "за половину FADE_T — наполовину")
	near(NameTag.glow_step(0.5, true, 1.0), 1.0, 1e-6, "не ярче 1")
	near(NameTag.glow_step(1.0, false, NameTag.FADE_T), 0.0, 1e-6, "выход за FADE_T")


func test_colors_lost_muted() -> void:
	var c := NameTag.colors(Crew.Role.BIOLOGIST, false)
	eq(c[1], NameTag.ring_color(Crew.Role.BIOLOGIST), "обычная — кружок цвета роли")
	for k: Color in NameTag.colors(Crew.Role.BIOLOGIST, true):
		eq(k, NameTag.DIM, "без связи — приглушено #78949D")
	ok(not (NameTag.ACTIVE.r > 0.7 and NameTag.ACTIVE.g < 0.45), "без красного")


func test_glow_image_strokes() -> void:
	var w := NameTag.width(1.5)
	var img := NameTag.glow_image(w)
	var h := NameTag.TEX_H
	var mid := img.get_pixel(img.get_width() / 2, h / 2)
	near(mid.a, 0.0, 0.01, "середина прозрачна — видно имя")
	var sx := roundi(img.get_width() - float(NameTag.STROKE_X[1]) * h)
	var st := img.get_pixel(sx, h / 2)
	ok(st.a > 0.9 and st.b > 0.8, "штрих голубой #67DDEB (%s)" % st)
	ok(img.get_pixel(img.get_width() / 2, 1).a > 0.5, "контур ярче")
	var name_end := NameTag.name_x(w, 1.5) + 0.75 + w * 0.5   # правый край имени от левого края
	ok(name_end <= w - float(NameTag.STROKE_X[0]) * 1.0, "имя не заходит на штрихи")


func test_member_press_and_snapshot() -> void:
	var m := Crew.Member.new(Crew.Role.SONAR, "Ира")
	ok(not m.active(), "без нажатий — обычная")
	m.pressed()
	ok(m.active(), "нажал — «нажимает»")
	m.tick_press(Crew.PRESS_SHOW + 0.01)
	ok(not m.active(), "через PRESS_SHOW — снова обычная")
	m.pressed()
	m.lost = true
	var s := NetSnap.unpack_member(NetSnap.pack_member(m.snapshot()))
	var c := Crew.Member.new(Crew.Role.SONAR)
	c.apply(s)
	ok(c.active(), "«нажимает» дошло до гостя")
	ok(c.lost, "«Нет связи» дошло до гостя")
	m.tick_press(1.0)
	m.lost = false
	c.apply(NetSnap.unpack_member(NetSnap.pack_member(m.snapshot())))
	ok(not c.active() and not c.lost, "и сброс дошёл")


func _mate() -> Crew.Member:
	main.walker.x = 0.0
	main.walker.z = 0.0
	main.walker.yaw = 0.0
	var mate := main.add_mate(0.0, -4.0, PI, Crew.Role.BIOLOGIST, 1)
	mate.name = "Марина"
	return mate


func test_mate_press_lights_tag() -> void:
	var mate := _mate()
	var i := main.crew.find(mate)
	main.step(1.0 / 30.0)
	var v := main.name_tags
	ok(v.tags[i].visible, "табличка видна")
	ok(not v.glows[i].visible, "без нажатия штрихов нет")
	mate.pad.action = true   # кнопка товарища: в этом кадре
	main.step(1.0 / 30.0)
	ok(mate.active(), "товарищ нажал — «нажимает»")
	ok(v.levels[i] > 0.0 and v.levels[i] < 1.0, "входит плавно, не сразу (%f)" % v.levels[i])
	for k in 5:
		main.step(1.0 / 30.0)
	near(v.levels[i], 1.0, 1e-6, "за 0,15 с — полностью")
	ok(v.glows[i].visible, "контур и штрихи видны")
	for k in 30:
		main.step(1.0 / 30.0)
	near(v.levels[i], 0.0, 1e-6, "через секунду — погасло")
	ok(not v.glows[i].visible, "штрихов нет")


func test_own_press_marks_me() -> void:
	main.overlay.router.action_pressed = true
	main._mark_presses(main.overlay.router, 1.0 / 30.0)
	main.overlay.router.action_pressed = false
	ok(main.me.active(), "свой нажал — гости увидят «нажимает» в кадре")


func test_lost_mate_tag() -> void:
	var mate := _mate()
	var i := main.crew.find(mate)
	main.step(1.0 / 30.0)
	var v := main.name_tags
	ok(not v.states[i].visible, "на связи — строки нет")
	near(v.names[i].position.y, 0.0, 1e-6, "имя посередине")
	mate.lost = true
	main.step(1.0 / 30.0)
	ok(v.states[i].visible, "строка «Нет связи»")
	eq(v.states[i].text, "Нет связи")
	ok(v.names[i].position.y > 0.0, "имя выше, строка под ним")
	var col := v.names[i].modulate
	near(Vector3(col.r, col.g, col.b).distance_to(Vector3(NameTag.DIM.r, NameTag.DIM.g, NameTag.DIM.b)), 0.0, 0.01,
		"имя приглушено")
	mate.pad.action = true
	main.step(1.0 / 30.0)
	near(v.levels[i], 0.0, 1e-6, "без связи «нажимает» не горит")
	mate.lost = false
	main.step(1.0 / 30.0)
	ok(not v.states[i].visible, "связь вернулась — строки нет")


func test_pressing_tag_goes_first() -> void:
	ok(NameTag.before(true, 5.0, false, 2.0), "нажимает — раньше ближней")
	ok(not NameTag.before(false, 2.0, true, 5.0))
	ok(NameTag.before(false, 2.0, false, 5.0), "иначе — ближняя раньше")


func test_pressing_mate_behind_other_seen() -> void:
	# #374, шаг 06d2-tag-press: биолог стоит прямо за инженером, его табличка не помещалась над ближней и пряталась
	main.walker.x = -1.6
	main.walker.z = -2.2
	main.walker.yaw = deg_to_rad(-90.0)
	main.walker.pitch = deg_to_rad(-5.0)
	main.add_mate(0.2, -2.6, deg_to_rad(60.0), Crew.Role.ENGINEER, 1)
	var bio := main.add_mate(0.9, -2.3, deg_to_rad(90.0), Crew.Role.BIOLOGIST, 0)
	var i := main.crew.find(bio)
	main.step(1.0 / 30.0)
	bio.pad.action = true
	for k in 4:
		main.step(1.0 / 30.0)
	var v := main.name_tags
	ok(bio.active(), "биолог нажимает")
	ok(v.tags[i].visible, "табличка биолога видна")
	ok(v.glows[i].visible, "и подсветка на ней")
