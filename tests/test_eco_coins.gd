extends TestCase
## Монетники и песчаные глазуны (initCoins, coinsUpdate, coinsPing в js/creatures.js): стайки пасутся над мхом,
## глазун в песке хватает проплывающих над ним, сонар рассыпает стайку прочь от ближайшей угрозы, глаза глазуна
## вспыхивают в луче прожектора, на спорах пузырчатки монетники кормятся.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
const SPOTS: Array[Vector3] = [Vector3(-60, FLAT, 0), Vector3(0, FLAT, 0), Vector3(60, FLAT, 0)]


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


## Ровное дно, корабль далеко, мох и три стайки в SPOTS (серпохвосты — если pred).
func _world(pred: EcoPred = null) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var m := w.add(EcoMoss.new(SPOTS)) as EcoMoss
	if pred:
		w.add(pred)
	w.add(EcoCoins.new(m, pred, SPOTS))
	return w


func _coins(w: EcoWorld) -> EcoCoins:
	return w.systems[w.systems.size() - 1] as EcoCoins


func _flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Корабль светит прожектором прямо на точку p с 10 м.
func _aim(w: EcoWorld, p: Vector3) -> void:
	var s := w.ship
	s.yaw = 0.0
	s.light_on = true
	s.light_range = Searchlight.BASE_RANGE
	var down := deg_to_rad(Searchlight.PITCH)
	var dir := Vector3(0.0, -sin(down), -cos(down))
	s.pos = p - dir * 10.0 - Searchlight.LAMP


# ---------- Расстановка ----------

func test_default_spots_near_start_like_bladders() -> void:
	var sp := EcoCoins.default_spots()
	eq(sp.size(), EcoCoins.SCHOOLS)
	for i in sp.size():
		ok(EcoMoss.SPOTS.has(sp[i]), "на пятне мха")
		for j in i:
			ok(_flat_d(sp[i], sp[j]) > EcoCoins.PICK_GAP, "пятна не ближе 25 м")
	var bl := EcoBladder.default_spots()
	for i in sp.size():
		near(_flat_d(bl[i], sp[i]), EcoBladder.OFFSET, 1e-4, "куст пузырчатки той же стайки рядом")


func test_reset_schools_glazuns_and_coins() -> void:
	var w := _world()
	var c := _coins(w)
	eq(c.schools.size(), 3)
	eq(c.coins.size(), 3 * EcoCoins.PER)
	eq(c.glazuns.size(), 3)
	for sc in c.schools:
		ok(sc.patch != null, "стайка над пятном мха")
		var gz := sc.glazun
		near(_flat_d(gz.pos, sc.center), EcoCoins.GZ_OFFSET, 1e-4, "глазун в 2,2 м от середины")
		near(gz.pos.y, FLAT, 1e-5, "в песке")
		ok(gz.eye_c.y > gz.pos.y + 0.1, "глаза торчат над песком")
		eq(sc.members.size(), EcoCoins.PER)
		for cn in sc.members:
			ok(cn.alive)
			ok(cn.pos.y >= FLAT + 0.6 - 1e-4 and cn.pos.y <= FLAT + 1.4 + 1e-4, "над мхом")
			ok(_flat_d(cn.pos, sc.center) <= 2.5 * sqrt(2.0) + 1e-4)


func test_coins_graze_over_moss() -> void:
	var w := _world()
	var c := _coins(w)
	w.run(30.0)
	for sc in c.schools:
		for cn in sc.members:
			ok(_flat_d(cn.pos, sc.center) < 6.0, "пасётся у пятна: %.1f м" % _flat_d(cn.pos, sc.center))
			ok(cn.pos.y >= FLAT + EcoCoins.CLEAR - 1e-4, "не под дном")
	eq(_notes(w, EcoCoins.ID, "graze").size(), 3, "каждая стайка пасётся (раз в 60 с)")
	ok(_notes(w, EcoCoins.ID, "graze")[0].text().begins_with("Стайка круглых рыбок пасётся"), "текст")


func test_coins_eat_moss() -> void:
	var a := _world()
	var b := EcoWorld.new()
	b.ground = _flat
	var mb := b.add(EcoMoss.new(SPOTS)) as EcoMoss
	var ma := a.systems[0] as EcoMoss
	for p in ma.patches:
		p.food = 0.0
	for p in mb.patches:
		p.food = 0.0
	a.run(20.0)
	b.run(20.0)
	near(mb.patches[0].food - ma.patches[0].food, 20.0 * EcoCoins.EAT, 0.002, "минус 0,002 в секунду")


# ---------- Засада глазуна ----------

