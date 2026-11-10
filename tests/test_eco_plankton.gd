extends TestCase
## Мерцающий планктон (initClouds, cloudUpdate, startCharge в js/creatures.js): четыре облака по 360 клеток над дном,
## вспышка от быстрого корабля, броска серпохвоста и ледокрыла, затухание, наблюдения «wake», «slow», «pred»,
## «betray» — след выдаёт корабль серпохвосту без прожектора; цели сонара; в сцене — один MultiMesh.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _sys(w: EcoWorld, cls: Variant) -> EcoSystem:
	for s in w.systems:
		if is_instance_of(s, cls):
			return s
	return null


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


## Одно облако в (0, 0) над ровным дном; with_pred — и серпохвосты (до планктона, как в EcoView).
func _world(with_pred := false) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var p: EcoPred = w.add(EcoPred.new()) as EcoPred if with_pred else null
	var pl := w.add(EcoPlankton.new(p, null, [Vector2(0, 0)] as Array[Vector2])) as EcoPlankton
	if p:
		p.plankton = pl
	return w


## Корабль так, что центр корпуса — в центре облака, курс 0, скорость speed.
func _ship_in(w: EcoWorld, cl: EcoPlankton.Cloud, speed: float) -> void:
	w.ship.yaw = 0.0
	w.ship.pos = cl.c - EcoHull.CENTER
	w.ship.speed = speed


func _glowing(pl: EcoPlankton, cl: EcoPlankton.Cloud, t: float) -> int:
	var n := 0
	for k in EcoPlankton.PER_CLOUD:
		if EcoPlankton.glow(cl, k, t) > EcoPlankton.LIT_ON:
			n += 1
	return n


# ---------- Расстановка ----------

func test_four_clouds_above_ground() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var pl := w.add(EcoPlankton.new()) as EcoPlankton
	eq(pl.clouds.size(), 4, "четыре облака")
	for i in 4:
		var cl := pl.clouds[i]
		var h := EcoPlankton.HOMES[i]
		near(cl.home.x, h.x, 1e-6)
		near(cl.home.z, h.y, 1e-6)
		near(cl.home.y, minf(Seabed.height(h.x, h.y) + 10.0, -10.0), 1e-4, "10 м над дном, не выше −10")
		eq(cl.offsets.size(), 360, "360 клеток")
		for k in 360:
			var o := cl.offsets[k]
			ok(o.length() <= EcoPlankton.R + 1e-3, "внутри облака 12 м")
			ok(absf(o.y) <= EcoPlankton.R * 0.5 + 1e-3, "облако сплюснуто по высоте")
			ok(cl.lit_at[k] < -50.0, "сначала не светится")
	var other := EcoWorld.new()
	other.ground = Seabed.height
	var pl2 := other.add(EcoPlankton.new()) as EcoPlankton
	near(pl2.clouds[2].offsets[77].x, pl.clouds[2].offsets[77].x, 1e-9, "то же зерно — то же облако")


func test_cloud_drifts_around_home() -> void:
	var w := _world()
	var cl := (_sys(w, EcoPlankton) as EcoPlankton).clouds[0]
	var far := 0.0
	for i in 60:
		w.run(5.0, 0.05)
		var d := Vector2(cl.c.x - cl.home.x, cl.c.z - cl.home.z).length()
		ok(d <= EcoPlankton.DRIFT * sqrt(2.0) + 1e-3, "не дальше дрейфа")
		ok(absf(cl.c.y - cl.home.y) <= EcoPlankton.DRIFT_Y + 1e-3)
		far = maxf(far, d)
	ok(far > 2.0, "облако дрейфует: %.1f м" % far)
	var t := w.time
	near(EcoPlankton.cell_pos(cl, 5, t).distance_to(cl.c + cl.offsets[5]), 0.0, 0.5, "клетка покачивается рядом")



