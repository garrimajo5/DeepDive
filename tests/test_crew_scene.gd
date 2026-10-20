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
