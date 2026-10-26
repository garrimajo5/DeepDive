extends TestCase
## Муть у дна от стеклоуста (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): вылетел из расщелины — клуб ила у устья,
## вернулся — клуб слабее; несётся у самого дна — облачка следа позади головы, высоко или медленно — нет; дальние от
## корабля и «Экономно» мути не поднимают; в сцене — свой MultiMesh на общем шейдере мира.

const FLAT := -40.0
const SPOT := Vector3(0, FLAT, 0)
## Корабль в 60 м от логова: муть видна, а нос далеко — к стеклу угорь не плывёт.
const SHIP := Vector3(0, -25, 60)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world(w: EcoWorld = null, g: EcoGrazer = null) -> EcoWorld:
	if w == null:
		w = EcoWorld.new()
		w.ground = _flat
		w.ship.pos = SHIP
	w.add(EcoEel.new(g, null, [SPOT] as Array[Vector3]))
	return w


func _eels(w: EcoWorld) -> EcoEel:
	for s in w.systems:
		if s is EcoEel:
			return s
	return null


## Мир, где угорь бросается на скребуна у логова (как test_eco_eel.test_strikes_grazer).
func _strike_world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = SHIP
	var moss := w.add(EcoMoss.new([SPOT + Vector3(5, 0, 0)] as Array[Vector3])) as EcoMoss
	var g := w.add(EcoGrazer.new(moss, 2)) as EcoGrazer
	_world(w, g)
	_eels(w).eels[0].cd = 0.0
	return w


func _born_after(d: EcoEelDust, t: float) -> Array[EcoGrazerDust.Puff]:
	var out: Array[EcoGrazerDust.Puff] = []
	for p in d.dust.puffs:
		if p.born >= t - 1e-6:
			out.append(p)
	return out


func test_burst_at_mouth_on_exit_and_return() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var e := _eels(w).eels[0]
	var d := EcoEelDust.new()
	d.update(_eels(w), 0.0, SHIP, _flat)
	d.update(_eels(w), 0.05, SHIP, _flat)
	eq(d._made, 0, "в логове — мути нет")
	e.agent.p = e.lair + e.out * 2.5
	d.update(_eels(w), 0.1, SHIP, _flat)
	var out := _born_after(d, 0.1)
	eq(out.size(), EcoEelDust.OUT_N, "вылетел — клуб из %d облачков" % EcoEelDust.OUT_N)
	for p in out:
		ok(p.born <= 0.1 + EcoEelDust.BURST_SPAN + 1e-6, "облачка клуба — вразнобой за долю секунды")
		near(p.at.y, FLAT + EcoEelDust.BASE_LIFT, 1e-4, "у дна под устьем")
		var flat := Vector3(p.at.x - e.lair.x, 0.0, p.at.z - e.lair.z)
		ok(flat.length() < EcoEelDust.BURST_OUT + EcoEelDust.BURST_SCATTER * 1.5, "у устья логова")
		near(p.scale, EcoEelDust.SCALE, 1e-6, "облачко угря — меньше, чем у скребуна")
		near(p.alpha, EcoEelDust.OUT_ALPHA, EcoEelDust.OUT_ALPHA * 0.21, "клуб густой")
	d.update(_eels(w), 0.15, SHIP, _flat)
	eq(d._made, EcoEelDust.OUT_N, "снаружи на месте — новых клубов нет")
	e.agent.p = e.lair + e.out * 0.3
	d.update(_eels(w), 1.0, SHIP, _flat)
	var back := _born_after(d, 1.0)
	eq(back.size(), EcoEelDust.IN_N, "вернулся — клуб меньше")
	for p in back:
		ok(p.alpha < EcoEelDust.OUT_ALPHA * 0.85, "и слабее")