## Б3 «плавность»: центр облака после сброса — уже по дрейфу; раньше стоял в доме и на первом шаге прыгал до 6 м.
func test_no_jump_after_reset() -> void:
	var w := _world()
	var pl := _sys(w, EcoPlankton) as EcoPlankton
	var dt := 1.0 / 30.0
	var was: Array[Vector3] = []
	for cl in pl.clouds:
		was.append(cl.c)
	var worst := 0.0
	for i in 30 * 5:
		w.step(dt)
		for k in pl.clouds.size():
			worst = maxf(worst, pl.clouds[k].c.distance_to(was[k]) / dt)
			was[k] = pl.clouds[k].c
	ok(worst < 1.0, "центр облака без рывков: %.2f м/с" % worst)


# ---------- Корабль ----------

func test_fast_ship_leaves_glowing_wake() -> void:
	var w := _world()
	var pl := _sys(w, EcoPlankton) as EcoPlankton
	var cl := pl.clouds[0]
	_ship_in(w, cl, 4.0)
	w.step(EcoWorld.MAX_STEP)
	ok(_glowing(pl, cl, w.time) > 25, "клетки у корпуса вспыхнули: %d" % _glowing(pl, cl, w.time))
	near(cl.ship, 1.0, 1e-6, "полный след")
	ok(pl.betrays(), "след выдаёт корабль")
	var ev := _notes(w, EcoPlankton.ID, "wake")
	eq(ev.size(), 1, "наблюдение «wake»")
	eq(ev[0].text(), "Светящееся облако вспыхивает: за кораблём тянется светящийся след", ev[0].text())
	# горят только клетки у корпуса
	for k in EcoPlankton.PER_CLOUD:
		if EcoPlankton.glow(cl, k, w.time) > 0.0:
			var l := EcoHull.to_ship(EcoPlankton.cell_pos(cl, k, w.time), w.ship.pos, 0.0)
			ok(EcoPlankton.near_box(l, EcoPlankton.WAKE_GAP + 0.01), "клетка %d у корпуса" % k)
			eq(cl.by[k], EcoPlankton.By.SHIP)
	w.run(10.0)
	eq(_notes(w, EcoPlankton.ID, "wake").size(), 1, "раз в 40 с")


func test_wake_fades_in_seconds() -> void:
	var w := _world()
	var pl := _sys(w, EcoPlankton) as EcoPlankton
	var cl := pl.clouds[0]
	_ship_in(w, cl, 4.0)
	w.step(EcoWorld.MAX_STEP)
	var t0 := w.time
	w.ship.speed = 0.0
	w.run(1.0)
	ok(pl.betrays(), "через секунду след ещё виден")
	var k0 := -1
	for k in EcoPlankton.PER_CLOUD:
		if absf(cl.lit_at[k] - t0) < 1e-4:
			k0 = k
	ok(k0 >= 0, "клетка последней вспышки")
	near(EcoPlankton.glow(cl, k0, w.time), 1.0 - (w.time - t0) * 0.45, 1e-4, "гаснет 0,45 в секунду")
	w.run(0.5)
	near(pl.wake, 0.0, 1e-6, "через полторы секунды — следа нет")
	eq(_glowing(pl, cl, w.time), 0)
	w.run(1.0)
	var after := cl.cut_at
	w.run(1.0)
	eq(cl.cut_at, after, "погасшее облако не считают")


func test_slow_ship_leaves_no_trace() -> void:
	var w := _world()
	var pl := _sys(w, EcoPlankton) as EcoPlankton
	var cl := pl.clouds[0]
	_ship_in(w, cl, 1.5)
	for i in 100:  # 5 с, корабль держим в центре облака
		w.ship.pos = cl.c - EcoHull.CENTER
		w.step(EcoWorld.MAX_STEP)
	eq(_glowing(pl, cl, w.time), 0, "медленно — не вспыхивает")
	ok(not pl.betrays())
	var ev := _notes(w, EcoPlankton.ID, "slow")
	eq(ev.size(), 1, "наблюдение «slow» через 4 с")
	eq(ev[0].text(), "Корабль идёт медленно — светящееся облако не вспыхивает", ev[0].text())
	w.ship.speed = 0.1
	w.run(5.0)
	eq(_notes(w, EcoPlankton.ID, "slow").size(), 1, "стоит — не «идёт медленно»")


