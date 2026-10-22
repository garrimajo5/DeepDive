extends TestCase
## Корпус снаружи (HullMesh, HullView): формы лицом наружу, детали одной краски — одним мешем, роторы и рули
## движутся за пилотом, корпус на слое отмели и в бюджете телефона.


func _faces_out(b: HullMesh.Builder) -> bool:
	for t in b.triangles():
		var a := b.pos[b.idx[t * 3]]
		var c1 := b.pos[b.idx[t * 3 + 1]]
		var c2 := b.pos[b.idx[t * 3 + 2]]
		var n := b.nor[b.idx[t * 3]] + b.nor[b.idx[t * 3 + 1]] + b.nor[b.idx[t * 3 + 2]]
		if (c1 - a).cross(c2 - a).dot(n) > 1e-9:   # по CLAUDE.md (b − a) × (c − a) смотрит внутрь
			return false
	return true


func test_unit_forms_face_out() -> void:
	for f in HullPlan.Form.values():
		var b := HullMesh.unit(f)
		ok(b.triangles() > 0, "форма %d построена" % f)
		ok(_faces_out(b), "форма %d: лицевые стороны наружу" % f)
	# у выпуклых форм нормали смотрят от центра
	for f in [HullPlan.Form.CUBE, HullPlan.Form.SPHERE, HullPlan.Form.CAPSULE, HullPlan.Form.CYLINDER, HullPlan.Form.FRUSTUM]:
		var b := HullMesh.unit(f)
		var good := true
		for i in b.pos.size():
			good = good and (b.pos[i].length() < 1e-6 or b.nor[i].dot(b.pos[i]) > -1e-6)
		ok(good, "форма %d: нормали от центра" % f)


func test_unit_sizes() -> void:
	var cube := HullMesh.unit(HullPlan.Form.CUBE)
	var box := AABB(cube.pos[0], Vector3.ZERO)
	for p in cube.pos:
		box = box.expand(p)
	ok(box.size.is_equal_approx(Vector3.ONE), "куб 1 м")
	var dome := HullMesh.unit(HullPlan.Form.DOME)
	var low := INF
	for p in dome.pos:
		low = minf(low, p.y)
	near(low, -0.25, 1e-4, "купол срезан на y = −0,25")


func test_paints_and_parts() -> void:
	var count := 0
	for part in HullPlan.parts():
		if HullMesh.drawn(part):
			count += 1
	eq(count, 27, "все детали ART-001, кроме крышки шлюза (её рисует RoomsView)")
	var total := 0
	for paint in HullMesh.paints():
		var b := HullMesh.paint_builder(paint)
		ok(_faces_out(b), "краска %d: собранный меш лицом наружу" % paint)
		total += b.triangles()
	for part in HullPlan.parts():
		if HullMesh.moving(part):
			total += HullMesh.part_builder(part).triangles()
	ok(total < 12000, "корпус легче 12 тыс. треугольников: %d" % total)
	ok(HullMesh.glow(HullPlan.Paint.WINDOW) > 0.0 and HullMesh.glow(HullPlan.Paint.METAL) == 0.0, "окна светятся, металл — нет")


func test_body_mesh_matches_plan() -> void:
	# меш основных объёмов лежит на поверхности форм HullPlan (по ним существа обходят корабль):
	# чуть внутрь от середины треугольника — внутри детали, чуть наружу — снаружи
	for part in HullPlan.parts():
		if not (part.piece in [HullPlan.Piece.BODY, HullPlan.Piece.NOSE, HullPlan.Piece.STERN]):
			continue
		var b := HullMesh.Builder.new()
		b.merge(HullMesh.unit(part.form), part.xform())
		var good := 0
		for t in b.triangles():
			var i := t * 3
			var c := (b.pos[b.idx[i]] + b.pos[b.idx[i + 1]] + b.pos[b.idx[i + 2]]) / 3.0
			var n := (b.nor[b.idx[i]] + b.nor[b.idx[i + 1]] + b.nor[b.idx[i + 2]]).normalized()
			if part.contains(c - n * 0.03) and not part.contains(c + n * 0.3):   # снаружи — с запасом на прогиб хорды
				good += 1
		ok(good > b.triangles() * 0.9, "%s: меш на поверхности формы (%d из %d)" % [part.name, good, b.triangles()])


