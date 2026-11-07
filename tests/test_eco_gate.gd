extends TestCase
## Терраса врат 07 (#831, часть 3): точка — как на карте слоя `LayerMap`; живая обвязка вокруг будущей арки — две
## рощи ленточника позади к северу и два веерника у сходов; середина (место арки и карман разворота) и четыре
## прохода свободны; стай у врат нет.


func test_place_from_layer_map() -> void:
	eq(EcoGate.CENTER, LayerMap.xz("07"), "середина террасы — место 07 карты слоя")
	eq(LayerMap.POINTS["07"]["key"], EcoGate.ID, "ключ места как в LayerMap")
	eq(Run.PLACES[EcoGate.ID][1], EcoGate.CENTER, "точка маршрута — на террасе")


## Обвязка у террасы, вне кармана разворота, дальше CLEAR от проходов, друг от друга ≥ 35 м; на гребне.
func test_frame_off_lanes_and_pocket() -> void:
	ok(EcoGate.POCKET >= Seabed.Layer.POCKET_R, "карман разворота у 07 свободен")
	var all := EcoGate.spots()
	eq(all.size(), 4, "две рощи и два веерника")
	for p in all:
		var d := p.distance_to(EcoGate.CENTER)
		ok(d >= EcoGate.POCKET and d < 70.0, "вокруг арки, но не на ней (%.1f м)" % d)
		for s: Array in Seabed.Layer.segments():
			ok(Seabed.Layer._seg_dist(p, s[0], s[1]) >= EcoGate.CLEAR, "%s дальше %.0f м от прохода" % [p, EcoGate.CLEAR])
		ok(Seabed.height(p.x, p.y) > Seabed.Layer.RIDGE_FLOOR - 4.0, "%s на гребне, а не в яме" % p)
		for o in all:
			if o != p:
				ok(p.distance_to(o) >= 35.0, "%s и %s не сливаются в одно пятно" % [p, o])
	for p in EcoGate.KELP:
		ok(p.y < EcoGate.CENTER.y, "роща позади арки, к северу")
		ok(EcoKelp.EXTRA.has(p), "роща врат — в рощах EcoKelp")
	ok((EcoGate.KELP[0].x - EcoGate.CENTER.x) * (EcoGate.KELP[1].x - EcoGate.CENTER.x) < 0.0, "рощи по обе стороны")
	for p in EcoGate.FANS:
		ok(EcoFan.default_spots().has(p), "веерник врат — в местах EcoFan")


## Весь живой мир (как в игре): у врат рощи и веерники на дне, стай и кустов в кармане нет.
func test_scene_frame_in_world() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var groves := 0
	for gr in view.kelp.groves:
		var c := Vector2(gr.center.x, gr.center.z)
		if c.distance_to(EcoGate.CENTER) < 70.0:
			groves += 1
			near(gr.center.y, Seabed.height(c.x, c.y), 0.5, "роща на дне")
	eq(groves, 2, "у врат — две рощи ленточника")
	var fans := 0
	for t in view.world.scan_targets():
		var p: Vector3 = t["pos"]
		var d := Vector2(p.x, p.z).distance_to(EcoGate.CENTER)
		if t["species"] == EcoFan.ID and d < 70.0:
			fans += 1
	eq(fans, 2, "у врат — два веерника")
	for sh in view.fish.shoals:
		ok(Vector2(sh.home.x, sh.home.z).distance_to(EcoGate.CENTER) > EcoGate.POCKET,
			"стая %d живёт не у врат" % sh.index)
	view.queue_free()
	await frames(1)
