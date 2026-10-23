extends TestCase
## Событие «пробоина» (Breach, js/breach.js, ART-013): сильный удар пробивает борт, вода прибывает, корпус слабеет,
## сварка удержанием закрывает пробоину, насосы откачивают воду от доли жизнеобеспечения.


func test_spots_on_walls_and_reachable() -> void:
	var b := Breach.new()
	eq(b.all.size(), 4, "четыре места")
	var lay := ShipLayout.new()
	for s in b.all:
		ok(lay.can_stand(s.at.x, s.at.y), "%s: у пробоины можно стоять" % s.name)
		ok(Vector2(s.p.x, s.p.z).distance_to(s.at) < Breach.POST_R + 0.2, "%s: пост рядом с пробоиной" % s.name)
		ok(not lay.can_stand(s.p.x - s.n.x * 0.15, s.p.z - s.n.z * 0.15, 0.0), "%s: за точкой — борт" % s.name)
		ok(lay.can_stand(s.p.x + s.n.x * 0.5, s.p.z + s.n.z * 0.5, 0.1), "%s: по нормали — отсек" % s.name)
		eq(ShipLayout.room_at(s.at.y), s.room, "%s: стоят в своём отсеке" % s.name)
		ok(s.floor.has_point(s.at), "%s: залитый пол — этот отсек" % s.name)
	ok(b.all[0].p.distance_to(Zap.LEVER_POS) > 1.5, "мостик: не на щитке разряда")
	ok(b.all[3].p.distance_to(EngineRoom.VALVE_POS) > 1.0, "машинное: не на вентиле")


func test_hit_opens_by_rules() -> void:
	var b := Breach.new()
	var msgs: Array[String] = []
	b.message.connect(func(t: String) -> void: msgs.append(t))
	ok(not b.on_hit(9, 80.0), "удар 9 % борт не пробивает")
	ok(b.on_hit(12, 80.0), "укус 12 % — пробоина")
	eq(b.active, b.all[0], "первая — на мостике")
	eq(msgs[0], "Пробоина: мостик — держите «Сварка» у пробоины", "сообщение")
	ok(not b.on_hit(30, 60.0), "вторая, пока открыта первая, — нет")
	b.hold(10.0)
	ok(b.active == null, "заварили")
	ok(not b.on_hit(30, 60.0), "откат 45 с")
	b.update(45.0, 1.0, 60.0)
	ok(b.on_hit(30, 60.0), "после отката — снова")
	eq(b.active, b.all[1], "следующая — в коридоре")
	b.reset()
	ok(not b.on_hit(20, 0.0), "корпус разрушен — не открывается")


func test_water_and_hull() -> void:
	var b := Breach.new()
	b.start(b.all[2])
	var hull := 50.0
	for i in 100:
		hull = b.update(0.1, 1.0, hull)
	near(b.water, 0.16, 1e-4, "за 10 с вода 16 см")
	near(hull, 44.0, 1e-4, "корпус −0,6 %/с")
	eq(b.status(), "ПРОБОИНА · ЛАБОРАТОРИЯ · вода 16 см", "на приборах")
	for i in 700:
		hull = b.update(0.1, 1.0, hull)
	near(b.water, Breach.WATER_MAX, 1e-6, "не выше колена")
	near(hull, Breach.HULL_FLOOR, 1e-6, "корпус не ниже 15 %")
	near(b.slow(ShipLayout.Room.LAB), Breach.SLOW, 1e-6, "по колено идти тяжело")
	near(b.slow(ShipLayout.Room.BRIDGE), 1.0, 1e-6, "в сухом отсеке — как обычно")
	ok(b.alarm() >= 0.0 and b.alarm() <= 1.0, "тревога пульсирует")


func test_weld_and_pump() -> void:
	var b := Breach.new()
	var msgs: Array[String] = []
	b.message.connect(func(t: String) -> void: msgs.append(t))
	b.start(b.all[3])
	b.water = 0.3
	for i in 20:   # 2 с удержания
		b.hold(0.1)
		b.update(0.1, 0.5, 80.0)
		b.end_step()
	near(b.weld, 0.56, 1e-4, "за 2 с — 56 %")
	eq(b.label(), "Сварка 56%", "подпись")
	near(BreachView.patch_scale(b), 0.56, 1e-4, "заплатка растёт со сваркой")
	for i in 10:   # отпустил — шов не пропадает
		b.update(0.1, 0.5, 80.0)
	near(b.weld, 0.56, 1e-4, "отпустил — прогресс остался")
	for i in 16:
		b.hold(0.1)
	ok(b.active == null, "заварено за ~3,6 с удержания")
	eq(msgs[-1], "Шов заварен: машинное отделение. Насосы откачивают воду", "сообщение")
	near(BreachView.patch_scale(b), 1.0, 1e-6, "заплатка целиком")
	near(BreachView.seam_glow(b), 1.6, 1e-6, "шов горячий")
	var w := b.water
	b.update(1.0, 0.5, 80.0)
	near(b.water, w - 0.01, 1e-6, "насосы: 0,02 м/с × доля 0,5")
	near(b.seam_heat, 0.75, 1e-6, "шов остывает за 4 с")
	eq(b.status(), "Вода: машинное отделение %d см" % roundi(b.water * 100.0), "вода ещё стоит")
	b.update(100.0, 0.0, 80.0)
	ok(b.water > 0.0, "без жизнеобеспечения не откачать")
	b.update(100.0, 1.0, 80.0)
	ok(b.water == 0.0 and b.water_spot == null and b.status() == "", "откачали")
	eq(b.last, b.all[3], "заплатка осталась на борту")


