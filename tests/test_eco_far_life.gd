extends TestCase
## Жизнь вдали (docs/grafika-plan-eco.md, Б5 «Плотнее фоновая жизнь вдали»): тёмные силуэты рыб в кольце 40…125 м
## от корабля, стайки стоят в мире (плитка по отмели), формула от времени — у гостя то же; один MultiMesh без
## нового шейдера, «Экономно» — скрыт.

const FLAT := -40.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _shown(tr: Transform3D) -> bool:
	return tr.basis.x.length() > 1e-4


func test_ring_fade() -> void:
	eq(EcoFarLife.fade(0.0), 0.0, "у корабля силуэтов нет")
	eq(EcoFarLife.fade(EcoFarLife.NEAR_IN - 1.0), 0.0, "ближе кольца — нет")
	near(EcoFarLife.fade(75.0), 1.0, 1e-6, "в кольце — полный размер")
	eq(EcoFarLife.fade(EcoFarLife.FAR_OUT + 1.0), 0.0, "дальше кольца — нет")
	var a := EcoFarLife.fade(EcoFarLife.NEAR_IN + 3.0)
	ok(a > 0.0 and a < 0.2, "растёт плавно, а не появляется сразу")
	ok(EcoFarLife.TILE > 2.0 * EcoFarLife.FAR_OUT, "в кольце — одна копия стайки")


func test_count_and_layout() -> void:
	eq(EcoFarLife.count(), EcoFarLife.SMALL * EcoFarLife.FISH + EcoFarLife.BIG * EcoFarLife.PAIR)
	var last := EcoFarLife.schools() - 1
	eq(EcoFarLife.first(last) + EcoFarLife.size_of(last), EcoFarLife.count(), "стайки плотно в буфере")
	eq(EcoFarLife.first(EcoFarLife.SMALL), EcoFarLife.SMALL * EcoFarLife.FISH, "крупные — после мелких")
	ok(EcoFarLife.length_of(0, 0) < 1.0 and EcoFarLife.length_of(last, 0) > 2.0, "мелкие и крупные")


func test_inside_ring_always_some() -> void:
	# куда бы корабль ни встал — вокруг кто-то плывёт
	for s in [Vector3.ZERO, Vector3(120, -30, -60), Vector3(-250, -30, 190), Vector3(37, -30, 400)]:
		var n := 0
		for i in EcoFarLife.schools():
			for j in EcoFarLife.size_of(i):
				var tr := EcoFarLife.xform(i, j, 10.0, s, _flat)
				if _shown(tr):
					n += 1
					var d := Vector2(tr.origin.x - s.x, tr.origin.z - s.z).length()
					ok(d > EcoFarLife.NEAR_IN - 12.0 and d < EcoFarLife.FAR_OUT + 12.0, "силуэт в кольце: %.1f" % d)
					ok(tr.origin.y >= FLAT + EcoFarLife.ABOVE - 1e-3 and tr.origin.y <= EcoFarLife.CEIL + 1e-3, "над дном и подо льдом")
		ok(n >= 6, "у %s видно силуэтов: %d" % [s, n])


func test_world_fixed_and_moving() -> void:
	# стайка стоит в мире: корабль сдвинулся на 5 м — силуэт там же; время идёт — плывёт носом вперёд
	var ship := Vector3.ZERO
	var found := false
	for i in EcoFarLife.schools():
		var a := EcoFarLife.xform(i, 0, 20.0, ship, _flat)
		if not _shown(a):
			continue
		var b := EcoFarLife.xform(i, 0, 20.0, ship + Vector3(5, 0, 0), _flat)
		if not _shown(b):
			continue
		found = true
		near(a.origin.distance_to(b.origin), 0.0, 1e-3, "сдвиг корабля не двигает стайку")
		var c := EcoFarLife.center(i, 20.0)
		var c2 := EcoFarLife.center(i, 21.0)
		var v := Vector2(c2.x - c.x, c2.z - c.z)
		var circ := EcoFarLife.circle(i)
		near(v.length(), circ.y, 0.05 * circ.y + 0.01, "скорость по кругу")
		var nose := Vector2(-sin(c.y), -cos(c.y))
		ok(nose.dot(v.normalized()) > 0.95, "нос — по ходу")
		break
	ok(found, "нашлась видимая стайка")


func test_same_on_guest() -> void:
	# формула времени и места — второй вызов (у гостя) даёт то же
	var s := Vector3(30, -30, -40)
	for i in EcoFarLife.schools():
		var a := EcoFarLife.xform(i, 1, 33.3, s, _flat)
		var b := EcoFarLife.xform(i, 1, 33.3, s, _flat)
		eq(a, b, "стайка %d" % i)


func test_wrap_copy() -> void:
	var t := EcoFarLife.TILE
	var p := EcoFarLife.near_copy(Vector2(10, 10), Vector2(t * 3.0 + 5.0, -t * 2.0))
	near(p.x, t * 3.0 + 10.0, 1e-3, "копия по x")
	near(p.y, -t * 2.0 + 10.0, 1e-3, "копия по z")


