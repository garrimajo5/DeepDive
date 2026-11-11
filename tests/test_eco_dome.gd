extends TestCase
## Купольник у террасы врат 07 (#837, часть 1): ждёт в нише, корабль у террасы — выходит к гнезду, поднимает
## створку (раз), уходит; на пути корабля стоит; не вид бестиария; диагностика от него не зависит.

const DT := 0.1


func _world(ship_at: Vector3) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = ship_at
	return w


func _far() -> Vector3:
	return Vector3(0.0, -30.0, 95.0)   # старт 00


## Корабль у террасы, но в стороне от пути ниша → гнездо (к югу от середины, на подходе).
func _near() -> Vector3:
	return Vector3(EcoGate.CENTER.x, -35.0, EcoGate.CENTER.y + 60.0)


func _run(w: EcoWorld, d: EcoDome, secs: float) -> int:
	var opens := 0
	var tt := 0.0
	while tt < secs:
		w.time += DT
		d.step(w, DT)
		if d.just_opened:
			opens += 1
		tt += DT
	return opens


func test_waits_in_niche_until_ship_comes() -> void:
	var w := _world(_far())
	var d := EcoDome.new()
	d.reset(w)
	var start := d.pos
	_run(w, d, 60.0)
	eq(d.state, EcoDome.State.WAIT, "корабль далеко — ждёт")
	near(d.pos.distance_to(start), 0.0, 1e-5, "стоит в нише")
	ok(Vector2(start.x, start.z).distance_to(EcoGate.CENTER) > 60.0, "ниша вне террасы")
	near(d.glow, EcoDome.GLOW_REST, 1e-5, "фотофоры в покое")


func test_goes_opens_once_and_leaves() -> void:
	var w := _world(_far())
	var d := EcoDome.new()
	d.reset(w)
	w.ship.pos = _near()
	_run(w, d, 0.2)
	eq(d.state, EcoDome.State.GO, "корабль у террасы — выходит")
	var peak := 0.0
	for i in 10:
		w.time += DT
		d.step(w, DT)
		peak = maxf(peak, d.glow)
	ok(peak > 0.6, "импульс фотофоров — команда")
	var opens := _run(w, d, 200.0)
	eq(opens, 1, "створка открылась один раз")
	ok(d.opened, "створка открыта")
	near(d.petal, 1.0, 1e-4, "поднята целиком и остаётся")
	eq(d.state, EcoDome.State.GONE, "ушёл в нишу")
	ok(not d.shown(), "после ухода не виден")
	eq(_run(w, d, 120.0), 0, "второй раз не открывает")
	w.ship.pos = _far()
	_run(w, d, 5.0)
	w.ship.pos = _near()
	eq(_run(w, d, 120.0), 0, "корабль вернулся — купольник больше не выходит")


func test_stands_at_nest_while_opening() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var guard := 0
	while d.state != EcoDome.State.OPEN and guard < 3000:
		w.time += DT
		d.step(w, DT)
		guard += 1
	eq(d.state, EcoDome.State.OPEN, "дошёл до гнезда")
	var n := GateDiag.nest_pos(EcoDome.NEST)
	ok(Vector2(d.pos.x, d.pos.z).distance_to(Vector2(n.x, n.z)) < 2.0, "у первого гнезда")
	near(d.pos.y - Seabed.height(d.pos.x, d.pos.z), EcoDome.AT_NEST, 0.2, "у дна, на уровне гнезда")
	eq(d.clip(), "OpenPetal", "клип открытия")
	_run(w, d, 1.0)
	near(d.petal, 0.0, 1e-4, "сначала держит обод — створка ещё закрыта")
	_run(w, d, 1.7)
	ok(d.petal > 0.2 and d.petal < 0.9, "поднимает по направляющей плавно")


func test_path_stays_above_floor() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var low := INF
	var guard := 0
	while d.state != EcoDome.State.GONE and guard < 4000:
		w.time += DT
		d.step(w, DT)
		low = minf(low, d.pos.y - Seabed.height(d.pos.x, d.pos.z))
		guard += 1
	eq(d.state, EcoDome.State.GONE, "весь путь пройден")
	ok(low > 0.4, "не уходит в дно (ниже всего %.2f м)" % low)


