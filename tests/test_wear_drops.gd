extends TestCase
## Частицы «корабль устал» ART-074 (WearDrops): пороги групп, капли у бортов и мимо постов, пакет искр, шлейф пара,
## «Экономно», кадры не выходят из группы, один MultiMesh без огней, скрыт при целом корпусе, ремонт гасит.


func _loss(hull: float) -> float:
	return CabinWear.target(hull)


func test_thresholds() -> void:
	near(WearDrops.drip_k(_loss(62.0)), 0.0, 1e-6, "капли — с 62 %")
	ok(WearDrops.drip_k(_loss(50.0)) > 0.0, "при 50 % уже капает")
	near(WearDrops.steam_k(_loss(55.0)), 0.0, 1e-6, "пар — с 52 %")
	ok(WearDrops.steam_k(_loss(40.0)) > 0.0, "при 40 % парит")
	near(WearDrops.spark_k(_loss(40.0)), 0.0, 1e-6, "искры — с 38 %")
	near(WearDrops.spark_k(_loss(14.0)), 1.0, 1e-6, "при 14 % искры в полную силу")
	ok(not WearDrops.shown(_loss(62.0)), "корпус 62 % — частиц нет")
	ok(WearDrops.shown(_loss(60.0)), "ниже — есть")


func test_counts_and_groups() -> void:
	eq(WearDrops.cards(0.0, 1.0, false).size(), 24, "24 карточки")
	eq(WearDrops.cards(0.0, 1.0, true).size(), 12, "«Экономно» — 12")
	for lite in [false, true]:
		var kinds := {}
		for c in WearDrops.cards(1.0, 1.0, lite):
			kinds[c.kind] = int(kinds.get(c.kind, 0)) + 1
		var per := 3 if lite else 6
		eq(kinds[WearDrops.Kind.DRIP], 2 * per, "капли — две группы")
		eq(kinds[WearDrops.Kind.SPARK], per, "искры — одна группа")
		eq(kinds[WearDrops.Kind.STEAM], per, "пар — одна группа")


func test_frames_stay_in_group() -> void:
	for t in [0.0, 0.7, 2.2, 3.79, 9.05]:
		for c in WearDrops.cards(t, 1.0, false):
			var last := c.first + c.span
			match c.kind:
				WearDrops.Kind.DRIP:
					ok(c.first >= 0 and last <= 3, "капля — кадры 0–3")
				WearDrops.Kind.SPARK:
					ok(c.first >= 4 and last <= 7, "искра — кадры 4–7")
					near(c.glow, 0.2, 1e-6, "искра светится × 1,2")
				WearDrops.Kind.STEAM:
					ok(c.first == 8 and last == 15, "пар — кадры 8–15")
			ok(c.glow < 1.0, "свечение — дробная часть, не ломает span")


func test_drips_fall_by_walls_past_posts() -> void:
	for t in [0.0, 1.1, 2.5]:
		for c in WearDrops.cards(t, 1.0, false):
			if c.kind != WearDrops.Kind.DRIP:
				continue
			ok(absf(c.pos.x) > 2.7, "капли у бортов (x %.2f)" % c.pos.x)
			ok(c.pos.y <= WearDrops.DRIP_TOP + 1e-5 and c.pos.y >= WearDrops.DRIP_BOTTOM - 1e-5, "с потолка до пола")
			for q: Vector2 in CabinWear.POSTS:
				ok(Vector2(c.pos.x, c.pos.z).distance_to(q) > 0.75, "мимо поста %s (капля %s)" % [q, c.pos])
	var a := WearDrops.card(0, 0.0, 1.0, false)
	var b := WearDrops.card(0, 1.0, 1.0, false)
	ok(b.pos.y < a.pos.y, "капля падает")
	near(a.alpha, 0.0, 1e-6, "рождается из нуля")
	near(WearDrops.card(0, 1.9, 1.0, false).alpha, 0.8, 1e-3, "в середине пути — 0,8")


func test_spark_burst_every_9s() -> void:
	var lit := func(t: float) -> int:
		var n := 0
		for c in WearDrops.cards(t, 1.0, false):
			if c.kind == WearDrops.Kind.SPARK and c.alpha > 0.0:
				n += 1
		return n
	eq(lit.call(0.05), 6, "пакет из 6 искр")
	eq(lit.call(0.2), 0, "через 0,16 с погасли")
	eq(lit.call(4.5), 0, "между пакетами темно")
	eq(lit.call(9.05), 6, "следующий через 9 с")
	for c in WearDrops.cards(0.05, 1.0, false):
		if c.kind == WearDrops.Kind.SPARK:
			ok(c.pos.distance_to(WearDrops.SPARK_AT) < 0.25, "искры за фронтом пульта энергии")
	eq(WearDrops.cards(0.05, _loss(45.0), false).filter(func(c): return c.kind == WearDrops.Kind.SPARK and c.alpha > 0.0).size(),
		0, "при 45 % искр ещё нет")


func test_steam_rises_thin() -> void:
	var a := WearDrops.card(18, 0.0, 1.0, false)
	eq(a.kind, WearDrops.Kind.STEAM, "последняя группа — пар")
	near(a.pos.distance_to(WearDrops.STEAM_AT), 0.0, 1e-5, "рождается над вентилем")
	var b := WearDrops.card(18, 1.9, 1.0, false)
	ok(b.pos.y > a.pos.y + 0.2, "поднимается")
	ok(b.size.x > a.size.x, "расплывается")
	ok(b.alpha <= WearDrops.STEAM_ALPHA + 1e-6, "тонкий — альфа ≤ 0,11")


func test_one_multimesh_shown_by_hull() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var view: WearDropsView = main.rooms.drops
	ok(view is MultiMeshInstance3D, "частицы — MultiMesh")
	eq(view.layers, OceanView.LAYER_SHIP, "на слое корабля")
	eq(view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без теней")
	eq(view.find_children("*", "Light3D", true, false).size(), 0, "без огней")
	eq(ShaderKey.of(view.mat), ShaderKey.of(main.rooms.steam.mat), "шейдер пара вентиля — новых шейдеров нет")
	main.step(1.0 / 60.0)
	ok(not view.visible, "целый корпус — скрыт")
	main.vitals.hull = 15.0
	for i in 30:
		main.step(1.0 / 60.0)
	ok(view.visible and view.shown == 24, "корпус 15 %% — 24 карточки (%d)" % view.shown)
	main.vitals.hull = 100.0
	for i in 30:
		main.step(1.0 / 60.0)
	ok(not view.visible, "ремонт — снова сухо")
	main.queue_free()
	await frames(1)
