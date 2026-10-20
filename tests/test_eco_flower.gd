extends TestCase
## Каменный цветок (js/world.js, место 1 карты отмели): место с карты, коралл 28 м стоит на дне, крона не задевает
## логово стеклоуста и огнецвет, ветвление как в браузере, кончики мерцают, меш — один вызов отрисовки, грани наружу.

const FLAT := -40.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _flower(ground: Callable) -> EcoFlower:
	var w := EcoWorld.new()
	w.ground = ground
	return w.add(EcoFlower.new()) as EcoFlower


func test_place_from_map() -> void:
	var f := FileAccess.open("res://docs/concept-art/karta-otmeli-mesta.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var spot: Dictionary = {}
	for l in data["locations"]:
		if l["name"] == "Каменный цветок":
			spot = l
	near(EcoFlower.CENTER.x, float(spot["x"]), 1e-6, "x с карты отмели")
	near(EcoFlower.CENTER.y, float(spot["z"]), 1e-6, "z с карты отмели")
	eq(EcoFlower.ID, "flower", "ключ места как в Run.PLACES")
	eq(Run.PLACES[EcoFlower.ID][1], EcoFlower.CENTER, "точка маршрута — у цветка")


func test_giant_on_ground() -> void:
	var fl := _flower(Seabed.height)
	var y0 := Seabed.height(EcoFlower.CENTER.x, EcoFlower.CENTER.y)
	near(fl.base.y, y0, 1e-4, "подножие на дне")
	near(fl.top().y - y0, EcoFlower.HEIGHT, 1e-3, "высота 28 м — девятиэтажный дом")
	var trunk := fl.branches[0]
	eq(trunk.depth, 0, "первая ветвь — ствол")
	ok(trunk.p0.y < y0, "ствол уходит в дно")
	ok(trunk.r0 > 1.2 and trunk.r0 < 2.5, "ствол толщиной около 3,4 м: r = %f" % trunk.r0)
	for b in fl.branches:
		ok(Vector2(b.p1.x - fl.base.x, b.p1.z - fl.base.z).length() <= EcoFlower.SPREAD + 1e-3, "крона не шире 11 м")
		ok(b.p1.y > y0, "ветви над дном")
	for i in fl.tips.size():
		ok(Vector2(fl.tips[i].x - fl.base.x, fl.tips[i].z - fl.base.z).length() + fl.tip_r[i] <= EcoFlower.SPREAD + 1e-3,
			"кончик в кроне")
	# соседи: логово стеклоуста (62; −45) и огнецвет (54,88; −68,69) — дальше кроны
	for xz in [EcoEel.LAIRS[2], EcoCoral.BASES[2]]:
		ok(Vector2(xz.x - fl.base.x, xz.y - fl.base.z).length() > EcoFlower.SPREAD + 6.0, "сосед %s не в кроне" % xz)


func test_branching_like_browser() -> void:
	var fl := _flower(_flat)
	var by_depth := [0, 0, 0, 0, 0]
	for b in fl.branches:
		by_depth[b.depth] += 1
		ok(b.r1 < b.r0, "ветвь сужается")
	eq(by_depth[0], 1, "один ствол")
	for d in range(1, 5):
		ok(by_depth[d] >= by_depth[d - 1] * 2 and by_depth[d] <= by_depth[d - 1] * 3, "ярус %d делится на 2–3" % d)
	eq(fl.tips.size(), by_depth[4], "кончики — на концах последнего яруса")
	ok(fl.tips.size() >= 16, "кончиков много: %d" % fl.tips.size())
	# форма своя — не зависит от зерна мира
	var w := EcoWorld.new(777)
	w.ground = _flat
	var other := w.add(EcoFlower.new()) as EcoFlower
	eq(other.tips, fl.tips, "форма одна при любом зерне мира")


func test_solid_trunk_and_water_around() -> void:
	var fl := _flower(_flat)
	ok(fl.solid(fl.base + Vector3(0, 2, 0)), "ствол твёрдый")
	ok(fl.solid(fl.tips[0]), "кончик твёрдый")
	ok(not fl.solid(fl.base + Vector3(0, EcoFlower.HEIGHT + 3.0, 0)), "над цветком — вода")
	ok(not fl.solid(fl.base + Vector3(EcoFlower.SPREAD + 3.0, 10, 0)), "сбоку за кроной — вода")
	ok(not fl.solid(fl.base + Vector3(6, 0.5, 0)), "у подножия в 6 м — вода")


func test_tips_shimmer_wave() -> void:
	var fl := _flower(_flat)
	var lo := 1.0
	var hi := 0.0
	for k in 80:
		var g := EcoFlower.glow(fl.tip_phase[0], k * 0.1)
		lo = minf(lo, g)
		hi = maxf(hi, g)
	ok(lo > 0.5, "кончик не гаснет: %f" % lo)
	ok(hi - lo > 0.3, "мерцает: %f…%f" % [lo, hi])
	# волна вверх: у верхних кончиков фаза отстаёт
	var top_i := 0
	var low_i := 0
	for i in fl.tips.size():
		if fl.tips[i].y > fl.tips[top_i].y:
			top_i = i
		if fl.tips[i].y < fl.tips[low_i].y:
			low_i = i
	ok(fl.tip_phase[top_i] < fl.tip_phase[low_i], "волна идёт снизу вверх")


func test_view_one_mesh_faces_out() -> void:
	var fl := _flower(_flat)
	var v := FlowerView.new(fl)
	tree.root.add_child(v)
	await frames(1)
	eq(v.mesh.get_surface_count(), 1, "один вызов отрисовки")
	ok(v.tris > 1000 and v.tris < 12000, "треугольников в бюджете: %d" % v.tris)
	eq(v.layers, OceanView.LAYER_WORLD, "слой отмели")
	# грань смотрит наружу от оси своей ветви: проверим ствол (ниже его верха ветвей нет)
	var trunk_top := fl.branches[0].p1.y - 1.0
	var outward := 0
	var total := 0
	for i in range(0, v.verts.size(), 3):
		var c := (v.verts[i] + v.verts[i + 1] + v.verts[i + 2]) / 3.0
		if c.y < trunk_top:
			total += 1
			var cr := (v.verts[i + 1] - v.verts[i]).cross(v.verts[i + 2] - v.verts[i])
			var out := Vector3(c.x - fl.base.x, 0, c.z - fl.base.z)
			if cr.dot(out) < 0.0 and v.normals[i].dot(out) > 0.0:
				outward += 1
	ok(total > 0, "у ствола есть грани")
	eq(outward, total, "лицевая сторона ствола — снаружи (обход по часовой)")
	v.queue_free()
	await frames(1)


func test_in_eco_view() -> void:
	var ev := EcoView.new()
	ev.ground = _flat
	ok(ev.flower != null and ev.flower_view != null, "цветок в живом мире")
	near(ev.flower.base.y, FLAT, 1e-4, "встал на дно мира")
	ev.free()
