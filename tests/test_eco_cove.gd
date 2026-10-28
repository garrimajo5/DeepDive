extends TestCase
## Тихая заводь 09 (#831): точка — как на карте слоя `LayerMap`; укрытия заводи (орган, станция чистки на огнецвете,
## роща ленточника) стоят по краю кармана разворота и не мешают кораблю в проходах; своей стаи у заводи нет —
## основной маршрут хищника сюда не ведёт. И сверка шести ориентиров живого мира с картой слоя.


func test_place_from_layer_map() -> void:
	eq(EcoCove.CENTER, LayerMap.xz("09"), "середина заводи — место 09 карты слоя")
	eq(LayerMap.POINTS["09"]["key"], EcoCove.ID, "ключ места как в LayerMap")
	eq(Run.PLACES[EcoCove.ID][1], EcoCove.CENTER, "точка маршрута — в заводи")


## Шесть ориентиров ART-005: точки модулей eco совпадают с картой слоя, ключи — с её ключами.
func test_landmarks_match_layer_map() -> void:
	var marks := {"01": [EcoFlower.ID, EcoFlower.CENTER], "02": [EcoVent.ID, EcoVent.CENTER],
		"03": [EcoShell.ID, EcoShell.CENTER], "04": [EcoBones.ID, EcoBones.CENTER],
		"05": [EcoWell.ID, EcoWell.CENTER], "06": [EcoDrop.ID, EcoDrop.CENTER]}
	for id: String in marks:
		eq(marks[id][0], LayerMap.POINTS[id]["key"], "ключ места %s" % id)
		eq(marks[id][1], LayerMap.xz(id), "точка места %s" % id)


## Укрытия — на краю кармана (не в круге разворота, но рядом с заводью), дальше CLEAR от проходов и друг от друга.
func test_shelters_off_lanes() -> void:
	var spots := EcoCove.spots()
	eq(spots.size(), 3, "орган, огнецвет, ленточник")
	for i in spots.size():
		var p := spots[i]
		var d := p.distance_to(EcoCove.CENTER)
		ok(d > Seabed.Layer.POCKET_R, "не в круге разворота (%.1f м)" % d)
		ok(d < 60.0, "у заводи (%.1f м)" % d)
		for s: Array in Seabed.Layer.segments():
			ok(Seabed.Layer._seg_dist(p, s[0], s[1]) >= EcoCove.CLEAR, "дальше %.0f м от прохода" % EcoCove.CLEAR)
		for j in range(i + 1, spots.size()):
			ok(p.distance_to(spots[j]) >= 35.0, "укрытия не сливаются в одно пятно")
	ok(EcoOrgan.SPOTS.has(EcoCove.ORGAN), "губка органа в заводи")
	ok(EcoCoral.BASES.has(EcoCove.CORAL), "огнецвет в заводи")
	ok(EcoKelp.EXTRA.has(EcoCove.KELP), "ленточник в заводи")


## В мире у заводи есть все три укрытия, станция чистки — на её огнецвете; роща без стаи; ничего из них не
## заходит в проходы шириной 60 м.
func test_world_shelters() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var fish := w.add(EcoFish.new()) as EcoFish
	var preds := w.add(EcoPred.new(fish)) as EcoPred
	var organs := w.add(EcoOrgan.new()) as EcoOrgan
	var coral := w.add(EcoCoral.new()) as EcoCoral
	var leech := w.add(EcoLeech.new(preds, coral)) as EcoLeech
	var kelp := w.add(EcoKelp.new(fish)) as EcoKelp
	var og: EcoOrgan.Organ = organs.organs[organs.organs.size() - 1]
	near(og.base.x, EcoCove.ORGAN.x, 1e-4)
	near(og.base.y, Seabed.height(EcoCove.ORGAN.x, EcoCove.ORGAN.y), 1e-4, "губка на дне")
	var bush: EcoCoral.Bush = coral.bushes[coral.bushes.size() - 1]
	near(bush.base.z, EcoCove.CORAL.y, 1e-4)
	var st := leech.near_station(bush.top)
	ok(st != null and st.top.distance_to(bush.top) < 0.5, "станция чистки на огнецвете заводи")
	var gr := kelp.grove_at(Vector3(EcoCove.KELP.x, 0, EcoCove.KELP.y))
	ok(gr != null, "роща ленточника в заводи")
	ok(gr != null and gr.shoal == null, "своей стаи у рощи нет")
	ok(gr != null and absf(gr.center.y - Seabed.height(EcoCove.KELP.x, EcoCove.KELP.y)) < 1e-3, "роща на дне")
	var parts: Array[Vector3] = [og.base, bush.base]
	if gr:
		for s in gr.stalks:
			parts.append(s.pos)
	for u in kelp.urchins:
		if u.grove == kelp.groves.find(gr):
			parts.append(u.pos)
	for p in parts:
		for s: Array in Seabed.Layer.segments():
			ok(Seabed.Layer._seg_dist(Vector2(p.x, p.z), s[0], s[1]) > Seabed.Layer.LANE_HALF,
				"проход свободен: (%.1f, %.1f)" % [p.x, p.z])
	# ежи пасутся и в заводи
	w.ship.pos = Vector3(EcoCove.KELP.x, -32.0, EcoCove.KELP.y)
	for i in 200:
		w.step(0.05)
	ok(gr != null and gr.cover < 1.0, "ленточник в заводи объедают")


## Основной маршрут хищника — к домам стай; ни один дом не в заводи.
func test_no_shoal_home_in_cove() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var fish := w.add(EcoFish.new()) as EcoFish
	for sh in fish.shoals:
		ok(Vector2(sh.home.x, sh.home.z).distance_to(EcoCove.CENTER) > 60.0, "стая %d живёт не в заводи" % sh.index)