func test_motion() -> void:
	var m := HullMesh.Motion.new()
	for i in 90:
		m.update(1.0 / 30.0, 1.0, 1.0, 1.0)
	ok(m.spin > 0.9 and m.spin <= 1.0, "роторы раскрутились за тягой: %.2f" % m.spin)
	ok(m.pitch > 24.0, "рули встали на всплытие: %.1f°" % m.pitch)
	ok(m.rotor_angle_of(-1.0) == -m.rotor_angle, "роторы бортов навстречу")
	for i in 150:
		m.update(1.0 / 30.0, 1.0, 0.0, 0.0)
	ok(m.spin < 0.01, "без энергии двигателей роторы встали")
	ok(absf(m.pitch) < 0.5, "рули вернулись")


func test_scene_hull() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var hull := main.hull
	ok(hull != null and hull.get_parent() == main.ship, "корпус едет с кораблём")
	eq(hull.body.layers, OceanView.LAYER_WORLD, "корпус на слое отмели: его освещают лёд и прожектор")
	eq(hull.body.mesh.get_surface_count(), HullMesh.paints().size(), "по поверхности на краску")
	eq(hull.rotors.size(), 2, "два ротора")
	eq(hull.rudders.size(), 2, "два руля глубины")
	main.sit_at_helm()
	var rudder := hull.rudders[0]
	var tail := func() -> float: return (rudder.global_transform * Vector3(0, 0, 0.9)).y - rudder.global_position.y
	var tail0: float = tail.call()
	var b0 := hull.rotors[0].basis
	var r := main.overlay.router
	r.begin(1, r.layout.up.c)   # «Всплыть» и полный ход крестовиной
	r.begin(2, r.layout.pad.c)
	r.moved(2, r.layout.pad.c + Vector2(0, -r.layout.pad.r))
	for i in 60:
		main.step(1.0 / 30.0)
	ok(not hull.rotors[0].basis.is_equal_approx(b0), "ротор повернулся")
	ok(tail.call() > tail0 + 0.2, "при всплытии задняя кромка руля поднята: %.2f → %.2f" % [tail0, tail.call()])
	ok(hull_rotor_turns(main), "двигатели на ходу")
	r.end(1)
	r.end(2)


func hull_rotor_turns(main: Main) -> bool:
	return main.hull_motion.spin > 0.5


func test_plating_numbers() -> void:
	# обшивка ART-024: обрастание по локальной высоте (заметки художника), 0 у киля — 1 у верха
	near(HullMesh.local_height(HullMesh.KEEL_Y), 0.0, 1e-6, "киль — h = 0")
	near(HullMesh.local_height(HullMesh.KEEL_Y + HullMesh.HULL_H), 1.0, 1e-6, "верх — h = 1")
	eq(HullMesh.local_height(-50.0), 0.0, "ниже киля h не уходит в минус")
	near(HullMesh.growth(0.0), 0.65, 1e-6, "у киля обрастание 0,65")
	near(HullMesh.growth(HullMesh.GROWTH_TO), 0.0, 1e-6, "с середины корпуса обрастания нет")
	var last := 1.0
	var down := true
	for i in 21:
		var g := HullMesh.growth(i / 20.0)
		down = down and g <= last + 1e-6
		last = g
	ok(down, "обрастание не растёт с высотой")
	ok(HullMesh.growth(HullMesh.local_height(HullPlan.CENTER_Y)) < 0.01, "у окон (ось корабля) — чистый металл")
	ok(HullMesh.plated(HullPlan.Paint.METAL), "металл — под обшивкой")
	for p in [HullPlan.Paint.SEAM, HullPlan.Paint.WINDOW, HullPlan.Paint.LENS, HullPlan.Paint.LOCK]:
		ok(not HullMesh.plated(p), "краска %d — своим цветом" % p)
	for k in ["tsvet", "maska", "obrastanie"]:
		var t: Texture2D = load(HullMesh.PLATE_TEX % k)
		ok(t != null and t.get_width() == 1024, "карта %s 1024²" % k)


