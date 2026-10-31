extends TestCase
## Эхоловец (js/echo.js, ART-007): лежит у Костей левиафана снаружи клетки, уши по отдельности поворачиваются
## на корабль, затаившегося нет на сонаре и в прицеле, импульс сонара ближе 70 м раскрывает его на 120 с;
## подделывает голоса экипажа по связи (EcoLink.VOICE): выпрошенный импульс — удар, выпрошенный свет —
## серпохвост; в сцене — шесть вызовов отрисовки.

const FLAT := -46.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world(with_bones: bool = true) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var b: EcoBones = null
	if with_bones:
		b = w.add(EcoBones.new()) as EcoBones
	w.add(EcoEcho.new(b))
	return w


func _sys(w: EcoWorld, cls: Variant) -> Variant:
	for s in w.systems:
		if is_instance_of(s, cls):
			return s
	return null


func _notes(w: EcoWorld, note: String) -> int:
	var n := 0
	for ev in w.bus.pending:
		if ev.species == EcoEcho.ID and ev.note == note:
			n += 1
	return n


func _ping(w: EcoWorld, at: Vector3) -> Array[Dictionary]:
	w.ship.pos = at
	w.ship.sonar_ping = true
	w.ship.sonar_range = 150.0
	w.step(0.05)
	w.ship.sonar_ping = false
	return w.take_link()


func _echo_near(link: Array[Dictionary]) -> Dictionary:
	for ev in link:
		if ev["type"] == EcoLink.NEAR and ev["species"] == EcoEcho.ID:
			return ev
	return {}


# ---------- Место ----------

func test_lies_outside_cage_between_ribs() -> void:
	var w := _world()
	var b: EcoBones = _sys(w, EcoBones)
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	near(ec.p.y, FLAT + EcoEcho.UP, 1e-4, "на дне")
	var q := b.to_local(ec.p)
	ok(q.z > b.rib_z[EcoEcho.PAIR] and q.z < b.rib_z[EcoEcho.PAIR + 1], "между парами рёбер: z %.2f" % q.z)
	var foot := absf(b.rib_point(EcoEcho.PAIR * 2, 0).x)
	ok(absf(q.x) > foot + 2.0, "снаружи клетки: |x| %.2f, нога %.2f" % [absf(q.x), foot])
	ok(absf(q.x) > EcoBones.PASS_W * 0.5 + 2.0, "не в проходе корабля")
	# тело ~3 м с запасом не в кости
	for dz in [-1.6, 0.0, 1.6]:
		for dx in [-0.7, 0.0, 0.7]:
			var p := ec.xform() * Vector3(dx, 0.0, dz)
			ok(not b.solid(p), "тело не в кости: %s" % p)
	ok(ec.p.distance_to(Vector3(EcoBones.CENTER.x, FLAT, EcoBones.CENTER.y)) < 25.0, "у Костей левиафана")
	# голова — наружу от оси клетки
	var head := ec.xform().basis * Vector3.BACK
	var out := ec.p - b.to_world(Vector3(0, ec.p.y - b.base.y, q.z))
	out.y = 0.0
	ok(head.dot(out.normalized()) > 0.95, "голова наружу от клетки")


func test_without_bones_offset_from_center() -> void:
	var w := _world(false)
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	near(ec.p.x, EcoBones.CENTER.x + 14.0, 1e-4, "как в браузере: +14")
	near(ec.p.z, EcoBones.CENTER.y + 10.0, 1e-4, "+10")
	near(ec.p.y, FLAT + 0.7, 1e-4)


static func _slope(x: float, _z: float) -> float:
	return FLAT + x * 0.4


func test_on_slope_body_above_floor() -> void:
	var w := EcoWorld.new()
	w.ground = _slope
	var e := w.add(EcoEcho.new()) as EcoEcho
	var ec := e.echo
	for o in EcoEcho.BED:
		var q := ec.xform().basis * o
		var p := ec.p + q
		ok(p.y >= _slope(p.x, p.z) + EcoEcho.UP - 1e-4, "тело не в склоне: %s" % o)


func test_reset_restores() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var p := e.echo.p
	_ping(w, p + Vector3(0, 10, 30))
	w.run(5.0)
	w.reset()
	ok(not e.echo.is_revealed(), "сброс — затаился")
	near(e.echo.p.distance_to(p), 0.0, 1e-4, "на том же месте")