func test_glazun_grabs_coin_overhead() -> void:
	var w := _world()
	var c := _coins(w)
	var sc := c.schools[0]
	var gz := sc.glazun
	gz.cd = 0.0
	var cn := sc.members[0]
	cn.pos = gz.pos + Vector3(0.3, 1.0, 0)
	cn.goal = cn.pos
	cn.goal_t = 10.0
	w.step(0.02)
	ok(not cn.alive, "схвачен")
	ok(cn.respawn >= EcoCoins.RESPAWN_MIN - 0.1 and cn.respawn <= EcoCoins.RESPAWN_MAX, "вернётся через 30…45 с")
	near(gz.cd, EcoCoins.GZ_CD, 0.05, "снова голоден через 18 с")
	near(gz.lunge, 1.0, 0.05, "бросок из песка")
	eq(sc.alive_count(), EcoCoins.PER - 1, "только одного")
	var ev := _notes(w, EcoCoins.GLAZUN, "ambush")
	eq(ev.size(), 1)
	eq(ev[0].text(), "Из песка что-то схватило круглую рыбку")
	w.scanned = func(sp: String) -> bool: return true
	eq(ev[0].text(), "Песчаный глазун схватил монетника")
	near(EcoCoins.glazun_transform(gz).origin.y, gz.pos.y + 0.35 * gz.lunge, 1e-5, "тело приподнято")


func test_glazun_waits_and_ignores_high_coins() -> void:
	var w := _world()
	var sc := _coins(w).schools[0]
	var gz := sc.glazun
	var cn := sc.members[0]
	gz.cd = 5.0
	cn.pos = gz.pos + Vector3(0, 1.0, 0)
	cn.goal = cn.pos
	cn.goal_t = 10.0
	w.step(0.02)
	ok(cn.alive, "сытый не хватает")
	gz.cd = 0.0
	cn.pos = gz.pos + Vector3(0, 2.5, 0)
	cn.goal = cn.pos
	w.step(0.02)
	ok(cn.alive, "выше 2,2 м не достаёт")
	cn.pos = gz.pos + Vector3(1.8, 1.0, 0)
	cn.goal = cn.pos
	w.step(0.02)
	ok(cn.alive, "дальше 1,5 м не достаёт")


func test_eaten_coin_returns_not_over_glazun() -> void:
	var w := _world()
	var sc := _coins(w).schools[1]
	var gz := sc.glazun
	var cn := sc.members[3]
	cn.alive = false
	cn.respawn = 1.0
	gz.cd = 100.0
	w.run(0.5)
	ok(not cn.alive)
	w.run(0.6)
	ok(cn.alive, "вернулся")
	ok(_flat_d(cn.pos, gz.pos) > EcoCoins.GZ_REACH, "не над глазуном")


func test_ambushes_over_time() -> void:
	var w := _world()
	w.run(300.0)
	ok(_notes(w, EcoCoins.GLAZUN, "ambush").size() >= 1, "за 5 минут глазуны кого-то схватили")
	for sc in _coins(w).schools:
		ok(sc.alive_count() >= EcoCoins.PER - 3, "стайка не вымирает")


# ---------- Глаза в луче ----------

func test_eyes_flash_in_beam() -> void:
	var w := _world()
	var gz := _coins(w).glazuns[0]
	_aim(w, gz.eye_c)
	ok(EcoWorld.beam_hits(w.ship, gz.eye_c), "луч на глазах")
	w.step(0.02)
	ok(gz.lit)
	near(EcoCoins.eye_k(gz, 1.0), 1.0, 1e-6, "ярко")
	var ev := _notes(w, EcoCoins.GLAZUN, "eyes")
	eq(ev.size(), 1)
	eq(ev[0].text(), "В луче прожектора блеснули два глаза в песке")
	w.ship.light_on = false
	w.step(0.02)
	ok(not gz.lit)
	ok(EcoCoins.eye_k(gz, 1.0) < 0.5, "без света тускло")
	w.ship.light_on = true
	w.step(0.02)
	eq(_notes(w, EcoCoins.GLAZUN, "eyes").size(), 1, "не чаще раза в 40 с")


# ---------- Сонар ----------

