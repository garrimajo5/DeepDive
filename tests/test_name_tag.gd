extends TestCase
## Табличка игрока над фигурой (ART-033): размер по расстоянию, имя и буква роли, своей нет, далеко — скрыта.

var main: Main


func before() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)


func test_size_by_distance() -> void:
	near(NameTag.px(1.0), 96.0, 1e-4, "вблизи 96 px")
	near(NameTag.px(6.0), 72.0, 1e-4, "на 6 м 72 px")
	near(NameTag.px(10.0), 48.0, 1e-4, "на 10 м 48 px")
	near(NameTag.world_height(6.0, 70.0), 0.56, 0.01, "72 px на 6 м при 70° ≈ 0,56 м (ART-033)")
	near(NameTag.alpha(9.0), 1.0, 1e-6, "до 10 м не гаснет")
	near(NameTag.alpha(11.0), 0.5, 1e-6, "10–12 м гаснет")
	ok(not NameTag.shown(12.5), "дальше 12 м скрыта")


func test_label_and_letter() -> void:
	eq(NameTag.label("Марина", Crew.Role.BIOLOGIST), "Марина")
	eq(NameTag.label("", Crew.Role.ENGINEER), "Инженер", "без имени — роль")
	eq(NameTag.label("Александрина-Длинная", 0).length(), NameTag.MAX_LEN, "длинное — 12 знаков")
	ok(NameTag.label("Александрина-Длинная", 0).ends_with("…"), "с многоточием")
	eq(NameTag.letter(Crew.Role.PILOT), "П")
	eq(NameTag.letter(Crew.Role.SONAR), "С")
	near(NameTag.width(0.1), NameTag.MIN_W, 1e-6, "короткое имя — не уже MIN_W")
	near(NameTag.width(20.0), NameTag.MAX_W, 1e-6, "не шире MAX_W")


func test_plate_image() -> void:
	var img := NameTag.plate_image(3.0, NameTag.ring_color(Crew.Role.PILOT))
	eq(img.get_size(), Vector2i(3 * NameTag.TEX_H, NameTag.TEX_H))
	near(img.get_pixel(0, 0).a, 0.0, 0.05, "угол скруглён — прозрачный")
	var mid := img.get_pixel(img.get_width() / 2, NameTag.TEX_H / 2)
	near(mid.a, NameTag.BACK_A, 0.02, "середина — фон")
	var ring := img.get_pixel(roundi((NameTag.CIRCLE_X + NameTag.CIRCLE_R) * NameTag.TEX_H), NameTag.TEX_H / 2)
	ok(ring.r > 0.7 and ring.b < 0.4, "кольцо пилота — янтарь (%s)" % ring)
	for c: Color in NameTag.ROLE_RING:
		ok(not (c.r > 0.7 and c.g < 0.45 and c.b < 0.45), "без красного (#129): %s" % c)


func test_mate_tag_over_head() -> void:
	main.walker.x = 0.0
	main.walker.z = 0.0
	main.walker.yaw = 0.0
	var mate := main.add_mate(0.0, -4.0, PI, Crew.Role.BIOLOGIST, 1)
	mate.name = "Марина"
	main.step(1.0 / 30.0)
	var v := main.name_tags
	var i := main.crew.find(mate)
	ok(not v.tags[main.crew.find(main.me)].visible, "своей таблички нет")
	ok(v.tags[i].visible, "у товарища табличка видна")
	eq(v.names[i].text, "Марина")
	eq(v.letters[i].text, "Б")
	eq(v.tags[i].get_child(0).layers, OceanView.LAYER_SHIP, "слой корабля")
	var sk := main.crew_view.skeletons[i]
	var top: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("head_end")).origin
	var h := v.tag_height(i)
	var bottom := v.tags[i].global_position.y - h * 0.5
	near(bottom - top.y, NameTag.LIFT, 0.01, "низ плашки на 0,18 м над макушкой")
	var anchor := top + Vector3.UP * NameTag.LIFT
	var d := main.camera.global_position.distance_to(anchor)
	var depth := -(main.camera.global_transform.affine_inverse() * anchor).z
	near(h, NameTag.world_height(d, main.camera.fov, depth), 1e-3, "высота по расстоянию и глубине взгляда")
	var to_cam := (main.camera.global_position - v.tags[i].global_position) * Vector3(1, 0, 1)
	ok(v.tags[i].global_basis.z.normalized().dot(to_cam.normalized()) > 0.99, "плашка лицом к камере")