# ---------- Уши ----------

func test_ears_turn_to_near_ship_each_separately() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ec := e.echo
	var ship := ec.xform() * Vector3(-8.0, 6.0, 4.0)
	w.ship.pos = ship
	w.run(6.0)
	ok(ec.near, "корабль ближе 60 м — слушает")
	for i in 2:
		var to := (ship - ec.ear_base(i)).normalized()
		ok(e.ear_dir(i).dot(to) > 0.99, "ухо %d смотрит на корабль: %.3f" % [i, e.ear_dir(i).dot(to)])
	ok(absf(ec.ears[0].x - ec.ears[1].x) > 0.02, "уши повёрнуты каждое на свой угол")


func test_ear_turn_speed_limited() -> void:
	var w := _world()
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	var before := ec.ears[0]
	w.ship.pos = ec.xform() * Vector3(0.0, 2.0, -20.0)  # позади
	w.step(0.1)
	var d := ec.ears[0] - before
	ok(absf(d.x) <= EcoEcho.EAR_TURN * 0.1 + 1e-4, "поворот не быстрее EAR_TURN")
	ok(absf(d.y) <= EcoEcho.EAR_TURN * 0.1 + 1e-4, "наклон не быстрее EAR_TURN")


func test_ear_starts_and_stops_smoothly() -> void:
	# Плавность (Б3): корабль подошёл — уши трогаются разгоном, а не сразу на EAR_TURN; скорость меняется не быстрее
	# EAR_ACCEL; к неподвижному кораблю подходят без перелёта и встают.
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ec := e.echo
	w.run(3.0)
	var ship := ec.xform() * Vector3(-14.0, 3.0, 6.0)
	w.ship.pos = ship
	var dt := 0.05
	var want := e.aim(0, ship)
	var prev := ec.ears[0]
	var vel := ec.ear_vel[0]
	var side := signf(want.x - prev.x)
	var top := 0.0
	for k in 120:
		w.step(dt)
		var now := ec.ears[0]
		var v := (now - prev) / dt
		ok(absf(v.x) <= EcoEcho.EAR_TURN + 1e-4, "шаг %d: поворот не быстрее EAR_TURN (%.3f)" % [k, v.x])
		ok(absf(v.x - vel.x) <= EcoEcho.EAR_ACCEL * dt + 1e-4,
			"шаг %d: разгон не быстрее EAR_ACCEL (%.3f → %.3f)" % [k, vel.x, v.x])
		ok(signf(want.x - now.x) != -side, "шаг %d: без перелёта цели" % k)
		top = maxf(top, absf(v.x))
		prev = now
		vel = v
	ok(top > EcoEcho.EAR_TURN * 0.5, "разогналось: %.2f" % top)
	near(ec.ears[0].x, want.x, 1e-3, "дошло до цели")
	near(ec.ear_vel[0].x, 0.0, 1e-2, "и встало")


func test_ear_does_not_swing_through_the_back() -> void:
	# Ухо справа сзади, корабль слева сзади: поворот идёт через нос, а не через затылок за предел сустава.
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ec := e.echo
	ec.ears[0] = Vector2(2.1, EcoEcho.IDLE_PITCH)
	var ship := ec.ear_base(0) + Basis(Vector3.UP, ec.yaw) * Vector3(sin(-2.1), 0.0, cos(-2.1)) * 20.0
	w.ship.pos = ship
	var want := e.aim(0, ship)
	ok(want.x < -2.0, "цель — слева сзади: %.2f" % want.x)
	var prev := ec.ears[0].x
	for k in 160:
		w.step(0.05)
		var x := ec.ears[0].x
		ok(x <= prev + 1e-5, "шаг %d: поворот только к носу и дальше влево" % k)
		ok(absf(x) <= EcoEcho.EAR_YAW + 1e-5, "шаг %d: в пределах сустава" % k)
		prev = x
	near(ec.ears[0].x, want.x, 1e-3, "дошло через нос")


func test_ear_joint_limits() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ec := e.echo
	var a := e.aim(0, ec.xform() * Vector3(0.0, 0.0, -30.0))  # прямо позади
	ok(absf(a.x) <= EcoEcho.EAR_YAW + 1e-5, "поворот в пределах")
	var up := e.aim(0, ec.ear_base(0) + Vector3(0, 40, 0))
	near(up.y, EcoEcho.EAR_PITCH_MAX, 1e-5, "наклон вверх ограничен")


