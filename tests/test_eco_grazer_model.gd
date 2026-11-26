extends TestCase
## Скребун — модель MOD-024 в сцене (#2107, заказ #2120, приёмка PR #2123; `models/skrebun.glb`): разметка вершин
## EcoGrazerModel (шесть лап по двум тройкам, скребок, тело), меш GrazerView — из модели, поза в шейдере совпадает
## с EcoGrazerModel.posed; на «Экономно» — процедурная форма (GrazerView.build_mesh lite) с той же разметкой в NORMAL.


func test_model_markup() -> void:
	eq(EcoGrazerModel.tris_n, 1119, "треугольников — как в notes MOD-024")
	eq(EcoGrazerModel.rest.size(), 958, "вершин")
	eq(EcoGrazerModel.part.size(), EcoGrazerModel.rest.size(), "разметка на каждую вершину")
	eq(EcoGrazerModel.hips.size(), 6, "шесть бёдер")
	ok(EcoGrazerModel.skin != null, "карта цвета — в шейдер")
	var legs := [0, 0, 0, 0, 0, 0]
	var scraper := 0
	var body := 0
	var min_y := INF
	var max_y := -INF
	var max_x := 0.0
	var max_z := 0.0
	for i in EcoGrazerModel.rest.size():
		var pt: int = EcoGrazerModel.part[i]
		var p: Vector3 = EcoGrazerModel.rest[i]
		if pt >= 0 and pt < 6:
			legs[pt] += 1
		elif pt == EcoGrazerLook.SCRAPER:
			scraper += 1
		else:
			body += 1
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
		max_x = maxf(max_x, absf(p.x))
		max_z = maxf(max_z, absf(p.z))
	for k in 6:
		ok(legs[k] >= 40, "лапа %d размечена: %d вершин" % [k, legs[k]])
	# лапы размечены ровно: правило «ближе LEG_D к оси бедро → стопа» не даёт перекоса
	var mid: float = (legs[0] + legs[1] + legs[2] + legs[3] + legs[4] + legs[5]) / 6.0
	for k in 6:
		ok(absf(legs[k] - mid) < mid * 0.35, "лапа %d в меру ровная: %d при среднем %.0f" % [k, legs[k], mid])
	ok(scraper >= 60, "скребок размечен: %d вершин" % scraper)
	ok(body >= 300, "тело — панцирь и низ: %d вершин" % body)
	near(min_y, 0.0, 0.005, "стопы на подошве")
	near(max_y, 0.64, 0.01, "высота 0,64 м")
	near(max_x, 0.794, 0.01, "размах лап")
	near(max_z, 0.75, 0.01, "длина 1,5 м")


func test_model_mesh_posed_like_shader() -> void:
	var mat := GrazerView.build_mesh().surface_get_material(0) as ShaderMaterial
	near(mat.get_shader_parameter("texk"), 1.0, 1e-5, "полный меш — краска из текстуры")
	var mesh := EcoGrazerModel.mesh(mat)
	eq(mesh.get_surface_count(), 1, "один вызов отрисовки")
	var norms: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var uv2: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	eq(norms.size(), EcoGrazerModel.rest.size())
	# у лапы 0: NORMAL.x = +1 (тройка), UV2 = её бедро
	var v := EcoGrazerModel.part.find(0)
	ok(v >= 0, "вершина лапы 0")
	near(norms[v].x, 1.0, 1e-5, "передняя лапа −x — тройка +1")
	near(uv2[v].x, EcoGrazerModel.hips[0].x, 1e-4, "бедро в UV2")
	near(uv2[v].y, EcoGrazerModel.hips[0].z, 1e-4)
	# у скребка: NORMAL.y = 1; поза вниз на ход скребка
	v = EcoGrazerModel.part.find(EcoGrazerLook.SCRAPER)
	ok(v >= 0, "вершина скребка")
	near(norms[v].y, 1.0, 1e-5, "скребок в NORMAL.y")
	var p := EcoGrazerModel.posed(v, Vector2(0.0, 0.05))
	near(p.y, EcoGrazerModel.rest[v].y - 0.05, 1e-5, "скребок ходит вниз")
	# у тела разметки нет — стоит
	v = EcoGrazerModel.part.find(EcoGrazerLook.BODY)
	ok(v >= 0, "вершина тела")
	near(norms[v].x, 0.0, 1e-5)
	near(norms[v].y, 0.0, 1e-5)
	# лапа крутится вокруг бедра: posed повторяет формулу шейдера
	v = EcoGrazerModel.part.find(4)   # средняя +x — тройка +1
	var s := 0.5 * EcoGrazerLook.tripod(4)
	var ang := EcoGrazerLook.SWING * s
	var h: Vector3 = EcoGrazerModel.hips[4]
	var r: Vector3 = EcoGrazerModel.rest[v]
	var dx := r.x - h.x
	var dz := r.z - h.z
	var want := Vector3(h.x + dx * cos(ang) + dz * sin(ang), r.y + EcoGrazerLook.STEP_LIFT * maxf(0.0, s),
		h.z - dx * sin(ang) + dz * cos(ang))
	ok(EcoGrazerModel.posed(v, Vector2(0.5, 0.0)).distance_to(want) < 1e-5, "лапа крутится вокруг бедра")


func test_view_mesh_is_model() -> void:
	var w := EcoWorld.new(7)
	w.ground = Seabed.height
	var m := w.add(EcoMoss.new()) as EcoMoss
	var grazers := w.add(EcoGrazer.new(m)) as EcoGrazer
	var view := GrazerView.new(grazers)
	tree.root.add_child(view)
	await frames(1)
	eq(view.tris, 1119, "полный меш — модель MOD-024")
	eq(view.multimesh.mesh.get_surface_count(), 1, "один вызов отрисовки")
	var mat := view.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	ok(mat != null, "свой шейдер")
	ok(mat.get_shader_parameter("skin") != null, "карта цвета отдана шейдеру")
	# «Экономно» — процедурный: разметка в NORMAL, текстура не читается (texk = 0)
	var lite := GrazerView.build_mesh(true)
	near((lite.surface_get_material(0) as ShaderMaterial).get_shader_parameter("texk"), 0.0, 1e-5,
		"«Экономно» — без текстуры")
	var norms: PackedVector3Array = lite.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	eq(norms.size(), EcoGrazerLook.lite_rest.size(), "разметка и на «Экономно»")
	var has_scraper := false
	for nm in norms:
		has_scraper = has_scraper or nm.y > 0.5
	ok(has_scraper, "скребок размечен и на «Экономно»")
	view.queue_free()
	await frames(1)
