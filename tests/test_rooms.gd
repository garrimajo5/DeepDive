extends TestCase
## Отсеки корабля: где стоять, люки, переход с мостика в трюм, реактор в машинном.


func test_rooms_and_names() -> void:
	var l := ShipLayout.new()
	ok(l.can_stand(0, 5), "коридор")
	ok(not l.can_stand(1.0, 5), "у стены коридора не встать")
	ok(l.can_stand(3.5, 11), "лаборатория широкая")
	ok(l.can_stand(2.5, 16), "машинное")
	ok(not l.can_stand(0, 17.2), "сквозь реактор не пройти")
	ok(l.can_stand(0, 22), "трюм")
	ok(not l.can_stand(0, 24.5), "за кормой нет")
	eq(ShipLayout.ROOM_NAMES[ShipLayout.room_at(-3)], "Мостик", "мостик")
	eq(ShipLayout.ROOM_NAMES[ShipLayout.room_at(16)], "Машинное отделение", "машинное")


func test_closed_door_blocks_open_passes() -> void:
	var l := ShipLayout.new()
	ok(not l.can_stand(0, 2.0), "закрытый люк не пройти")
	l.doors[0].open = true
	l.update(0.3)
	ok(not l.doors[0].passable(), "за 0,3 с ещё не открыт")
	l.update(0.3)
	ok(l.doors[0].passable() and l.can_stand(0, 2.0), "открылся — проходим")
	ok(not l.can_stand(0.6, 2.0), "сбоку от проёма — переборка")
	near(l.doors[0].offset(), ShipLayout.Door.SLIDE, 0.05, "створка уехала вбок")


func test_bulkheads_have_door_openings() -> void:
	for p in ShipLayout.parts():
		if p.name != "Переборка" and p.name != "Над люком":
			continue
		var lo := p.center - p.size / 2.0
		var hi := p.center + p.size / 2.0
		var hits_door := lo.x < ShipLayout.DOOR_HALF - 0.01 and hi.x > -ShipLayout.DOOR_HALF + 0.01 and lo.y < ShipLayout.DOOR_H - 0.01
		ok(not hits_door, "%s на z %.1f не перекрывает проём" % [p.name, p.center.z])


func test_rod_color_by_state() -> void:
	var r := Reactor.new()
	eq(ShipLayout.rod_color(r), Color("6FE3FF"), "норма — голубой")
	r.start_hot(false)
	r.heat = 100.0
	ok(ShipLayout.rod_color(r).r > 0.9, "перегрев — янтарный")
	r.scram = 5.0
	ok(ShipLayout.rod_color(r).v < 0.3, "сброс — тёмный")


func test_walk_from_bridge_to_cargo() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var r := main.overlay.router
	main.walker.yaw = PI   # лицом к корме
	main.walker.z = 0.5
	for i in 4:
		# дойти до люка, открыть его кнопкой, пройти
		r.begin(1, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.7))
		for k in 240:
			main.step(1.0 / 30.0)
			if main.walker.z > ShipLayout.DOOR_Z[i] - 0.9:
				break
		r.end(1)
		if i == 3:
			ok(main.walker.z > 18.0, "обошли реактор по борту")
			main.walker.x = 0.0   # шаг к оси люка
		main.step(0.05)
		eq(main.overlay.action_label, "Люк", "у люка %d — кнопка «Люк»" % (i + 1))
		r.begin(2, r.layout.action.c)
		r.end(2)
		for k in 30:
			main.step(1.0 / 30.0)
		ok(main.layout.doors[i].passable(), "люк %d открыт" % (i + 1))
		r.begin(3, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.7))
		for k in 45:
			main.step(1.0 / 30.0)
		r.end(3)
		ok(main.walker.z > ShipLayout.DOOR_Z[i] + 0.5, "прошли люк %d: z %.1f" % [i + 1, main.walker.z])
		if i == 2:
			main.walker.x = 1.8   # обойти реактор по борту
	ok(Status.join(main.status_parts()).contains("Трюм"), "в трюме: " + Status.join(main.status_parts()))
