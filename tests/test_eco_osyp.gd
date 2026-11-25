extends TestCase
## Каменная крошка, осыпи и валуны у дна (#2108, часть 3; схема участков PR #2111): камни на дне в кольце
## до 55 м, плотность по участкам маршрута 00 → 01 → 07 (ось без валунов, края гуще, у рифа плотнее всех,
## у врат реже); неподвижны и в мире — у гостя то же; один MultiMesh, камень освещается, «Экономно» — скрыт.

const FLAT := -40.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _shown(tr: Transform3D) -> bool:
	return tr.basis.x.length() > 1e-4


func test_ring_fade() -> void:
	near(EcoOsyp.fade(0.0), 1.0, 1e-6, "у корабля камни есть (лежат на дне, через корпус не летят)")
	near(EcoOsyp.fade(EcoOsyp.FAR_FULL - 1.0), 1.0, 1e-6, "в кольце — полный размер")
	eq(EcoOsyp.fade(EcoOsyp.FAR_OUT + 1.0), 0.0, "дальше кольца — нет")
	var a := EcoOsyp.fade(EcoOsyp.FAR_FULL + 4.0)
	ok(a > 0.0 and a < 1.0, "гаснет плавно, а не обрывается")
	ok(EcoOsyp.TILE > 2.0 * EcoOsyp.FAR_OUT, "в кольце — одна копия пятна")


func test_lane_free_of_boulders() -> void:
	# валун только у края полосы (band ≥ VALUN_BAND); на оси и в полосе хода — крошка и камни
	var big := 0
	for k in EcoOsyp.count():
		ok(EcoOsyp.size_of(k, 0.0) < EcoOsyp.VAL_MIN, "на оси маршрута валуна нет: %d" % k)
		ok(EcoOsyp.size_of(k, EcoOsyp.VALUN_BAND - 0.05) < EcoOsyp.VAL_MIN, "в полосе хода валуна нет: %d" % k)
		if EcoOsyp.size_of(k, 1.0) >= EcoOsyp.VAL_MIN:
			big += 1
	ok(big > 0, "валуны у краёв бывают: %d" % big)
	ok(big < EcoOsyp.count() / 4, "валуны — редкость: %d" % big)


func test_weight_by_sections() -> void:
	# у рифа 01 — плотнее всех; в стороне от маршрута — фон; край перегона 01 → 07 — средняя; у врат — реже
	near(EcoOsyp.weight(EcoOsyp.REEF), EcoOsyp.REEF_K, 1e-6, "у подошвы рифа — самая плотная")
	near(EcoOsyp.weight(Vector2(300.0, 300.0)), EcoOsyp.AMBIENT, 1e-6, "в стороне от маршрута — фон")
	var n5 := Vector2(190.0, -140.0).normalized()   # нормаль к оси 01 → 07
	var axis5 := Vector2(-30.0, -145.0)
	near(EcoOsyp.weight(axis5), EcoOsyp.AMBIENT, 1e-6, "ось перегона 01 → 07 свободна")
	var band5 := axis5 + n5 * 20.0
	near(EcoOsyp.weight(band5), 0.6, 1e-6, "край перегона 01 → 07 — гряды с осыпями")
	var hollow := Vector2(26.5, 0.5)   # середина ложбины (20;23)→(33;−22) — плато стыка отрезков, не ось
	near(EcoOsyp.weight(hollow), 0.25, 1e-6, "ложбина — редкий детрит")
	ok(EcoOsyp.weight(hollow) < EcoOsyp.weight(band5), "ложбина реже края перегона 01 → 07")
	var gate_n := EcoOsyp.GATE + Vector2(140.0, 190.0).normalized() * 20.0 + n5 * 20.0
	near(EcoOsyp.weight(gate_n), 0.6 * EcoOsyp.GATE_K, 0.03, "у врат — приглушено")


func test_density_scales_with_weight() -> void:
	# доля камней в пятне растёт с weight участка (хеш против weight), а не размером
	var s_lo := PackedFloat32Array([10.0, 10.0, 1.0, FLAT, 0.12, 1.0])
	var s_hi := PackedFloat32Array([10.0, 10.0, 1.0, FLAT, 0.9, 1.0])
	var lo := 0
	var hi := 0
	for i in EcoOsyp.PATCHES:
		for j in EcoOsyp.PER:
			if _shown(EcoOsyp.stone(i, j, s_hi, _flat)):
				hi += 1
			if _shown(EcoOsyp.stone(i, j, s_lo, _flat)):
				lo += 1
	ok(hi > lo * 3, "плотный участок заметно гуще: %d против %d" % [hi, lo])
	ok(lo > 0, "и на фоне камни бывают: %d" % lo)


