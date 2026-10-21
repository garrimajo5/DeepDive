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
	var d := main.camera.global_position.distance_to(top + Vector3.UP * NameTag.LIFT)
	near(h, NameTag.world_height(d, main.camera.fov), 1e-3, "высота по расстоянию")
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
