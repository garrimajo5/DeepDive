extends TestCase
## Экипаж в сцене: своя фигура идёт за игроком и садится за штурвал, другой член экипажа виден целиком.

var main: Main


func before() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)


func _shown(fig: int, part: String) -> Variant:
	return main.crew_view.shown[fig].get(part)


func test_own_figure_follows_player() -> void:
	eq(main.crew_view.figures.size(), 1, "одна фигура — свой игрок")
	eq(main.crew_view.meshes[0].layers, 2, "слой корабля")
	for i in 15:
		main.walker.z -= Deck.Walker.SPEED / 30.0
		main.step(1.0 / 30.0)
	ok(main.me.swing > 0.5, "фигура шагает")
	var knee: Vector3 = _shown(0, "knee_l")
	near(Vector2(knee.x, knee.z).distance_to(Vector2(main.walker.x, main.walker.z)), 0.0, 0.4, "ноги под игроком")
	ok(_shown(0, "head") == null, "свою голову не видно")


func test_seated_hands_on_wheel_in_scene() -> void:
	main.sit_at_helm()
	main.helm.turn = 0.0
	main.step(1.0 / 30.0)
	var hand: Vector3 = _shown(0, "hand_r")
	var grip: Vector3 = Crew.wheel_grips(main.helm.turn)[1]
	ok(hand.distance_to(grip) < 0.12, "правая рука у обода (%.2f м)" % hand.distance_to(grip))
	near(main.camera.position.y, main.me.eye().y, 1e-4, "камера в голове фигуры")
	main.stand_up()


func test_mate_visible_whole() -> void:
	await main.debug_setup({"mate": "1,0.5,180,2"})
	main.step(1.0 / 30.0)
	eq(main.crew_view.figures.size(), 2, "две фигуры")
	eq(main.crew[1].role, Crew.Role.ENGINEER, "роль из ключа")
	ok(_shown(1, "head") != null, "голову другого видно")
	near(_shown(1, "head").y, Deck.Walker.EYE, 0.05, "на высоте роста")