func test_far_ship_ears_idle() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ec := e.echo
	w.ship.pos = ec.p + Vector3(0, 0, EcoEcho.LISTEN_R + 5.0)
	w.run(10.0)
	ok(not ec.near, "дальше 60 м — не слушает")
	var a := ec.ears[0]
	w.run(5.0)
	ok(ec.ears[0].distance_to(a) > 0.05, "уши медленно обводят воду")


# ---------- Сонар и сканер ----------

func test_hidden_from_sonar_and_scanner() -> void:
	var w := _world()
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	var t := {}
	for x in w.scan_targets():
		if x["species"] == EcoEcho.ID:
			t = x
	ok(not t.is_empty(), "цель есть")
	ok(t["hidden"] and not t["sonar"], "затаился — ни сонару, ни сканеру")
	w.ship.pos = ec.p + Vector3(0, 8, 20)
	w.ship.scan_range = 80.0
	w.step(0.05)
	ok(_echo_near(w.take_link()).is_empty(), "сканер его не видит")


func test_ping_reveals_for_120s() -> void:
	var w := _world()
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	var link := _ping(w, ec.p + Vector3(0, 10, 50))
	ok(ec.is_revealed(), "импульс ближе 70 м — раскрыт")
	var obs := 0
	for ev in link:
		if ev["type"] == EcoLink.OBSERVE and ev["species"] == EcoEcho.ID and ev["note"] == "reveal":
			obs += 1
			eq(ev["text"], "Импульс сонара выдал засадчика с ушами-воронками: он раскрыт", "текст наблюдения")
	eq(obs, 1, "наблюдение «reveal»")
	var n := _echo_near(link)
	ok(not n.is_empty() and n["sonar"], "отметка на сонаре в том же импульсе")
	w.ship.scan_range = 80.0
	w.step(0.05)
	var s := _echo_near(w.take_link())
	ok(not s.is_empty() and s["scan"], "раскрытый — в прицеле сканера")
	_ping(w, ec.p + Vector3(0, 10, 50))
	eq(_notes(w, "reveal"), 0, "повторный импульс — без нового наблюдения")
	w.ship.scan_range = 0.0
	w.run(EcoEcho.REVEAL_T - 1.0)
	ok(ec.is_revealed(), "держится REVEAL_T от последнего импульса")
	w.run(2.0)
	ok(not ec.is_revealed(), "потом снова затаился")


func test_far_ping_does_not_reveal() -> void:
	var w := _world()
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	var link := _ping(w, ec.p + Vector3(0, 0, EcoEcho.REVEAL_R + 2.0))
	ok(not ec.is_revealed(), "дальше 70 м — затаился")
	ok(_echo_near(link).is_empty(), "и на сонаре его нет")


func test_reveal_text_uses_scanned_name() -> void:
	var w := _world()
	w.scanned = func(sp: String) -> bool: return sp == EcoEcho.ID
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	var link := _ping(w, ec.p + Vector3(0, 10, 30))
	var txt := ""
	for ev in link:
		if ev["type"] == EcoLink.OBSERVE and ev["note"] == "reveal":
			txt = ev["text"]
	eq(txt, "Импульс сонара выдал эхоловца: он раскрыт", "изученный — по имени")


# ---------- Подделки голосов (Ec.fake/real/onPing/onLight) ----------

