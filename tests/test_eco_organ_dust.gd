extends TestCase
## Выдох трубного органа (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): в такт гулу трубы выпускают над устьями
## облачка отцеженной мути — вдали от корабля не каждый такт и слабо, корабль рядом — каждый такт и гуще; дальние
## от корабля и «Экономно» не дышат; при том же времени мира выдохи те же; в сцене — свой MultiMesh на общем шейдере.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	w.add(EcoOrgan.new())
	return w


func _org(w: EcoWorld) -> EcoOrgan:
	return w.systems[0] as EcoOrgan


## Время идёт secs секунд кадрами по 1/30 с от t0, выдохи шагают за ним; корабль — в ship.
func _run(o: EcoOrgan, d: EcoOrganDust, t0: float, secs: float, ship: Vector3) -> float:
	var t := t0
	d.update(o, t, ship)
	while t < t0 + secs - 1e-6:
		t += 1.0 / 30.0
		d.update(o, t, ship)
	return t


func test_breath_over_tube_mouths() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var o := _org(w)
	var og := o.organs[0]
	var ship := og.base + Vector3(0, 8, 40)   # дальше гула, ближе 80 м
	var d := EcoOrganDust.new()
	var t := _run(o, d, 0.0, 40.0, ship)
	var cycles := int(40.0 * EcoOrganDust.RATE)
	var tubes := o.organs.size() * EcoOrgan.TUBES
	ok(d._made > 0, "губка дышит (%d)" % d._made)
	# вдали — около доли BREATH_CHANCE тактов; вторая губка дальше 80 м и не дышит
	var per_tube := float(d._made) / EcoOrgan.TUBES
	ok(per_tube < cycles * 0.8, "вдали не каждый такт (%.1f из %d)" % [per_tube, cycles])
	ok(per_tube > cycles * 0.15, "но дышит (%.1f из %d)" % [per_tube, cycles])
	ok(tubes == 21, "три губки по семь труб")
	for p in d.dust.puffs:
		if p.born < -1e8:
			continue
		ok(p.born <= t + 1e-4, "облачко не из будущего")
		var over := false
		for k in EcoOrgan.TUBES:
			var m := EcoOrganDust.mouth(og, k)
			if absf(p.at.y - (m.y + EcoOrganDust.LIFT)) < 1e-4 and Vector2(p.at.x - m.x, p.at.z - m.z).length() \
					<= EcoOrganDust.SCATTER * 1.5:
				over = true
		ok(over, "облачко над устьем трубы")
		ok(p.alpha <= EcoOrganDust.ALPHA * 1.21, "вдали — слабое (%.2f)" % p.alpha)
		near(p.scale, EcoOrganDust.SCALE, 1e-3, "и мелкое")


func test_ship_near_breathes_every_cycle_denser() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var o := _org(w)
	var og := o.organs[0]
	var ship := og.base + Vector3(0, 4, 0)   # над самой губкой
	var d := EcoOrganDust.new()
	_run(o, d, 0.0, 30.0, ship)
	var cycles := 0
	for k in EcoOrgan.TUBES:
		var j := EcoOrganDust.tube_id(og, k)
		cycles += EcoOrganDust.cycle(j, 30.0) - EcoOrganDust.cycle(j, 0.0)
	eq(d._made, cycles, "корабль над губкой — каждая труба каждый такт")
	for p in d.dust.puffs:
		if p.born < -1e8:
			continue
		ok(p.alpha > EcoOrganDust.ALPHA_NEAR * 0.75, "гуще (%.2f)" % p.alpha)
		ok(p.scale > EcoOrganDust.SCALE + 0.15, "и крупнее (%.2f)" % p.scale)
	# в такт тлению губки: трубы выдыхают в свой момент, а не все разом
	var starts := {}
	for k in EcoOrgan.TUBES:
		starts[snappedf(EcoOrganDust.phase(EcoOrganDust.tube_id(og, k)), 0.01)] = true
	ok(starts.size() >= 5, "трубы дышат вразнобой (%d разных фаз)" % starts.size())
	near(1.0 / EcoOrganDust.RATE, TAU / 1.7, 1e-4, "такт — такт тления губки (EcoOrgan.glow)")


func test_far_and_lite_no_breath() -> void:
	var w := _world()
	var o := _org(w)
	var og := o.organs[0]
	EcoGrazerDust.lite = false
	var d := EcoOrganDust.new()
	_run(o, d, 0.0, 20.0, FAR)
	eq(d._made, 0, "дальше 80 м от корабля губки не дышат")
	EcoGrazerDust.lite = true
	d = EcoOrganDust.new()
	_run(o, d, 0.0, 20.0, og.base + Vector3(0, 4, 0))
	eq(d._made, 0, "«Экономно» — выдохов нет")
	EcoGrazerDust.lite = false
	_run(o, d, 20.0, 10.0, og.base + Vector3(0, 4, 0))
	ok(d._made > 0, "выключатель вернули — дышат (%d)" % d._made)