func test_mesh_faces_out() -> void:
	var m := FarLifeView.build()
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	ok(v.size() > 0 and v.size() % 3 == 0 and n.size() == v.size(), "треугольники с нормалями")
	for i in range(0, v.size(), 3):
		ok((v[i + 1] - v[i]).cross(v[i + 2] - v[i]).dot(n[i]) < 0.0, "грань %d: лицом по нормали" % (i / 3))
	var box := m.get_aabb()
	near(box.size.z, 1.02, 0.05, "длина 1 м")
	ok(box.position.z < -0.45, "нос в −Z")


func test_view_one_mesh_no_new_shader() -> void:
	var view := EcoView.new()
	tree.root.add_child(view)
	await frames(1)
	var fv := view.far_view
	ok(fv != null and fv.get_parent() == view, "у мира — «Жизнь вдали»")
	eq(fv.mm.multimesh.instance_count, EcoFarLife.count())
	eq(fv.mm.layers, OceanView.LAYER_WORLD)
	eq(fv.mm.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := fv.mm.multimesh.mesh.surface_get_material(0)
	eq(ShaderKey.of(mat), ShaderKey.of(KrabView.build_spine().surface_get_material(1)), "шейдер кончиков игл — нового нет")
	var ship := EcoLink.ShipState.new()
	for k in FarLifeView.EVERY:
		view.step(0.05, ship)
	var shown := 0
	for k in EcoFarLife.count():
		if Vector3(fv.buffer[k * 16], fv.buffer[k * 16 + 4], fv.buffer[k * 16 + 8]).length() > 1e-4:
			shown += 1
			ok(fv.buffer[k * 16 + 12] < 0.1, "силуэт тёмный")
	ok(shown >= 6, "силуэты в буфере: %d" % shown)
	view.set_lite(true)
	ok(not fv.visible, "«Экономно» — силуэтов нет")
	view.set_lite(false)
	ok(fv.visible, "вернулись")
	tree.root.remove_child(view)
	view.free()


func test_view_schools_take_turns() -> void:
	# стайка переписывается раз в EVERY кадров, за EVERY кадров — все
	var fv := FarLifeView.new()
	var ship := Vector3.ZERO
	var seen := {}
	for f in FarLifeView.EVERY:
		var before := fv.buffer.duplicate()
		fv.sync(5.0 + f, ship, _flat)
		var changed := {}
		for i in EcoFarLife.schools():
			var a := EcoFarLife.first(i) * FarLifeView.STRIDE
			for q in 12:
				if not is_equal_approx(before[a + q], fv.buffer[a + q]):
					changed[i] = true
		for i in changed:
			ok(not seen.has(i), "стайка %d — раз за круг" % i)
			seen[i] = true
	var visible := 0
	for i in EcoFarLife.schools():
		if EcoFarLife.school_at(i, 5.0, ship, _flat)[4] > 0.0:
			visible += 1
	ok(seen.size() >= visible - 1 and visible > 0, "за круг переписаны видимые: %d из %d" % [seen.size(), visible])
	fv.free()


## Склон 06→10 (#832): жизнь редеет с глубиной дна — на отмели все стайки, внизу склона — около четверти, крупных
## пар нет; стайка гаснет плавно.
func test_thins_with_depth() -> void:
	var n := EcoFarLife.schools()
	for i in n:
		eq(EcoFarLife.thin(i, -40.0), 1.0, "на отмели стайка %d целиком" % i)
		eq(EcoFarLife.thin(i, EcoFarLife.THIN_FROM + 1.0), 1.0, "до начала склона — тоже")
	var prev := float(n) + 1.0
	for y in [-120.0, -160.0, -200.0, -250.0, -300.0]:
		var sum := 0.0
		for i in n:
			sum += EcoFarLife.thin(i, y)
		ok(sum <= prev + 1e-6, "глубже — не больше жизни (%.0f м: %.2f)" % [y, sum])
		prev = sum
	var bottom := 0.0
	for i in n:
		bottom += EcoFarLife.thin(i, -306.0)
		if EcoFarLife.is_big(i):
			eq(EcoFarLife.thin(i, -306.0), 0.0, "крупные пары внизу склона уходят")
	ok(bottom < n * 0.45, "внизу склона жизни меньше половины (%.2f из %d)" % [bottom, n])
	var mid := 0
	for i in n:
		for y in range(-120, -310, -2):
			var k := EcoFarLife.thin(i, float(y))
			if k > 0.0 and k < 1.0:
				mid += 1
	ok(mid > 0, "есть промежуточные доли — гаснет плавно")


## У места 10 на дне склона силуэтов вокруг корабля заметно меньше, чем на отмели (над стенами котловины дно
## высоко — там стайки остаются).
func test_fewer_at_place_10() -> void:
	var shelf := 0
	var deep := 0
	var ship := Vector3(560, -290, 200)
	for t in [0.0, 40.0, 90.0, 160.0]:
		for i in EcoFarLife.schools():
			for j in EcoFarLife.size_of(i):
				if _shown(EcoFarLife.xform(i, j, t, ship, Callable(self, "_flat"))):
					shelf += 1
				if _shown(EcoFarLife.xform(i, j, t, ship, Seabed.height)):
					deep += 1
	ok(shelf > 0, "на ровной отмели вокруг кто-то есть")
	ok(deep * 10 < shelf * 7, "у 10 жизни меньше на треть и больше (%d против %d)" % [deep, shelf])
