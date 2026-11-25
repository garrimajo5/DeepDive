extends TestCase
## Бортовые посты мостика: пульт энергии с ползунками, сканер биолога, люк в коридор (MOD-005…007).


func test_posts_reachable_and_apart() -> void:
	var posts := Deck.posts()
	var ship := ShipLayout.new()
	for p in posts:
		var reach := false
		for i in 16:  # есть где встать в радиусе поста
			var a := TAU * i / 16.0
			var q := p.at + Vector2(cos(a), sin(a)) * p.r * 0.8
			if ship.can_stand(q.x, q.y) and Deck.nearest(posts, q.x, q.y) == p:
				reach = true
		ok(reach, "к посту «%s» можно подойти" % p.label)
		eq(Deck.nearest(posts, p.at.x, p.at.y).id, p.id, "в центре поста «%s» — он сам" % p.label)


func test_side_panels_block_walk_and_fit_between_ribs() -> void:
	ok(not Deck.can_stand(-4.6, -2.0), "в пульт энергии не войти")
	ok(not Deck.can_stand(4.6, -2.0), "в сканер не войти")
	for z in BridgePlan.RIB_Z:
		ok(absf(z - BridgeProps.SIDE_Z) > 0.6 + 0.09, "ребро борта z %.2f не пересекает пульт" % z)


func test_slider_follows_tilted_face() -> void:
	near(BridgeProps.slider_z(0.75), -0.35, 1e-6, "внизу лица — 0,35 м от стены")
	ok(BridgeProps.slider_z(1.15) > BridgeProps.slider_z(0.85), "выше — ближе к стене")
	near(BridgeProps.slider_y(0.0), BridgeProps.SLIDER_Y_MIN, 1e-6, "доля 0 — внизу")
	near(BridgeProps.slider_y(1.0), BridgeProps.SLIDER_Y_MAX, 1e-6, "доля 1 — вверху")


func test_scene_side_models_and_posts() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var b := main.bridge
	for name in [BridgeProps.ENERGY, BridgeProps.SCANNER, BridgeProps.HATCH_FRAME]:
		ok(b.props.has(name), "модель %s на мостике" % name)
	eq(b.sliders.size(), 5, "пять ползунков")
	var panel: Node3D = b.props[BridgeProps.ENERGY]
	var face := -panel.global_transform.basis.z
	ok(face.x > 0.99, "пульт энергии смотрит в отсек (+X): %s" % str(face))
	b.set_slider(0, 1.0)
	ok(b.sliders[0].position.y > b.sliders[1].position.y, "ползунок двигается")
	# двигатели — левый паз для того, кто стоит лицом к пульту (как пиктограмма вентилятора на модели)
	var cam_right := Vector3(0, 0, -1)   # смотрим на пульт с отсека (в −X): правая рука — к −Z
	ok(b.sliders[0].global_position.dot(cam_right) < b.sliders[4].global_position.dot(cam_right), "двигатели левее прожектора")
	ok(b.hatch_wheel.get_parent() == b.hatch_door, "колесо на створке люка")
	main.walker.x = -3.9
	main.walker.z = -2.0
	var r := main.overlay.router
	r.begin(1, r.layout.action.c)
	r.end(1)
	main.step(0.1)
	ok(main.at_power and main.power_panel.visible, "у пульта открылся пульт энергии")
	var box: Rect2 = main.power_panel.box()   # #349: панель не под тестовой кнопкой noclip и не под кнопкой действия
	for c: Touch.Circle in [r.layout.noclip, r.layout.action]:
		ok(not box.intersects(NameTag.circle_rect(c.c, c.r)), "панель %s не задевает кнопку у %s" % [box, c.c])
	ok(box.size.y > 300.0, "пять строк помещаются: %.0f px" % box.size.y)
	r.begin(5, r.layout.action.c)
	r.end(5)
	main.step(0.1)
	ok(not main.at_power and not main.power_panel.visible, "кнопка закрывает пульт")
	main.walker.x = 0.0
	main.walker.z = 1.4
	r.begin(2, r.layout.action.c)
	r.end(2)
	main.step(0.1)
	ok(main.layout.doors[0].open, "кнопка у люка открывает его")


## Числа из объявления шейдера (vec2(…) или {…, …}) — списком float.
static func _shader_floats(src: String, decl: String) -> Array[float]:
	var out: Array[float] = []
	var re := RegEx.create_from_string("const\\s+\\w+\\s+" + decl + "(\\[\\d+\\])?\\s*=\\s*(?:vec2\\()?\\{?([^;\\)\\}]+)")
	var m := re.search(src)
	if m:
		for part in m.get_string(2).split(","):
			out.append(part.strip_edges().to_float())
	return out