func test_ping_scatters_away_from_glazun() -> void:
	var w := _world()
	var c := _coins(w)
	w.run(5.0)
	var sc := c.schools[0]
	var gz := sc.glazun
	var before := 0.0
	for cn in sc.members:
		before += _flat_d(cn.pos, gz.pos)
	w.ship.pos = sc.center + Vector3(0, 20, 30)
	w.ship.sonar_ping = true
	w.step(0.05)
	w.ship.sonar_ping = false
	near(sc.scatter, EcoCoins.SCATTER_TIME - 0.05, 1e-4, "рассыпается 2,5 с")
	ok(sc.from.is_equal_approx(gz.pos), "от глазуна — он ближе корабля")
	w.run(1.5)
	var after := 0.0
	for cn in sc.members:
		after += _flat_d(cn.pos, gz.pos)
	ok(after > before + EcoCoins.PER * 3.0, "разбежались от глазуна: %.1f → %.1f" % [before, after])
	var ev := _notes(w, EcoCoins.ID, "scatter").filter(func(e): return e.pos == sc.center)
	eq(ev.size(), 1, "стайка сообщила о бегстве")
	ok(ev[0].text().ends_with("от песка рядом — там кто-то прячется"), ev[0].text())
	ok(_notes(w, EcoCoins.GLAZUN, "sonar").size() >= 1, "глазун выдан сонаром")
	ok(_notes(w, EcoCoins.GLAZUN, "sonar")[0].text() == "", "без текста")
	w.run(10.0)
	ok(_flat_d(sc.members[0].pos, sc.center) < 8.0, "вернулись к мху")


func test_ping_message_once_in_30_s_far_ignored() -> void:
	var w := _world()
	var c := _coins(w)
	var sc := c.schools[2]
	w.ship.pos = sc.center + Vector3(0, 10, 0)
	w.ship.sonar_ping = true
	w.step(0.05)
	w.ship.sonar_ping = false
	var n := _notes(w, EcoCoins.ID, "scatter").size()
	eq(n, 2, "стайки ближе 70 м (третья и вторая, первая — в 120 м)")
	w.run(5.0)
	w.ship.sonar_ping = true
	w.step(0.05)
	w.ship.sonar_ping = false
	ok(sc.scatter > 0.0, "снова рассыпалась")
	eq(_notes(w, EcoCoins.ID, "scatter").size(), n, "сообщение — раз в 30 с")
	ok(c.schools[0].scatter <= 0.0, "дальняя стайка не слышит")


func test_ping_scatter_from_pred_or_ship() -> void:
	var pr := EcoPred.new()
	var w := _world(pr)
	var c := _coins(w)
	var sc := c.schools[1]
	sc.glazun.pos = sc.center + Vector3(40, 0, 0)  # глазун далеко — его стайка не боится
	var at := sc.center + Vector3(0, 3, 6)
	pr.all[0].agent.p = at
	for k in range(1, pr.all.size()):
		pr.all[k].agent.p = FAR
	w.ship.pos = sc.center + Vector3(0, 10, 40)
	w.ship.sonar_ping = true
	w.step(0.05)
	ok(sc.from.distance_to(pr.all[0].agent.p) < 1.0, "от серпохвоста ближе 30 м")
	var ev := _notes(w, EcoCoins.ID, "scatter")
	var txt := ""
	for e in ev:
		if e.pos == sc.center:
			txt = e.text()
	ok(txt.contains("от серпохвост") or txt.contains("от " + Species.called("pred", Species.Case.GEN)), txt)
	var w2 := _world()
	var sc2 := _coins(w2).schools[1]
	sc2.glazun.pos = sc2.center + Vector3(40, 0, 0)
	w2.ship.pos = sc2.center + Vector3(0, 10, 40)
	w2.ship.sonar_ping = true
	w2.step(0.05)
	ok(sc2.from.is_equal_approx(w2.ship.pos), "иначе — от корабля")


# ---------- Корпус, сонар и сканер ----------

func test_coins_stay_outside_hull() -> void:
	var w := _world()
	var sc := _coins(w).schools[0]
	w.ship.pos = sc.center + Vector3(0, 3.5, 4)
	w.run(10.0)
	for cn in sc.members:
		if cn.alive:
			ok(not EcoHull.touches(cn.pos, w.ship.pos, w.ship.yaw, 0.0), "не внутри корпуса: %s" % cn.pos)


func test_targets() -> void:
	var w := _world()
	var c := _coins(w)
	var out: Array[Dictionary] = []
	c.targets(w, out)
	var mon := out.filter(func(t): return t["species"] == EcoCoins.ID)
	var glz := out.filter(func(t): return t["species"] == EcoCoins.GLAZUN)
	eq(mon.size(), 3)
	eq(glz.size(), 3)
	ok(mon[0]["sonar"], "стайка видна сонару")
	near(float(mon[0]["r"]), 1.2, 1e-6)
	ok(not glz[0]["sonar"], "глазун сонару не виден")
	ok(not glz[0]["hidden"], "но сканер его берёт")
	near(float(glz[0]["r"]), 0.6, 1e-6)
	for k in EcoCoins.PER - 2:
		c.schools[0].members[k].alive = false
		c.schools[0].members[k].respawn = 100.0
	out.clear()
	c.targets(w, out)
	eq(out.filter(func(t): return t["species"] == EcoCoins.ID).size(), 2, "меньше трёх рыбок — не цель")