func test_far_mate_hidden() -> void:
	main.walker.x = 0.0
	main.walker.z = -4.0
	var mate := main.add_mate(0.0, 14.0, 0.0, Crew.Role.ENGINEER, 0)   # машинное — дальше 12 м
	main.step(1.0 / 30.0)
	ok(not main.name_tags.tags[main.crew.find(mate)].visible, "дальше 12 м табличка скрыта")


func test_flyby_hides_tags() -> void:
	var mate := main.add_mate(0.0, -4.0, PI, Crew.Role.PILOT, 0)
	main.name_tags.show_tags(main.crew, main.me, main.crew_view, main.flyby_cam, main.camera)
	ok(not main.name_tags.tags[main.crew.find(mate)].visible, "камера с борта — таблички скрыты")


## Прямоугольник плашки i на экране, px.
func _screen_rect(i: int) -> Rect2:
	var t := main.name_tags.tags[i]
	var w := main.name_tags.widths[i]
	var a := main.camera.unproject_position(t.global_transform * Vector3(-w * 0.5, 0.5, 0.0))
	var b := main.camera.unproject_position(t.global_transform * Vector3(w * 0.5, -0.5, 0.0))
	return Rect2(a, b - a).abs()


func test_depth_and_spread_rules() -> void:
	near(NameTag.world_height(2.0, 70.0, 1.0), NameTag.world_height(2.0, 70.0) * 0.5, 1e-6, "по глубине — меньше")
	ok(not NameTag.visible_at(1.5, 0.3), "вплотную к плоскости камеры — скрыта (#319)")
	ok(not NameTag.visible_at(1.5, -1.0), "за камерой — скрыта")
	ok(NameTag.visible_at(3.0, 2.5), "впереди — видна")
	var rs := [Rect2(100, 100, 200, 50), Rect2(150, 110, 200, 50), Rect2(600, 100, 200, 50), Rect2(160, 105, 200, 50)]
	var lift := NameTag.spread(rs)
	eq(lift[0], 0.0, "ближняя на месте")
	ok(lift[1] >= 60.0 and lift[1] <= 50.0 * NameTag.MAX_UP + 0.5, "задевающая поднята над ближней (%s)" % lift[1])
	eq(lift[2], 0.0, "в стороне — на месте")
	eq(lift[3], NameTag.HIDDEN, "третья в ряд не помещается (потолок) — скрыта, только вверх (ART-033)")
	for i in 3:
		for j in i:
			ok(not Rect2(rs[i].position - Vector2(0, lift[i]), rs[i].size).intersects(
				Rect2(rs[j].position - Vector2(0, lift[j]), rs[j].size)), "%d и %d не перекрываются" % [i, j])


## #319: товарищ сбоку вплотную — плашка не больше 96 px (при 1080), а не в треть экрана.
func test_side_mate_not_huge() -> void:
	main.walker.x = 0.0
	main.walker.z = 0.0
	main.walker.yaw = -0.6   # повернулся к товарищу справа: плашка целиком в кадре (окно тестов квадратное)
	var mate := main.add_mate(1.1, -1.3, PI, Crew.Role.BIOLOGIST, 1)
	mate.name = "Биолог"
	main.step(1.0 / 30.0)
	var i := main.crew.find(mate)
	ok(main.name_tags.tags[i].visible, "табличка видна")
	var vp_h := main.get_viewport().get_visible_rect().size.y
	var r := _screen_rect(i)
	ok(r.size.y <= 96.0 * vp_h / NameTag.REF_H * 1.05, "высота на экране %.0f px ≤ 96 при 1080 (окно %.0f)" % [r.size.y, vp_h])


