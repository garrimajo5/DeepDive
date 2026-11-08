extends TestCase
## Край отмели по концепту ART-032 (место 6 карты отмели): бровка по фактическому склону Seabed (x ≈ 150–160)
## вдоль z 40…140, рваная кромка ± 5 м; четыре скальных клина ≈ 20 м — верх вровень с дном у бровки, стенка круче
## склона, низ заглублён; шрам оползня 20 м у z = 90 врезан в площадку на 5–8 м, светлый скол, осыпь по диагонали;
## трещины на площадке; один меш, ≤ 5000 треуг., светится только редкое обрастание.


func _drop() -> EcoDrop:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	return w.add(EcoDrop.new()) as EcoDrop


func test_place_from_map() -> void:
	var f := FileAccess.open("res://docs/concept-art/karta-otmeli-mesta.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var spot: Dictionary = {}
	for l in data["locations"]:
		if l["name"] == "Край отмели":
			spot = l
	near(EcoDrop.CENTER.x, float(spot["x"]), 1e-6, "x с карты отмели")
	near(EcoDrop.CENTER.y, float(spot["z"]), 1e-6, "z с карты отмели")
	eq(EcoDrop.ID, "drop", "ключ места как в Run.PLACES")
	eq(Run.PLACES[EcoDrop.ID][1], EcoDrop.CENTER, "точка маршрута — над склоном")
	# круг открытия места захватывает бровку у шрама
	var r: float = Run.PLACES[EcoDrop.ID][2]
	ok(EcoDrop.CENTER.distance_to(Vector2(EcoDrop.brow_x(EcoDrop.SCAR_Z), EcoDrop.SCAR_Z)) < r + 5.0,
		"бровка у края круга открытия")


## Бровка там, где склон начинается в рельефе: дно −43…−62 м, дальше на восток — глубже; кромка рваная, ± 5 м.
func test_brow_on_real_slope() -> void:
	var d := _drop()
	var lo := 1e9
	var hi := -1e9
	var z := EcoDrop.Z_FROM
	while z <= EcoDrop.Z_TO:
		var x := EcoDrop.brow_x(z)
		lo = minf(lo, x)
		hi = maxf(hi, x)
		var y := d.floor_y(x, z)
		ok(y < -42.0 and y > -63.0, "дно у бровки при z %.0f: %.1f" % [z, y])
		ok(d.floor_y(x + 30.0, z) < y - 15.0, "за бровкой склон уходит вниз при z %.0f" % z)
		z += 2.0
	ok(lo >= EcoDrop.BROW_X - EcoDrop.JAG - 1e-4 and hi <= EcoDrop.BROW_X + EcoDrop.JAG + 1e-4,
		"кромка ± 5 м: %.1f…%.1f" % [lo, hi])
	ok(hi - lo > 3.0, "кромка не ровная: размах %.1f м" % (hi - lo))


## Четыре клина по ≈ 20 м вдоль всего участка, кроме шрама 20 м у z = 90.
func test_wedges_and_scar_span() -> void:
	eq(EcoDrop.WEDGES.size(), 4, "четыре клина")
	var covered := 0.0
	for w in EcoDrop.WEDGES.size():
		var r := EcoDrop.WEDGES[w]
		ok(r.y - r.x >= 18.0 and r.y - r.x <= 25.0, "клин %d — %.0f м" % [w, r.y - r.x])
		ok(r.y <= EcoDrop.SCAR_Z - EcoDrop.SCAR_W * 0.5 or r.x >= EcoDrop.SCAR_Z + EcoDrop.SCAR_W * 0.5,
			"клин %d не заходит в шрам" % w)
		covered += r.y - r.x
	near(covered + EcoDrop.SCAR_W, EcoDrop.Z_TO - EcoDrop.Z_FROM, 1e-4, "клинья и шрам — весь участок 100 м")
	near(EcoDrop.WEDGES[0].x, EcoDrop.Z_FROM, 1e-6, "с севера — от z 40")
	near(EcoDrop.WEDGES[3].y, EcoDrop.Z_TO, 1e-6, "до z 140")


## Профиль: верх у бровки вровень с дном (кромка на RISE), заход в площадку под дном, полка над склоном,
## стенка круче склона, низ заглублён; хорда «заход — низ» под дном — торец без просвета.
func test_profile_flush_steep_buried() -> void:
	var d := _drop()
	for w in EcoDrop.WEDGES.size():
		var zr := EcoDrop.wedge_z(w)
		for k in 5:
			var z := lerpf(zr.x, zr.y, k / 4.0)
			var p := d.profile(w, z)
			var xe := EcoDrop.brow_x(z)
			near(p[1].x, xe, 1e-5, "кромка на бровке")
			near(p[1].y, d.floor_y(xe, z) + EcoDrop.RISE, 1e-4, "кромка вровень с дном (+RISE)")
			ok(p[0].y < d.floor_y(p[0].x, z), "заход в площадку — под дном")
			ok(p[2].y > d.floor_y(p[2].x, z) + 2.0, "губа полки над склоном")
			ok(p[3].y <= d.floor_y(p[3].x, z) - EcoDrop.FOOT_SINK + 1e-4, "низ стенки заглублён в склон")
			var wall := (p[2].y - p[3].y) / (p[3].x - p[2].x)
			var slope := (d.floor_y(p[2].x, z) - d.floor_y(p[3].x, z)) / (p[3].x - p[2].x)
			ok(wall > slope * 2.0, "стенка круче склона: %.2f против %.2f" % [wall, slope])
			for s in 9:
				var q := p[0].lerp(p[3], (s + 1) / 10.0)
				ok(q.y < d.floor_y(q.x, z), "хорда торца под дном")
	# посередине клина стенка видна над склоном на 7+ м, вся кромка — до 35+ м ниже бровки
	for w in EcoDrop.WEDGES.size():
		var zr := EcoDrop.wedge_z(w)
		var z := (zr.x + zr.y) * 0.5
		var p := d.profile(w, z)
		ok(p[2].y - d.floor_y(p[2].x, z) > 7.0, "клин %d: стенка у губы %.1f м" % [w, p[2].y - d.floor_y(p[2].x, z)])
		ok(p[1].y - p[3].y >= EcoDrop.DEPTH, "клин %d: стенка уходит на 40 м" % w)


func test_scar_cut_into_platform() -> void:
	var d := _drop()
	var cut := EcoDrop.brow_x(EcoDrop.SCAR_Z) - EcoDrop.scar_head_x(EcoDrop.SCAR_Z)
	ok(cut >= 5.0 and cut <= 8.0, "шрам врезан на 5–8 м: %.1f" % cut)
	for e in [-1.0, 1.0]:
		var z: float = EcoDrop.SCAR_Z + e * EcoDrop.SCAR_W * 0.5
		near(EcoDrop.scar_head_x(z), EcoDrop.brow_x(z), 1e-4, "края шрама сходятся с бровкой")
	var s := d.scar_point()
	near(s.z, EcoDrop.SCAR_Z, 1e-6, "точка схода — у середины шрама")
	ok(s.x < EcoDrop.brow_x(EcoDrop.SCAR_Z), "точка схода — у скола, за бровкой")
	ok(s.y > d.floor_y(s.x, s.z), "точка схода — над дном")
	# в полосе шрама скалы нет: ложе открыто
	var x := EcoDrop.brow_x(EcoDrop.SCAR_Z) + 8.0
	ok(not d.solid(Vector3(x, d.floor_y(x, EcoDrop.SCAR_Z) + 1.0, EcoDrop.SCAR_Z)), "ложе шрама — не скала")


## Осыпь — по диагонали вниз по ложу и дальше по склону, на дне; к низу камни крупнее.
func test_scree_diagonal() -> void:
	var d := _drop()
	var rocks := d.scree()
	eq(rocks.size(), EcoDrop.SCREE, "камней осыпи")
	var first := rocks[0]
	var last := rocks[rocks.size() - 1]
	ok(last.x - first.x > 30.0, "вниз по склону: %.1f м" % (last.x - first.x))
	ok(last.z - first.z > 5.0, "по диагонали: снос %.1f м" % (last.z - first.z))
	var small := 0.0
	var big := 0.0
	for i in rocks.size():
		var r := rocks[i]
		ok(r.x > EcoDrop.brow_x(r.z), "камень за бровкой")
		ok(r.y - d.floor_y(r.x, r.z) < r.w, "камень лежит на дне")
		if i < rocks.size() / 2:
			small += r.w
		else:
			big += r.w
	ok(big > small, "к низу крупнее")
	eq(d.scree()[5], rocks[5], "осыпь своя, от зерна мира не зависит")


func test_cracks_on_platform() -> void:
	var d := _drop()
	eq(EcoDrop.CRACKS.size(), 3, "три трещины")
	for k in EcoDrop.CRACKS.size():
		var pts := d.crack_points(k)
		for p in pts:
			ok(p.x < EcoDrop.brow_x(p.z), "трещина на площадке, за бровкой")
			near(p.y, d.floor_y(p.x, p.z) + EcoDrop.CRACK_UP, 1e-4, "трещина лежит на дне")


func test_solid() -> void:
	var d := _drop()
	var z := 50.0
	var p := d.profile(0, z)
	var mid := (p[1] + p[2]) * 0.5
	ok(d.solid(Vector3(mid.x, mid.y - 1.0, z)), "под полкой — скала")
	ok(not d.solid(Vector3(mid.x, mid.y + 2.0, z)), "над полкой — вода")
	ok(not d.solid(Vector3(p[3].x + 20.0, -60.0, z)), "над склоном за стенкой — вода")
	ok(not d.solid(Vector3(EcoDrop.CENTER.x, -80.0, EcoDrop.CENTER.y)), "точка места — вода")
	ok(not d.solid(Vector3(mid.x, mid.y - 1.0, 160.0)), "за участком — нет скалы")


## top(x,z) — верх клина (один источник для solid); вне клиньев и в полосе шрама — −INF.
func test_top_matches_solid() -> void:
	var d := _drop()
	var z := 50.0
	var p := d.profile(0, z)
	var mid := (p[1] + p[2]) * 0.5
	var t := d.top(mid.x, z)
	ok(t != -INF, "над клином есть верх")
	near(t, mid.y, 1e-4, "верх — на профиле клина")
	ok(d.solid(Vector3(mid.x, t - 1.0, z)), "под верхом — скала")
	ok(not d.solid(Vector3(mid.x, t + 1.0, z)), "над верхом — вода")
	eq(d.top(mid.x, 160.0), -INF, "за участком верха нет")
	eq(d.top(EcoDrop.CENTER.x, EcoDrop.CENTER.y), -INF, "над склоном за стенкой верха нет")


## Облако оползня идёт из свежего шрама (ниже скола по склону), а не с открытого склона в ~60 м восточнее (issue #258).
func test_slide_cloud_at_scar() -> void:
	var d := _drop()
	var c := d.slide_cloud_point()
	var sp := d.scar_point()
	near(c.z, EcoDrop.SCAR_Z, 1e-6, "облако у середины шрама по z")
	ok(c.x > sp.x and absf(c.x - sp.x) <= 12.0, "облако ниже по склону (+X) от скола, рядом: Δx %.1f" % absf(c.x - sp.x))
	ok(c.y > d.floor_y(c.x, c.z) and c.y <= maxf(d.floor_y(c.x, c.z) + EcoDrop.SLIDE_UP, -55.0) + 1e-4,
		"облако над дном, не глубже −55")
	ok(absf(c.x - Silt.DROP.x) > 40.0, "новая точка далеко от старой DROP над открытым склоном")


## Подключение в корабль (issue #258): main поднимает «пол» корпуса на верх скалы и берёт точку облака из шрама.
func test_wired_into_ship() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(main.silt.slide_origin != Vector3.INF, "silt берёт точку схода из мира")
	near(main.silt.slide_origin.z, EcoDrop.SCAR_Z, 1e-6, "облако оползня — у шрама Края отмели")
	var zr := EcoDrop.wedge_z(0)
	var zc := (zr.x + zr.y) * 0.5
	var rim := main.eco.drop.profile(0, zc)[1]
	var g_here: float = main.helm.ground.call(rim.x, zc)
	ok(g_here >= rim.y - 1e-3, "пол корпуса не ниже верха скалы: %.2f ≥ %.2f" % [g_here, rim.y])
	ok(g_here > Seabed.height(rim.x, zc) + 0.5, "над скалой пол корпуса выше дна — корабль чиркает")
	main.queue_free()
	await frames(1)


func test_view_one_mesh_budget() -> void:
	var d := _drop()
	var v := DropView.new(d)
	eq(v.mesh.get_surface_count(), 1, "один материал — один вызов отрисовки")
	eq(v.layers, OceanView.LAYER_WORLD, "слой отмели")
	ok(v.tris > 1000 and v.tris <= 5000, "бюджет ART-032 ≤ 5000: %d" % v.tris)
	ok(v.glowing > 0 and float(v.glowing) / v.tris < 0.1, "светится только редкое обрастание: %d" % v.glowing)
	var aabb := v.mesh.get_aabb()
	ok(aabb.position.z >= EcoDrop.Z_FROM - 1.0 and aabb.end.z <= EcoDrop.Z_TO + 1.0, "вдоль z 40…140")
	ok(aabb.position.x > 135.0 and aabb.end.x < 205.0, "у бровки x 150–160: %s" % aabb)
	# грани клиньев смотрят наружу: нормаль полки вверх, стенки — к глубине
	var up := 0
	var east := 0
	for t in v.wedge_tris:
		var n := v.normals[t * 3]
		near(n.length(), 1.0, 1e-4, "нормаль единичная")
		if n.y > 0.5:
			up += 1
		if n.x > 0.5:
			east += 1
	ok(up > v.wedge_tris / 5, "полки лицом вверх: %d" % up)
	ok(east > v.wedge_tris / 4, "стенки лицом к глубине: %d" % east)
	v.free()


func test_in_eco_view() -> void:
	var ev := EcoView.new()
	ev.ground = Seabed.height
	ok(ev.drop != null and ev.drop_view != null, "край отмели в живом мире")
	ok(ev.drop_view.tris > 1000, "меш собран по дну мира")
	ev.free()


func test_view_lite_coarser_same_material() -> void:
	var d := _drop()
	var v := DropView.new(d)
	var full := v.tris
	var full_wedge := v.wedge_tris
	var full_glow := v.glowing
	var mat := v.mesh.surface_get_material(0)
	var box_full := v.mesh.get_aabb()
	v.set_lite(true)
	ok(v.lite, "край — на «Экономно»")
	ok(v.tris * 10 <= full * 7, "треугольников не больше 70 %% (%d → %d)" % [full, v.tris])
	ok(v.wedge_tris * 100 <= full_wedge * 65, "клинья грубее: %d → %d" % [full_wedge, v.wedge_tris])
	eq(v.mesh.get_surface_count(), 1, "вызов тот же")
	ok(v.mesh.surface_get_material(0) == mat, "материал тот же")
	eq(v.glowing, full_glow, "обрастание то же")
	var box := v.mesh.get_aabb()
	ok(box.size.z > box_full.size.z * 0.97 and box.size.x > box_full.size.x * 0.9
		and box.size.y > box_full.size.y * 0.9, "силуэт тот же: %s → %s" % [box_full.size, box.size])
	# полки по-прежнему вверх, стенки — к глубине
	var up := 0
	var east := 0
	for t in v.wedge_tris:
		var n := v.normals[t * 3]
		if n.y > 0.5:
			up += 1
		if n.x > 0.5:
			east += 1
	ok(up > v.wedge_tris / 5 and east > v.wedge_tris / 4, "грани наружу: %d вверх, %d к глубине" % [up, east])
	v.set_lite(false)
	eq(v.tris, full, "назад — полный меш")
	eq(v.glowing, full_glow, "и обрастание не задвоилось")
	v.free()


func test_lite_kept_after_world_reset() -> void:
	var ev := EcoView.new()
	ev.ground = Seabed.height
	var full := ev.drop_view.tris
	ev.set_lite(true)
	ok(ev.drop_view.lite and ev.drop_view.tris < full, "уровень дошёл до края: %d → %d" % [full, ev.drop_view.tris])
	var lite_tris := ev.drop_view.tris
	ev.ground = Seabed.height
	ok(ev.drop_view.lite, "после сброса мира — по-прежнему «Экономно»")
	eq(ev.drop_view.tris, lite_tris, "и меш грубый")
	ev.set_lite(false)
	ev.free()
	EcoShaders.set_sway_lite(false)
