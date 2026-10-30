extends TestCase
## Сцена старта под место 00 на 30 м (#827, часть 2б): с (0, −30, 95) в первые секунды строка приборов не занята
## миром — кружевной веер дальше READ_R, стая гребневиков вне луча, ближайшая цель сканера — стая светляков,
## огнецвет дальше неё. Те же условия держатся и с прежнего старта на 20 м (Helm.Ship.START), пока его не сдвинули.

const OLD_START := Vector3(0.0, -20.0, 95.0)


func _spots() -> Array[Vector3]:
	return [LayerMap.at("00"), OLD_START]


func _world(at: Vector3) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = at
	w.ship.yaw = 0.0
	w.ship.light_on = true
	w.ship.light_range = Searchlight.BASE_RANGE
	return w


func _notes(w: EcoWorld, species: String) -> Array[String]:
	var out: Array[String] = []
	for ev in w.bus.pending:
		if ev.species == species:
			out.append(ev.note)
	return out


func test_point_00_is_30_m() -> void:
	near(LayerMap.at("00").y, -30.0, 1e-6, "место 00 — 30 м")


func test_start_fan_out_of_read_radius() -> void:
	for at in _spots():
		var w := _world(at)
		var sea := w.add(EcoCurrent.new()) as EcoCurrent
		var fan := w.add(EcoFan.new(sea)) as EcoFan
		var f: EcoFan.Fan = fan.fans[fan.fans.size() - 1]
		near(Vector2(f.pos.x, f.pos.z).distance_to(EcoFan.START), 0.0, 1e-4, "последний — веер у старта")
		ok(f.pos.distance_to(at) > EcoFan.READ_R + 1.0, "веер у старта дальше READ_R от %s: %.1f м" % [at, f.pos.distance_to(at)])
		ok(f.pos.distance_to(at) < 45.0, "но рядом — его видно из окна: %.1f м" % f.pos.distance_to(at))
		w.run(10.0)
		eq(_notes(w, EcoFan.ID), [] as Array[String], "веер молчит первые 10 с")


func test_ferns_farther_than_shoal() -> void:
	for at in _spots():
		var w := _world(at)
		var fish := w.add(EcoFish.new()) as EcoFish
		var fr := w.add(EcoFern.new(fish)) as EcoFern
		var shoal_d := fish.shoals[0].center.distance_to(at)
		for fe in fr.ferns:
			ok(fe.top.distance_to(at) > shoal_d + 1.0, "куст дальше стаи светляков от %s" % at)


func test_raduzh_not_in_beam_at_start() -> void:
	for at in _spots():
		var w := _world(at)
		w.add(EcoRaduzh.new())
		w.run(20.0)
		eq(_notes(w, EcoRaduzh.ID), [] as Array[String], "гребневики не вспыхивают в луче с %s первые 20 с" % at)


func test_raduzh_still_reachable() -> void:
	# первая стая — у старта по-прежнему: подойти и посветить недалеко
	var home: Vector2 = EcoRaduzh.HOMES[0]
	ok(home.distance_to(LayerMap.xz("00")) < 90.0, "стая гребневиков в пределах 90 м от старта")
