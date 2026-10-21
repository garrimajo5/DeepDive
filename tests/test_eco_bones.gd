extends TestCase
## Кости левиафана по концепту ART-030 (место 4 карты отмели): 8 пар рёбер, клетка 26 м, наружная ширина 18 м,
## высота 9 м; чистый проход 14 × 7 м по всей длине клетки и свободные подходы ≥ 32 м с обоих торцов; ось —
## к Каменному цветку; череп сбоку ≥ 12 м от оси; хвост вбок; матовая кость, светится только обрастание;
## один вызов отрисовки, ≤ 6000 треугольников, грани наружу.

const FLAT := -46.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _bones(ground: Callable) -> EcoBones:
	var w := EcoWorld.new()
	w.ground = ground
	return w.add(EcoBones.new()) as EcoBones


func test_place_from_map() -> void:
	var f := FileAccess.open("res://docs/concept-art/karta-otmeli-mesta.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var spot: Dictionary = {}
	var flower: Dictionary = {}
	for l in data["locations"]:
		if l["name"] == "Кости левиафана":
			spot = l
		if l["name"] == "Каменный цветок":
			flower = l
	near(EcoBones.CENTER.x, float(spot["x"]), 1e-6, "x с карты отмели")
	near(EcoBones.CENTER.y, float(spot["z"]), 1e-6, "z с карты отмели")
	eq(EcoBones.ID, "bones", "ключ места как в Run.PLACES")
	eq(Run.PLACES[EcoBones.ID][1], EcoBones.CENTER, "точка маршрута — у костей")
	eq(EcoBones.FROM, Vector2(float(flower["x"]), float(flower["z"])), "ось — к Каменному цветку")
	var b := _bones(_flat)
	var to := (EcoBones.FROM - EcoBones.CENTER).normalized()
	ok(Vector2(b.axis().x, b.axis().z).dot(to) > 0.999, "клетка смотрит головой на цветок")
	var w := EcoWorld.new(777)
	w.ground = _flat
	var other := w.add(EcoBones.new()) as EcoBones
	eq(other.rib_pts, b.rib_pts, "форма одна при любом зерне мира")


func test_size_from_concept() -> void:
	for g in [_flat, Seabed.height]:
		var b := _bones(g)
		eq(b.rib_pts.size(), EcoBones.PAIRS * 2 * EcoBones.rib_points(), "8 пар рёбер")
		near(b.rib_z[EcoBones.PAIRS - 1] - b.rib_z[0], 26.0, 1e-4, "клетка 26 м")
		var wmax := 0.0
		for r in EcoBones.PAIRS * 2:
			for i in EcoBones.rib_points():
				wmax = maxf(wmax, absf(b.rib_point(r, i).x) + b.rib_radius(r, i))
			var crest := b.rib_point(r, EcoBones.rib_points() - 1)
			var h := crest.y + b.rib_radius(r, EcoBones.rib_points() - 1) - b.rib_floor[r / 2]
			ok(h > 8.5 and h < 9.5, "верх ребра на %f м над низом прохода" % h)
			near(crest.x, 0.0, 1e-4, "пара сходится под хребтом")
		ok(wmax > 17.5 * 0.5 and wmax < 19.5 * 0.5, "наружная ширина %f м" % (wmax * 2.0))
		# вся длина 44 м: от конца хвоста до кончика носа
		var lo := INF
		for v in b.vert_c:
			lo = minf(lo, v.z)
		var hi := b.skull_point(1.0, 0.0, 0.0).z
		ok(hi - lo > 41.0 and hi - lo < 47.0, "длина вдоль оси %f м" % (hi - lo))


func test_feet_in_ground() -> void:
	for g in [_flat, Seabed.height]:
		var b := _bones(g)
		for r in EcoBones.PAIRS * 2:
			var foot := b.to_world(b.rib_point(r, 0))
			ok(foot.y < float(g.call(foot.x, foot.z)) - 0.3, "нога ребра %d в дне" % r)
		var tail := b.to_world(b.vert_c[b.vert_c.size() - 1])
		ok(tail.y < float(g.call(tail.x, tail.z)) + 0.3, "конец хвоста лежит на дне")
		var s := b.skull.origin
		var low := b.to_world(s - Vector3(0, EcoBones.SKULL_H * 0.5, 0))
		ok(low.y < float(g.call(low.x, low.z)), "череп утоплен в дно")


## Точки прямоугольника прохода |x| ≤ 7 от низа low до low + 7 на длине z (локально): ни одной кости.
func _clear(b: EcoBones, z: float, low: float) -> int:
	var hit := 0
	for xi in 15:
		var x := lerpf(-EcoBones.PASS_W * 0.5, EcoBones.PASS_W * 0.5, xi / 14.0)
		for yi in 15:
			var y := low + EcoBones.PASS_H * yi / 14.0
			if b.solid(b.to_world(Vector3(x, y, z))):
				hit += 1
	return hit


func test_passage_14x7_clear() -> void:
	for g in [_flat, Seabed.height]:
		var b := _bones(g)
		var hits := 0
		var z := b.rib_z[0] - EcoBones.LEAN - 1.0
		while z <= b.rib_z[EcoBones.PAIRS - 1] + 1.0:
			hits += _clear(b, z, b.pass_floor(z))
			z += 0.25
		eq(hits, 0, "проход 14 × 7 м в клетке чист")
		# низ прохода не ниже дна поперёк полосы — прямоугольник стоит на дне, а не в нём
		for k in EcoBones.PAIRS:
			near(b.rib_floor[k], b.strip_floor(b.rib_z[k]), 1e-4, "низ прохода у пары %d — по дну" % k)


func test_approaches_32m_clear() -> void:
	for g in [_flat, Seabed.height]:
		var b := _bones(g)
		var hits := 0
		for e in 2:
			var z0 := b.rib_z[0] - 1.0 if e == 0 else b.rib_z[EcoBones.PAIRS - 1] + 1.0
			for q in 129:
				var z := z0 + (-1.0 if e == 0 else 1.0) * q * 0.25
				hits += _clear(b, z, b.strip_floor(z))
		eq(hits, 0, "подходы по 32 м с торцов свободны (хвост и череп — вбок)")


func test_skull_aside() -> void:
	var b := _bones(Seabed.height)
	var s := b.skull.origin
	ok(absf(s.x) >= 12.0, "череп в %f м от оси" % absf(s.x))
	ok(s.z > b.rib_z[EcoBones.PAIRS - 1], "череп у головного торца")
	# размеры оболочки ≈ 8 × 6 × 5
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in EcoBones.SKULL_RINGS:
		for j in EcoBones.SKULL_SIDES:
			var p := b.skull.affine_inverse() * b.skull_point(EcoBones.skull_u(i), TAU * j / EcoBones.SKULL_SIDES)
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	near(hi.x - lo.x, 8.0, 0.05, "длина черепа 8 м")
	near(hi.z - lo.z, 6.0, 0.3, "ширина 6 м")
	near(hi.y - lo.y, 5.0, 0.3, "высота 5 м")
	var windows := 0
	for i in EcoBones.SKULL_RINGS - 1:
		for j in EcoBones.SKULL_SIDES:
			if EcoBones.window(i, j):
				windows += 1
	ok(EcoBones.WINDOWS.size() >= 4 and EcoBones.WINDOWS.size() <= 6, "4–6 окон")
	ok(windows > 10, "окна вырезаны: %d клеток" % windows)
	ok(b.solid(b.to_world(s)), "череп твёрдый")
	ok(b.solid(b.to_world(b.jaw[4])), "челюсть твёрдая")


func test_solid_bones_and_water() -> void:
	var b := _bones(Seabed.height)
	ok(b.solid(b.to_world(b.rib_point(3, 4))), "ребро твёрдое")
	ok(b.solid(b.to_world(b.vert_c[5])), "позвонок твёрдый")
	ok(b.solid(b.to_world(b.vert_c[EcoBones.SPINE_N + 3])), "хвост твёрдый")
	ok(not b.solid(b.to_world(Vector3(0, b.pass_floor(0.0) + 3.5, 0))), "в середине клетки — вода")
	ok(not b.solid(b.to_world(Vector3(0, b.pass_floor(0.0) + 14.0, 0))), "над хребтом — вода")
	ok(not b.solid(b.to_world(Vector3(-14.0, b.pass_floor(0.0) + 3.0, 0))), "сбоку — вода")
	ok(not b.solid(b.base + Vector3(EcoBones.OBSTACLE_R + 5.0, -40, 0)), "далеко — вода")


func test_matte_only_growth_glows() -> void:
	var b := _bones(Seabed.height)
	eq(b.tuft_c.size(), EcoBones.PAIRS * 2 * EcoBones.TUFTS_RIB + ceili(float(b.vert_c.size()) / EcoBones.TUFT_EVERY)
		+ EcoBones.TUFTS_SKULL, "кустики обрастания")
	for q in b.tuft_c.size():
		ok(b.solid(b.to_world(b.tuft_c[q] - b.tuft_n[q] * 0.12)), "кустик %d растёт на кости" % q)
	var v := BonesView.new(b)
	var share := float(v.glowing) / v.tris
	ok(share > 0.03 and share < 0.12, "светится только обрастание: %f" % share)
	for t in v.rib_tris:
		ok(v._col[t * 3].a == 0.0, "кость не светится")
	eq(float(v.mesh.surface_get_material(0).get_shader_parameter("flicker")), 0.0, "скелет статичен, без мигания")
	v.free()


func test_view_one_mesh_faces_out() -> void:
	var b := _bones(Seabed.height)
	var v := BonesView.new(b)
	tree.root.add_child(v)
	await frames(1)
	eq(v.mesh.get_surface_count(), 1, "один вызов отрисовки")
	ok(v.tris > 3000 and v.tris <= 6000, "треугольников в бюджете ART-030: %d" % v.tris)
	ok(v.rib_tris <= EcoBones.PAIRS * 2 * 110, "рёбра ≈ 96 треуг.: %d" % v.rib_tris)
	ok(v.skull_tris <= 1200, "череп ≤ 1200: %d" % v.skull_tris)
	eq(v.layers, OceanView.LAYER_WORLD, "слой отмели")
	# рёбра: грань смотрит наружу от осевой линии, обход по часовой стрелке
	var outward := 0
	var n := EcoBones.rib_points()
	var per_rib := v.rib_tris / (EcoBones.PAIRS * 2)
	eq(per_rib * EcoBones.PAIRS * 2, v.rib_tris, "у каждого ребра поровну граней")
	for t in v.rib_tris:
		var a := v.verts[t * 3]
		var c := (a + v.verts[t * 3 + 1] + v.verts[t * 3 + 2]) / 3.0
		var lc := b.to_local(c)
		var best := INF
		var axis := Vector3.ZERO
		var r := t / per_rib
		if true:
			for i in n - 1:
				var p0 := b.rib_point(r, i)
				var p1 := b.rib_point(r, i + 1)
				var d := EcoBones.seg_dist(lc, p0, p1)
				if d < best:
					best = d
					var ab := p1 - p0
					axis = p0 + ab * clampf((lc - p0).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var out := c - b.to_world(axis)
		if t % per_rib >= (n - 1) * EcoBones.RIB_SIDES * 2:
			# торец у хребта — наружу вдоль ребра
			out = b.basis * (b.rib_point(r, n - 1) - b.rib_point(r, n - 2))
		var cr := (v.verts[t * 3 + 1] - a).cross(v.verts[t * 3 + 2] - a)
		if cr.dot(out) < 0.0 and v.normals[t * 3].dot(out) > 0.0:
			outward += 1
	ok(outward == v.rib_tris, "лицевая сторона рёбер — снаружи: %d из %d" % [outward, v.rib_tris])
	v.queue_free()
	await frames(1)


func test_in_eco_view() -> void:
	var ev := EcoView.new()
	ev.ground = Seabed.height
	ok(ev.bones != null and ev.bones_view != null, "кости в живом мире")
	ok(ev.bones_view.tris > 0, "меш собран по дну мира")
	ev.free()


## «Рёбра обросли мхом» (ART-030): шесть пятен светящегося мха у ног рёбер, по дну, свои у костей — пятна рифа
## (еда скребунов) не меняются; в сцене — свой меш мха, один вызов отрисовки.
func test_moss_at_rib_feet() -> void:
	var b := _bones(Seabed.height)
	ok(b.moss != null, "у костей свой мох")
	eq(b.moss.patches.size(), EcoBones.MOSS_PAIRS.size(), "шесть пятен")
	var sides := [0, 0]
	for i in b.moss.patches.size():
		var p := b.moss.patches[i]
		var k := EcoBones.MOSS_PAIRS[i]
		var foot := b.to_world(b.rib_point(k * 2 + i % 2, 0))
		near(Vector2(p.pos.x - foot.x, p.pos.z - foot.z).length(), EcoBones.MOSS_IN, 0.15, "пятно у ноги ребра %d" % k)
		near(p.pos.y, Seabed.height(p.pos.x, p.pos.z), 1e-3, "пятно на дне")
		var q := b.to_local(p.pos)
		ok(absf(q.x) < EcoBones.HALF_W and absf(q.x) > EcoBones.PASS_W * 0.5 - EcoMoss.RADIUS, "заходит в проход от ноги")
		sides[0 if q.x < 0.0 else 1] += 1
		ok(p.food >= 0.6 and p.glow() > 0.6, "мох светится")
	eq(sides, [3, 3], "по три пятна с каждой стороны")
	var ev := EcoView.new()
	ev.ground = Seabed.height
	eq(ev.moss.patches.size(), 22, "пятна рифа — прежние 22, скребуны их не делят с костями")
	var mv := ev.bones_view.moss_view
	ok(mv != null and mv.get_parent() == ev.bones_view, "мох на костях — в сцене")
	eq(mv.look.verts.size(), EcoBones.MOSS_PAIRS.size() * EcoMossLook.VERTS_PER_PATCH, "один меш на все пятна")
	eq(mv.layers, OceanView.LAYER_WORLD, "слой отмели")
	ev.free()
