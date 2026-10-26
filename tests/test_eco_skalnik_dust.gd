extends TestCase
## Муть у дна от скальника (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): «камень» снялся с места — клуб ила вокруг
## дома, вернулся — клуб слабее; ползёт у дна — облачка следа позади тела, в броске — чаще и гуще, высоко или
## медленно — нет; бросил образец дома — облачко у камешка; дальние от корабля и «Экономно» мути не поднимают;
## в сцене — свой MultiMesh на общем шейдере мира.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
const SPOTS: Array[Vector3] = [Vector3(-60, FLAT, 0), Vector3(0, FLAT, 0)]


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var k := w.add(EcoKelp.new(null, SPOTS)) as EcoKelp
	var kr := w.add(EcoKrab.new(k)) as EcoKrab
	w.add(EcoSkalnik.new(kr))
	return w


func _sk(w: EcoWorld) -> EcoSkalnik:
	return w.systems[2] as EcoSkalnik


## Корабль в 30 м над домом скальника: муть видна.
func _ship(w: EcoWorld) -> Vector3:
	return _sk(w).octo.home + Vector3(0, 10, 25)


func _born_after(d: EcoSkalnikDust, t: float) -> Array[EcoGrazerDust.Puff]:
	var out: Array[EcoGrazerDust.Puff] = []
	for p in d.dust.puffs:
		if p.born >= t - 1e-6:
			out.append(p)
	return out


func test_burst_when_rock_leaves_and_settles() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var s := _sk(w)
	var sk := s.octo
	var ship := _ship(w)
	var d := EcoSkalnikDust.new()
	d.update(s, 0.0, ship)
	d.update(s, 0.05, ship)
	eq(d._made, 0, "камень на месте — мути нет")
	sk.pos = sk.home + Vector3(0.5, 0, 0)
	d.update(s, 0.1, ship)
	var out := _born_after(d, 0.1)
	eq(out.size(), EcoSkalnikDust.WAKE_N, "снялся — клуб из %d облачков" % EcoSkalnikDust.WAKE_N)
	for p in out:
		ok(p.born <= 0.1 + EcoSkalnikDust.BURST_SPAN + 1e-6, "облачка клуба — вразнобой за долю секунды")
		near(p.at.y, FLAT + EcoSkalnikDust.BASE_LIFT, 1e-4, "у дна")
		var r := Vector2(p.at.x - sk.home.x, p.at.z - sk.home.z).length()
		ok(r <= EcoSkalnikDust.RING + EcoSkalnikDust.SCATTER + 1e-4, "кольцом вокруг дома (%.2f м)" % r)
		near(p.scale, EcoSkalnikDust.SCALE, 1e-6, "доля размера скальника")
		near(p.alpha, EcoSkalnikDust.WAKE_ALPHA, EcoSkalnikDust.WAKE_ALPHA * 0.21, "клуб густой")
	d.update(s, 0.15, ship)
	eq(d._made, EcoSkalnikDust.WAKE_N, "стоит снаружи — новых клубов нет")
	sk.pos = sk.home
	d.update(s, 1.0, ship)
	var back := _born_after(d, 1.0)
	eq(back.size(), EcoSkalnikDust.SETTLE_N, "осел дома — клуб меньше")
	for p in back:
		ok(p.alpha < EcoSkalnikDust.WAKE_ALPHA * 0.85, "и слабее")


func test_trail_low_crawl_and_rush() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var s := _sk(w)
	var sk := s.octo
	var ship := _ship(w)
	var d := EcoSkalnikDust.new()
	sk.pos = sk.home + Vector3(3, 0.2, 0)
	d.update(s, 0.0, ship)
	var t := 0.0
	for i in 60:   # 3 с ползком по +X 1,6 м/с у дна
		t += 0.05
		sk.pos += Vector3(0.08, 0, 0)
		d.update(s, t, ship)
	var crawl := d._made
	ok(crawl >= 3 and crawl <= 5, "ползёт у дна — облачко раз в ~0,7 с (%d за 3 с)" % crawl)
	for p in d.dust.puffs:
		if p.born > 0.0:
			near(p.at.y, FLAT + EcoSkalnikDust.BASE_LIFT, 1e-4, "след — на дне")
			ok(p.at.x < sk.pos.x, "позади тела")
			ok(p.alpha <= EcoSkalnikDust.CRAWL_ALPHA * 1.21, "ползком — слабо")
	for i in 60:   # 3 с броском 5 м/с
		t += 0.05
		sk.pos += Vector3(0.25, 0, 0)
		d.update(s, t, ship)
	var rush := d._made - crawl
	ok(rush >= 7 and rush <= 10, "в броске — чаще, раз в ~0,35 с (%d за 3 с)" % rush)
	var made := d._made
	sk.pos.y = FLAT + EcoSkalnikDust.LOW + 1.0
	d.update(s, t + 0.05, ship)
	t += 0.05
	for i in 40:
		t += 0.05
		sk.pos += Vector3(0.25, 0, 0)
		d.update(s, t, ship)
	eq(d._made, made, "выше %.1f м над дном — следа нет" % EcoSkalnikDust.LOW)
	sk.pos.y = FLAT + 0.2
	for i in 40:   # 0,6 м/с — почти стоит
		t += 0.05
		sk.pos += Vector3(0.03, 0, 0)
		d.update(s, t, ship)
	eq(d._made, made, "медленно — следа нет")


