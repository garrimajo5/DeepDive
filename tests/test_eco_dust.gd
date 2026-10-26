extends TestCase
## Муть у дна от скребунов (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): пасущийся поднимает облачко у скребка,
## идущий — слабее из-под лап; облачко стоит, где поднято, растёт, поднимается, уплывает по течению и тает;
## пул ограничен, дальние от корабля и «Экономно» мути не поднимают; в сцене — один MultiMesh «Муть» на общем
## шейдере мира.


## Ровное дно на −40 м, два пятна мха в 10 м и один скребун; корабль рядом.
func _pair() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float: return -40.0
	w.ship.pos = Vector3(0, -30, 0)
	var m := w.add(EcoMoss.new([Vector3(0, -40, 0), Vector3(0, -40, 10)] as Array[Vector3])) as EcoMoss
	for p in m.patches:
		p.food = 1.0
	w.add(EcoGrazer.new(m, 1))
	return w


func _grazers(w: EcoWorld) -> EcoGrazer:
	for s in w.systems:
		if s is EcoGrazer:
			return s
	return null


## Прогон мира и мути вместе шагом 0,05 с; done — когда остановиться.
func _run(w: EcoWorld, d: EcoGrazerDust, secs: float, ship: Vector3, done: Callable = Callable()) -> void:
	var t := 0.0
	while t < secs:
		w.step(EcoWorld.MAX_STEP)
		d.update(_grazers(w), w.time, ship)
		t += EcoWorld.MAX_STEP
		if done.is_valid() and done.call():
			return


func _newest(d: EcoGrazerDust) -> EcoGrazerDust.Puff:
	var best: EcoGrazerDust.Puff = null
	for p in d.puffs:
		if best == null or p.born > best.born:
			best = p
	return best


func test_grazing_stirs_at_snout() -> void:
	EcoGrazerDust.lite = false
	var w := _pair()
	var g := _grazers(w).all[0]
	var d := EcoGrazerDust.new()
	_run(w, d, 30.0, w.ship.pos, g.grazing)
	if not ok(g.grazing(), "дошёл до мха и пасётся"):
		return
	var walked := d.shown(w.time)
	ok(walked >= 1, "по пути из-под лап поднялась муть")
	var before := _newest(d)
	near(before.alpha, EcoGrazerDust.WALK_ALPHA, EcoGrazerDust.WALK_ALPHA * 0.26, "из-под лап — слабая")
	_run(w, d, 2.0, w.ship.pos)
	var p := _newest(d)
	ok(p != before, "пасётся — новое облачко")
	near(p.alpha, EcoGrazerDust.GRAZE_ALPHA, EcoGrazerDust.GRAZE_ALPHA * 0.26, "от скребка — гуще")
	var snout := EcoGrazerLook.origin(g) + EcoGrazerLook.forward(g) * EcoGrazerDust.SNOUT
	ok(Vector2(p.at.x - snout.x, p.at.z - snout.z).length() <= EcoGrazerDust.SCATTER * 1.5, "у скребка, впереди по курсу")
	near(p.at.y, -40.0 + EcoGrazerDust.BASE_LIFT, 1e-3, "у самого дна")
	# пасётся 8–14 с: облачка идут примерно раз в 0,8 с
	var n0 := d._made
	_run(w, d, 4.0, w.ship.pos)
	var made := d._made - n0
	ok(made >= 4 and made <= 6, "за 4 с — 4…6 облачков (%d)" % made)


func test_puff_stays_grows_rises_fades() -> void:
	var p := EcoGrazerDust.Puff.new()
	p.at = Vector3(5, -40, 7)
	p.born = 10.0
	p.alpha = 0.3
	near(EcoGrazerDust.fade(p, 10.0), 0.0, 1e-6, "в миг рождения ещё не видно")
	ok(EcoGrazerDust.fade(p, 10.0 + EcoGrazerDust.LIFE * 0.12) > 0.2, "проявилось за десятую жизни")
	near(EcoGrazerDust.fade(p, 10.0 + EcoGrazerDust.LIFE), 0.0, 1e-6, "к концу жизни растаяло")
	ok(not EcoGrazerDust.alive(p, 10.0 + EcoGrazerDust.LIFE + 0.1))
	near(EcoGrazerDust.size(p, 10.0), EcoGrazerDust.SIZE_START, 1e-6)
	near(EcoGrazerDust.size(p, 10.0 + EcoGrazerDust.LIFE), EcoGrazerDust.SIZE_END, 1e-6, "раздулось")
	ok(EcoGrazerDust.size(p, 10.0 + EcoGrazerDust.LIFE * 0.5) > (EcoGrazerDust.SIZE_START + EcoGrazerDust.SIZE_END) * 0.5,
		"быстро в начале, медленнее к концу")
	var still := EcoGrazerDust.pos(p, 10.0 + EcoGrazerDust.LIFE, Vector3.ZERO)
	near(still.x, 5.0, 1e-6, "без течения стоит, где поднято")
	near(still.z, 7.0, 1e-6)
	near(still.y, -40.0 + EcoGrazerDust.RISE, 1e-5, "поднялось на RISE")
	var flow := Vector3(0.2, 0.5, 0)
	var moved := EcoGrazerDust.pos(p, 12.0, flow)
	near(moved.x, 5.0 + 0.2 * EcoGrazerDust.DRIFT * 2.0, 1e-5, "уплывает по течению")
	ok(moved.y < -40.0 + EcoGrazerDust.RISE, "течение вверх не тянет — только подъём")


