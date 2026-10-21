extends TestCase
## Раковина древних по концепту ART-029 (место 3 карты отмели): спираль 2,25 оборота 10 × 11 × 5 м стоит торцом
## на дне лицом к старту, утоплена на 0,4 м; трубка растёт к концу, витки касаются; разлом внешней губы открывает
## пластину колец с линией родства; гнёзда по три; матовая — светится только обрастание; один вызов отрисовки,
## бюджет ≤ 4000 треугольников, грани наружу.

const FLAT := -40.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Склон: дно падает на восток на 1 м за 5 м.
static func _slope(x: float, _z: float) -> float:
	return -40.0 - (x - 162.0) * 0.2


func _shell(ground: Callable) -> EcoShell:
	var w := EcoWorld.new()
	w.ground = ground
	return w.add(EcoShell.new()) as EcoShell


func test_place_from_map() -> void:
	var f := FileAccess.open("res://docs/concept-art/karta-otmeli-mesta.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var spot: Dictionary = {}
	for l in data["locations"]:
		if l["name"] == "Раковина древних":
			spot = l
	near(EcoShell.CENTER.x, float(spot["x"]), 1e-6, "x с карты отмели")
	near(EcoShell.CENTER.y, float(spot["z"]), 1e-6, "z с карты отмели")
	eq(EcoShell.ID, "shell", "ключ места как в Run.PLACES")
	eq(Run.PLACES[EcoShell.ID][1], EcoShell.CENTER, "точка маршрута — у раковины")


func test_size_from_concept() -> void:
	var sh := _shell(_flat)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in EcoShell.SECTIONS:
		for j in EcoShell.SIDES:
			var p := sh.surface(sh.theta[i], sh.phi(j))
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	near(hi.y - lo.y, 10.0, 0.05, "высота 10 м")
	near(hi.x - lo.x, 11.0, 0.15, "ширина 11 м")
	near(hi.z - lo.z, 5.0, 0.05, "толщина 5 м")
	near(lo.y, 0.0, 0.05, "начало — на нижней точке")


func test_spiral_grows_and_touches() -> void:
	var sh := _shell(_flat)
	eq(sh.ring.size(), EcoShell.SECTIONS * EcoShell.SIDES, "48 сечений × 12 вершин")
	near((sh.theta[EcoShell.SECTIONS - 1] - sh.theta[0]) / TAU, 2.25, 1e-5, "2,25 оборота")
	# трубка растёт: толщина конца в WIDEN^2,25 раз больше середины
	var t0 := sh.surface(sh.theta[0], PI * 0.5).z
	var t1 := sh.surface(sh.theta[EcoShell.SECTIONS - 1], PI * 0.5).z
	near(t1 / t0, pow(EcoShell.WIDEN, 2.25), 1e-3, "трубка растёт к концу")
	# соседние витки касаются (с нахлёстом): внутренняя сторона витка заходит за наружную сторону прежнего
	var th := sh.theta[EcoShell.SECTIONS - 1] - PI
	var outer_in := sh.surface(th, PI)       # внутренняя сторона внешнего витка (к оси спирали)
	var inner_out := sh.surface(th - TAU, 0.0)   # наружная сторона витка оборотом раньше
	var axis := sh.surface(-100.0, 0.0, 0.0)  # середина спирали
	ok(outer_in.distance_to(axis) < inner_out.distance_to(axis), "витки без щели")
	# конец трубки — внизу слева (лежит на дне)
	var end := sh.surface(sh.theta[EcoShell.SECTIONS - 1], 0.0, 0.0)
	ok(end.x < 0.0 and end.y < 3.5, "конец трубки внизу слева: %s" % end)


func test_on_ground_sunk() -> void:
	for g in [_flat, _slope, Seabed.height]:
		var sh := _shell(g)
		var low := sh.lowest()
		ok(low.y < float(g.call(low.x, low.z)) - 0.2, "нижняя точка в дне")
		# ни одна точка опоры не висит над дном
		for i in EcoShell.SECTIONS:
			for j in EcoShell.SIDES:
				var p := sh.to_world(sh.vertex(i, j))
				if sh.vertex(i, j).y < 0.5:
					ok(p.y <= float(g.call(p.x, p.z)) + 0.15, "опора не висит: %s" % p)
		var top := sh.top().y - float(g.call(sh.base.x, sh.base.z))
		ok(top > 7.0 and top <= EcoShell.OBSTACLE_TOP, "верх на %f м над дном" % top)
		for p in sh.ring:
			var w := sh.to_world(p)
			ok(Vector2(w.x - sh.base.x, w.z - sh.base.z).length() <= EcoShell.OBSTACLE_R, "в круге препятствия")
	var flat := _shell(_flat)
	near(flat.base.y, FLAT - EcoShell.SINK, 1e-4, "на ровном дне утоплена на 0,4 м")


func test_faces_start() -> void:
	var sh := _shell(_flat)
	var f := sh.face()
	var to := Vector2(EcoShell.FACE.x - sh.base.x, EcoShell.FACE.y - sh.base.z).normalized()
	ok(Vector2(f.x, f.z).normalized().dot(to) > 0.99, "лицо — к старту забега")
	near(f.y, 0.0, 1e-6, "стоит торцом, без наклона")
	var w := EcoWorld.new(777)
	w.ground = _flat
	var other := w.add(EcoShell.new()) as EcoShell
	eq(other.ring, sh.ring, "форма одна при любом зерне мира")


func test_broken_lip_shows_plate() -> void:
	var sh := _shell(_flat)
	ok(sh.break_to - sh.break_from >= 8, "разлом на %d рядах" % (sh.break_to - sh.break_from))
	# разлом — на внешнем витке справа
	var mid := sh.surface(section_mid(sh), 0.0, 0.0)
	ok(mid.x > 1.5, "разлом справа: %s" % mid)
	var removed := 0
	for i in EcoShell.SECTIONS - 1:
		for j in EcoShell.SIDES:
			if sh.broken(i, j):
				removed += 1
				ok(sh.in_break(i), "снято только в разломе")
				ok(sin((j + 0.5) * TAU / EcoShell.SIDES) > 0.0, "снята только передняя стенка")
	ok(removed > 20, "снято граней: %d" % removed)
	# рваный край: внешняя полоса стенки разной ширины по рядам
	var widths := {}
	for i in range(sh.break_from, sh.break_to):
		var kept := 0
		for j in EcoShell.SIDES / 2:
			if not sh.broken(i, j):
				kept += 1
		ok(kept >= 1, "внешняя полоса стенки остаётся")
		widths[kept] = true
	ok(widths.size() >= 2, "край рваный")
	# пластина — за лицом, внутри трубки, ближе к оси, чем снятая стенка
	var p := sh.plate_point(0.5, 0.0)
	var wall := sh.surface(section_mid(sh), PI * 0.5)
	ok(p.z > 0.0 and p.z < wall.z * 0.5, "пластина вдавлена: %f из %f" % [p.z, wall.z])


func section_mid(sh: EcoShell) -> float:
	return EcoShell.section_theta((sh.break_from + sh.break_to) * 0.5)


func test_nests_by_three_on_surface() -> void:
	var sh := _shell(_flat)
	eq(sh.nest_c.size(), EcoShell.NESTS.size() * 3, "гнёзда группами по три")
	for q in sh.nest_c.size():
		ok(sh.nest_n[q].z > -0.2, "гнездо не на тыльной стороне")
		ok(sh.solid(sh.to_world(sh.nest_c[q] - sh.nest_n[q] * 0.2)), "гнездо на трубке")


func test_solid_tube_and_water_around() -> void:
	var sh := _shell(_flat)
	var end := sh.theta[EcoShell.SECTIONS - 1] - 0.3
	ok(sh.solid(sh.to_world(sh.surface(end, 0.0, 0.0))), "ось трубки твёрдая")
	ok(sh.solid(sh.to_world(sh.surface(end, 1.0, 0.8))), "внутри стенки твёрдо")
	ok(not sh.solid(sh.to_world(sh.surface(end, 1.0, 1.3))), "за стенкой — вода")
	ok(not sh.solid(sh.base + Vector3(0, EcoShell.HEIGHT + 2.0, 0)), "над раковиной — вода")
	ok(not sh.solid(sh.base + sh.face() * (EcoShell.THICK * 0.5 + 1.5) + Vector3(0, 4, 0)), "перед лицом — вода")
	ok(not sh.solid(sh.base + Vector3(EcoShell.OBSTACLE_R + 3.0, 4, 0)), "сбоку — вода")


func test_matte_only_growth_glows() -> void:
	var sh := _shell(_flat)
	eq(sh.tuft_c.size(), EcoShell.TUFTS_GROOVE + EcoShell.TUFTS_LOW, "кустики обрастания")
	var low := 0
	for q in sh.tuft_c.size():
		if sh.tuft_c[q].y < EcoShell.GLOW_LOW:
			low += 1
		ok(sh.solid(sh.to_world(sh.tuft_c[q] - sh.tuft_n[q] * 0.15)), "кустик растёт на трубке")
	ok(low >= EcoShell.TUFTS_LOW, "у дна — %d кустиков" % low)
	var v := ShellView.new(sh)
	var share := float(v.glowing) / v.tris
	ok(share > 0.04 and share < 0.16, "светится только обрастание, около 10 %%: %f" % share)
	for t in v.tube_tris:
		ok(v._col[t * 3].a == 0.0, "камень трубки не светится")
	eq(float(v.mesh.surface_get_material(0).get_shader_parameter("flicker")), 0.0, "архив статичен, без мигания")
	v.free()


func test_view_one_mesh_faces_out() -> void:
	var sh := _shell(_flat)
	var v := ShellView.new(sh)
	tree.root.add_child(v)
	await frames(1)
	eq(v.mesh.get_surface_count(), 1, "один вызов отрисовки")
	ok(v.tris > 1200 and v.tris <= 4000, "треугольников в бюджете ART-029: %d" % v.tris)
	eq(v.layers, OceanView.LAYER_WORLD, "слой отмели")
	# трубка: грань смотрит наружу от оси своего ряда, обход по часовой стрелке
	var outward := 0
	for t in v.tube_tris:
		var a := v.verts[t * 3]
		var c := (a + v.verts[t * 3 + 1] + v.verts[t * 3 + 2]) / 3.0
		var cr := (v.verts[t * 3 + 1] - a).cross(v.verts[t * 3 + 2] - a)
		var i := v.tube_row[t]
		var axis := sh.surface((sh.theta[i] + sh.theta[i + 1]) * 0.5, 0.0, 0.0)
		var out := c - sh.to_world(axis)
		if cr.dot(out) < 0.0 and v.normals[t * 3].dot(out) > 0.0:
			outward += 1
	ok(outward == v.tube_tris, "лицевая сторона трубки — снаружи: %d из %d" % [outward, v.tube_tris])
	v.queue_free()
	await frames(1)


func test_in_eco_view() -> void:
	var ev := EcoView.new()
	ev.ground = _flat
	ok(ev.shell != null and ev.shell_view != null, "раковина в живом мире")
	near(ev.shell.base.y, FLAT - EcoShell.SINK, 1e-4, "встала на дно мира")
	ev.free()