func test_power_columns_window_matches_shader() -> void:
	## Окно полос и колонки в tex_glow.gdshader — те же числа, что в BridgeProps (#2102): расходятся —
	## срез свечения уедет с полос.
	var src := FileAccess.get_file_as_string("res://shaders/tex_glow.gdshader")
	var y := _shader_floats(src, "STRIP_Y")
	eq(y.size(), 2, "STRIP_Y — два числа")
	if y.size() == 2:
		near(y[0], BridgeProps.STRIP_Y.x, 1e-6, "низ окна")
		near(y[1], BridgeProps.STRIP_Y.y, 1e-6, "верх окна")
	var half := _shader_floats(src, "STRIP_HALF")
	eq(half.size(), 1, "STRIP_HALF — одно число")
	if half.size() == 1:
		near(half[0], BridgeProps.STRIP_HALF, 1e-6, "полуширина колонки")
	var xs := _shader_floats(src, "STRIP_X")
	eq(xs.size(), 5, "STRIP_X — пять колонок")
	for i in mini(xs.size(), BridgeProps.STRIP_X.size()):
		near(xs[i], BridgeProps.STRIP_X[i], 1e-6, "колонка %d по x" % i)


func test_power_columns_window_covers_strips() -> void:
	## Окно STRIP_Y накрывает светящиеся полосы модели пульта (#2102): растеризация треугольников,
	## точки с голубым текселем (TextureGlow.glows) в колонке по x — в окне с запасом и тянутся за его середину.
	var scene: PackedScene = load("res://models/pult-energii.glb")
	var n: Node3D = scene.instantiate()
	tree.root.add_child(n)
	var mi: MeshInstance3D
	for c in n.find_children("*", "MeshInstance3D", true, false):
		mi = c
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var img := (mi.get_active_material(0) as BaseMaterial3D).albedo_texture.get_image()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var col_y := []
	for i in 5:
		col_y.append([])
	const STEPS := 8
	for t in range(0, idx.size(), 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		for i in STEPS + 1:
			for j in STEPS + 1 - i:
				var wa := 1.0 - float(i + j) / STEPS
				var wb := float(i) / STEPS
				var wc := float(j) / STEPS
				var uv := uvs[a] * wa + uvs[b] * wb + uvs[c] * wc
				var px := img.get_pixel(clampi(int(uv.x * w), 0, w - 1), clampi(int(uv.y * h), 0, h - 1))
				if not TextureGlow.glows(px):
					continue
				var p := verts[a] * wa + verts[b] * wb + verts[c] * wc
				if p.z >= -0.2:
					continue   # лицо с полосами глубже; у задней плоскости — другие огни
				for k in 5:
					if absf(p.x - BridgeProps.STRIP_X[k]) < BridgeProps.STRIP_HALF + 0.002:
						col_y[k].append(p.y)
						break
	var total := 0
	for k in 5:
		var ys: Array = col_y[k]
		total += ys.size()
		ok(ys.size() >= 100, "колонка %d: светящихся точек %d ≥ 100" % [k, ys.size()])
		if ys.is_empty():
			continue
		ys.sort()
		var ymin: float = ys[0]
		var ymax: float = ys[ys.size() - 1]
		ok(ymin > BridgeProps.STRIP_Y.x - 0.04, "колонка %d: низ %.3f в окне %.2f" % [k, ymin, BridgeProps.STRIP_Y.x])
		ok(ymax < BridgeProps.STRIP_Y.y + 0.04, "колонка %d: верх %.3f в окне %.2f" % [k, ymax, BridgeProps.STRIP_Y.y])
		var p90: float = ys[int(0.9 * (ys.size() - 1))]
		var mid := BridgeProps.STRIP_Y.x + (BridgeProps.STRIP_Y.y - BridgeProps.STRIP_Y.x) * 0.5
		ok(p90 > mid, "колонка %d: полоса тянется за середину окна (%.3f > %.3f)" % [k, p90, mid])
	ok(total > 500, "всего светящихся точек %d > 500" % total)
	n.queue_free()
	await frames(1)


func test_power_columns_follow_share() -> void:
	## Светящаяся часть столбика = доле системы (#2102): у пульта — материал с отсечением (level_k),
	## uniform levels идёт за долями реактора; без правки материала нет — тест красный.
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var b := main.bridge
	ok(b.power_mat != null, "у пульта энергии — материал с отсечением свечения по доле")
	if b.power_mat == null:
		main.queue_free()
		await frames(1)
		return
	near(b.power_mat.get_shader_parameter("level_k") as float, 1.0, 1e-6, "отсечение по доле включено")
	var lv := b.power_mat.get_shader_parameter("levels") as PackedFloat32Array
	eq(lv.size(), 5, "пять долей")
	main.step(0.1)   # доли реактора пошли в ползунки и свечение (Main._step_view)
	lv = b.power_mat.get_shader_parameter("levels") as PackedFloat32Array
	for i in 5:
		near(lv[i], main.reactor.share[i] / float(Reactor.MAX), 1e-4, "столбик %d — по доле системы" % i)
	b.set_slider(2, 1.0)
	near((b.power_mat.get_shader_parameter("levels") as PackedFloat32Array)[2], 1.0, 1e-6, "доля 1 — полный столбик")
	b.set_slider(2, 0.0)
	near((b.power_mat.get_shader_parameter("levels") as PackedFloat32Array)[2], 0.0, 1e-6, "доля 0 — погашен")
	main.queue_free()
	await frames(1)