func test_far_and_lite_make_no_dust() -> void:
	EcoGrazerDust.lite = false
	var w := _pair()
	var g := _grazers(w).all[0]
	var d := EcoGrazerDust.new()
	_run(w, d, 20.0, Vector3(500, 0, 500))
	eq(d._made, 0, "дальше 80 м от корабля мути нет")
	EcoGrazerDust.lite = true
	_run(w, d, 6.0, w.ship.pos)
	eq(d._made, 0, "«Экономно» — мути нет")
	EcoGrazerDust.lite = false
	_run(w, d, 3.0, w.ship.pos)
	ok(d._made > 0, "выключатель вернули — муть есть")
	ok(g.agent.alive)


func test_dead_grazer_no_dust_and_pool_bounded() -> void:
	EcoGrazerDust.lite = false
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var m := w.add(EcoMoss.new()) as EcoMoss
	var gr := w.add(EcoGrazer.new(m)) as EcoGrazer
	var d := EcoGrazerDust.new()
	var ship := gr.all[0].agent.p
	_run(w, d, 60.0, ship)
	ok(d.shown(w.time) <= EcoGrazerDust.POOL, "в пуле не больше POOL")
	ok(d._made > EcoGrazerDust.POOL, "старые уступают новым (%d)" % d._made)
	var made := d._made
	for g in gr.all:
		gr.kill(g)
	for i in 20:
		d.update(gr, w.time + i * 0.5, ship)
	eq(d._made, made, "съеденные муть не поднимают")


func test_same_dust_every_run() -> void:
	EcoGrazerDust.lite = false
	var runs: Array = []
	for k in 2:
		var w := _pair()
		var d := EcoGrazerDust.new()
		_run(w, d, 25.0, w.ship.pos)
		var row := []
		for p in d.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "та же муть при том же мире")


func test_scene_one_multimesh() -> void:
	EcoGrazerDust.lite = false
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	await frames(1)
	var dust := view.find_child("Муть", true, false) as MultiMeshInstance3D
	if not ok(dust != null, "муть в сцене"):
		view.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoGrazerDust.POOL, "один MultiMesh на весь пул")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var ship := EcoLink.ShipState.new()
	ship.pos = view.grazers.all[0].agent.p
	for i in 200:
		view.step(0.05, ship)
	var gv := view.grazer_view
	var seen := 0
	for n in EcoGrazerDust.POOL:
		if gv.dust_buffer[n * GrazerView.DUST_STRIDE + 15] > 0.0:
			seen += 1
			ok(gv.dust_buffer[n * GrazerView.DUST_STRIDE] > 0.0, "видимое облачко — с размером")
	ok(seen > 0, "у корабля скребуны подняли муть (%d)" % seen)
	view.set_lite(true)
	ok(EcoGrazerDust.lite, "EcoView.set_lite гасит муть")
	view.set_lite(false)
	view.queue_free()
	await frames(1)


func test_lit_by_searchlight() -> void:
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(0, -30, 0)
	ship.light_on = true
	ship.light_range = 40.0
	near(EcoGrazerDust.light(Vector3(0, -30, 10), ship), 1.0, 1e-6, "близко в луче — светлая")
	near(EcoGrazerDust.light(Vector3(0, -30, 30), ship), 0.5, 1e-6, "к краю луча темнеет")
	near(EcoGrazerDust.light(Vector3(0, -30, 45), ship), 0.0, 1e-6, "за дальностью — темно")
	ship.light_on = false
	near(EcoGrazerDust.light(Vector3(0, -30, 10), ship), 0.0, 1e-6, "прожектор погашен — темно")
	near(EcoGrazerDust.light(Vector3.ZERO, null), 0.0, 1e-6)
	ok(EcoGrazerDust.tone(1.0).v > EcoGrazerDust.tone(0.0).v * 1.8, "в луче муть заметно светлее")
	# в буфере: то же облачко у включённого прожектора светлее
	var d := EcoGrazerDust.new()
	var p := d.puffs[0]
	p.at = Vector3(0, -40, 5)
	p.born = 0.0
	p.alpha = 0.4
	ship.light_on = true
	var lit := GrazerView.pack_dust(d, 1.0, Vector3.ZERO, ship)
	ship.light_on = false
	var dark := GrazerView.pack_dust(d, 1.0, Vector3.ZERO, ship)
	ok(lit[12] > dark[12] and lit[13] > dark[13], "цвет в буфере — по свету")
	near(lit[15], dark[15], 1e-6, "прозрачность от света не зависит")
	near(dark[12], EcoGrazerDust.COLOR.r, 1e-6)
