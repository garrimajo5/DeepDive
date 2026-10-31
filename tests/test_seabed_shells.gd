extends TestCase
## Ракушки на дне (`SeabedShells`, `ShellsView`): на песке наносами, не в иле, свои места (не камни), лежат на
## сетке дна, светлее дна, ближе камней, «Экономно» — ещё ближе; меш створки смотрит наружу.

const AT := Vector3(0, -30, 95)   # старт 00


func _filled(s: SeabedStones, at: Vector3) -> void:
	var steps := 0
	while not s.complete(at) and steps < 200:
		s.update(at)
		steps += 1
	s.update(at)


## Точка у дна с наибольшим числом ракушек вблизи из нескольких (наносы — полосами).
func _rich() -> Vector3:
	var best := AT
	var most := -1
	for p in [AT, Vector3(-40, 0, 60), Vector3(40, 0, 20), Vector3(-80, 0, -40), Vector3(60, 0, -120)]:
		var s := SeabedShells.new()
		_filled(s, p)
		if s.list.size() > most:
			most = s.list.size()
			best = p
	return best


func test_density_by_ground() -> void:
	ok(SeabedShells.shell_density([1.0, 0.0, 0.0]) > 5.0 * SeabedShells.shell_density([0.0, 0.0, 1.0]),
			"на песке створок много больше, чем на гальке")
	eq(SeabedShells.shell_density([0.0, 1.0, 0.0]), 0.0, "в иле — нет")


func test_drift_patches() -> void:
	var lo := 1.0
	var hi := 0.0
	for i in 200:
		var d := SeabedShells.drift(i * 1.7 - 170.0, i * 0.9 - 60.0)
		lo = minf(lo, d)
		hi = maxf(hi, d)
		ok(d >= SeabedShells.DRIFT_MIN - 1e-6 and d <= 1.0 + 1e-6, "доля наноса в пределах")
	ok(hi > 0.9 and lo < 0.2, "наносы пятнами: есть густо (%.2f) и почти пусто (%.2f)" % [hi, lo])


func test_shells_sit_on_mesh_and_pale() -> void:
	var at := _rich()
	var s := SeabedShells.new()
	_filled(s, at)
	ok(s.list.size() > 20, "у дна есть ракушки: %d" % s.list.size())
	for sh in s.list:
		var y := Seabed.mesh_height(sh.pos.x, sh.pos.z)
		ok(sh.pos.y < y and sh.pos.y > y - sh.size, "створка в (%.1f, %.1f) на дне, утоплена меньше размера" % [sh.pos.x, sh.pos.z])
		ok(sh.size >= SeabedShells.SHELL_SIZE.x and sh.size <= SeabedShells.SHELL_SIZE.y, "размер в пределах")
		ok(Vector2(sh.pos.x - at.x, sh.pos.z - at.z).length() <= SeabedShells.SHELL_RADIUS + SeabedStones.MOVE, "в своём радиусе")
		var g := Seabed.color_at(sh.pos.x, y, sh.pos.z, 1.0)
		ok(sh.color.get_luminance() > g.get_luminance() * 0.9, "створка не темнее дна")


func test_not_where_stones() -> void:
	var a := SeabedShells.new()
	var b := SeabedStones.new()
	var same := 0
	var total := 0
	for ix in range(-10, 10):
		var ca := a.cell(ix, 31)
		var cb := b.cell(ix, 31)
		total += ca.size()
		for x in ca:
			for y in cb:
				if Vector2(x.pos.x - y.pos.x, x.pos.z - y.pos.z).length() < 0.05:
					same += 1
	eq(same, 0, "свой хеш — створки не на местах камней (%d створок)" % total)


func test_same_cells_same_shells() -> void:
	var a := SeabedShells.new()
	var b := SeabedShells.new()
	for ix in range(-5, 5):
		var ca := a.cell(ix, 30)
		var cb := b.cell(ix, 30)
		eq(ca.size(), cb.size(), "клетка %d: столько же створок" % ix)
		for i in ca.size():
			ok(ca[i].pos.is_equal_approx(cb[i].pos), "и на тех же местах")


func test_not_near_samples() -> void:
	var at := _rich()
	var s := SeabedShells.new()
	var spot := at + Vector3(2.0, 0.0, 1.0)
	s.set_avoid([spot] as Array[Vector3])
	_filled(s, at)
	for sh in s.list:
		ok(Vector2(sh.pos.x - spot.x, sh.pos.z - spot.z).length() >= SeabedStones.SAMPLE_GAP, "у образца створок нет")


func test_lite_closer() -> void:
	var at := _rich()
	var s := SeabedShells.new()
	_filled(s, at)
	var full := s.list.size()
	s.set_lite(true)
	_filled(s, at)
	ok(s.list.size() < full * 0.6, "«Экономно» — меньше створок: %d из %d" % [s.list.size(), full])
	for sh in s.list:
		ok(Vector2(sh.pos.x - at.x, sh.pos.z - at.z).length() <= SeabedShells.SHELL_LITE + SeabedStones.MOVE, "и ближе")


func test_shell_mesh_faces_out() -> void:
	var m := ShellsView.shell_mesh()
	var a: Array = m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	eq(v.size(), ShellsView.RIBS * 2 * 3 * 3, "три грани на луч веера")
	var up := 0
	for i in range(0, v.size(), 3):
		var nrm := (v[i + 2] - v[i]).cross(v[i + 1] - v[i])   # наружу при обходе по часовой
		var c := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		ok(nrm.dot(c - Vector3(0, -0.3, -0.05)) > 0.0, "грань %d смотрит наружу" % (i / 3))
		if nrm.y > 0.0:
			up += 1
		ok(c.y >= -1e-4 and c.y <= SeabedShells.SHELL_HEIGHT + 0.05, "грань в высоте чаши")
	eq(up, v.size() / 3, "все грани чаши — вверх (створка выпуклой стороной вверх)")


func test_view_in_ocean() -> void:
	var view := ShellsView.new()
	tree.root.add_child(view)
	eq(str(view.name), "Ракушки на дне", "свой узел")
	ok(view.stones is SeabedShells, "свой список — ракушки")
	eq(view.multimesh.mesh.get_faces().size(), ShellsView.RIBS * 2 * 3 * 3, "меш — створка, не камень")
	var at := _rich()
	while not view.stones.complete(at):
		view.follow(at)
	view.follow(at)
	ok(view.multimesh.visible_instance_count > 20, "ракушки видны: %d" % view.multimesh.visible_instance_count)
	eq(view.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "тени не отбрасывает")
	view.queue_free()
	await frames(1)