func test_trail_low_and_fast_only() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var eels := _eels(w)
	var e := eels.eels[0]
	var d := EcoEelDust.new()
	var start := e.lair + Vector3(10, 0, 0)
	start.y = FLAT + 1.0
	e.agent.p = start
	e.face = Vector3.RIGHT
	d.update(eels, 0.0, SHIP, _flat)
	var t := 0.0
	for i in 40:   # 2 с по +X со скоростью 12 м/с в метре над дном
		t += 0.05
		e.agent.p += Vector3(0.6, 0, 0)
		d.update(eels, t, SHIP, _flat)
	ok(d._made >= 5 and d._made <= 8, "у дна в броске — облачко раз в ~0,3 с (%d за 2 с)" % d._made)
	for p in d.dust.puffs:
		if p.born > 0.0:
			near(p.at.y, FLAT + EcoEelDust.BASE_LIFT, 1e-4, "след — на дне")
			ok(p.alpha <= EcoEelDust.TRAIL_ALPHA * 1.21, "след слабее клуба")
	var made := d._made
	e.agent.p.y = FLAT + EcoEelDust.LOW + 1.0
	d.update(eels, t + 0.05, SHIP, _flat)
	t += 0.05
	for i in 40:
		t += 0.05
		e.agent.p += Vector3(0.6, 0, 0)
		d.update(eels, t, SHIP, _flat)
	eq(d._made, made, "выше %.1f м над дном — следа нет" % EcoEelDust.LOW)
	e.agent.p.y = FLAT + 1.0
	for i in 40:   # 4 м/с — домой не спеша
		t += 0.05
		e.agent.p += Vector3(0.2, 0, 0)
		d.update(eels, t, SHIP, _flat)
	eq(d._made, made, "медленно — следа нет")


func test_far_and_lite_make_no_dust() -> void:
	var w := _world()
	var eels := _eels(w)
	var e := eels.eels[0]
	var d := EcoEelDust.new()
	EcoGrazerDust.lite = false
	d.update(eels, 0.0, Vector3(500, -30, 500), _flat)
	e.agent.p = e.lair + e.out * 3.0
	d.update(eels, 0.05, Vector3(500, -30, 500), _flat)
	eq(d._made, 0, "дальше 80 м от корабля мути нет")
	EcoGrazerDust.lite = true
	e.agent.p = e.lair
	d.update(eels, 0.1, SHIP, _flat)
	eq(d._made, 0, "«Экономно» — мути нет")
	EcoGrazerDust.lite = false
	e.agent.p = e.lair + e.out * 3.0
	d.update(eels, 0.15, SHIP, _flat)
	eq(d._made, EcoEelDust.OUT_N, "выключатель вернули — муть есть")


func test_strike_in_world_dusts_same_every_run() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _strike_world()
		var d := EcoEelDust.new()
		var t := 0.0
		var caught := false
		while t < 40.0:
			w.step(EcoWorld.MAX_STEP)
			d.update(_eels(w), w.time, w.ship.pos, w.ground)
			t += EcoWorld.MAX_STEP
			for ev in w.bus.pending:
				caught = caught or ev.note == "eelcatch"
		ok(caught, "угорь бросился на скребуна")
		ok(d._made >= EcoEelDust.OUT_N + EcoEelDust.IN_N, "вылетел и вернулся — клубы у устья (%d)" % d._made)
		eq(d.dust.puffs.size(), EcoEelDust.POOL, "пул не растёт")
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "та же муть при том же мире")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _strike_world()
	var view := EelView.new(_eels(w))
	tree.root.add_child(view)
	await frames(1)
	var dust := view.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть угря в сцене"):
		view.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoEelDust.POOL, "один MultiMesh на пул")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var seen := 0
	var t := 0.0
	while t < 20.0 and seen == 0:
		w.step(EcoWorld.MAX_STEP)
		t += EcoWorld.MAX_STEP
		view.sync(w.time, w.ship, Vector3.ZERO, w.ground)
		for n in EcoEelDust.POOL:
			var i := n * GrazerView.DUST_STRIDE
			if view.dust_buffer[i + 15] > 0.0:
				seen += 1
				ok(view.dust_buffer[i] <= EcoGrazerDust.SIZE_END * EcoEelDust.SCALE + 1e-5, "облачко угря — с размером")
				near(view.dust_buffer[i + 12], EcoEelDust.COLOR.r, 1e-5, "серый ил без луча")
	ok(seen > 0, "угорь поднял муть (%d)" % seen)
	view.queue_free()
	await frames(1)