func _tris(mi: MeshInstance3D) -> int:
	return (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3


func test_model_replaces_capsules() -> void:
	await main.debug_setup({"mate": "1,0.5,180,2"})
	main.step(1.0 / 30.0)
	var cv := main.crew_view
	ok(cv.skeletons[0] is Skeleton3D and cv.skeletons[0].get_bone_count() == 24, "модель MOD-012 со скелетом")
	eq(cv.looks[1], 1, "второй член экипажа — женская модель")
	eq(cv.meshes[1].layers, 2, "модель на слое корабля")
	ok(_tris(cv.meshes[0]) < _tris(cv.meshes[1]) * 0.9, "свой игрок — без головы (%d треуг.)" % _tris(cv.meshes[0]))
	ok(cv.meshes[0].material_override != null and cv.meshes[1].material_override == null, "свой — с отсечением граней")
	ok(cv.patches[1].visible and not cv.patches[0].visible, "нашивка роли — у других")
	var back: Vector3 = cv.figures[0].position
	near(back.dot(main.me.joints()["fwd"]), -CrewView.OWN_BACK, 1e-4, "стоя своя модель чуть позади камеры")
	main.sit_at_helm()
	main.step(1.0 / 30.0)
	eq(cv.figures[0].position, Vector3.ZERO, "сидя — на месте, руки на штурвале")
	main.stand_up()


func test_hands_on_posts_in_scene() -> void:
	main.walker.x = -3.9
	main.walker.z = -2.0
	main.open_power()
	main.power.sel = 4
	for i in 10:   # наклон к пульту плавный
		main.step(1.0 / 30.0)
	var g := CrewHands.energy(4, main.reactor.share[4] / float(Reactor.MAX))
	ok(main.me.hands[1].is_equal_approx(g[1]), "у пульта: правая на ползунке прожектора")
	var hand: Vector3 = main.crew_view.shown[0]["hand_r"]
	ok(hand.distance_to(g[1]) < 0.08, "модель дотянулась до ползунка (%.3f м)" % hand.distance_to(g[1]))
	eq(main.crew_view.figures[0].position, Vector3.ZERO, "с руками на посте модель не сдвинута назад")
	main.close_power()
	main.step(1.0 / 30.0)
	ok(not main.me.holding(), "отошёл от пульта — руки свободны")
	main.walker.x = 0.0
	main.walker.z = 0.5
	main.use_post("sonar")
	main.step(1.0 / 30.0)
	ok(main.me.hands[0].is_finite() and main.me.hands[0].z > BridgeProps.TABLE_Z, "импульс — ладони на голостоле")
	for i in int(CrewHands.PRESS * 30.0) + 2:
		main.step(1.0 / 30.0)
	ok(not main.me.holding(), "через %.1f с руки свободны" % CrewHands.PRESS)


## По issue #106: наклон к голостолу — камера идёт за головой, а не остаётся над спиной (лоскуты меша у камеры).
func test_camera_follows_lean_at_table() -> void:
	main.walker.x = 0.0
	main.walker.z = 0.5
	main.walker.yaw = 0.0
	main.use_post("sonar")
	for i in 10:
		main.step(1.0 / 30.0)
	ok(main.me.lean > 0.1, "наклон к столу (%.2f рад)" % main.me.lean)
	var j := main.me.joints()
	var head: Vector3 = j["head"] + (j["fwd"] as Vector3) * 0.04
	ok(main.camera.position.distance_to(head) < 0.01, "камера в голове (%.3f м)" % main.camera.position.distance_to(head))
	for i in int(CrewHands.PRESS * 30.0) + 10:
		main.step(1.0 / 30.0)
	eq(main.me.lean, 0.0, "руки свободны — выпрямился")
	near(main.camera.position.y, Deck.Walker.EYE, 1e-4, "камера на прежней высоте")


## По issue #107: у пульта энергии игрок встаёт к нему и смотрит на ползунки — ближняя рука на выбранном.
func test_power_steps_to_panel() -> void:
	main.walker.x = -3.4   # край радиуса поста
	main.walker.z = -2.3
	main.open_power()
	var post: Deck.Post = Deck.posts().filter(func(p): return p.id == "energy")[0]
	eq(Vector2(main.walker.x, main.walker.z), post.at, "встал к пульту")
	near(main.walker.pitch, Main.POWER_PITCH, 1e-6, "взгляд на ползунки")
	main.power.sel = 0
	for i in 15:
		main.step(1.0 / 30.0)
	var g := CrewHands.energy(0, main.reactor.share[0] / float(Reactor.MAX))
	var hand: Vector3 = main.crew_view.shown[0]["hand_l"]
	ok(hand.distance_to(g[0]) < 0.08, "левая на ползунке двигателей (%.3f м)" % hand.distance_to(g[0]))
	main.close_power()


## Снаряжение ролей MOD-016: роль видна по деталям, свой игрок не видит их на голове и груди, щиток — на сварке.
func test_role_gear() -> void:
	var mate := main.add_mate(0.0, -4.6, PI, Crew.Role.ENGINEER, 0)
	main.step(1.0 / 30.0)
	var i := main.crew.find(mate)
	var g: Dictionary = main.crew_view.gear[i]
	eq(g.keys(), CrewRig.ROLE_GEAR[Crew.Role.ENGINEER], "инженер — фартук и щиток")
	for n in g.values():
		ok((n as Node3D).is_visible_in_tree(), "%s видна" % n.name)
		for mi in (n as Node).find_children("*", "MeshInstance3D", true, false):
			eq((mi as MeshInstance3D).layers, 2, "%s на слое корабля" % n.name)
	var visor: Node3D = g["gear-shchitok"]
	var head: Vector3 = main.crew_view.shown[i]["head"]
	var at := main.crew_view.to_local(visor.global_position)
	ok(at.distance_to(head) < 0.3, "щиток у головы (%.2f м)" % at.distance_to(head))
	var up := visor.transform
	mate.weld(Vector3(0.0, 1.2, -6.0), Vector3.BACK)
	main.step(1.0 / 30.0)
	ok(not visor.transform.is_equal_approx(up), "на сварке щиток опущен")
	mate.weld(Vector3.INF)
	mate.role = Crew.Role.BIOLOGIST
	main.step(1.0 / 30.0)
	eq(main.crew_view.gear[i].keys(), CrewRig.ROLE_GEAR[Crew.Role.BIOLOGIST], "сменил роль — туника и пробы")
	var own: Dictionary = main.crew_view.gear[main.crew.find(main.me)]
	ok(not (own["gear-garnitura"] as Node3D).visible, "своя гарнитура не видна (камера в голове)")