func test_sonar_does_not_show_glazun_but_scanner_does() -> void:
	var w := _world()
	var gz := _coins(w).glazuns[0]
	w.ship.pos = gz.pos + Vector3(0, 6, 6)
	w.ship.sonar_ping = true
	w.ship.sonar_range = 100.0
	w.ship.scan_range = 80.0
	w.step(0.05)
	var g := w.take_link().filter(func(e): return e["type"] == EcoLink.NEAR and e["species"] == EcoCoins.GLAZUN)
	ok(g.size() >= 1)
	for e in g:
		ok(not e["sonar"] and e["scan"], "глазун — только сканеру")


# ---------- Споры пузырчатки ----------

func test_coins_feed_on_bladder_spores() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var m := w.add(EcoMoss.new(SPOTS)) as EcoMoss
	var bush_at: Array[Vector3] = []
	for p in SPOTS:
		bush_at.append(p + Vector3(4.5, 0, 0))
	var bl := w.add(EcoBladder.new(null, bush_at)) as EcoBladder
	var c := w.add(EcoCoins.new(m, null, SPOTS)) as EcoCoins
	c.bladders = bl
	bl.coins = c
	w.run(2.0)
	ok(c.feed_of(c.schools[0]) == null, "спор нет — пасутся")
	bl.pop(w, bl.bushes[0], false)
	ok(c.feed_of(c.schools[0]) == bl.bushes[0])
	ok(c.feed_of(c.schools[1]) == null, "чужой куст не зовёт")
	w.run(6.0)
	var close := 0
	for cn in c.schools[0].members:
		if cn.pos.distance_to(bl.bushes[0].cloud) < 2.5:
			close += 1
	ok(close >= EcoCoins.PER - 2, "кормятся на спорах: %d" % close)
	ok(c.came_to(0))
	eq(_notes(w, EcoBladder.ID, "feed").size(), 1, "пузырчатка: «на споры слетаются рыбы»")
	w.run(10.0)
	ok(c.feed_of(c.schools[0]) == null, "облако рассеялось")


# ---------- Детерминизм, сброс ----------

func test_same_seed_same_story() -> void:
	var a := _world()
	var b := _world()
	a.run(60.0)
	b.run(60.0)
	for i in _coins(a).coins.size():
		ok(_coins(a).coins[i].pos.is_equal_approx(_coins(b).coins[i].pos), "рыбка %d там же" % i)


func test_reset_restores() -> void:
	var w := _world()
	var c := _coins(w)
	var first := c.coins[0].pos
	c.coins[0].alive = false
	w.run(10.0)
	w.reset()
	c = _coins(w)
	ok(c.coins[0].alive)
	ok(c.coins[0].pos.is_equal_approx(first), "то же место после сброса")


# ---------- Сцена ----------

## Два вызова отрисовки (#849): монетники и глазуны целиком (тело, стебли, глаза — один MultiMesh).
func test_view_two_draws() -> void:
	var w := _world()
	var c := _coins(w)
	var v := CoinsView.new(c)
	tree.root.add_child(v)
	await frames(1)
	ok(v.visible)
	for mi: MultiMeshInstance3D in [v.fish, v.bodies]:
		eq(mi.layers, OceanView.LAYER_WORLD)
	eq(v.fish.multimesh.instance_count, 27)
	eq(v.bodies.multimesh.instance_count, 3)
	ok(v.find_child("Глаза", false, false) == null, "отдельного узла глаз нет")
	var cn := c.coins[4]
	ok(KelpView.transform_at(v.coin_buffer, 4, CoinsView.STRIDE_C).origin.is_equal_approx(cn.pos), "рыбка на месте")
	cn.alive = false
	c.glazuns[1].lit = true
	v.sync(1.0)
	ok(KelpView.transform_at(v.coin_buffer, 4, CoinsView.STRIDE_C).basis.x.length() < 1e-6, "съеденная сжата")
	eq(v.body_buffer[1 * CoinsView.STRIDE_C + 15], 1.0, "глаза в луче: альфа 1 — ярко и крупнее")
	ok(v.body_buffer[0 * CoinsView.STRIDE_C + 15] < 0.8, "вне луча — тусклее, не раздуваются")
	near(v.body_buffer[0 * CoinsView.STRIDE_C + 12], 1.0, 1e-6, "цвет экземпляра белый — тело своей краски")
	v.queue_free()
	await frames(1)