func test_far_ship_cuts_nothing() -> void:
	var w := _world()
	var pl := _sys(w, EcoPlankton) as EcoPlankton
	w.ship.speed = 10.0
	w.run(2.0)
	near(pl.clouds[0].cut_at, -99.0, 1e-6, "облако вдали от корабля не считают")
	eq(pl.clouds[0].version, 0, "буфер не трогают")


# ---------- Серпохвост и ледокрыл ----------

func test_pred_charge_lights_cloud() -> void:
	var w := _world(true)
	var preds := _sys(w, EcoPred) as EcoPred
	var pl := _sys(w, EcoPlankton) as EcoPlankton
	var cl := pl.clouds[0]
	for pr in preds.all:
		pr.agent.p = FAR + Vector3(0, 0, 50 * pr.index)
	var pr := preds.all[0]
	pr.agent.p = cl.c + Vector3(0, 0, 6)
	pr.agent.v = Vector3(0, 0, -8)
	for i in 20:  # секунду бросок идёт сквозь облако (хищника двигаем сами, мир не шагаем)
		w.time += 0.05
		w.steps += 1
		pr.agent.p += pr.agent.v * 0.05
		pl.step(w, 0.05)
	ok(cl.pred_lit > EcoPlankton.PRED_LIT, "бросок зажёг клетки: %d" % cl.pred_lit)
	near(cl.ship, 0.0, 1e-6, "след хищника — не след корабля")
	var ev := _notes(w, EcoPlankton.ID, "pred")
	eq(ev.size(), 1, "наблюдение «pred»")
	eq(ev[0].text(), "Бросок крупного хищника сквозь светящееся облако видно издалека", ev[0].text())
	pr.agent.v = Vector3(0, 0, -3)
	cl.lit_at.fill(-99.0)
	pl.step(w, 0.0)
	eq(cl.pred_lit, 0, "медленный хищник облако не режет")


func test_ray_lights_cloud() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var rays := w.add(EcoRay.new()) as EcoRay
	var pl := w.add(EcoPlankton.new(null, rays, [Vector2(0, 0)] as Array[Vector2])) as EcoPlankton
	w.step(EcoWorld.MAX_STEP)
	var cl := pl.clouds[0]
	var ry := rays.rays[0]
	ry.p = cl.c
	ry.dir = Vector3(1, 0, 0)
	pl.step(w, 0.0)
	var n := 0
	for k in EcoPlankton.PER_CLOUD:
		if cl.by[k] == EcoPlankton.By.RAY and EcoPlankton.glow(cl, k, w.time) > 0.9:
			n += 1
	ok(n > 20, "крыло ледокрыла зажгло клетки: %d" % n)
	ok(not pl.betrays(), "ледокрыл корабль не выдаёт")


## Серпохвост голоден и в 28 м от корабля (дальше слуха 24 м, ближе чутья 32 м); прожектор и сонар молчат.
func _betray_world(wake: float) -> Array:
	var w := _world(true)
	var preds := _sys(w, EcoPred) as EcoPred
	var pl := _sys(w, EcoPlankton) as EcoPlankton
	var pr := preds.all[0]
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.pos = pr.agent.p + Vector3(28, 0, 0)
	w.ship.light_on = false
	pl.wake = wake  # хищник шагает раньше облака и видит след прошлого шага
	return [w, pr]


func test_wake_betrays_ship_to_pred() -> void:
	var a := _betray_world(1.0)
	var w: EcoWorld = a[0]
	var pr: EcoPred.Pred = a[1]
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.CHARGE, "след в темноте — бросок на корабль")
	var ev := _notes(w, EcoPlankton.ID, "betray")
	eq(ev.size(), 1, "наблюдение «betray»")
	eq(ev[0].text(), "Крупный хищник заметил светящийся след светящегося облака и разворачивается к кораблю", ev[0].text())

	a = _betray_world(0.3)
	w = a[0]
	pr = a[1]
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.PATROL, "слабый след (≤ 0,5) не выдаёт")
	eq(_notes(w, EcoPlankton.ID, "betray").size(), 0)

	a = _betray_world(1.0)
	w = a[0]
	pr = a[1]
	w.ship.light_on = true
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.CHARGE)
	eq(_notes(w, EcoPred.ID, "ship").size(), 1, "при прожекторе — привлёк свет, не след")
	eq(_notes(w, EcoPlankton.ID, "betray").size(), 0)