func test_ship_in_the_way_waits() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	_run(w, d, 20.0)
	eq(d.state, EcoDome.State.GO, "в пути")
	w.ship.pos = d.pos + Vector3(0.0, 4.0, 10.0)   # корабль у самого купольника
	var from := d.pos
	_run(w, d, 1.0)
	ok(d.pos.distance_to(from) < 0.3, "тормозит, а не плывёт дальше (%.2f м)" % d.pos.distance_to(from))
	var at := d.pos
	_run(w, d, 15.0)
	near(d.pos.distance_to(at), 0.0, 1e-4, "корабль на пути — стоит")
	eq(d.clip(), "Idle", "не плывёт")
	w.ship.pos = _near()
	_run(w, d, 5.0)
	ok(d.pos.distance_to(at) > 1.0, "пропустили — плывёт дальше")


## Б3: трогается и встаёт плавно — скорость меняется не быстрее ACCEL/BRAKE, к гнезду подходит тихим ходом.
func test_speed_eases() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var prev := 0.0
	var worst := 0.0
	var at_arrive := -1.0
	var guard := 0
	while d.state != EcoDome.State.OPEN and guard < 3000:
		var was_go := d.state == EcoDome.State.GO
		w.time += DT
		d.step(w, DT)
		if d.state == EcoDome.State.OPEN and was_go:
			at_arrive = prev
		worst = maxf(worst, absf(d.speed - prev))
		if d.state == EcoDome.State.GO and guard < 5:
			ok(d.speed <= EcoDome.ACCEL * DT * (guard + 1) + 1e-4, "трогается с места: %.2f м/с" % d.speed)
		prev = d.speed
		guard += 1
	eq(d.state, EcoDome.State.OPEN, "дошёл до гнезда")
	ok(worst <= EcoDome.BRAKE * DT + 1e-4, "скорость за шаг меняется не больше %.2f (было %.2f)" % [EcoDome.BRAKE * DT, worst])
	ok(at_arrive >= 0.0 and at_arrive < 0.3, "к гнезду — тихим ходом (%.2f м/с)" % at_arrive)
	near(EcoDome.want_speed(EcoDome.SWIM, 1.0, 50.0, true), 0.0, 1e-6, "корабль на пути — стоп")
	near(EcoDome.want_speed(EcoDome.SWIM, 1.0, 50.0, false), EcoDome.SWIM, 1e-6, "далеко — полный ход")


func test_does_not_close_in_on_ship() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	w.ship.pos = d.stand() + Vector3(0.0, 8.0, 8.0)   # корабль завис у самого гнезда
	var closest := INF
	_run(w, d, 0.1)
	for i in 3000:
		w.time += DT
		d.step(w, DT)
		closest = minf(closest, d.pos.distance_to(w.ship.pos))
	ok(closest >= EcoDome.KEEP - 0.5, "ближе KEEP к кораблю не подходит (%.1f м)" % closest)
	ok(not d.opened, "пока корабль у гнезда — створку не открыл")


func test_not_a_bestiary_target_and_ignores_light() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var out: Array[Dictionary] = []
	d.targets(w, out)
	eq(out.size(), 0, "не цель сканера и сонара")
	w.ship.light_on = true
	w.ship.light_range = 60.0
	var lit := EcoDome.new()
	var w2 := _world(_near())
	lit.reset(w2)
	_run(w, d, 40.0)
	_run(w2, lit, 40.0)
	near(d.pos.distance_to(lit.pos), 0.0, 1e-5, "прожектор путь не меняет")


func test_diagnostics_do_not_need_dome() -> void:
	var g := GateDiag.new()
	var lore := LayerLore.new()
	var n := GateDiag.nest_pos(EcoDome.NEST)
	g.aim(n + Vector3(0.0, 10.0, 20.0), lore)
	eq(g.nest, EcoDome.NEST, "гнездо читается и при закрытой створке")


func test_scene_has_dome_at_gate() -> void:
	var v := EcoView.new()
	tree.root.add_child(v)
	await frames(1)
	ok(v.dome != null and v.world.systems.has(v.dome), "купольник в мире")
	eq(v.dome.state, EcoDome.State.WAIT, "на старте ждёт в нише")
	v.queue_free()
	await frames(1)


func test_petal_event_sent_once() -> void:   # часть 2: событие «створка открыта» — одно, с гнездом и строкой
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var got: Array[Dictionary] = []
	for i in 4000:
		w.time += DT
		d.step(w, DT)
		for e in w.take_link():
			if e["type"] == EcoLink.PETAL:
				got.append(e)
	eq(got.size(), 1, "событие пришло один раз")
	eq([got[0]["nest"], got[0]["text"]], [EcoDome.NEST, EcoDome.PETAL_TEXT], "гнездо и строка")