## Глазун одним мешем (#849): одна поверхность на общем шейдере растений; тело и стебли — альфа 0, глаза — 1,
## свет глаз — по альфе, в луче шарик раздувается по нормали до прежних 1,6 радиуса.
func test_glazun_one_mesh() -> void:
	var m := CoinsView.build_glazun()
	eq(m.get_surface_count(), 1, "одна поверхность")
	var mat := m.surface_get_material(0) as ShaderMaterial
	ok(mat != null and mat.get_shader_parameter("mode") == EcoShaders.Plant.TENTACLE, "шейдер растений, щупальце")
	eq(ShaderKey.of(mat), ShaderKey.of(KelpView.build_urchin().surface_get_material(0)), "нового шейдера нет")
	var grow: Vector2 = mat.get_shader_parameter("tip_grow")
	near(CoinsView.EYE_R * (1.0 + grow.y), CoinsView.EYE_R * 1.6, 1e-6, "в луче глаз в 1,6 раза крупнее")
	var arr := m.surface_get_arrays(0)
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var cc: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var eye_v := 0
	var off := 0
	for i in vv.size():
		if cc[i].a > 0.5:
			eye_v += 1
			var ctr := Vector3(signf(vv[i].x) * EcoCoins.EYE.x, EcoCoins.EYE.y, EcoCoins.EYE.z)
			if absf(vv[i].distance_to(ctr) - CoinsView.EYE_R) > 1e-4 \
					or nn[i].distance_to((vv[i] - ctr).normalized()) > 1e-3:
				off += 1
		elif cc[i].a > 0.01:
			off += 1
	ok(eye_v > 0, "у глаз альфа 1")
	eq(off, 0, "глаза — шарики на стебельках с нормалью от центра, у тела альфа 0")
	# глаз светится: свет = краска · сила · альфа² — в луче как прежние (k = 1: зелёный 1,25)
	near(CoinsView.EYE_PAINT.g * CoinsView.EYE_GLOW, 1.25, 1e-4, "в луче — прежняя яркость")


## Без броска глаза шейдерного глазуна стоят там же, где мир считает глаза (gz.eyes — сканер, луч).
func test_glazun_eyes_where_world_sees() -> void:
	var c := _coins(_world())
	for gz in c.glazuns:
		var tr := EcoCoins.glazun_transform(gz)
		for e in 2:
			var local := Vector3((-1.0 if e == 0 else 1.0) * EcoCoins.EYE.x, EcoCoins.EYE.y, EcoCoins.EYE.z)
			ok((tr * local).distance_to(gz.eyes[e]) < 1e-4, "глаз %d глазуна %d" % [e, gz.index])
	var gz := c.glazuns[0]
	gz.lit = false
	ok(CoinsView.eye_alpha(gz, 3.0) < 0.9, "вне луча шейдер глаза не раздувает")
	gz.lit = true
	eq(CoinsView.eye_alpha(gz, 3.0), 1.0)


func test_meshes_face_outward() -> void:
	for m: ArrayMesh in [CoinsView.build_coin(), CoinsView.build_glazun()]:
		var arr := m.surface_get_arrays(0)
		var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bad := 0
		for k in range(0, vv.size(), 3):
			if (vv[k + 1] - vv[k]).cross(vv[k + 2] - vv[k]).dot(n[k]) > 0.0:
				bad += 1
		eq(bad, 0, "все грани наружу")


## Монетник плывёт со скоростью v n шагов по dt (только поворот тела).
func _swim(cn: EcoCoins.Coin, v: Vector3, n: int, dt := 0.05) -> void:
	cn.vel = v
	for i in n:
		EcoCoins.turn(cn, dt)


func test_coin_faces_its_swim() -> void:
	var cn := EcoCoins.Coin.new()
	_swim(cn, Vector3(1, 0, 0), 60)
	var b := EcoCoins.coin_basis(cn, 0.0)
	ok(b.z.dot(Vector3.RIGHT) > 0.95, "нос (+Z) догнал скорость")
	_swim(cn, Vector3(0, 1, 0), 60)
	ok(EcoCoins.coin_basis(cn, 0.0).is_finite(), "вертикально — без ошибки")


# ---------- Плавность (Б3) ----------

