extends TestCase
## Граница у Спуска 10 (#832, часть 3): кварцевая корка на дне котловины склона — западнее волнистой границы её нет,
## к востоку гуще, крупнее и светлее; друзы ниже корабля у 10; не вид мира — ни целей сонара, ни сканера; вид — один
## меш общим шейдером камня, рамка вокруг 10.


func _brink() -> EcoBrink:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	return w.add(EcoBrink.new()) as EcoBrink


func test_place_is_10() -> void:
	eq(EcoBrink.CENTER, LayerMap.xz("10"), "середина — место 10 карты слоя")
	ok(EcoBrink.CENTER.x > EcoBrink.BORDER_X + EcoBrink.WAVE, "10 — уже за границей корки")
	ok(EcoBrink.share(EcoBrink.CENTER.x, EcoBrink.CENTER.y) > 0.3, "у 10 корка заметна")


func test_border_wavy_and_share_grows_east() -> void:
	var lo := 1e9
	var hi := -1e9
	for i in 60:
		var z := 110.0 + i * 3.0
		var b := EcoBrink.border_x(z)
		lo = minf(lo, b)
		hi = maxf(hi, b)
		near(EcoBrink.share(b - 1.0, z), 0.0, 1e-6, "западнее границы корки нет (z %.0f)" % z)
		var prev := -1.0
		for x in range(int(b), int(b + EcoBrink.FULL) + 10, 5):
			var s := EcoBrink.share(float(x), z)
			ok(s >= prev, "к востоку корка не редеет (x %d, z %.0f)" % [x, z])
			prev = s
		near(EcoBrink.share(b + EcoBrink.FULL + 1.0, z), 1.0, 1e-6, "за FULL — полная корка")
	ok(hi - lo > 4.0, "граница волнистая, не по линейке")
	ok(lo >= EcoBrink.BORDER_X - EcoBrink.WAVE and hi <= EcoBrink.BORDER_X + EcoBrink.WAVE, "волна в ± WAVE")
	ok(EcoBrink.glow(1.0) > EcoBrink.glow(0.0) * 3.0, "свет к востоку сильнее")


func test_druses_in_basin_east_of_border() -> void:
	var b := _brink()
	ok(b.druses.size() > 60 and b.druses.size() < EcoBrink.MAX, "друз %d — заметно, до предела" % b.druses.size())
	eq(b.shares.size(), b.druses.size(), "доля на каждую друзу")
	for i in b.druses.size():
		var d := b.druses[i]
		ok(d.x > EcoBrink.border_x(d.z), "друза %d за границей" % i)
		ok(Seabed.Slope.mask(d.x, d.z) >= EcoBrink.MASK, "друза %d на дне котловины, не на стене" % i)
		near(d.y, Seabed.height(d.x, d.z), 1e-3, "друза %d стоит на дне" % i)
		ok(d.x > 430.0 or absf(d.z - Seabed.Slope.GAP_Z) > 30.0, "друза %d не в проходе 60 м" % i)


## Плотность и размер растут к востоку: в восточной полосе друз больше и они крупнее, чем у границы.
func test_denser_and_bigger_east() -> void:
	var b := _brink()
	var west := []
	var east := []
	for d in b.druses:
		if d.x < EcoBrink.BORDER_X + 30.0:
			west.append(d.w)
		elif d.x > EcoBrink.BORDER_X + EcoBrink.FULL:
			east.append(d.w)
	ok(east.size() > west.size() * 2, "к востоку гуще: %d против %d" % [east.size(), west.size()])
	var avg := func(a: Array) -> float:
		var s := 0.0
		for v: float in a:
			s += v
		return s / maxf(a.size(), 1.0)
	ok(avg.call(east) > avg.call(west) * 1.3, "к востоку крупнее")


## Друзы ниже корабля: верх не выше MAX_H над дном, у оси подхода — ниже AXIS_H; у 10 корабль на 290 м проходит над
## коркой с запасом своего зазора над дном.
func test_druses_stay_low() -> void:
	var b := _brink()
	var ship_y := -float(LayerMap.POINTS["10"]["depth"])
	for i in b.druses.size():
		var d := b.druses[i]
		var top := EcoBrink.top_of(d.w)
		ok(top <= EcoBrink.MAX_H + 1e-4, "друза %d ниже MAX_H" % i)
		if EcoBrink.on_axis(d.x, d.z):
			ok(top <= EcoBrink.AXIS_H + 1e-4, "друза %d у оси подхода ниже AXIS_H" % i)
		if Vector2(d.x, d.z).distance_to(EcoBrink.CENTER) < 30.0:
			ok(d.y + top < ship_y - Helm.Ship.CLEARANCE, "друза %d у 10 ниже корабля" % i)


