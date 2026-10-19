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
	eq(main.crew_view.figures[0].layers, 2, "слой корабля")
	for i in 15:
		main.walker.z -= Deck.Walker.SPEED / 30.0
		main.step(1.0 / 30.0)
	ok(main.me.swing > 0.5, "фигура шагает")
	var shin: Transform3D = _shown(0, "shin_l")
	near(Vector2(shin.origin.x, shin.origin.z).distance_to(Vector2(main.walker.x, main.walker.z)), 0.0, 0.4, "ноги под игроком")
	ok(_shown(0, "head") == null, "свою голову не видно")


func test_seated_hands_on_wheel_in_scene() -> void:
	main.sit_at_helm()
	main.helm.turn = 0.0
	main.step(1.0 / 30.0)
	var hand: Transform3D = _shown(0, "hand_r")
	var grip: Vector3 = Crew.wheel_grips(main.helm.turn)[1]
	ok(hand.origin.distance_to(grip) < 0.12, "правая рука у обода (%.2f м)" % hand.origin.distance_to(grip))
	near(main.camera.position.y, main.me.eye().y, 1e-4, "камера в голове фигуры")
	main.stand_up()


func test_mate_visible_whole() -> void:
	await main.debug_setup({"mate": "1,0.5,180,2"})
	main.step(1.0 / 30.0)
	eq(main.crew_view.figures.size(), 2, "две фигуры")
	eq(main.crew[1].role, Crew.Role.ENGINEER, "роль из ключа")
	ok(_shown(1, "head") != null, "голову другого видно")
	near(_shown(1, "head").origin.y, Deck.Walker.EYE, 0.02, "на высоте роста")
