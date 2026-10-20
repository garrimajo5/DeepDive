extends TestCase
## Лаборатория (ART-009, MOD-015): в колбах — три последних образца груза, посты «Колба» и «Журнал», тумбы и стойка —
## препятствия, экран журнала показывает сводку.


func test_contents_last_three() -> void:
	eq(Lab.contents([]), [-1, -1, -1] as Array[int], "пустой трюм — колбы пусты")
	eq(Lab.contents([[Samples.Kind.SHELL, 3]]), [Samples.Kind.SHELL, -1, -1] as Array[int], "один образец — в первой")
	var cargo := [[0, 1], [1, 8], [2, 10], [3, 13]]
	eq(Lab.contents(cargo), [1, 2, 3] as Array[int], "четыре — три последних по порядку")


func test_labels_and_journal() -> void:
	var s := Samples.new(func(_x: float, _z: float) -> float: return -60.0)
	eq(Lab.flask_label(s.cargo, 0), "Колба 1 пуста", "подпись пустой")
	ok(Lab.flask_info(s.cargo, 2).contains("лебёдка"), "подсказка, откуда берутся образцы")
	eq(Lab.journal_lines(s)[-1], "Образцов пока нет", "журнал пуст")
	s.restore([0, 8], [[Samples.Kind.MOSS, 0], [Samples.Kind.SHELL, 8], [Samples.Kind.MOSS, -1]])
	eq(Lab.flask_label(s.cargo, 1), "Колба 2: ракушка моллюска", "во второй — ракушка")
	var lines := Lab.journal_lines(s)
	eq(lines[0], "ЖУРНАЛ ЭКСПЕДИЦИИ", "заголовок")
	ok(lines.has("Образцов в трюме: 3"), "груз")
	ok(lines.has("Поднято со дна: 2 из 14"), "поднято")
	ok(lines.has("Светящийся мох — 2"), "по видам")
	eq(Lab.journal_info(s), "Журнал: образцов 3, видов образцов 2 из 4", "сообщение журнала")


func test_obstacles_and_posts() -> void:
	var l := ShipLayout.new()
	for f in Lab.FLASKS:
		ok(not l.can_stand(f.x, f.y), "в тумбу не встать (%s)" % f)
	ok(not l.can_stand(Lab.JOURNAL.x, Lab.JOURNAL.y), "в стойку журнала не встать")
	ok(l.can_stand(0.0, 11.0), "центр отсека свободен")
	for p in Lab.posts():
		var at := p.at
		if p.id.begins_with("flask"):
			# подойти к тумбе: у кормовых двух — с носа (сбоку мешает соседняя), у третьей — со стороны прохода
			var d := Vector2(-1.0, 0.0) if p.at.x > 0.0 else Vector2(0.0, -1.0)
			at = p.at + d * (Lab.BASE / 2.0 + Deck.Walker.RADIUS + 0.05)
		ok(l.can_stand(at.x, at.y), "к посту %s можно подойти" % p.id)
		ok(at.distance_to(p.at) <= p.r, "точка подхода в радиусе поста %s" % p.id)
	# колба 1 и 2 рядом: ближний пост — своей колбы
	var near1 := Deck.nearest(Lab.posts(), -3.3, 12.6)
	eq(near1.id, "flask0", "у первой колбы — пост первой")


func test_scene_flasks_and_journal() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.samples.cargo.append([Samples.Kind.CORAL, -1])
	main.walker.x = -2.9
	main.walker.z = 12.5
	main.step(1.0 / 30.0)
	ok(main.rooms.lab_samples[0].visible, "образец в первой колбе виден")
	ok(not main.rooms.lab_samples[1].visible, "вторая пуста")
	eq((main.rooms.lab_samples[0].material_override as StandardMaterial3D).albedo_color, Samples.COLORS[Samples.Kind.CORAL],
		"цвет вида")
	eq(main.overlay.action_label, "Колба", "кнопка «Колба»")
	var r := main.overlay.router
	r.begin(5, r.layout.action.c)
	main.step(1.0 / 30.0)
	r.end(5)
	main.step(1.0 / 30.0)
	eq(main.message.text, "Колба 1: ветка огнецвета", "на приборах — что в колбе")
	main.walker.x = Lab.JOURNAL_POST.x
	main.walker.z = Lab.JOURNAL_POST.y
	main.step(1.0 / 30.0)
	eq(main.overlay.action_label, "Журнал", "кнопка «Журнал»")
	r.begin(5, r.layout.action.c)
	main.step(1.0 / 30.0)
	r.end(5)
	main.step(1.0 / 30.0)
	eq(main.message.text, "Журнал: образцов 1, видов образцов 1 из 4", "сводка журнала")
	ok(main.rooms.journal_text.text.contains("Ветка огнецвета — 1"), "экран журнала: %s" % main.rooms.journal_text.text)
	main.queue_free()
	await frames(1)
