extends TestCase
## Кочки водорослей на дне (`SeabedTufts`, `TuftsView`): гуще на иле, на гальке почти нет, лужайками, с глубиной
## пропадают, свои места (не камни и не створки), стоят на сетке дна, темнее и зеленее дна, «Экономно» — ближе;
## меш пучка смотрит наружу; в `OceanView` — третья россыпь, заготовка под прыжок её тоже считает.

const AT := Vector3(0, -30, 95)   # старт 00


func _filled(s: SeabedStones, at: Vector3) -> void:
	var steps := 0
	while not s.complete(at) and steps < 200:
		s.update(at)
		steps += 1
	s.update(at)


## Точка у дна с наибольшим числом кочек вблизи из нескольких (лужайки — пятнами).
func _rich() -> Vector3:
	var best := AT
	var most := -1
	for p in [AT, Vector3(-40, 0, 60), Vector3(40, 0, 20), Vector3(-80, 0, -40), Vector3(60, 0, -120)]:
		var s := SeabedTufts.new()
		_filled(s, p)
		if s.list.size() > most:
			most = s.list.size()
			best = p
	return best


func test_density_by_ground() -> void:
	ok(SeabedTufts.tuft_density([0.0, 1.0, 0.0]) > 2.0 * SeabedTufts.tuft_density([1.0, 0.0, 0.0]),
			"на иле кочек больше, чем на песке")
	ok(SeabedTufts.tuft_density([0.0, 0.0, 1.0]) < 0.1, "на гальке почти нет")


func test_meadow_patches() -> void:
	var lo := 1.0
	var hi := 0.0
	for i in 200:
		var d := SeabedTufts.meadow(i * 1.7 - 170.0, i * 0.9 - 60.0)
		lo = minf(lo, d)
		hi = maxf(hi, d)
		ok(d >= SeabedTufts.MEADOW_MIN - 1e-6 and d <= 1.0 + 1e-6, "доля лужайки в пределах")
	ok(hi > 0.9 and lo < 0.25, "лужайки пятнами: есть густо (%.2f) и почти пусто (%.2f)" % [hi, lo])


func test_fade_with_depth() -> void:
	eq(SeabedTufts.light_k(30.0), 1.0, "на отмели — полная густота")
	ok(SeabedTufts.light_k(75.0) > 0.0 and SeabedTufts.light_k(75.0) < 1.0, "глубже — редеют")
	eq(SeabedTufts.light_k(SeabedTufts.DEEP.y), 0.0, "к DEEP.y — нет совсем")
	eq(SeabedTufts.light_k(200.0), 0.0, "на склоне к 10 — голое дно")
	# клетки глубже предела пусты
	var s := SeabedTufts.new()
	var found := 0
	for ix in range(-40, 40):
		for iz in range(-40, 40):
			var cx := (ix + 0.5) * SeabedStones.CELL
			var cz := (iz + 0.5) * SeabedStones.CELL
			if -Seabed.height(cx, cz) >= SeabedTufts.DEEP.y:
				found += 1
				eq(s.cell(ix, iz).size(), 0, "клетка на %.0f м пуста" % -Seabed.height(cx, cz))
				if found > 30:
					return


func test_tufts_sit_on_mesh_and_olive() -> void:
	var at := _rich()
	var s := SeabedTufts.new()
	_filled(s, at)
	ok(s.list.size() > 20, "у дна есть кочки: %d" % s.list.size())
	for t in s.list:
		var y := Seabed.mesh_height(t.pos.x, t.pos.z)
		ok(t.pos.y <= y and t.pos.y > y - 0.2 * t.size, "кочка в (%.1f, %.1f) на дне, чуть утоплена" % [t.pos.x, t.pos.z])
		ok(t.size >= SeabedTufts.TUFT_SIZE.x and t.size <= SeabedTufts.TUFT_SIZE.y, "размер в пределах")
		ok(Vector2(t.pos.x - at.x, t.pos.z - at.z).length() <= SeabedTufts.TUFT_RADIUS + SeabedStones.MOVE, "в своём радиусе")
		var g := Seabed.color_at(t.pos.x, y, t.pos.z, 1.0)
		ok(t.color.g >= t.color.b * 1.3, "пучок зеленее, чем синее (олива): %s" % t.color)
		ok(t.color.get_luminance() < g.get_luminance() * 1.2, "не светлее дна заметно")


func test_not_where_stones_or_shells() -> void:
	var a := SeabedTufts.new()
	var others: Array[SeabedStones] = [SeabedStones.new(), SeabedShells.new()]
	var same := 0
	var total := 0
	for ix in range(-12, 12):
		var ca := a.cell(ix, 31)
		total += ca.size()
		for o in others:
			for x in ca:
				for y in o.cell(ix, 31):
					if Vector2(x.pos.x - y.pos.x, x.pos.z - y.pos.z).length() < 0.05:
						same += 1
	eq(same, 0, "свой хеш — кочки не на местах камней и створок (%d кочек)" % total)