func test_dropped_sample_puffs() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var s := _sk(w)
	var sk := s.octo
	var ship := _ship(w)
	var d := EcoSkalnikDust.new()
	sk.loot = 5
	d.update(s, 0.0, ship)
	d.update(s, 0.05, ship)
	sk.loot = -1
	d.update(s, 0.1, ship)
	eq(d._made, 1, "бросил образец дома — облачко")
	var p := _born_after(d, 0.1)[0]
	var at := EcoSkalnik.stash_point(sk.home, 5)
	near(Vector2(p.at.x, p.at.z).distance_to(Vector2(at.x, at.z)), 0.0, 1e-4, "у камешка")


func test_far_and_lite_make_no_dust() -> void:
	var w := _world()
	var s := _sk(w)
	var sk := s.octo
	var d := EcoSkalnikDust.new()
	EcoGrazerDust.lite = false
	d.update(s, 0.0, FAR)
	sk.pos = sk.home + Vector3(1, 0, 0)
	d.update(s, 0.05, FAR)
	eq(d._made, 0, "дальше 80 м от корабля мути нет")
	EcoGrazerDust.lite = true
	sk.pos = sk.home
	d.update(s, 0.1, _ship(w))
	eq(d._made, 0, "«Экономно» — мути нет")
	EcoGrazerDust.lite = false
	sk.pos = sk.home + Vector3(1, 0, 0)
	d.update(s, 0.15, _ship(w))
	eq(d._made, EcoSkalnikDust.WAKE_N, "выключатель вернули — муть есть")


## Скальник гонит краба с бедным панцирем (как test_eco_skalnik): снимается, ползёт, возвращается — муть одна и
## та же при том же мире.
func test_stalk_in_world_dusts_same_every_run() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _world()
		var s := _sk(w)
		w.ship.pos = _ship(w)
		var d := EcoSkalnikDust.new()
		var left := false
		var t := 0.0
		while t < 120.0:
			w.step(EcoWorld.MAX_STEP)
			d.update(s, w.time, w.ship.pos)
			t += EcoWorld.MAX_STEP
			left = left or s.octo.state == EcoSkalnik.State.STALK
		ok(left, "скальник вышел на охоту")
		ok(d._made >= EcoSkalnikDust.WAKE_N, "снялся с места — муть (%d)" % d._made)
		eq(d.dust.puffs.size(), EcoSkalnikDust.POOL, "пул не растёт")
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "та же муть при том же мире")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var s := _sk(w)
	var view := SkalnikView.new(s)
	tree.root.add_child(view)
	await frames(1)
	var dust := view.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть скальника в сцене"):
		view.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoSkalnikDust.POOL, "один MultiMesh на пул")
	eq(dust.layers, OceanView.LAYER_WORLD, "на слое отмели")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var ship := _ship(w)
	var info := EcoLink.ShipState.new()
	info.pos = ship
	view.sync(0.0, ship, false, info)
	s.octo.pos = s.octo.home + Vector3(0.6, 0, 0)
	view.sync(0.5, ship, false, info)
	view.sync(1.0, ship, false, info)
	var seen := 0
	for n in EcoSkalnikDust.POOL:
		var i := n * GrazerView.DUST_STRIDE
		if view.dust_buffer[i + 15] > 0.0:
			seen += 1
			ok(view.dust_buffer[i] <= EcoGrazerDust.SIZE_END * EcoSkalnikDust.SCALE + 1e-5, "облачко — с размером")
			near(view.dust_buffer[i + 12], EcoSkalnikDust.COLOR.r, 1e-5, "серо-лиловый ил без луча")
	ok(seen > 0, "скальник поднял муть (%d)" % seen)
	view.queue_free()
	await frames(1)