func test_coin_turns_smoothly() -> void:
	var cn := EcoCoins.Coin.new()
	cn.vel = Vector3(1, 0, 0)
	var before := cn.look
	EcoCoins.turn(cn, 0.05)
	var a := before.angle_to(cn.look)
	ok(a > 0.0 and a <= EcoCoins.TURN_MAX * 0.05 + 1e-4, "за шаг — не больше TURN_MAX·dt: %.3f" % a)
	ok(cn.look.dot(Vector3.RIGHT) < 0.5, "на прямой угол сразу не щёлкает")
	_swim(cn, Vector3(1, 0, 0), 40)
	ok(cn.look.dot(Vector3.RIGHT) > 0.99, "за 2 с догнал путь")


func test_coin_banks_into_turn() -> void:
	var cn := EcoCoins.Coin.new()  # нос в +Z, phase 0: в t = 0 покачивания нет
	_swim(cn, Vector3(1, 0, 0), 4)  # +X при носе в +Z — поворот влево
	ok(cn.bank > 0.05, "в повороте влево — крен влево: %.3f" % cn.bank)
	ok(cn.bank <= EcoCoins.BANK_MAX, "не круче BANK_MAX")
	ok(EcoCoins.coin_basis(cn, 0.0).y.x > 0.02, "спина наклонена внутрь поворота (+X)")
	_swim(cn, Vector3(1, 0, 0), 80)
	ok(absf(cn.bank) < 0.02, "на прямой крен уходит: %.3f" % cn.bank)
	var right := EcoCoins.Coin.new()
	_swim(right, Vector3(-1, 0, 0), 4)
	ok(right.bank < -0.05, "вправо — на правый бок")


func test_coin_holds_course_when_stopped() -> void:
	var cn := EcoCoins.Coin.new()
	_swim(cn, Vector3(1, 0, 0), 60)
	_swim(cn, Vector3.ZERO, 40)
	ok(cn.look.dot(Vector3.RIGHT) > 0.99, "стоит — держит курс")
	ok(EcoCoins.coin_basis(cn, 0.0).z.dot(Vector3.RIGHT) > 0.95, "меш не щёлкает носом на свой случайный угол")
	_swim(cn, Vector3(0.02, 0.05, 0), 40)
	ok(absf(cn.look.y) < 0.01, "медленный дрейф — нос выровнен к горизонту")


func test_coin_pitch_limited() -> void:
	var cn := EcoCoins.Coin.new()
	_swim(cn, Vector3(0, 2, 0.01), 100)
	ok(cn.look.y <= sin(EcoCoins.PITCH_MAX) + 1e-3, "вверх — не круче PITCH_MAX: %.3f" % cn.look.y)
	ok(cn.look.y > sin(EcoCoins.PITCH_MAX) - 0.05, "но носом вверх")
	_swim(cn, Vector3(0, -2, 0.01), 100)
	ok(cn.look.y >= -sin(EcoCoins.PITCH_MAX) - 1e-3, "вниз — тоже")


func test_coins_turn_smoothly_in_world() -> void:
	var w := _world()
	w.reset()
	var c := _coins(w)
	w.ship.pos = c.schools[1].center + Vector3(0, 30, 0)  # стайка 1 рядом — шагает каждый кадр (дальние — EcoLod)
	var prev: Array[Vector3] = []
	for cn in c.coins:
		prev.append(cn.look)
	var worst := 0.0
	for i in 400:
		if i == 200:
			c.schools[1].scatter = EcoCoins.SCATTER_TIME  # рассыпались — резкий разворот
			c.schools[1].from = c.schools[1].center + Vector3(1, 0, 0)
		w.step(0.05)
		for cn in c.coins:
			if cn.alive and cn.school == 1:
				worst = maxf(worst, prev[cn.index].angle_to(cn.look))
				ok(absf(cn.look.length() - 1.0) < 1e-3 and absf(cn.bank) <= EcoCoins.BANK_MAX + 1e-4, "нос единичный, крен в пределе")
			prev[cn.index] = cn.look
	ok(worst <= EcoCoins.TURN_MAX * 0.05 + 1e-3, "за кадр 0,05 с — не больше TURN_MAX·dt: %.3f" % worst)


func test_eco_view_has_coins() -> void:
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	var c := view.coins
	eq(c.schools.size(), 3)
	ok(view.bladders.coins == c and c.bladders == view.bladders, "пузырчатка и монетники связаны")
	ok(c.moss == view.moss and c.preds == view.preds)
	for gz in c.glazuns:
		near(gz.pos.y, Seabed.height(gz.pos.x, gz.pos.z), 1e-3, "глазун на дне")
	for sc in c.schools:
		ok(sc.patch != null, "над пятном мха")
	ok(view.coins_view != null and view.coins_view.get_parent() == view)
	var ship := EcoLink.ShipState.new()
	ship.pos = Helm.Ship.START
	view.step(0.1, ship)
	view.queue_free()
	await frames(1)


