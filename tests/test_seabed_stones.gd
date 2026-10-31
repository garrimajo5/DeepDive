extends TestCase
## Камни на дне (`SeabedStones`, `StonesView`): детерминированно, гуще на гальке, лежат на сетке дна, не у образцов,
## клетки по нескольку за шаг, у края мельчают, «Экономно» — ближе.

const AT := Vector3(0, -30, 95)   # старт 00


func _filled(s: SeabedStones, at: Vector3) -> int:
	var steps := 0
	while not s.complete(at) and steps < 200:
		s.update(at)
		steps += 1
	s.update(at)
	return steps


func test_same_cells_same_stones() -> void:
	var a := SeabedStones.new()
	var b := SeabedStones.new()
	for ix in range(-5, 5):
		var ca := a.cell(ix, 30)
		var cb := b.cell(ix, 30)
		eq(ca.size(), cb.size(), "клетка %d: столько же камней" % ix)
		for i in ca.size():
			ok(ca[i].pos.is_equal_approx(cb[i].pos), "и на тех же местах")


func test_density_by_ground() -> void:
	ok(SeabedStones.density([0.0, 0.0, 1.0]) > 10.0 * SeabedStones.density([1.0, 0.0, 0.0]),
			"на гальке камней на порядок больше, чем на песке")
	ok(SeabedStones.density([0.0, 1.0, 0.0]) < SeabedStones.density([0.0, 0.0, 1.0]), "ил — реже гальки")


func test_stones_sit_on_mesh() -> void:
	var s := SeabedStones.new()
	_filled(s, AT)
	ok(s.list.size() > 60, "у старта есть камни: %d" % s.list.size())
	ok(s.list.size() <= SeabedStones.MAX, "не больше ёмкости")
	for st in s.list:
		var y := Seabed.mesh_height(st.pos.x, st.pos.z)
		ok(st.pos.y < y and st.pos.y > y - st.size, "камень в (%.1f, %.1f) лежит на дне, утоплен меньше размера" % [st.pos.x, st.pos.z])
		ok(st.size >= SeabedStones.SIZE.x and st.size <= SeabedStones.SIZE.y, "размер в пределах")


func test_not_near_samples() -> void:
	var s := SeabedStones.new()
	var spot := Vector3(3.0, 0.0, 96.0)
	s.set_avoid([spot] as Array[Vector3])
	_filled(s, AT)
	for st in s.list:
		ok(Vector2(st.pos.x - spot.x, st.pos.z - spot.z).length() >= SeabedStones.SAMPLE_GAP, "у образца камней нет")


func test_jump_fills_at_once() -> void:
	var s := SeabedStones.new()
	s.update(AT)
	ok(s.complete(AT), "первый шаг (центр издалека — старт, загрузка) — радиус сразу")
	var to := AT + Vector3(SeabedStones.JUMP + 5.0, 0, 0)
	s.update(to)
	ok(s.complete(to), "перескок дальше JUMP — тоже сразу")


func test_cells_spread_over_steps() -> void:
	var s := SeabedStones.new()
	_filled(s, AT)
	var to := AT + Vector3(0, 0, -SeabedStones.JUMP + 5.0)
	var done := s.cells_done
	s.update(to)
	eq(s.cells_done - done, SeabedStones.CELLS_STEP, "ход — не больше CELLS_STEP новых клеток за шаг")
	ok(not s.complete(to), "радиус ещё не весь")
	var steps := _filled(s, to)
	ok(steps > 3, "радиус досчитан за несколько шагов: %d" % steps)
	_check_still(s, to)


func _check_still(s: SeabedStones, at: Vector3) -> void:
	var done := s.cells_done
	var rev := s.rev
	ok(not s.update(at), "стоим — список тот же")
	eq(s.cells_done, done, "и новых клеток нет")
	eq(s.rev, rev, "рев не растёт")


func test_step_time_bounded() -> void:
	var s := SeabedStones.new()
	_filled(s, AT)
	var worst := 0.0
	for i in 60:   # ход 6 м/с при 30 к/с
		var t := Time.get_ticks_usec()
		s.update(AT + Vector3(0, 0, -0.2 * i))
		worst = maxf(worst, (Time.get_ticks_usec() - t) / 1000.0)
	print("  камни: худший шаг на ходу %.2f мс" % worst)
	ok(worst < 25.0, "шаг на ходу короткий: %.2f мс" % worst)   # с запасом под нагрузку CI (на ПК ≈ 2,7 мс)
	var t0 := Time.get_ticks_usec()
	for i in 30:
		s.update(AT)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 30.0
	ok(ms < 0.5, "стоим — шаг почти даром: %.3f мс" % ms)


func test_follow_ship_and_forget_far() -> void:
	var s := SeabedStones.new()
	_filled(s, AT)
	var far := AT + Vector3(0, 0, -200)
	for i in 400:
		s.update(AT.lerp(far, i / 399.0))
	_filled(s, far)
	for st in s.list:
		ok(Vector2(st.pos.x - far.x, st.pos.z - far.z).length() <= SeabedStones.RADIUS + SeabedStones.MOVE, "камни — вокруг нового места (центр отстаёт не больше MOVE)")
	var n := int(ceilf(SeabedStones.RADIUS / SeabedStones.CELL)) + 1
	ok(s._cache.size() <= 4 * (2 * n + 1) * (2 * n + 1) + 4 * SeabedStones.CELLS_STEP, "кэш не растёт за кораблём")


func test_edge_shrinks() -> void:
	near(SeabedStones.edge_k(0.0, 40.0), 1.0, 1e-6, "в середине — полный размер")
	near(SeabedStones.edge_k(40.0, 40.0), 0.0, 1e-6, "на краю — ноль")
	ok(SeabedStones.edge_k(36.0, 40.0) > 0.0 and SeabedStones.edge_k(36.0, 40.0) < 1.0, "у края — мельче")


func test_lite_closer() -> void:
	var s := SeabedStones.new()
	_filled(s, AT)
	var full := s.list.size()
	s.set_lite(true)
	_filled(s, AT)
	ok(s.list.size() < full * 0.5, "«Экономно» — меньше камней: %d из %d" % [s.list.size(), full])
	for st in s.list:
		ok(Vector2(st.pos.x - AT.x, st.pos.z - AT.z).length() <= SeabedStones.LITE_RADIUS, "и ближе")


func test_rock_mesh_faces_out() -> void:
	var m := StonesView.rock_mesh()
	var a: Array = m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	eq(v.size(), 60, "20 треугольников")
	for i in range(0, v.size(), 3):
		var c := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		ok((v[i + 1] - v[i]).cross(v[i + 2] - v[i]).dot(c) < 0.0, "грань %d: (b − a) × (c − a) внутрь" % (i / 3))


func test_view_writes_on_change() -> void:
	var view := StonesView.new()
	tree.root.add_child(view)
	view.follow(AT)
	var w := view.writes
	ok(w == 1, "первый шаг записал буфер")
	eq(view.multimesh.visible_instance_count, view.stones.list.size(), "видно столько, сколько камней")
	while not view.stones.complete(AT):
		view.follow(AT)
	view.follow(AT)
	var w2 := view.writes
	view.follow(AT)
	eq(view.writes, w2, "стоим — буфер не переписан")
	ok(view.multimesh.visible_instance_count > 60, "камни видны")
	eq(view.layers, OceanView.LAYER_WORLD, "слой отмели")
	view.queue_free()
	await frames(1)