## Долгая заминка кадра: труба выдыхает один раз, а не за все пропущенные такты.
func test_long_frame_one_breath() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var o := _org(w)
	var og := o.organs[0]
	var ship := og.base + Vector3(0, 4, 0)
	var d := EcoOrganDust.new()
	d.update(o, 0.0, ship)
	d.update(o, 30.0, ship)
	ok(d._made <= EcoOrgan.TUBES * o.organs.size(), "не больше облачка на трубу (%d)" % d._made)


## Тот же ход времени мира — те же выдохи (у гостя время мира то же).
func test_same_time_same_breath() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for r in 2:
		var w := _world()
		var o := _org(w)
		var og := o.organs[0]
		var d := EcoOrganDust.new()
		_run(o, d, 0.0, 15.0, og.base + Vector3(0, 6, 30))
		_run(o, d, 15.0, 15.0, og.base + Vector3(0, 4, 5))
		eq(d.dust.puffs.size(), EcoOrganDust.POOL, "пул не растёт")
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha, p.scale])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "те же выдохи при том же времени")
	# шаг кадров другой (гость) — облачка те же: время выдоха — начало такта
	var w := _world()
	var o := _org(w)
	var og := o.organs[0]
	var ship := og.base + Vector3(0, 4, 0)
	var a := EcoOrganDust.new()
	var b := EcoOrganDust.new()
	var t := 0.0
	a.update(o, 0.0, ship)
	b.update(o, 0.0, ship)
	while t < 8.0:
		t += 1.0 / 30.0
		a.update(o, t, ship)
		if int(t * 30.0) % 2 == 0:
			b.update(o, t, ship)
	b.update(o, t, ship)
	eq(a._made, b._made, "столько же выдохов при другом шаге кадров")
	var sa := []
	var sb := []
	for p in a.dust.puffs:
		if p.born > -1e8:
			sa.append([p.at, snappedf(p.born, 1e-4)])
	for p in b.dust.puffs:
		if p.born > -1e8:
			sb.append([p.at, snappedf(p.born, 1e-4)])
	sa.sort()
	sb.sort()
	eq(str(sa), str(sb), "и те же облачка")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var o := _org(w)
	var og := o.organs[0]
	var view := OrganView.new(o)
	tree.root.add_child(view)
	await frames(1)
	var dust := view.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "выдох губки в сцене"):
		view.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoOrganDust.POOL, "один MultiMesh на пул")
	eq(dust.layers, OceanView.LAYER_WORLD, "на слое отмели")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var info := EcoLink.ShipState.new()
	info.pos = og.base + Vector3(0, 4, 0)
	var t := 0.0
	view.sync(t, info)
	while t < 4.0:
		t += 0.1
		view.sync(t, info)
	var seen := 0
	for n in EcoOrganDust.POOL:
		var i := n * GrazerView.DUST_STRIDE
		if view.dust_buffer[i + 15] > 0.0:
			seen += 1
			ok(view.dust_buffer[i] <= EcoGrazerDust.SIZE_END * EcoOrganDust.SCALE_NEAR + 1e-5, "облачко — с размером")
			near(view.dust_buffer[i + 12], EcoOrganDust.COLOR.r, 1e-5, "бледная муть без луча")
	ok(seen > 0, "губка выдохнула (%d)" % seen)
	view.queue_free()
	await frames(1)


## Свой буфер мути — тот же, что GrazerView.pack_dust: живые облачка на месте, растаявшие стянуты в точку.
func test_pack_same_as_grazer_pack() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var o := _org(w)
	var view := OrganView.new(o)
	var info := EcoLink.ShipState.new()
	info.pos = o.organs[0].base + Vector3(0, 4, 6)
	info.light_on = true
	info.light_range = 30.0
	var flow := Vector3(0.3, 0, -0.1)
	var t := 0.0
	var checked := 0
	while t < 20.0:
		t += 0.05
		view.sync(t, info, flow)
		var ref := GrazerView.pack_dust(view.dust.dust, t, flow, info, EcoOrganDust.COLOR, EcoOrganDust.LIT)
		if view.dust.dust.shown(t) > 0:
			checked += 1
			for i in ref.size():
				if absf(ref[i] - view.dust_buffer[i]) > 1e-5 and not (ref[(i / 16) * 16 + 15] <= 0.0
						and view.dust_buffer[(i / 16) * 16] == 0.0):
					ok(false, "буфер расходится в %d: %.4f и %.4f" % [i, view.dust_buffer[i], ref[i]])
					view.free()
					return
	ok(checked > 100, "сравнили кадров с облачками (%d)" % checked)
	view.free()
