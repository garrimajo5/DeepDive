extends TestCase
## Терраса врат 07 (#831, часть 3): точка — как на карте слоя `LayerMap`; живая обвязка вокруг будущей арки — две
## рощи ленточника позади к северу и два веерника у сходов; середина (место арки и карман разворота) и четыре
## прохода свободны; стай у врат нет.


func test_place_from_layer_map() -> void:
	eq(EcoGate.CENTER, LayerMap.xz("07"), "середина террасы — место 07 карты слоя")
	eq(LayerMap.POINTS["07"]["key"], EcoGate.ID, "ключ места как в LayerMap")
	eq(Run.PLACES[EcoGate.ID][1], EcoGate.CENTER, "точка маршрута — на террасе")


## Обвязка у террасы, вне кармана разворота, дальше CLEAR от проходов, друг от друга ≥ 35 м; на гребне. Жёлоб
## под аркой MOD-023 (#1757): каждое растение в полосе STRIP по |dx| и |dz| ≤ STRIP_DZ, всем объёмом — за склонами
## жёлоба, край на гребне; рощи и веерники — на прежней стороне от оси.
func test_frame_off_lanes_and_pocket() -> void:
	ok(EcoGate.POCKET >= Seabed.Layer.POCKET_R, "карман разворота у 07 свободен")
	ok(EcoGate.KELP_REACH >= EcoKelp.KELP_R + EcoKelp.H_MAX * sin(EcoKelp.TILT), "объём рощи — круг лент и наклон")
	ok(EcoGate.FAN_REACH >= EcoFan.WIDTH * 0.5, "объём веерника — полширины")
	var all := EcoGate.spots()
	eq(all.size(), 4, "две рощи и два веерника")
	var edge := EcoGate.TROUGH_HALF + EcoGate.TROUGH_SLOPE
	for p in all:
		var reach := EcoGate.KELP_REACH if EcoGate.KELP.has(p) else EcoGate.FAN_REACH
		var o := p - EcoGate.CENTER
		ok(o.length() >= EcoGate.POCKET, "вне кармана у арки (%.1f м)" % o.length())
		ok(absf(o.x) >= EcoGate.STRIP.x and absf(o.x) <= EcoGate.STRIP.y and absf(o.y) <= EcoGate.STRIP_DZ,
			"%s в полосе рамки (dx %.0f, dz %.0f)" % [p, o.x, o.y])
		ok(absf(o.x) - reach >= edge, "%s всем объёмом за склоном жёлоба (%.1f ≥ %.0f м)" % [p, absf(o.x) - reach, edge])
		for s: Array in Seabed.Layer.segments():
			ok(Seabed.Layer._seg_dist(p, s[0], s[1]) >= EcoGate.CLEAR, "%s дальше %.0f м от прохода" % [p, EcoGate.CLEAR])
		ok(Seabed.height(p.x, p.y) > Seabed.Layer.RIDGE_FLOOR - 4.0, "%s на гребне, а не в яме" % p)
		for i in 16:
			var q := p + Vector2.from_angle(TAU * i / 16.0) * reach
			ok(Seabed.mesh_height(q.x, q.y) > Seabed.Layer.RIDGE_FLOOR - 4.0, "%s край на гребне (%s)" % [p, q])
		for o2 in all:
			if o2 != p:
				ok(p.distance_to(o2) >= 35.0, "%s и %s не сливаются в одно пятно" % [p, o2])
	for p in EcoGate.KELP:
		ok(p.y < EcoGate.CENTER.y, "роща к северу от оси")
		ok(EcoKelp.EXTRA.has(p), "роща врат — в рощах EcoKelp")
	ok((EcoGate.KELP[0].x - EcoGate.CENTER.x) * (EcoGate.KELP[1].x - EcoGate.CENTER.x) < 0.0, "рощи по обе стороны")
	ok((EcoGate.FANS[0].x - EcoGate.CENTER.x) * (EcoGate.FANS[1].x - EcoGate.CENTER.x) < 0.0, "веерники по обе стороны")
	ok(EcoGate.KELP[0].x < EcoGate.CENTER.x and EcoGate.FANS[0].x < EcoGate.CENTER.x, "западные — как были, на западе")
	for p in EcoGate.FANS:
		ok(EcoFan.default_spots().has(p), "веерник врат — в местах EcoFan")


## Купольник (#837) ходит из ниши к гнезду: роща не на его пути и не в нише, веерник — не в нише.
func test_frame_clear_of_dome() -> void:
	var home := EcoGate.CENTER + EcoDome.HOME_OFF
	var nest: Vector2 = EcoGate.CENTER + GateDiag.NESTS[EcoDome.NEST]["at"] + Vector2(0.0, EcoDome.FRONT)
	for p in EcoGate.KELP:
		var d := Seabed.Layer._seg_dist(p, home, nest)
		print("  роща %s: до пути купольника %.1f м" % [p, d])
		ok(d - EcoGate.KELP_REACH >= 5.0, "роща %s не на пути купольника" % p)
	for p in EcoGate.FANS:
		ok(p.distance_to(home) - EcoGate.FAN_REACH >= 10.0, "веерник %s не в нише купольника" % p)


## Весь живой мир (как в игре): у врат (до края полос рамки) — две рощи на дне и два веерника; стай у врат нет.
func test_scene_frame_in_world() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var groves := 0
	for gr in view.kelp.groves:
		var c := Vector2(gr.center.x, gr.center.z)
		if _in_frame(c):
			groves += 1
			near(gr.center.y, Seabed.height(c.x, c.y), 0.5, "роща на дне")
	eq(groves, 2, "у врат — две рощи ленточника")
	var fans := 0
	for t in view.world.scan_targets():
		var p: Vector3 = t["pos"]
		if t["species"] == EcoFan.ID and _in_frame(Vector2(p.x, p.z)):
			fans += 1
	eq(fans, 2, "у врат — два веерника")
	for sh in view.fish.shoals:
		ok(Vector2(sh.home.x, sh.home.z).distance_to(EcoGate.CENTER) > EcoGate.POCKET,
			"стая %d живёт не у врат" % sh.index)
	view.queue_free()
	await frames(1)


## У террасы в полосах рамки или ближе (|dx| ≤ STRIP.y, |dz| ≤ STRIP_DZ от середины).
func _in_frame(p: Vector2) -> bool:
	var o := p - EcoGate.CENTER
	return absf(o.x) <= EcoGate.STRIP.y and absf(o.y) <= EcoGate.STRIP_DZ
