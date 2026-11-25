extends TestCase
## Фоновая мелочь у дна (#2108, схема участков уровней PR #2111): косячки 6–15 см над дном в кольце 9…45 м,
## плотность по участкам маршрута 00 → 01 → 07 (ось свободна, края гуще, у рифа плотнее всех, у врат реже);
## формула от времени — у гостя то же; один MultiMesh без нового шейдера, «Экономно» — скрыт.

const FLAT := -40.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _shown(tr: Transform3D) -> bool:
	return tr.basis.x.length() > 1e-4


func test_ring_fade() -> void:
	eq(EcoMeloch.fade(0.0), 0.0, "у корабля мелочи нет (не летит через корпус)")
	eq(EcoMeloch.fade(EcoMeloch.NEAR_IN - 1.0), 0.0, "ближе кольца — нет")
	near(EcoMeloch.fade(22.0), 1.0, 1e-6, "в кольце — полный размер")
	eq(EcoMeloch.fade(EcoMeloch.FAR_OUT + 1.0), 0.0, "дальше кольца — нет")
	var a := EcoMeloch.fade(EcoMeloch.NEAR_IN + 2.0)
	ok(a > 0.0 and a < 0.4, "растёт плавно, а не появляется сразу")
	ok(EcoMeloch.TILE > 2.0 * EcoMeloch.FAR_OUT, "в кольце — одна копия пятна")


func test_band_profile() -> void:
	eq(EcoMeloch.band(0.0), 0.0, "ось маршрута свободна")
	eq(EcoMeloch.band(EcoMeloch.LANE - 1.0), 0.0, "полоса хода свободна")
	near(EcoMeloch.band(20.0), 1.0, 1e-6, "край полосы — полная жизнь")
	eq(EcoMeloch.band(EcoMeloch.BAND_OUT + 1.0), 0.0, "дальше края — нет")


func test_weight_by_sections() -> void:
	# у рифа 01 — плотнее всех; ось перегона свободна (фон); край перегона — средняя; ложбина — редкая
	near(EcoMeloch.weight(EcoMeloch.REEF), EcoMeloch.REEF_K, 1e-6, "у подошвы рифа — самая плотная")
	near(EcoMeloch.weight(Vector2(300.0, 300.0)), EcoMeloch.AMBIENT, 1e-6, "в стороне от маршрута — фон")
	var n5 := Vector2(190.0, -140.0).normalized()   # нормаль к оси 01 → 07
	var axis5 := Vector2(-30.0, -145.0)
	near(EcoMeloch.weight(axis5), EcoMeloch.AMBIENT, 1e-6, "ось перегона 01 → 07 свободна")
	var band5 := axis5 + n5 * 18.0
	near(EcoMeloch.weight(band5), 0.5, 1e-6, "край перегона 01 → 07 — средняя жизнь")
	var hollow := Vector2(26.5, 0.5)   # середина ложбины (20;23)→(33;−22)
	near(EcoMeloch.weight(hollow), 0.22, 1e-6, "ложбина — редкая жизнь")
	ok(EcoMeloch.weight(band5) > EcoMeloch.weight(hollow), "перегон 01 → 07 гуще ложбины")
	# у врат (20 м от центра 07 у оси + 18 м в край) — реже, чем в середине перегона (GATE_K)
	var gate_n := EcoMeloch.GATE + Vector2(140.0, 190.0).normalized() * 20.0 + n5 * 18.0
	near(EcoMeloch.weight(gate_n), 0.5 * EcoMeloch.GATE_K, 0.02, "у врат — приглушено")
	ok(EcoMeloch.weight(gate_n) < EcoMeloch.weight(band5), "у врат реже, чем в середине 01 → 07")