## «Экономно» (Б6): в каждой стайке рисуются две рыбки из трёх — видимые в начале буфера; мир считает всех, глазуны —
## все; назад — буфер снова по номеру; сброс мира уровень не теряет.
func test_view_lite_draws_two_of_three_per_school() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var cv := view.coins_view
	var n := view.coins.coins.size()
	eq(cv.drawn(), n, "на «Обычно» — все монетники")
	view.set_lite(true)
	ok(cv.lite, "монетники — на «Экономно»")
	var per := EcoCoins.PER - EcoCoins.PER / CoinsView.LITE_SKIP
	eq(cv.drawn(), per * view.coins.schools.size(), "две трети в каждой стайке")
	ok(cv.drawn() < n * 0.7, "рыбок меньше на треть: %d" % cv.drawn())
	eq(cv.bodies.multimesh.visible_instance_count, -1, "глазуны — все")
	var seen := {}
	for sc in view.coins.schools:
		var shown := 0
		for k in sc.members.size():
			var cn: EcoCoins.Coin = sc.members[k]
			seen[cv.slot_of(cn.index)] = true
			if cv.slot_of(cn.index) < cv.drawn():
				shown += 1
				ok(CoinsView.lite_shown(k), "видна только показанная")
		eq(shown, per, "в стайке %d видно %d" % [sc.index, per])
	eq(seen.size(), n, "места в буфере не повторяются")
	var ship := EcoLink.ShipState.new()
	ship.pos = FAR
	view.step(0.05, ship)
	var cn4: EcoCoins.Coin = view.coins.schools[1].members[4]
	ok(cv.slot_of(cn4.index) != cn4.index, "место в буфере сдвинуто")
	ok(KelpView.transform_at(cv.coin_buffer, cv.slot_of(cn4.index), CoinsView.STRIDE_C).origin.is_equal_approx(
		cn4.pos), "видимая рыбка — на своём месте буфера")
	view.ground = Seabed.height   # сброс мира — виды пересобираются
	ok(view.coins_view.lite and view.coins_view.drawn() < n, "сброс мира — снова «Экономно»")
	view.set_lite(false)
	cv = view.coins_view
	view.step(0.05, ship)
	eq(cv.drawn(), n, "назад — все")
	cn4 = view.coins.schools[1].members[4]
	eq(cv.slot_of(cn4.index), cn4.index, "буфер снова по номеру")
	ok(KelpView.transform_at(cv.coin_buffer, cn4.index, CoinsView.STRIDE_C).origin.is_equal_approx(cn4.pos),
		"и места переписаны")
	view.queue_free()
	await frames(1)


## Хвост машет (Б3): хвост-конус гнётся вбок бегущей волной, передняя часть диска стоит; у рыбки своя фаза —
## альфа цвета экземпляра; общий шейдер растений с волной `breath` и временем мира `t`.
func test_tail_wave_mesh_and_shader() -> void:
	var m := CoinsView.build_coin()
	var arr := m.surface_get_arrays(0)
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	eq(uv.size(), vv.size(), "UV у каждой вершины")
	eq(uv2.size(), vv.size(), "UV2 у каждой вершины")
	var tip := 0.0
	for i in vv.size():
		near(uv[i].y, CoinsView.tail_bend(vv[i].z), 1e-6, "доля изгиба — по z")
		near(uv[i].x, CoinsView.tail_lag(vv[i].z), 1e-6, "сдвиг фазы — по z")
		eq(uv2[i], Vector2(1, 0), "гнётся вбок")
		if vv[i].z > 0.0:
			eq(uv[i].y, 0.0, "передняя половина диска жёсткая")
		tip = maxf(tip, uv[i].y)
	near(tip, 1.0, 1e-6, "кончик хвоста гнётся целиком")
	var mat := m.surface_get_material(0) as ShaderMaterial
	ok(mat != null and mat.shader.code.contains("UV.x + COLOR.a"), "общий шейдер растений, фаза — альфа цвета")
	eq(mat.get_shader_parameter("breath"), Vector2(CoinsView.TAIL_AMP, CoinsView.TAIL_RATE), "размах и ритм — в шейдер")
	eq(mat.get_shader_parameter("back"), Vector3.ZERO, "без просвета")
	eq(mat.get_shader_parameter("tip_glow"), null, "без светящихся кончиков")