func test_scene_bite_breach_weld() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.on_eco_event({"type": EcoLink.HIT, "damage": 0.12, "by": "Серпохвост"})
	ok(main.breach.active == main.breach.all[0], "укус пробил мостик")
	eq(main.message.text, "Пробоина: мостик — держите «Сварка» у пробоины", "на приборах")
	for i in 20:
		main.step(0.1)
	ok(main.breach_view.spot_node.visible and main.breach_view.jet_mm.visible, "струя бьёт")
	ok(main.breach_view.water.visible, "на полу вода")
	ok(main.breach_view.alarm.visible, "тревога")
	ok(main.breach_view.siren.playing and main.breach_view.jet_sound.playing, "воет сирена, шумит струя")
	ok(main.breach_view.jet_sound.global_position.distance_to(main.breach_view.spot_node.global_position) < 0.2,
		"шум — из пробоины")
	ok(main.status_parts()[0].begins_with("ПРОБОИНА · МОСТИК"), "первая часть строки — пробоина: %s" % main.status_parts()[0])
	var s: Breach.Spot = main.breach.all[0]
	var t := main.breach_view.spot_node.global_transform
	ok((t.basis.z).is_equal_approx(main.ship.global_transform.basis * s.n), "обшивка лицом внутрь")
	main.walker.x = s.at.x
	main.walker.z = s.at.y
	main.step(0.1)
	eq(main.overlay.action_label, "Сварка", "у пробоины — «Сварка»")
	var r := main.overlay.router
	r.begin(1, r.layout.action.c)
	for i in 20:
		main.step(0.1)
	ok(main.breach_view.spark_mm.visible and main.breach_view.parts.flash, "искры и вспышка электрода")
	ok(main.me.welding() and main.crew_view.torches[0].visible, "резак в правой руке")
	ok(main.visor.visible, "щиток опущен — экран затемнён")
	ok(main.breach_view.splash_mm.visible, "брызги там, где струя бьёт в воду")
	ok(main.breach_view.patch.scale.x > 0.4 and main.breach_view.patch.scale.x < 0.7, "заплатка наполовину: %.2f" % main.breach_view.patch.scale.x)
	for i in 20:
		main.step(0.1)
	r.end(1)
	main.step(0.1)
	ok(main.breach.active == null, "заварено")
	var born := main.breach_view.parts.born
	ok(not main.breach_view.parts.flash, "электрод погас")
	ok(not main.breach_view.siren.playing and not main.breach_view.jet_sound.playing, "сирена и струя смолкли")
	ok(not main.me.welding() and not main.crew_view.torches[0].visible and not main.visor.visible,
		"заварил — резак убран, щиток поднят")
	ok(main.breach_view._seam_mat.emission_energy_multiplier > 1.0, "шов горит")
	ok(main.breach_view.water.visible, "вода ещё стоит")
	for i in 8:
		main.step(0.1)
	eq(main.breach_view.parts.born, born, "заварено — новых частиц нет")
	ok(not main.breach_view.jet_mm.visible and not main.breach_view.splash_mm.visible
		and not main.breach_view.spark_mm.visible, "живые дожили: струи, брызг и искр нет")
	main.queue_free()
	await frames(1)


func test_scene_water_slows_walker() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.open_breach(1)
	main.breach.water = 0.3
	main.walker.x = 0.0
	main.walker.z = 3.5
	main.walker.yaw = PI   # лицом к корме
	var r := main.overlay.router
	r.begin(2, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.9))
	main.step(0.5)
	r.end(2)
	near(main.walker.z - 3.5, Deck.Walker.SPEED * Breach.SLOW * 0.5, 0.05, "по щиколотку шаг медленнее")
	main.queue_free()
	await frames(1)


func test_destroyed_clears_breach() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.open_breach(2)
	main.vitals.hit(100, "")
	for i in 36:   # шторка «Корпус разрушен» 3,5 с, под ней подъём (ART-036)
		main.step(0.1)
	ok(main.breach.active == null and main.breach.water == 0.0, "корабль поднят — пробоины нет")
	main.step(0.1)
	ok(not main.breach_view.spot_node.visible, "обшивки не видно")
	main.queue_free()
	await frames(1)


func test_jet_lands_inside_room() -> void:
	for s in Breach.spots():
		var dry := Breach.jet_reach(s, 0.0)
		var wet := Breach.jet_reach(s, Breach.WATER_MAX)
		ok(dry > 0.5, "%s: струя бьёт в отсек (%.2f м)" % [s.name, dry])
		ok(wet <= dry + 1e-6, "%s: вода выше — струя падает ближе" % s.name)
		var hit := Vector2(s.p.x, s.p.z) + Vector2(s.n.x, s.n.z) * dry
		ok(s.floor.has_point(hit), "%s: брызги на полу своего отсека" % s.name)
	var b := Breach.spots()[0]   # мостик широкий: струя не долетает до правого борта
	var d := Vector3(0.0, Breach.JET_UP, 1.0).normalized() * Breach.JET_V
	var t := Breach.jet_reach(b, 0.0) / d.z
	near(b.p.y + d.y * t - Breach.JET_G * 0.5 * t * t, 0.0, 1e-4, "мостик: точка падения — на полу")
	var sp := BreachView.splash_local(b, 0.2)
	near(sp.y, 0.2 - b.p.y, 1e-6, "брызги на уровне воды")