func test_visible_on_route() -> void:
	# на маршруте у 01 и в середине 01 → 07 из кресла видны осыпи
	for s in [Vector3(40, -42, -50), Vector3(-30, -40, -145), Vector3(12, -38, 51.5)]:
		var n := 0
		for i in EcoOsyp.PATCHES:
			for j in EcoOsyp.PER:
				var tr := EcoOsyp.xform(i, j, s, _flat)
				if _shown(tr):
					n += 1
					var d := Vector2(tr.origin.x - s.x, tr.origin.z - s.z).length()
					ok(d < EcoOsyp.FAR_OUT + 12.0, "камень в кольце: %.1f" % d)
		ok(n >= 10, "у %s видно камней: %d" % [s, n])


func test_rest_on_ground() -> void:
	# видимый камень лежит на дне: центр выше дна не более чем на радиус, утоплен на SINK
	var s := Vector3(40, -42, -50)
	var n := 0
	for i in EcoOsyp.PATCHES:
		for j in EcoOsyp.PER:
			var tr := EcoOsyp.xform(i, j, s, _flat)
			if not _shown(tr):
				continue
			n += 1
			ok(tr.origin.y > FLAT - 1e-3, "не ниже дна: %.2f" % tr.origin.y)
			ok(tr.origin.y <= FLAT + EcoOsyp.VAL_MAX, "не парит: %.2f" % tr.origin.y)
	ok(n > 0, "видимые камни у 01 есть")


func test_static_in_world() -> void:
	# камень стоит в мире: корабль сдвинулся на 5 м — камень там же (времени в формуле нет)
	var ship := Vector3(40, -42, -50)
	var found := false
	for i in EcoOsyp.PATCHES:
		for j in EcoOsyp.PER:
			var a := EcoOsyp.xform(i, j, ship, _flat)
			if not _shown(a):
				continue
			var b := EcoOsyp.xform(i, j, ship + Vector3(5, 0, 0), _flat)
			if not _shown(b):
				continue
			found = true
			near(a.origin.distance_to(b.origin), 0.0, 1e-3, "сдвиг корабля не двигает камень")
			break
		if found:
			break
	ok(found, "нашёлся видимый камень")


func test_same_on_guest() -> void:
	# формула места — второй вызов (у гостя) даёт то же
	var s := Vector3(-30, -40, -145)
	for i in EcoOsyp.PATCHES:
		for j in EcoOsyp.PER:
			eq(EcoOsyp.xform(i, j, s, _flat), EcoOsyp.xform(i, j, s, _flat), "камень %d/%d" % [i, j])


func test_count_and_budget() -> void:
	eq(EcoOsyp.count(), EcoOsyp.PATCHES * EcoOsyp.PER)
	ok(EcoOsyp.count() <= 400, "потолок фона: %d экземпляров" % EcoOsyp.count())
	var m := OsypView.build()
	var tris: int = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3
	eq(tris, 20, "икосаэдр — 20 граней")
	ok(EcoOsyp.count() * tris <= 8000, "треугольников в кадре: %d" % (EcoOsyp.count() * tris))


func test_mesh_lit_and_outward() -> void:
	# камень ловит прожектор (без света — только светящееся, test_eco_lit) и грани смотрят наружу
	var m := OsypView.build()
	var mat := m.surface_get_material(0) as BaseMaterial3D
	ok(mat != null and mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED, "камень освещается")
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	eq(n.size(), v.size(), "нормали у всех вершин")
	for i in range(0, v.size(), 3):
		var mid := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		ok(n[i].dot(mid) > 0.0, "нормаль наружу")
		ok((v[i + 1] - v[i]).cross(v[i + 2] - v[i]).dot(mid) < 0.0, "обход по часовой снаружи")


func test_view_one_multimesh_and_lite() -> void:
	var v := OsypView.new()
	tree.root.add_child(v)
	await frames(1)
	var mms := 0
	for c in v.get_children():
		if c is MultiMeshInstance3D:
			mms += 1
	eq(mms, 1, "один MultiMesh — один вызов отрисовки")
	eq(v.mm.multimesh.instance_count, EcoOsyp.count(), "все экземпляры в буфере")
	ok(v.visible, "на «Обычно» виден")
	v.set_lite(true)
	ok(not v.visible, "«Экономно» — скрыт")
	v.queue_free()


func test_view_refills_only_on_copy_switch() -> void:
	# камни неподвижны: без смены копии плитки буфер не переписывается (дешёвый кадр)
	var v := OsypView.new()
	tree.root.add_child(v)
	await frames(1)
	var ship := Vector3(40, -42, -50)
	v.sync(ship, _flat)
	var first := v.buffer
	v.sync(ship, _flat)   # тот же корабль — те же копии, записи нет
	eq(v.buffer, first, "повторный sync без движения ничего не меняет")
	v.sync(ship + Vector3(3, 0, 0), _flat)   # в пределах тех же копий — буфер стоит
	eq(v.buffer, first, "3 м по плитке — копии те же, буфер стоит")
	v.queue_free()