func test_layout_stable_and_not_a_target() -> void:
	var a := _brink()
	var b := _brink()
	eq(a.druses, b.druses, "расклад свой, одинаковый при каждом сбросе")
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.add(EcoBrink.new())
	eq(w.scan_targets().size(), 0, "корка — не цель сонара и сканера")


func test_view_one_mesh_glowing_tips() -> void:
	var b := _brink()
	var v := BrinkView.new(b)
	ok(v.mesh != null and v.mesh.get_surface_count() == 1, "один меш, одна поверхность")
	ok(v.tris > b.druses.size() * 3 * 18 - 1 and v.tris < 30000, "треугольников %d — в пределах" % v.tris)
	ok(v.glowing > 0 and v.glowing < v.verts.size() / 2, "светятся только кончики")
	var mat := v.mesh.surface_get_material(0) as ShaderMaterial
	eq(mat.shader.code, EcoShaders.STONE, "общий шейдер камня — нового шейдера нет")
	eq(v.layers, OceanView.LAYER_WORLD, "слой отмели")
	ok(v.custom_aabb.has_point(Vector3(EcoBrink.CENTER.x, Seabed.height(560.0, 200.0), EcoBrink.CENTER.y)),
		"рамка вокруг 10")
	ok(not v.custom_aabb.has_point(Vector3(0.0, -40.0, 95.0)), "у старта не рисуется")
	# лицевые стороны наружу: нормаль кончика смотрит от оси кристалла вверх/вбок, не вниз
	var down := 0
	for i in range(0, v.normals.size(), 3):
		if v.normals[i].y < -0.7:
			down += 1
	ok(down < v.tris / 20, "грани не смотрят вниз (обход по часовой стрелке)")
	v.free()


func test_scene_has_brink() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	ok(main.eco.brink != null and main.eco.brink.druses.size() > 60, "корка в мире сцены")
	ok(main.eco.brink_view != null and main.eco.brink_view.is_inside_tree(), "вид корки в сцене")
	main.queue_free()
	await frames(1)


## Б6: на «Экономно» в друзе не больше трёх кристаллов по четыре грани — треугольников вдвое меньше, меш один,
## корни и рамка те же, кончики светятся; сброс мира уровень не теряет, назад — полная корка.
func test_view_lite_fewer_crystals_and_faces() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var bv := view.brink_view
	var full := bv.tris
	var frame := bv.custom_aabb
	view.set_lite(true)
	ok(bv.lite, "корка — на «Экономно»")
	ok(bv.tris * 2 <= full, "треугольников вдвое меньше: %d из %d" % [bv.tris, full])
	eq(bv.mesh.get_faces().size() / 3, bv.tris, "меш пересобран")
	eq(bv.mesh.get_surface_count(), 1, "одна поверхность — вызов тот же")
	ok(bv.glowing > 0, "кончики светятся")
	ok(bv.custom_aabb.is_equal_approx(frame), "рамка та же")
	view.ground = Seabed.height   # сброс мира — вид пересобирается
	bv = view.brink_view
	ok(bv.lite and bv.tris * 2 <= full, "сброс мира — снова «Экономно»")
	view.set_lite(false)
	eq(bv.tris, full, "назад — полная корка")
	view.queue_free()
	await frames(1)


## Б6: на «Экономно» кристаллы стоят там же — первый кристалл каждой друзы тот же, что в полной корке.
func test_view_lite_keeps_layout() -> void:
	var b := _brink()
	var a := BrinkView.new(b)
	var l := BrinkView.new(b, true)
	# первый кристалл первой друзы — первые 3 · SIDES (полная) и 3 · LITE_SIDES (лёгкая) треугольников; кончик — общий
	var tip_full := a.verts[(3 * BrinkView.SIDES - 1) * 3 + 2]
	var tip_lite := l.verts[(3 * BrinkView.LITE_SIDES - 1) * 3 + 2]
	ok(tip_full.distance_to(tip_lite) < 1e-4, "кончик первого кристалла на месте")
	a.free()
	l.free()