func _voices(link: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev in link:
		if ev["type"] == EcoLink.VOICE:
			out.append(ev)
	return out


func _hits(link: Array[Dictionary]) -> int:
	var n := 0
	for ev in link:
		if ev["type"] == EcoLink.HIT:
			n += 1
	return n


## Корабль у эхоловца: подождать первую подделку; вернуть её событие.
func _first_fake(w: EcoWorld, ec: EcoEcho.Lurker) -> Dictionary:
	w.ship.pos = ec.p + Vector3(0, 10, 30)
	for i in int(EcoEcho.FAKE_FIRST / 0.05) + 2:
		w.step(0.05)
		for v in _voices(w.take_link()):
			if v["fake"]:
				return v
	return {}


func test_fake_call_when_ship_near() -> void:
	var w := _world()
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	w.ship.pos = ec.p + Vector3(0, 10, EcoEcho.LISTEN_R + 5.0)
	w.run(EcoEcho.FAKE_FIRST + 5.0)
	var far := 0
	for v in _voices(w.take_link()):
		if v["fake"]:
			far += 1
	eq(far, 0, "дальше LISTEN_R — подделок нет")
	w.ship.pos = ec.p + Vector3(0, 10, 30)
	w.run(EcoEcho.FAKE_FIRST - 1.0)
	eq(ec.fakes, 0, "первая — не раньше FAKE_FIRST после подхода")
	w.run(1.5)
	eq(ec.fakes, 1, "потом ложный вызов")
	var v := _voices(w.take_link())
	var f := {}
	for x in v:
		if x["fake"]:
			f = x
	ok(not f.is_empty(), "VOICE с fake")
	ok(f["ask"] == EcoEcho.ASK_PING or f["ask"] == EcoEcho.ASK_LIGHT, "с просьбой: %s" % f["ask"])
	eq([f["role"], f["text"]], EcoEcho.FAKES[f["ask"]], "роль и текст по просьбе")
	ok(f["silent"], "первый спуск: старого кода нет — молчит на «Спросить код»")
	eq(ec.bait, f["ask"], "просьба ждёт исполнения")
	w.run(EcoEcho.FAKE_CD - 2.0)
	eq(ec.fakes, 1, "следующая не раньше FAKE_CD")
	w.run(3.0)
	eq(ec.fakes, 2, "раз в FAKE_CD")


func test_fake_answers_old_word_on_later_dive() -> void:
	var w := _world()
	w.ship.dive = 1
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	var f := _first_fake(w, ec)
	ok(not f.is_empty(), "подделка")
	ok(not f["silent"], "второй спуск: отвечает старым словом (у корабля — «Код не совпал»)")


func test_light_off_sometimes_asks_light() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var kinds := {}
	for i in 30:
		kinds[e.fake(w)["ask"]] = true
	ok(kinds.has(EcoEcho.ASK_LIGHT) and kinds.has(EcoEcho.ASK_PING), "без света — и свет, и импульс: %s" % kinds)
	w.ship.light_on = true
	for i in 20:
		eq(e.fake(w)["ask"], EcoEcho.ASK_PING, "свет уже горит — просит импульс")


func test_asked_ping_strikes_hull() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ec := e.echo
	w.ship.pos = ec.p + Vector3(0, 10, 30)
	e.fake(w, EcoEcho.ASK_PING)
	w.take_link()
	var link := _ping(w, ec.p + Vector3(0, 10, 30))
	eq(_hits(link), 1, "выпрошенный импульс — удар")
	for ev in link:
		if ev["type"] == EcoLink.HIT:
			near(ev["damage"], EcoEcho.STRIKE, 1e-6, "−12 %")
	ok(not ec.is_revealed(), "свой импульс его не раскрывает")
	eq(ec.bait, "", "просьба исполнена")
	var txt := ""
	for ev in link:
		if ev["type"] == EcoLink.OBSERVE and ev["note"] == "strike":
			txt = ev["text"]
	eq(txt, "Засадчик с ушами-воронками ударил по корпусу на звук импульса, который сам выпросил", "наблюдение «strike»")
	link = _ping(w, ec.p + Vector3(0, 10, 30))
	eq(_hits(link), 0, "второй импульс — уже не выпрошен")
	ok(ec.is_revealed(), "и раскрывает его")


func test_asked_ping_far_no_strike() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ec := e.echo
	e.fake(w, EcoEcho.ASK_PING)
	var link := _ping(w, ec.p + Vector3(0, 10, EcoEcho.STRIKE_R + 5.0))
	eq(_hits(link), 0, "дальше STRIKE_R — не дотянулся")
	ok(not ec.is_revealed(), "выпрошенный импульс не раскрывает")


func test_unasked_ping_reveals_and_stops_fakes() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ec := e.echo
	e.fake(w, EcoEcho.ASK_LIGHT)
	var link := _ping(w, ec.p + Vector3(0, 10, 30))
	eq(_hits(link), 0, "о импульсе не просил — удара нет")
	ok(ec.is_revealed(), "раскрыт")
	eq(ec.bait, "", "просьба сорвана")
	var n := ec.fakes
	w.run(EcoEcho.FAKE_CD + 5.0)
	eq(ec.fakes, n, "пока раскрыт — подделок нет")


func test_asked_light_lures_predator() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var b := w.add(EcoBones.new()) as EcoBones
	var preds := w.add(EcoPred.new()) as EcoPred
	var e := w.add(EcoEcho.new(b, preds)) as EcoEcho
	var ec := e.echo
	w.ship.pos = ec.p + Vector3(0, 10, 30)
	w.step(0.05)
	w.take_link()
	e.fake(w, EcoEcho.ASK_LIGHT)
	w.ship.light_on = true
	w.step(0.05)
	var charging := 0
	for pr in preds.all:
		if pr.mode == EcoPred.Mode.CHARGE:
			charging += 1
	eq(charging, 1, "ближайший серпохвост бросается на корабль")
	eq(ec.bait, "", "просьба исполнена")
	var lure := 0
	for ev in w.take_link():
		if ev["type"] == EcoLink.OBSERVE and ev["note"] == "lure":
			lure += 1
			ok(str(ev["text"]).begins_with("Свет включили по ложному вызову"), "текст: %s" % ev["text"])
	eq(lure, 1, "наблюдение «lure»")
	w.ship.light_on = false
	w.step(0.05)
	w.ship.light_on = true
	w.step(0.05)
	eq(_notes(w, "lure"), 0, "свет без просьбы — без «lure»")


func test_ignored_bait_expires() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ec := e.echo
	w.ship.pos = ec.p + Vector3(0, 10, 30)
	e.fake(w, EcoEcho.ASK_PING)
	w.run(EcoEcho.BAIT_T + 0.2)
	eq(ec.bait, "", "не послушались — просьба истекла")
	var obs := 0
	for ev in w.take_link():
		if ev["type"] == EcoLink.OBSERVE and ev["note"] == "fake":
			obs += 1
			eq(ev["text"], "", "без текста: подсказку не выдаём строкой")
	eq(obs, 1, "наблюдение «fake»")
	var link := _ping(w, ec.p + Vector3(0, 10, 30))
	eq(_hits(link), 0, "поздний импульс — не на просьбу")
	ok(ec.is_revealed(), "а раскрывает его")


func test_real_reports_near_bones() -> void:
	var w := _world()
	var ec := (_sys(w, EcoEcho) as EcoEcho).echo
	w.ship.pos = ec.p + Vector3(0, 10, EcoEcho.TALK_R + 10.0)
	w.run(EcoEcho.REAL_FIRST + 5.0)
	eq(_voices(w.take_link()).size(), 0, "далеко от костей — эфир тих")
	w.ship.pos = ec.p + Vector3(0, 10, EcoEcho.LISTEN_R + 20.0)   # слышно, но не подслушивает
	w.run(EcoEcho.REAL_FIRST - 1.0)
	eq(_voices(w.take_link()).size(), 0, "первый доклад — не раньше REAL_FIRST")
	w.run(2.0)
	var v := _voices(w.take_link())
	eq(v.size(), 1, "настоящий доклад")
	ok(not v[0]["fake"] and v[0]["ask"] == "" and not v[0]["silent"], "свой: с кодом, без просьбы")
	ok(EcoEcho.REALS.has([v[0]["role"], v[0]["text"]]), "из списка докладов")
	w.run(EcoEcho.REAL_CD)
	eq(_voices(w.take_link()).size(), 1, "раз в REAL_CD")


func test_voices_repeat_with_seed_and_reset() -> void:
	var a := _world()
	var b := _world()
	var ea := (_sys(a, EcoEcho) as EcoEcho)
	var eb := (_sys(b, EcoEcho) as EcoEcho)
	var la: Array = []
	var lb: Array = []
	for i in 12:
		la.append(ea.fake(a)["ask"])
		lb.append(eb.fake(b)["ask"])
	eq(la, lb, "одно зерно — те же просьбы")
	a.reset()
	eq(ea.echo.fakes, 0, "сброс — счёт с нуля")
	eq(ea.echo.bait, "", "без просьбы")
	var lc: Array = []
	for i in 12:
		lc.append(ea.fake(a)["ask"])
	eq(lc, la, "после сброса — те же")


# ---------- Сцена ----------

func test_view_six_draw_calls() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var ev := view.echo_view
	ok(ev != null and ev.get_parent() == view, "эхоловец — в живом мире")
	var ec := view.echo.echo
	ok(view.bones.to_local(ec.p).z > view.bones.rib_z[EcoEcho.PAIR], "у костей сцены")
	ok(ec.p.y >= Seabed.height(ec.p.x, ec.p.z) + EcoEcho.UP - 1e-3, "на дне сцены")
	ok(ec.p.y < Seabed.height(ec.p.x, ec.p.z) + EcoEcho.UP + 1.5, "не висит над дном")
	var ship := EcoLink.ShipState.new()
	ship.pos = ec.p + Vector3(10, 8, 10)
	for i in 80:
		view.step(0.05, ship)
	ok(ev.visible, "рядом — виден")
	near(ev.group.position.distance_to(ec.p), 0.0, 1e-4, "узел на теле")
	for i in 2:
		var dir := ev.group.basis * ev.ears[i].basis * Vector3.BACK
		ok(dir.dot(view.echo.ear_dir(i)) > 0.999, "ухо %d в сцене — как в мире" % i)
	var calls := 0
	var tris := 0
	for mi in ev.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		eq(m.layers, OceanView.LAYER_WORLD, "слой отмели: %s" % m.name)
		for s in m.mesh.get_surface_count():
			calls += 1
			tris += m.mesh.surface_get_array_len(s) / 3
	eq(calls, 6, "шесть вызовов отрисовки")
	ok(tris < 2500, "треугольников: %d" % tris)
	var hush: Color = ev.fold_mat.emission
	ship.sonar_ping = true
	ship.sonar_range = 150.0
	view.step(0.05, ship)
	ship.sonar_ping = false
	var brightest := 0.0
	for i in 40:
		view.step(0.05, ship)
		brightest = maxf(brightest, ev.fold_mat.emission.b)
	ok(brightest > hush.b * 3.0, "раскрытый — складки ушей светятся ярче")
	var far_ship := EcoLink.ShipState.new()
	far_ship.pos = Vector3(300, -20, 300)
	view.step(0.05, far_ship)
	ok(not ev.visible, "далеко — спрятан")
	view.queue_free()
	await frames(1)


func _echo_tris(ev: EchoView) -> Dictionary:
	var out := {}
	for mi in ev.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		var n := 0
		for s in m.get_surface_count():
			n += m.surface_get_array_len(s) / 3
		out[String(mi.get_path())] = n
	return out


func test_view_lite_coarser_body_sac_and_ears() -> void:
	var w := _world()
	var e: EcoEcho = _sys(w, EcoEcho)
	var ev := EchoView.new(e)
	tree.root.add_child(ev)
	await frames(1)
	var full := _echo_tris(ev)
	ev.set_lite(true)
	ok(ev.lite, "эхоловец — на «Экономно»")
	var lite := _echo_tris(ev)
	var sum_full := 0
	var sum_lite := 0
	for k in full:
		ok(lite[k] < full[k], "%s грубее (%d → %d)" % [k, full[k], lite[k]])
		sum_full += full[k]
		sum_lite += lite[k]
	ok(sum_lite * 10 <= sum_full * 6, "треугольников не больше 60 %% (%d → %d)" % [sum_full, sum_lite])
	var calls := 0
	for mi in ev.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		calls += m.get_surface_count()
		for s in m.get_surface_count():
			ok(m.surface_get_material(s) != null, "материал на месте: %s/%d" % [mi.name, s])
	eq(calls, 6, "вызовов столько же")
	var ear := ev.ears[0].get_child(0) as MeshInstance3D
	ok(ear.mesh.surface_get_material(1) == ev.fold_mat, "складки — тот же материал (свечение по сонару)")
	var a_full := EchoView.build_body(false).get_aabb()
	var a_lite := EchoView.build_body(true).get_aabb()
	near(a_lite.size.z, a_full.size.z, 0.05, "длина тела та же")
	near(a_lite.size.y, a_full.size.y, 0.05, "высота та же")
	ev.set_lite(false)
	eq(_echo_tris(ev), full, "назад — прежняя сетка")
	ev.queue_free()
	await frames(1)
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	view.set_lite(true)
	ok(view.echo_view.lite, "EcoView.set_lite — до эхоловца")
	view.ground = Seabed.height   # сброс мира — вид тот же
	ok(view.echo_view.lite, "сброс мира — снова «Экономно»")
	view.set_lite(false)   # общие выключатели мира (EcoShaders, EcoRim…) — назад для следующих тестов
	view.queue_free()
	await frames(1)