func test_same_cells_same_tufts() -> void:
	var a := SeabedTufts.new()
	var b := SeabedTufts.new()
	for ix in range(-5, 5):
		var ca := a.cell(ix, 30)
		var cb := b.cell(ix, 30)
		eq(ca.size(), cb.size(), "клетка %d: столько же кочек" % ix)
		for i in ca.size():
			ok(ca[i].pos.is_equal_approx(cb[i].pos), "и на тех же местах")


func test_not_near_samples() -> void:
	var at := _rich()
	var s := SeabedTufts.new()
	var spot := at + Vector3(2.0, 0.0, 1.0)
	s.set_avoid([spot] as Array[Vector3])
	_filled(s, at)
	for t in s.list:
		ok(Vector2(t.pos.x - spot.x, t.pos.z - spot.z).length() >= SeabedStones.SAMPLE_GAP, "у образца кочек нет")


func test_lite_closer() -> void:
	var at := _rich()
	var s := SeabedTufts.new()
	_filled(s, at)
	var full := s.list.size()
	s.set_lite(true)
	_filled(s, at)
	ok(s.list.size() < full * 0.6, "«Экономно» — меньше кочек: %d из %d" % [s.list.size(), full])
	for t in s.list:
		ok(Vector2(t.pos.x - at.x, t.pos.z - at.z).length() <= SeabedTufts.TUFT_LITE + SeabedStones.MOVE, "и ближе")


func test_tuft_mesh_faces_out() -> void:
	var m := TuftsView.tuft_mesh()
	var a: Array = m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	eq(v.size(), TuftsView.BLADES * 3 * 3, "три грани на лопасть")
	for i in range(0, v.size(), 3):
		var blade := i / 9
		var tip := v[i + 2] if v[i + 2].y > 0.5 else (v[i + 1] if v[i + 1].y > 0.5 else v[i])
		var c := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		# середина лопасти: от основания (y = 0, среднее трёх точек основания ≈ корень) к верхушке
		var root := Vector3.ZERO
		var base_n := 0
		for j in 9:
			var p := v[blade * 9 + j]
			if p.y < 0.01:
				root += p
				base_n += 1
		root /= float(base_n)
		var nrm := (v[i + 2] - v[i]).cross(v[i + 1] - v[i])   # наружу при обходе по часовой
		ok(nrm.dot(c - (root + tip) * 0.5) > 0.0, "грань %d смотрит наружу" % (i / 3))
		ok(c.y >= 0.0 and c.y <= 1.0, "грань в высоте пучка")


func test_view_in_ocean() -> void:
	var view := TuftsView.new()
	tree.root.add_child(view)
	eq(str(view.name), "Кочки на дне", "свой узел")
	ok(view.stones is SeabedTufts, "свой список — кочки")
	eq(view.multimesh.mesh.get_faces().size(), TuftsView.BLADES * 3 * 3, "меш — пучок, не камень")
	var at := _rich()
	while not view.stones.complete(at):
		view.follow(at)
	view.follow(at)
	ok(view.multimesh.visible_instance_count > 20, "кочки видны: %d" % view.multimesh.visible_instance_count)
	eq(view.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "тени не отбрасывает")
	view.queue_free()
	await frames(1)


func test_ocean_has_third_scatter() -> void:
	var ocean := OceanView.new()
	tree.root.add_child(ocean)
	await frames(1)
	ok(ocean.tufts is TuftsView, "кочки в океане")
	eq(ocean.scatters().size(), 3, "три россыпи: камни, ракушки, кочки")
	ok(ocean.scatters()[2] == ocean.tufts.stones, "третья — кочки")
	ocean.set_stones_lite(true)
	ok(ocean.tufts.stones.lite, "«Экономно» — и у кочек")
	ocean.set_stones_lite(false)
	var spot := _rich()
	ocean.set_floor_avoid([spot] as Array[Vector3])
	eq(ocean.tufts.stones.avoid.size(), 1, "образцы — и у кочек")
	# заготовка под прыжок досчитывает все три россыпи, не больше CELLS_STEP за шаг
	var far := spot + Vector3(30.0, 0.0, 0.0)
	var own := 0
	while own < 200 and not ocean.scatters().all(func(v: SeabedStones) -> bool: return v.complete(spot)):
		ocean.set_ship(spot, 0.0)   # своя россыпь корабля досчитана — дальше шаги только заготовки
		own += 1
	var worst := 0
	var steps := 0
	while not ocean.prefetch(far) and steps < 400:
		var done := ocean.scatter_cells()
		ocean.set_ship(spot, 0.0)
		worst = maxi(worst, ocean.scatter_cells() - done)
		steps += 1
	ok(ocean.prefetch(far), "заготовка готова за %d шагов" % steps)
	ok(ocean.tufts.stones.complete(far), "и у кочек клетки в кэше")
	ok(worst <= SeabedStones.CELLS_STEP, "за шаг клеток не больше CELLS_STEP: %d" % worst)
	ocean.queue_free()
	await frames(1)
