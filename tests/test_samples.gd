extends TestCase
## Образцы на дне и лебёдка трюма (Samples, js/manip.js): места, захват удержанием, подъём, груз, сохранение.


func _flat(_x: float, _z: float) -> float:
	return -40.0


func test_places() -> void:
	var s := Samples.new()
	eq(s.all.size(), 14, "14 образцов, как в браузерной версии")
	var kinds := [0, 0, 0, 0]
	for smp in s.all:
		kinds[smp.kind] += 1
		near(smp.pos.y, Seabed.height(smp.pos.x, smp.pos.z) + (0.1 if smp.kind in [Samples.Kind.SHELL, Samples.Kind.SPINE] else 0.15), 1e-4, "лежит на дне")
	eq(kinds, [8, 2, 3, 1], "мох, ракушки, огнецвет, игла")
	eq(s.all[8].title(), "Ракушка моллюска", "имя вида")


func test_find_below_and_within_reach() -> void:
	var s := Samples.new(_flat)
	var p: Vector3 = s.all[3].pos
	ok(s.find(p + Vector3(0, 8, 0)) == s.all[3], "прямо под шлюзом в 8 м")
	ok(s.find(p + Vector3(0, 15, 0)) == null, "дальше 14 м — не достать")
	ok(s.find(p + Vector3(0, -1, 0)) == null, "выше шлюза — нет")
	s.all[3].taken = true
	ok(s.find(p + Vector3(0, 8, 0)) != s.all[3], "поднятый уже не ищется")


func test_grab_lift_stow() -> void:
	var s := Samples.new(_flat)
	var lock: Vector3 = s.all[8].pos + Vector3(0, 6, 0)
	var msgs: Array[String] = []
	s.message.connect(func(t: String) -> void: msgs.append(t))
	var dt := 0.05
	for i in 20:   # 1 с — ещё не взял
		s.hold(lock, dt)
		s.update(dt)
	eq(s.state, Samples.State.REACH, "тянется")
	ok(s.reach_k() > 0.6 and s.reach_k() < 0.8, "прошёл ~70 %% пути: %.2f" % s.reach_k())
	eq(s.label(), "Захват 71%", "подпись на кнопке")
	for i in 9:
		s.hold(lock, dt)
		s.update(dt)
	eq(s.state, Samples.State.BACK, "взял — поднимает")
	ok(s.all[8].taken, "образца на дне нет")
	eq(msgs[0], "Образец захвачен", "сообщение")
	eq(s.label(), "Поднимаю…", "подпись")
	for i in 30:   # кнопку можно отпустить: подъём идёт сам
		s.update(dt)
	eq(s.state, Samples.State.IDLE, "поднял")
	eq(s.cargo, [[Samples.Kind.SHELL, 8]], "в трюме ракушка")
	ok(s.got.has(8), "в списке поднятых")
	eq(msgs[-1], "В трюме: ракушка моллюска (образцов 1)", "сообщение о грузе")


func test_release_returns_hook() -> void:
	var s := Samples.new(_flat)
	var lock: Vector3 = s.all[0].pos + Vector3(0, 5, 0)
	for i in 10:
		s.hold(lock, 0.05)
		s.update(0.05)
	ok(s.progress > 0.3, "захват ушёл")
	for i in 20:
		s.update(0.05)
	eq(s.state, Samples.State.IDLE, "отпустил — вернулся")
	ok(s.target == null and not s.all[0].taken, "образец на месте")


func test_hook_path() -> void:
	var s := Samples.new(_flat)
	var ship := Samples.ship_xform(Vector3(10, -20, 50), 0.7)
	eq(s.hook_local(ship), Samples.REST, "в покое — в трюме над проёмом")
	var lock := Samples.lock_point(ship)
	near(lock.y, -20.0 + Airlock.Y, 1e-5, "шлюз — на днище")
	ok((ship * Vector3(0, Airlock.Y, Airlock.Z)).is_equal_approx(lock), "шлюз в осях корабля")
	s.all[5].pos = lock + Vector3(1, -6, 0)
	for i in 28:
		s.hold(lock, 0.05)
	s.update(0.0)
	var tip := ship * s.hook_local(ship)
	ok(tip.distance_to(s.all[5].pos + Vector3(0, 0.35, 0)) < 1e-3, "на полном захвате — над образцом")


func test_why_not() -> void:
	var s := Samples.new(_flat)
	var lock: Vector3 = s.all[0].pos + Vector3(0, 5, 0)
	eq(s.why_not(false, lock), "Сначала открыть шлюз", "шлюз закрыт")
	eq(s.why_not(true, lock + Vector3(500, 0, 0)), "Под шлюзом нет образцов ближе 14 м", "нечего поднять")
	eq(s.why_not(true, lock), "", "можно")