## #320: двое рядом — таблички на экране не перекрываются.
func test_close_mates_no_overlap() -> void:
	main.walker.x = 0.0
	main.walker.z = 2.0
	main.walker.yaw = 0.0
	var a := main.add_mate(-0.25, -2.0, PI, Crew.Role.BIOLOGIST, 1)
	a.name = "Биолог"
	var b := main.add_mate(0.35, -2.6, PI, Crew.Role.ENGINEER, 0)
	b.name = "Инженер"
	main.step(1.0 / 30.0)
	var ia := main.crew.find(a)
	var ib := main.crew.find(b)
	ok(main.name_tags.tags[ia].visible and main.name_tags.tags[ib].visible, "обе видны")
	var ra := _screen_rect(ia)
	var rb := _screen_rect(ib)
	ok(not ra.intersects(rb), "не перекрываются: %s и %s" % [ra, rb])
	ok(rb.position.y < ra.position.y, "дальняя поднята над ближней")


## #319: табличка целиком в кадре и не на кнопках и открытых панелях — иначе скрыта.
func test_clear_of() -> void:
	var screen := Rect2(0, 0, 1600, 720)
	ok(NameTag.clear_of(Rect2(700, 200, 200, 50), screen, []), "в кадре, ничего рядом — видна")
	ok(not NameTag.clear_of(Rect2(1500, 10, 200, 50), screen, []), "за правым краем — скрыта")
	ok(not NameTag.clear_of(Rect2(700, -10, 200, 50), screen, []), "за верхним краем — скрыта")
	var noclip := NameTag.circle_rect(Vector2(1520, 80), 36.0)
	eq(noclip, Rect2(1484, 44, 72, 72))
	ok(not NameTag.clear_of(Rect2(1400, 60, 120, 40), screen, [noclip]), "на кнопке noclip — скрыта")
	ok(NameTag.clear_of(Rect2(1200, 60, 120, 40), screen, [noclip]), "рядом с кнопкой — видна")


## #319 (отчёт qa/2026-10-21-2350, 22-itog): открытая панель справа — табличка, попавшая на неё, скрыта; видимые
## таблички не задевают ни кнопок, ни панели и целиком в кадре.
func test_tag_not_over_panel() -> void:
	main.walker.x = 0.0
	main.walker.z = 2.0
	main.walker.yaw = 0.0
	main.walker.pitch = 0.0
	var mate := main.add_mate(0.0, -2.0, PI, Crew.Role.BIOLOGIST, 1)
	mate.name = "Биолог"
	var i := main.crew.find(mate)
	var screen := main.get_viewport().get_visible_rect()
	var hidden_by_panel := 0
	for k in 13:
		var x := -2.4 + 0.4 * k
		main.vote_panel.visible = false
		mate.place(x, -1.0, PI)
		main.step(1.0 / 30.0)
		var free := main.name_tags.tags[i].visible
		main.vote_panel.visible = true
		main.step(1.0 / 30.0)
		var t := main.name_tags.tags[i]
		if free and not t.visible:
			hidden_by_panel += 1
		if t.visible:
			var r := _screen_rect(i)
			ok(screen.grow(1.0).encloses(r), "x %.1f: целиком в кадре %s" % [x, r])
			for b: Rect2 in main.tag_blocks():
				ok(not b.intersects(r.grow(-1.0)), "x %.1f: табличка %s не на %s" % [x, r, b])
	main.vote_panel.visible = false
	ok(hidden_by_panel > 0, "хотя бы раз табличка попала на панель и скрыта")