func test_scene_plating() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var mesh: ArrayMesh = main.hull.body.mesh
	var plated := 0
	for i in mesh.get_surface_count():
		var paint: int = HullMesh.paints()[i]
		var m := mesh.surface_get_material(i)
		if HullMesh.plated(paint):
			plated += 1
			ok(m is ShaderMaterial, "металл корпуса — шейдер обшивки")
			var sm := m as ShaderMaterial
			ok(sm.get_shader_parameter("color_tex") is Texture2D and sm.get_shader_parameter("mask_tex") is Texture2D
				and sm.get_shader_parameter("growth_tex") is Texture2D, "три карты ART-024 в материале")
			near(sm.get_shader_parameter("tile"), HullMesh.PLATE_TILE, 1e-6, "плитка 2 м")
			near(sm.get_shader_parameter("keel_y"), HullMesh.KEEL_Y, 1e-6, "киль из HullMesh")
		else:
			ok(m is StandardMaterial3D, "краска %d — однотонный материал" % paint)
	eq(plated, 1, "одна поверхность обшивки — без новых вызовов отрисовки")
	for r in main.hull.rotors + main.hull.rudders:
		ok(r.mesh.surface_get_material(0) is StandardMaterial3D, "%s: без обрастания и плитки (свои оси)" % r.name)


func test_damage_numbers() -> void:
	# следы ART-049: потеря корпуса 0…1, след виден при d > 0 и d ≥ порога (как в шейдере)
	near(HullMesh.wear(100.0), 0.0, 1e-6, "целый корпус — потерь нет")
	near(HullMesh.wear(70.0), 0.3, 1e-6)
	near(HullMesh.wear(0.0), 1.0, 1e-6)
	eq(HullMesh.wear(130.0), 0.0, "сверх 100 % — не в минус")
	ok(not HullMesh.damage_shown(0.0, 0.0), "при целом корпусе нет даже следов с порогом 0")
	ok(HullMesh.damage_shown(0.3, 0.0), "след с порогом 0 — с первых потерь")
	ok(not HullMesh.damage_shown(0.99, 1.0), "последний порог — только при нулевой прочности")
	ok(HullMesh.damage_shown(1.0, 1.0))


## Доля площади плитки под видимыми следами (альфа > 0,1) при прочности `hull`, по картам из textures/hull.
func _damage_area(col: Image, lvl: Image, hull: float) -> float:
	var d := HullMesh.wear(hull)
	var n := 0
	var all := 0
	for y in range(0, 1024, 4):
		for x in range(0, 1024, 4):
			all += 1
			if col.get_pixel(x, y).a > 0.1 and HullMesh.damage_shown(d, lvl.get_pixel(x, y).r):
				n += 1
	return n / float(all)