func test_restore() -> void:
	var s := Samples.new(_flat)
	s.restore([2, 99, -1], [[Samples.Kind.SHELL, 8], [Samples.Kind.MOSS, 8], [Samples.Kind.SHELL, 8], [Samples.Kind.CORAL, -1], [7, 0], "x"])
	eq(s.cargo, [[Samples.Kind.SHELL, 8], [Samples.Kind.CORAL, -1]], "чужой вид и повтор номера пропущены")
	ok(s.all[2].taken and s.all[8].taken and not s.all[0].taken, "поднятые убраны со дна")
	eq(s.got.size(), 2, "поднятые: 2 и 8")
	s.reset()
	ok(s.cargo.is_empty() and not s.all[8].taken, "сброс")


func test_column_blocks_floor() -> void:
	var lay := ShipLayout.new()
	ok(not lay.can_stand(Samples.BASE.x, Samples.BASE.z + 0.3), "сквозь колонну опоры не пройти")
	ok(lay.can_stand(Samples.POST_AT.x - 0.7, Samples.POST_AT.y + 0.3), "у поста лебёдки стоять можно")
	ok(Vector2(Samples.POST_AT.x - 0.7, Samples.POST_AT.y + 0.3).distance_to(Samples.POST_AT) < Samples.POST_R, "и это в радиусе поста")
	ok(Samples.POST_AT.distance_to(Airlock.POST_AT) > Samples.POST_R + Airlock.POST_R, "посты лебёдки и шлюза не слипаются")


func test_scene_winch() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.walker.x = Samples.POST_AT.x - 0.7
	main.walker.z = Samples.POST_AT.y + 0.3
	main.step(0.1)
	eq(main.overlay.action_label, "Лебёдка", "у опоры — кнопка «Лебёдка»")
	var r := main.overlay.router
	r.begin(1, r.layout.action.c)
	r.end(1)
	main.step(0.1)
	eq(main.message.text, "Сначала открыть шлюз", "шлюз закрыт — не пойдёт")
	main.park_over_sample(8)
	var smp: Samples.Sample = main.samples.all[8]
	r.begin(1, r.layout.action.c)
	for i in 10:
		main.step(0.1)
	ok(main.samples.state == Samples.State.REACH, "держим — захват тянется")
	ok(main.rooms.winch_hook.position.y < Samples.REST.y - 2.0, "захват ушёл вниз: y %.1f" % main.rooms.winch_hook.position.y)
	ok(main.rooms.winch_cable.basis.y.length() > 3.0, "трос вытянулся")
	for i in 6:
		main.step(0.1)
	r.end(1)
	ok(smp.taken, "образец взят")
	ok(main.rooms.winch_carry.visible, "висит в захвате")
	ok(main.samples_view._version == main.samples.version and SamplesView.instance_xform(smp).basis.get_scale().x < 0.01,
		"на дне его нет")
	main.walker.x = Airlock.POST_AT.x
	main.walker.z = Airlock.POST_AT.y
	main.step(0.1)
	main.use_post("airlock")
	eq(main.message.text, "Захват за бортом — шлюз не закрыть", "шлюз ждёт захват")
	ok(main.airlock.open, "шлюз открыт")
	for i in 15:
		main.step(0.1)
	eq(main.samples.cargo.size(), 1, "образец в трюме")
	ok(main.message.text.begins_with("В трюме: ракушка моллюска"), "на приборах: %s" % main.message.text)
	ok(main.rooms.winch_hook.position.is_equal_approx(Samples.REST) and not main.rooms.winch_carry.visible, "захват вернулся")
	main.queue_free()
	await frames(1)


func test_steal_and_drop() -> void:   # скальник срывает образец с захвата и бросает (EcoLink.STEAL/DROP, #201)
	var s := Samples.new(_flat)
	var lock: Vector3 = s.all[8].pos + Vector3(0, 6, 0)
	ok(not s.steal(8), "захват в покое — красть нечего")
	for i in 29:
		s.hold(lock, 0.05)
		s.update(0.05)
	eq(s.state, Samples.State.BACK, "поднимает")
	ok(not s.steal(3), "другой образец — не тот, что на захвате")
	var v := s.version
	ok(s.steal(8), "сорван на подъёме")
	eq(s.state, Samples.State.IDLE, "захват пуст")
	ok(s.target == null and s.reach_k() == 0.0, "захват в трюме")
	ok(s.all[8].taken and s.stolen.has(8), "на дне его нет — унесён")
	ok(s.version > v, "дно перерисуется")
	for i in 40:
		s.update(0.05)
	eq(s.cargo.size(), 0, "в груз не лёг")
	ok(not s.got.has(8), "не в списке поднятых")
	ok(not s.drop(2, Vector3.ZERO), "не унесённый — не трогаем")
	ok(s.drop(8, Vector3(5, -99, 7)), "брошен у норы")
	ok(not s.all[8].taken and not s.stolen.has(8), "снова лежит на дне")
	near(s.all[8].pos.distance_to(Vector3(5, -40 + 0.15, 7)), 0.0, 1e-5, "в точке броска, над дном")
	eq(s.find(s.all[8].pos + Vector3(0, 6, 0)), s.all[8], "его можно поднять заново")
	s.reset()
	near(s.all[8].pos.x, Samples.PLACES[8][1], 1e-4, "сброс — на прежнем месте")