func test_inside_ring_on_route_some_visible() -> void:
	# на маршруте у 01 и в середине 01 → 07 из кресла видна мелочь
	for s in [Vector3(40, -42, -50), Vector3(-30, -40, -145), Vector3(12, -38, 51.5)]:
		var n := 0
		for i in EcoMeloch.PATCHES:
			for j in EcoMeloch.PER:
				var tr := EcoMeloch.xform(i, j, 10.0, s, _flat)
				if _shown(tr):
					n += 1
					var d := Vector2(tr.origin.x - s.x, tr.origin.z - s.z).length()
					ok(d > EcoMeloch.NEAR_IN - 12.0 and d < EcoMeloch.FAR_OUT + 12.0, "мелочь в кольце: %.1f" % d)
		ok(n >= 3, "у %s видно мелочи: %d" % [s, n])


func test_above_ground() -> void:
	# вся видимая мелочь — над дном в пределах LOW…HIGH + покачивание
	var s := Vector3(40, -42, -50)
	var n := 0
	for i in EcoMeloch.PATCHES:
		for j in EcoMeloch.PER:
			var tr := EcoMeloch.xform(i, j, 7.0, s, _flat)
			if not _shown(tr):
				continue
			n += 1
			ok(tr.origin.y >= FLAT + EcoMeloch.LOW - 1e-3, "не ниже LOW над дном: %.2f" % tr.origin.y)
			ok(tr.origin.y <= FLAT + EcoMeloch.HIGH + 0.45, "не выше HIGH + покачивание: %.2f" % tr.origin.y)
	ok(n > 0, "видимая мелочь у 01 есть")


func test_world_fixed_and_moving() -> void:
	# пятно стоит в мире: корабль сдвинулся на 5 м — мелочь там же; время идёт — плывёт
	var ship := Vector3(40, -42, -50)
	var found := false
	for i in EcoMeloch.PATCHES:
		for j in EcoMeloch.PER:
			var a := EcoMeloch.xform(i, j, 20.0, ship, _flat)
			if not _shown(a):
				continue
			var b := EcoMeloch.xform(i, j, 20.0, ship + Vector3(5, 0, 0), _flat)
			if not _shown(b):
				continue
			found = true
			near(a.origin.distance_to(b.origin), 0.0, 1e-3, "сдвиг корабля не двигает пятно")
			var c := EcoMeloch.xform(i, j, 21.0, ship, _flat)
			ok(c.origin.distance_to(a.origin) > 0.01, "за секунду проплыла")
			break
		if found:
			break
	ok(found, "нашлась видимая мелочь")


func test_same_on_guest() -> void:
	# формула времени и места — второй вызов (у гостя) даёт то же
	var s := Vector3(-30, -40, -145)
	for i in EcoMeloch.PATCHES:
		for j in EcoMeloch.PER:
			var a := EcoMeloch.xform(i, j, 33.3, s, _flat)
			var b := EcoMeloch.xform(i, j, 33.3, s, _flat)
			eq(a, b, "мелочь %d/%d" % [i, j])


func test_count_and_budget() -> void:
	eq(EcoMeloch.count(), EcoMeloch.PATCHES * EcoMeloch.PER)
	ok(EcoMeloch.count() <= 400, "потолок фона: %d экземпляров" % EcoMeloch.count())
	ok(EcoMeloch.length_of(0, 0) >= 0.05 and EcoMeloch.length_of(0, 0) <= 0.2, "размер — мелочь, не рыба")


func test_view_one_multimesh_and_lite() -> void:
	var v := MelochView.new()
	tree.root.add_child(v)
	await frames(1)
	var mms := 0
	for c in v.get_children():
		if c is MultiMeshInstance3D:
			mms += 1
	eq(mms, 1, "один MultiMesh — один вызов отрисовки")
	eq(v.mm.multimesh.instance_count, EcoMeloch.count(), "все экземпляры в буфере")
	ok(v.visible, "на «Обычно» виден")
	v.set_lite(true)
	ok(not v.visible, "«Экономно» — скрыт")
	v.queue_free()