func test_damage_maps() -> void:
	var ct: Texture2D = load(HullMesh.DAMAGE_TEX % "povrezhdeniya")
	var lt: Texture2D = load(HullMesh.DAMAGE_TEX % "povrezhdeniya-uroven")
	ok(ct != null and ct.get_width() == 1024 and ct.get_height() == 1024, "цвет следов 1024²")
	ok(lt != null and lt.get_width() == 1024 and lt.get_height() == 1024, "порог 1024²")
	var lvl := lt.get_image()
	ok(not lvl.is_compressed(), "порог без потерного сжатия — назначенные пороги целы")
	ok(not lvl.has_mipmaps(), "порог без mipmap — соседние пороги не смешиваются")
	var col := Image.load_from_file(ProjectSettings.globalize_path(HullMesh.DAMAGE_TEX % "povrezhdeniya"))
	ok(col.detect_alpha() != Image.ALPHA_NONE, "у цвета следов есть прозрачность")
	var a100 := _damage_area(col, lvl, 100.0)
	var a70 := _damage_area(col, lvl, 70.0)
	var a40 := _damage_area(col, lvl, 40.0)
	var a15 := _damage_area(col, lvl, 15.0)
	eq(a100, 0.0, "при 100 % следов нет")
	ok(a70 > 0.08 and a70 < a40 and a40 < a15, "следы растут с потерей: %.3f < %.3f < %.3f" % [a70, a40, a15])
	ok(a15 < 0.45, "при 15 %% следы не сплошные — обшивка читается (%.3f)" % a15)


func test_damage_not_tiled() -> void:
	# issue #406: при 30 % по всему борту читалась ровная сетка одинаковых пятен — соседние плитки 2 м
	# должны отличаться, а доля следов на большом куске борта — остаться как у одной плитки
	var col := Image.load_from_file(ProjectSettings.globalize_path(HullMesh.DAMAGE_TEX % "povrezhdeniya"))
	var lvl := Image.load_from_file(ProjectSettings.globalize_path(HullMesh.DAMAGE_TEX % "povrezhdeniya-uroven"))
	var loss := HullMesh.wear(30.0)
	var steps := 48
	for shift in [Vector2(1, 0), Vector2(0, 1), Vector2(3, 2)]:
		var differ := 0
		var marked := 0
		for j in steps:
			for i in steps:
				var uv := Vector2(i, j) / steps
				var a := HullMesh.damage_alpha(col, lvl, uv, loss) > 0.1
				var b := HullMesh.damage_alpha(col, lvl, uv + shift, loss) > 0.1
				if a or b:
					marked += 1
					if a != b:
						differ += 1
		ok(marked > 0 and differ > marked * 0.4,
			"плитка и её сосед %s различаются: %d из %d точек со следами" % [shift, differ, marked])
	var hit := 0.0
	var all := 0
	for j in 96:
		for i in 96:
			all += 1
			if HullMesh.damage_alpha(col, lvl, Vector2(i, j) / 16.0 + Vector2(0.013, 0.021), loss) > 0.1:
				hit += 1.0
	var one := _damage_area(col, lvl, 30.0)
	var big := hit / all
	ok(big > one * 0.7 and big < one * 1.3, "доля следов на борту 6×6 плиток %.3f — как у плитки %.3f" % [big, one])
	ok(HullMesh.damage_gate(Vector2(0.2, 0.3)) >= 0.0 and HullMesh.damage_gate(Vector2(0.2, 0.3)) <= 1.0)


func test_scene_damage_follows_hull() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var sm: ShaderMaterial = main.hull.body_material(HullPlan.Paint.METAL)
	ok(sm.get_shader_parameter("damage_tex") is Texture2D and sm.get_shader_parameter("damage_lvl") is Texture2D,
		"две карты ART-049 в материале обшивки")
	near(sm.get_shader_parameter("wear"), 0.0, 1e-6, "в начале корпус целый — следов нет")
	near(sm.get_shader_parameter("gate_cell"), HullMesh.DAMAGE_CELL, 1e-6, "шум выбора слоя следов из HullMesh (#406)")
	near(sm.get_shader_parameter("alt_scale"), HullMesh.DAMAGE_ALT_SCALE, 1e-6)
	main.vitals.hull = 40.0
	main.step(1.0 / 30.0)
	near(sm.get_shader_parameter("wear"), HullMesh.wear(main.vitals.hull), 1e-3, "следы по прочности корпуса")
	ok(float(sm.get_shader_parameter("wear")) > 0.55, "при 40 % — потеря около 0,6")
	main.queue_free()
	await frames(1)