# ---------- Цели и сцена ----------

func test_clouds_are_targets() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.add(EcoPlankton.new())
	var n := 0
	for t in w.scan_targets():
		if t["species"] == EcoPlankton.ID:
			n += 1
			near(t["r"], 4.0, 1e-6)
			ok(t["sonar"], "видно сонару")
	eq(n, 4, "четыре цели")


func test_view_one_multimesh() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	ok(view.preds.plankton == view.plankton, "серпохвосты видят след")
	var pv := view.plankton_view
	ok(pv != null and pv.get_parent() == view, "планктон — в живом мире")
	eq(pv.cells.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(pv.cells.multimesh.instance_count, 1440, "все клетки — один MultiMesh")
	eq(ShaderKey.of(pv.material), ShaderKey.of(view.raduzh_view.halos.multimesh.mesh.surface_get_material(0)),
		"клетки и ореолы гребневиков — один шейдер")
	ok(bool(pv.material.get_shader_parameter("cloud")), "режим облака")
	var cl := view.plankton.clouds[1]
	near(pv.origin_at(1, 7).distance_to(cl.home + cl.offsets[7]), 0.0, 1e-4, "дом клетки в буфере")
	var ship := EcoLink.ShipState.new()
	ship.pos = FAR
	view.step(0.05, ship)
	var writes := pv.writes
	view.step(0.05, ship)
	eq(pv.writes, writes, "без вспышек буфер не переписывают")
	near(float(pv.material.get_shader_parameter("now")), view.world.time, 1e-6, "время мира — в шейдер")
	# корабль быстро проходит сквозь облако 1
	ship.pos = cl.c - EcoHull.CENTER
	ship.speed = 5.0
	view.step(0.05, ship)
	ok(pv.writes > writes, "вспышка — буфер переписан")
	var lit := 0
	for k in EcoPlankton.PER_CLOUD:
		if cl.lit_at[k] > 0.0:
			lit += 1
			near(pv.lit_at(1, k), cl.lit_at[k], 1e-4, "время вспышки — в буфере")
	ok(lit > 25, "клетки вспыхнули: %d" % lit)
	view.queue_free()
	await frames(1)


## «Экономно»: рисуется половина клеток — поровну из каждого облака, мир считает все; сброс мира уровень не теряет.
func test_lite_draws_half_of_each_cloud() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var pv := view.plankton_view
	eq(pv.drawn(), 1440, "на «Обычно» — все клетки")
	view.set_lite(true)
	eq(pv.drawn(), 720, "«Экономно» — половина")
	var shown: Array[int] = [0, 0, 0, 0]
	for c in view.plankton.clouds.size():
		for k in EcoPlankton.PER_CLOUD:
			if pv.slot(c, k) < pv.drawn():
				shown[c] += 1
	eq(shown, [180, 180, 180, 180] as Array[int], "из каждого облака поровну")
	var cl := view.plankton.clouds[1]
	var ship := EcoLink.ShipState.new()
	ship.pos = cl.c - EcoHull.CENTER
	ship.speed = 5.0
	view.step(0.05, ship)
	var lit := 0
	for k in EcoPlankton.PER_CLOUD:
		if cl.lit_at[k] > 0.0:
			lit += 1
			near(pv.lit_at(1, k), cl.lit_at[k], 1e-4, "вспышка — в буфере и у скрытых клеток")
	ok(lit > 25, "мир зажигает клетки как раньше: %d" % lit)
	view.ground = Seabed.height
	ok(view.plankton_view != pv, "дно сменилось — вид пересобран")
	ok(view.plankton_view.lite, "после пересборки — тоже «Экономно»")
	eq(view.plankton_view.drawn(), 720, "после пересборки — половина")
	view.set_lite(false)
	eq(view.plankton_view.drawn(), 1440, "назад — все клетки")
	view.queue_free()
	await frames(1)