func test_tail_offset_twin() -> void:
	var z := CoinsView.TAIL_TIP
	var t0 := -CoinsView.tail_lag(z) / CoinsView.TAIL_RATE
	near(CoinsView.tail_offset(z, t0, 0.0), -CoinsView.TAIL_AMP, 1e-5, "кончик на полном размахе")
	near(CoinsView.tail_offset(z, t0 + 0.5 / CoinsView.TAIL_RATE, 0.0), CoinsView.TAIL_AMP, 1e-5,
		"через полвзмаха — в другую сторону")
	near(CoinsView.tail_offset(0.1, 0.3, 0.2), 0.0, 1e-6, "нос стоит")
	near(CoinsView.tail_offset(z, 0.0, 0.0, 0.0), 0.0, 1e-6, "«Экономно» — не машет")
	ok(absf(CoinsView.tail_offset(-0.15, 0.0, 0.0)) < CoinsView.TAIL_AMP * 0.35, "задний край диска — слабее кончика")
	# волна бежит к кончику: кончик повторяет середину хвоста с опозданием
	var lag := (CoinsView.tail_lag(-0.12) - CoinsView.tail_lag(z)) / CoinsView.TAIL_RATE
	ok(lag > 0.0, "к кончику волна приходит позже")
	near(CoinsView.tail_offset(z, 0.7 + lag, 0.3) / CoinsView.tail_bend(z),
		CoinsView.tail_offset(-0.12, 0.7, 0.3) / CoinsView.tail_bend(-0.12), 1e-5, "та же фаза — позже")
	# за кадр 1/30 с кончик сдвигается плавно
	var worst := 0.0
	for k in 60:
		var t := k / 30.0
		worst = maxf(worst, absf(CoinsView.tail_offset(z, t + 1.0 / 30.0, 0.4) - CoinsView.tail_offset(z, t, 0.4)))
	ok(worst < 0.012, "без рывков: %.4f м за кадр" % worst)


## Б3: появившаяся над мхом рыбка вырастает за COIN_RISE, а не возникает за кадр; схваченная — пропадает сразу.
func test_view_new_coin_grows() -> void:
	var w := _world()
	var c := _coins(w)
	var v := CoinsView.new(c)
	var cn := c.coins[4]
	var t := 1.0
	v.sync(t)
	var full := KelpView.transform_at(v.coin_buffer, v.slot_of(4), CoinsView.STRIDE_C).basis.x.length()
	ok(full > 0.05, "живая во весь размер: %.3f" % full)
	cn.alive = false
	t += 0.1
	v.sync(t)
	ok(KelpView.transform_at(v.coin_buffer, v.slot_of(4), CoinsView.STRIDE_C).basis.x.length() < 1e-6, "схваченная — сразу")
	cn.alive = true
	var dt := 1.0 / 30.0
	var last := 0.0
	var worst := 0.0
	for i in int(CoinsView.COIN_RISE / dt) + 2:
		t += dt
		v.sync(t)
		var tr := KelpView.transform_at(v.coin_buffer, v.slot_of(4), CoinsView.STRIDE_C)
		var sz := tr.basis.x.length()
		if i == 0:
			ok(sz < full * 0.05, "появилась крошечной: %.4f" % sz)
			ok(tr.origin.is_equal_approx(cn.pos), "растёт на своём месте")
		worst = maxf(worst, sz - last)
		last = sz
	ok(worst < full * 0.15, "за шаг растёт на %.4f < 15 %%" % worst)
	near(last, full, 1e-4, "выросла во весь размер")
	cn.alive = false
	v.sync(t)
	cn.alive = true
	v.sync(t + 5.0)
	near(KelpView.transform_at(v.coin_buffer, v.slot_of(4), CoinsView.STRIDE_C).basis.x.length(), full, 1e-4,
			"скачок времени — сразу к цели")
	v.free()


func test_view_tail_phase_and_time() -> void:
	var w := _world()
	var c := _coins(w)
	var v := CoinsView.new(c)
	v.sync(3.5)
	near(float(v.mat.get_shader_parameter("t")), 3.5, 1e-6, "время мира — в шейдер")
	var phases := {}
	for cn in c.coins:
		var a := v.coin_buffer[v.slot_of(cn.index) * CoinsView.STRIDE_C + 15]
		near(a, CoinsView.tail_phase(cn), 1e-6, "фаза рыбки — альфа экземпляра")
		ok(a >= 0.0 and a < 1.0)
		phases[snappedf(a, 0.05)] = true
	ok(phases.size() >= 8, "машут вразнобой: %d разных фаз" % phases.size())
	v.free()
