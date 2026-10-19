extends TestCase
## Нижний шлюз трюма: крышка на петле, сообщения, проём в полу, пост.


func test_open_close() -> void:
	var a := Airlock.new()
	var msgs: Array[String] = []
	a.message.connect(func(m: String) -> void: msgs.append(m))
	eq(a.label(), "Открыть шлюз", "закрыт")
	a.toggle()
	for i in 10:
		a.update(0.1)
	ok(not a.fully_open() and not a.closed(), "через 1 с — в движении")
	for i in 11:
		a.update(0.1)
	ok(a.fully_open(), "через 2 с открыт")
	near(a.angle(), 100.0, 1e-4, "крышка вниз на 100°")
	eq(msgs, ["Шлюз открывается", "Шлюз открыт"] as Array[String], "сообщения")
	a.toggle()
	for i in 25:
		a.update(0.1)
	ok(a.closed() and msgs.has("Шлюз закрыт"), "закрылся")


func test_cover_hinged_at_bow_edge() -> void:
	var a := Airlock.new()
	var hinge := Vector3(0, Airlock.Y, Airlock.HINGE_Z)
	for tt in [0.0, 0.5, 1.0]:
		a.t = tt
		var x := a.cover_pose()
		var bow_edge := x * Vector3(0, 0, -Airlock.RADIUS)
		ok(bow_edge.distance_to(hinge) < 1e-4, "носовая кромка на петле при t %.1f" % tt)
	a.t = 1.0
	var stern := a.cover_pose() * Vector3(0, 0, Airlock.RADIUS)
	ok(stern.y < Airlock.Y - 2.0, "кормовая кромка ушла вниз: %.2f" % stern.y)
	a.t = 0.0
	near(a.cover_pose().origin.z, Airlock.Z, 1e-4, "закрыта — под проёмом")


func test_hole_and_shaft_inside_hull() -> void:
	for p in ShipLayout.parts():
		if p.name.begins_with("Пол трюма"):
			var lo := p.center - p.size / 2.0
			var hi := p.center + p.size / 2.0
			var over := lo.x < Airlock.HOLE / 2.0 - 0.01 and hi.x > -Airlock.HOLE / 2.0 + 0.01 and lo.z < Airlock.Z + Airlock.HOLE / 2.0 - 0.01 and hi.z > Airlock.Z - Airlock.HOLE / 2.0 + 0.01
			ok(not over, "%s не закрывает проём" % p.name)
		if p.name.begins_with("Шахта"):
			for c in p.corners():
				ok(HullPlan.inside(c), "шахта внутри корпуса")


func test_scene_airlock_post() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.walker.x = Airlock.POST_AT.x
	main.walker.z = Airlock.POST_AT.y
	main.step(0.1)
	eq(main.overlay.action_label, "Шлюз", "в трюме у проёма — кнопка «Шлюз»")
	var r := main.overlay.router
	r.begin(1, r.layout.action.c)
	r.end(1)
	for i in 25:
		main.step(0.1)
	ok(main.airlock.fully_open(), "открыт")
	ok(main.rooms.airlock_cover.position.y < Airlock.Y - 0.5, "крышка опустилась")
	ok(Status.join(main.status_parts()).contains("шлюз открыт"), "на приборах")
	eq(main.message.text, "Шлюз открыт", "сообщение")