func test_petal_already_open_in_campaign() -> void:   # сохранение: створка открыта — купольник не выходит
	var w := _world(_near())
	w.ship.petal_open = true
	var d := EcoDome.new()
	d.reset(w)
	var opens := _run(w, d, 200.0)
	eq(opens, 0, "второй раз не открывает")
	eq(d.state, EcoDome.State.GONE, "в нише, не выходит")
	ok(d.opened and is_equal_approx(d.petal, 1.0), "створка поднята")
	var sent := 0
	for e in w.take_link():
		if e["type"] == EcoLink.PETAL:
			sent += 1
	eq(sent, 0, "события нет")


func test_turn_eases_without_jerk() -> void:   # Б3: поворот с инерцией — не трогается рывком на TURN рад/с
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var prev_v := 0.0
	var worst := 0.0
	var top := 0.0
	var steps := 0
	var guard := 0
	while d.state != EcoDome.State.GONE and guard < 6000:
		w.time += DT
		d.step(w, DT)
		worst = maxf(worst, absf(d.turn_v - prev_v))
		top = maxf(top, absf(d.turn_v))
		if d.state == EcoDome.State.BACK and steps < 3:
			ok(absf(d.turn_v) <= EcoDome.TURN_ACCEL * DT * (steps + 1) + 1e-4, "разворот к нише — не рывком: %.2f рад/с" % d.turn_v)
			steps += 1
		prev_v = d.turn_v
		guard += 1
	eq(d.state, EcoDome.State.GONE, "открыл створку и ушёл в нишу")
	ok(worst <= EcoDome.TURN_ACCEL * DT + 1e-3, "скорость поворота за шаг меняется не больше %.3f (было %.3f)" % [EcoDome.TURN_ACCEL * DT, worst])
	ok(top <= EcoDome.TURN + 1e-4 and top > 0.1, "поворачивает, не быстрее TURN (%.2f рад/с)" % top)


func test_turn_settles_on_course() -> void:   # доворачивает без перелёта, коротким путём через ±PI
	for want in [1.5, -2.0, 3.0]:
		var yaw := -2.9 if want > 2.0 else 0.0
		var v := 0.0
		var err0 := wrapf(want - yaw, -PI, PI)
		var over := 0.0
		for i in 400:
			var r := EcoDome.turn(yaw, v, want, DT)
			yaw = r.x
			v = r.y
			var err := wrapf(want - yaw, -PI, PI)
			if signf(err) != signf(err0) and err != 0.0:
				over = maxf(over, absf(err))
		near(wrapf(want - yaw, -PI, PI), 0.0, 1e-3, "встал на курс %.1f" % want)
		near(v, 0.0, 1e-2, "и остановил поворот")
		ok(over < 0.01, "без перелёта (%.3f рад)" % over)


## Б3: у гнезда не прыгает — прийти (ближе ARRIVE) не значит встать в точку разом: раньше за шаг прихода купол
## переставлялся в stand() на остаток до 0,3 м (3 м/с при ходе 0,12), теперь доходит в OPEN ходом SETTLE.
func test_no_jump_at_nest() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var prev := d.pos
	var worst := 0.0
	var guard := 0
	while d.state != EcoDome.State.GONE and guard < 6000:
		w.time += DT
		d.step(w, DT)
		if d.shown():
			worst = maxf(worst, d.pos.distance_to(prev))
		prev = d.pos
		guard += 1
	eq(d.state, EcoDome.State.GONE, "открыл створку и ушёл")
	ok(worst <= EcoDome.LEAVE * 1.2 * DT, "за шаг сдвиг не больше %.2f м (было %.2f)" % [EcoDome.LEAVE * 1.2 * DT, worst])
	# у гнезда доходит в точку до подъёма створки
	var d2 := EcoDome.new()
	d2.reset(w)
	w.ship.pos = _near()
	guard = 0
	while d2.state != EcoDome.State.OPEN and guard < 3000:
		w.time += DT
		d2.step(w, DT)
		guard += 1
	_run(w, d2, EcoDome.LIFT.x)
	near(d2.pos.distance_to(d2.stand()), 0.0, 1e-3, "к подъёму створки стоит у гнезда")


