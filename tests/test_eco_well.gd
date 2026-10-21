extends TestCase
## Световой колодец по концепту ART-031 (место 5 карты отмели): трещина 12 × 3 м прямо под льдом, столб света
## наклонён по «солнцу» OceanView и падает в пятно мха 22 × 16 м на дне; открытая оболочка без торцов, мягкая
## альфа к краю и к низу, тёплая сердцевина у льда; дыхание ± 5 % за 10 с; ≤ 1000 треуг., ≤ 3 вызова; свой мох.

const FLAT := -46.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _well(ground: Callable) -> EcoWell:
	var w := EcoWorld.new()
	w.ground = ground
	return w.add(EcoWell.new()) as EcoWell


func test_place_from_map() -> void:
	var f := FileAccess.open("res://docs/concept-art/karta-otmeli-mesta.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var spot: Dictionary = {}
	for l in data["locations"]:
		if l["name"] == "Световой колодец":
			spot = l
	near(EcoWell.CENTER.x, float(spot["x"]), 1e-6, "x с карты отмели")
	near(EcoWell.CENTER.y, float(spot["z"]), 1e-6, "z с карты отмели")
	eq(EcoWell.ID, "well", "ключ места как в Run.PLACES")
	eq(Run.PLACES[EcoWell.ID][1], EcoWell.CENTER, "точка маршрута — у колодца")
	var w := _well(Seabed.height)
	near(w.base.y, Seabed.height(EcoWell.CENTER.x, EcoWell.CENTER.y), 1e-4, "пятно света — на дне")
	ok(w.base.y < -44.0 and w.base.y > -49.0, "дно ≈ −46 м: %f" % w.base.y)


## Один источник света: столб идёт ровно по «солнцу» OceanView, от трещины под льдом в середину пятна.
func test_column_follows_sun() -> void:
	var ov := OceanView.new()
	tree.root.add_child(ov)
	await frames(1)
	var light := -ov.sun.global_basis.z.normalized()
	ok(light.dot(EcoWell.sun_dir()) > 0.9999, "направление — как у света сквозь лёд")
	ov.queue_free()
	for g in [_flat, Seabed.height]:
		var w := _well(g)
		near(w.top.y, Seabed.ICE_Y - EcoWell.CRACK_SINK, 1e-5, "трещина прямо под льдом")
		ok((w.base - w.top).normalized().dot(EcoWell.sun_dir()) > 0.9999, "луч падает в пятно")
		ok(Vector2(w.top.x - w.base.x, w.top.z - w.base.z).length() > 5.0, "трещина смещена против света")
		near(w.along.dot(w.across), 0.0, 1e-5, "оси трещины поперёк")
		near(w.along.y, 0.0, 1e-6, "трещина горизонтальна")
	await frames(1)


func test_sizes_from_concept() -> void:
	var w := _well(Seabed.height)
	var lo := 0.0
	var hi := 0.0
	for i in EcoWell.CRACK_PTS:
		var p := w.crack_point(i) - w.top
		near(p.y, 0.0, 1e-5, "край трещины в плоскости под льдом")
		hi = maxf(hi, absf(p.dot(w.along)))
		lo = maxf(lo, absf(p.dot(w.across)))
	ok(hi > 5.0 and hi <= 6.0 + 1e-4, "трещина 12 м: полудлина %f" % hi)
	ok(lo > 1.0 and lo <= 1.5 + 1e-4, "ширина 3 м: полуширина %f" % lo)
	# низ столба — эллипс 22 × 16 вокруг середины пятна
	var last := EcoWell.RINGS - 1
	for j in EcoWell.SIDES:
		var p := w.column_point(last, j) - w.base
		var e := pow(p.dot(w.along) / 11.0, 2) + pow(p.dot(w.across) / 8.0, 2)
		near(e, 1.0, 1e-4, "низ столба по краю пятна 22 × 16")
		near(p.y, 0.0, 1e-5, "низ на уровне дна")
		var q := w.column_point(0, j) - w.top
		near(pow(q.dot(w.along) / 6.0, 2) + pow(q.dot(w.across) / 1.5, 2), 1.0, 1e-4, "верх — по трещине")


func test_moss_spot() -> void:
	var w := _well(Seabed.height)
	ok(w.moss != null, "у колодца свой мох")
	eq(w.moss.patches.size(), EcoWell.MOSS.size(), "пять пятен")
	var span_l := 0.0
	var span_w := 0.0
	for p in w.moss.patches:
		near(p.pos.y, Seabed.height(p.pos.x, p.pos.z), 1e-3, "пятно на дне")
		var d := p.pos - w.base
		span_l = maxf(span_l, absf(d.dot(w.along)) + EcoMoss.SIZE * 0.5)
		span_w = maxf(span_w, absf(d.dot(w.across)) + EcoMoss.SIZE * 0.5)
		ok(p.glow() > 0.6, "мох светится")
	near(span_l, 11.0, 0.01, "мох на 22 м вдоль")
	near(span_w, 8.0, 0.01, "мох на 16 м поперёк")
	var ev := EcoView.new()
	ev.ground = Seabed.height
	eq(ev.moss.patches.size(), 22, "пятна рифа — прежние 22, скребуны их не делят с колодцем")
	ok(ev.well != null and ev.well_view != null, "колодец в живом мире")
	var mv := ev.well_view.moss_view
	ok(mv != null and mv.get_parent() == ev.well_view, "мох колодца — в сцене")
	eq(mv.look.verts.size(), EcoWell.MOSS.size() * EcoMossLook.VERTS_PER_PATCH, "один меш на все пятна")
	ev.free()


func test_breathes_slowly() -> void:
	near(EcoWell.glow(0.0), 1.0, 1e-6, "середина")
	near(EcoWell.glow(2.5), 1.05, 1e-6, "+5 %")
	near(EcoWell.glow(7.5), 0.95, 1e-6, "−5 %")
	near(EcoWell.glow(10.0), 1.0, 1e-5, "период 10 с")
	var w := _well(Seabed.height)
	var v := WellView.new(w)
	for mi in [v.crack, v.column]:
		var code: String = mi.mesh.surface_get_material(0).shader.code
		ok(code.contains("TIME") and code.contains("pulse") and code.contains("period"), "дыхание в шейдере")
		near(float(mi.mesh.surface_get_material(0).get_shader_parameter("pulse")), EcoWell.PULSE, 1e-6, "размах")
		near(float(mi.mesh.surface_get_material(0).get_shader_parameter("period")), EcoWell.PERIOD, 1e-6, "период")
		ok(code.contains("unshaded") and code.contains("depth_draw_never"), "мягкий свет без записи глубины")
	v.free()


func test_view_budget_and_faces() -> void:
	var w := _well(Seabed.height)
	var v := WellView.new(w)
	tree.root.add_child(v)
	await frames(1)
	var calls := 0
	for mi in [v.crack, v.column, v.moss_view]:
		eq(mi.layers, OceanView.LAYER_WORLD, "слой отмели")
		calls += mi.mesh.get_surface_count()
	ok(calls <= 3, "≤ 3 вызова отрисовки: %d" % calls)
	eq(v.column_verts.size() / 3, EcoWell.SIDES * (EcoWell.RINGS - 1) * 2, "открытая оболочка без торцов")
	ok(v.tris <= 1000, "≤ 1000 треуг. (без мха): %d" % v.tris)
	ok(v.crack_verts.size() / 3 <= 200, "трещина ≤ 200 треуг.")
	# трещина лицом вниз (смотрим из-подо льда): (b − a) × (c − a) — вверх
	for t in v.crack_verts.size() / 3:
		var a := v.crack_verts[t * 3]
		var cr := (v.crack_verts[t * 3 + 1] - a).cross(v.crack_verts[t * 3 + 2] - a)
		ok(cr.y > 0.0, "грань трещины %d лицом вниз" % t)
	# столб лицом наружу: (b − a) × (c − a) — к оси
	var inward := 0
	for t in v.column_verts.size() / 3:
		var a := v.column_verts[t * 3]
		var c := (a + v.column_verts[t * 3 + 1] + v.column_verts[t * 3 + 2]) / 3.0
		var s := (c.y - w.top.y) / (w.base.y - w.top.y)
		var axis := w.top.lerp(w.base, s)
		var cr := (v.column_verts[t * 3 + 1] - a).cross(v.column_verts[t * 3 + 2] - a)
		if cr.dot(axis - c) > 0.0:
			inward += 1
	eq(inward, v.column_verts.size() / 3, "грани столба смотрят наружу")
	# альфа: у льда плотнее, к низу тает; тёплая сердцевина вверху, рассеянный голубой внизу
	var cols: PackedColorArray = v.column.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var top_c := cols[0]
	var low_c := cols[cols.size() - 1]
	ok(top_c.a > low_c.a, "к низу прозрачнее")
	ok(top_c.r > low_c.r, "у льда — тёплая сердцевина #F4E9CF, у дна — #9AD9E8")
	ok(not v.column.mesh.surface_get_material(0).shader.code.contains("blend_add"),
		"не прожектор: мягкое смешение, без яркого сложения")
	v.queue_free()
	await frames(1)