## Б3: корпус не проходит сквозь купольника. Раньше он лишь вставал, когда центр корабля ближе KEEP, — корма (до 29 м
## от центра) задевала его, а корабль, прошедший над ним в пути (купольник — на CRUISE над дном, днище корабля на
## CLEARANCE — ниже его купола), шёл сквозь тело. Теперь обшивка отодвигает его по горизонтали (`HULL_R`, нос — вперёд
## и вбок `SLIP`), без рывков и не в дно; корабль ушёл — плывёт дальше.
func test_hull_pushes_dome_aside() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	_run(w, d, 20.0)
	eq(d.state, EcoDome.State.GO, "в пути")
	ok(Vector2(d.pos.x - d.stand().x, d.pos.z - d.stand().z).length() > EcoDome.DESCEND, "ещё на высоте пути")
	# корабль на высоте дна + CLEARANCE идёт над купольником носом в −Z: от 40 м позади до 40 м впереди
	var at := d.pos
	var fy := d.floor_y(at.x, at.z)
	w.ship.yaw = 0.0
	ok(EcoHull.touches(at, Vector3(at.x, fy + Helm.Ship.CLEARANCE, at.z), 0.0, EcoDome.HULL_R),
			"проверка честная: над ним корпус задевает купольника")
	w.ship.pos = Vector3(at.x, fy + Helm.Ship.CLEARANCE, at.z + 40.0)
	var dt := 1.0 / 30.0
	var ship_v := 6.0
	var inside := 0
	var worst := 0.0
	var low := INF
	var prev := d.pos
	for i in int(80.0 / ship_v / dt):
		w.ship.pos += Vector3(0.0, 0.0, -ship_v * dt)
		w.ship.pos.y = d.floor_y(w.ship.pos.x, w.ship.pos.z) + Helm.Ship.CLEARANCE
		w.time += dt
		d.step(w, dt)
		if w.touches_ship(d.pos):
			inside += 1
		worst = maxf(worst, d.pos.distance_to(prev) / dt)
		low = minf(low, d.pos.y - d.floor_y(d.pos.x, d.pos.z))
		prev = d.pos
	eq(inside, 0, "ни на шаге не внутри корпуса")
	ok(worst < 15.0, "обшивка толкает без рывков (как в test_eco_reset_jumps): %.1f м/с" % worst)
	ok(low >= 0.0, "не уходит в дно: %.2f м над дном" % low)
	w.ship.pos = _near()
	var guard := 0
	while not d.opened and guard < 3000:
		w.time += DT
		d.step(w, DT)
		guard += 1
	ok(d.opened, "корабль ушёл — дошёл до гнезда и открыл створку")


func test_stage_for_qa_step() -> void:   # #1350: шаг «dome» сценария тестера — у гнезда посреди клипа, дальше сам
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	_run(w, d, 400.0)
	eq(d.state, EcoDome.State.GONE, "до шага створку уже открыл и ушёл (как в прогоне после 32f)")
	d.stage(2.5)
	eq(d.state, EcoDome.State.OPEN, "снова у гнезда")
	eq(d.clip(), "OpenPetal", "клип открывания")
	ok(d.shown(), "виден")
	near(d.pos.distance_to(d.stand()), 0.0, 1e-4, "стоит на месте у гнезда")
	ok(d.petal > 0.2 and d.petal < 0.9, "створка на полпути: %.2f" % d.petal)
	ok(not d.opened, "ещё не открыта")
	var n := GateDiag.nest_pos(EcoDome.NEST)
	var face := Vector2(-sin(d.yaw), -cos(d.yaw)).dot(Vector2(n.x - d.pos.x, n.z - d.pos.z).normalized())
	ok(face > 0.99, "носом к гнезду: %.3f" % face)
	w.ship.pos = Vector3(n.x, -41.0, n.z + 25.0)   # корабль кадра шага — в 25 м южнее
	var opens := _run(w, d, 2.0)
	eq(opens, 1, "через 1,3 с створка поднята — одно событие")
	ok(d.petal > 0.99, "створка поднята")
	_run(w, d, 2.0)
	eq(d.state, EcoDome.State.BACK, "после клипа уходит в нишу")
	d.stage(99.0)
	near(d.t, EcoDome.OPEN_TIME, 1e-5, "время клипа — не дальше его длины")
