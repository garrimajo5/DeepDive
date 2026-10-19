extends TestCase
## Ядро экосистемы (Unity EcoCoreTests): случай по зерну, шина событий, состояния существ и шаг мира без рендера.
## Тесты реестра видов придут с задачей «Реестр видов отмели».


# ---------- Случай по зерну (js/util.js, mulberry32) ----------

func test_random_matches_browser() -> void:
	# значения G.rng() из node для зерна мира и для зерна огнецвета G.seed(7031)
	var r := EcoRandom.new()
	near(r.next(), 0.6241667082, 1e-9, "1-е")
	near(r.next(), 0.7992063749, 1e-9, "2-е")
	near(r.next(), 0.4817302453, 1e-9, "3-е")
	var s := EcoWorld.seeded_for(7031)
	near(s.next(), 0.5156495699, 1e-9, "огнецвет 1-е")
	near(s.next(), 0.9910667124, 1e-9, "огнецвет 2-е")
	near(s.next(), 0.6177227497, 1e-9, "огнецвет 3-е")


func test_random_in_bounds() -> void:
	var r := EcoRandom.new(42)
	var items := ["а", "б", "в"]
	var hit := {}
	for i in 2000:
		var x := r.next()
		if not ok(x >= 0.0 and x < 1.0, "next в [0, 1): %f" % x):
			return
		var v := r.range_f(-3.0, 5.0)
		if not ok(v >= -3.0 and v <= 5.0, "range_f в границах: %f" % v):
			return
		var k := r.index(7)
		if not ok(k >= 0 and k <= 6, "index в 0…6: %d" % k):
			return
		hit[r.pick(items)] = true
	eq(hit.size(), 3, "выпадает каждый элемент")
	eq(r.index(0), 0, "пусто — 0")


func test_same_seed_same_sequence() -> void:
	var a := EcoRandom.new(5)
	var b := EcoRandom.new(5)
	var c := EcoRandom.new(6)
	var differs := false
	for i in 50:
		var x := a.next()
		if not eq(b.next(), x, "одно зерно"):
			return
		if x != c.next():
			differs = true
	ok(differs, "другое зерно — другие числа")
	var d := EcoRandom.new(5)
	d.state = a.state
	eq(d.next(), a.next(), "по состоянию — та же последовательность дальше")


# ---------- Шина событий (E.emit) ----------

func test_bus_order_and_lazy_text() -> void:
	var bus := EcoBus.new()
	var heard: Array[String] = []
	bus.emitted.connect(func(e: EcoBus.Event): heard.append(e.note))
	var scanned := [false]
	bus.emit("pred", "catch", Vector3(1, -10, 2),
		func(): return "Серпохвост поймал светляка" if scanned[0] else "Хищник поймал мелкую рыбу")
	bus.emit("leech", "signal", Vector3(0, -10, 0))
	eq(heard, ["catch", "signal"] as Array[String], "подписчик узнаёт сразу")
	eq(bus.pending.size(), 2, "в очереди")
	scanned[0] = true  # текст собирается в момент показа
	var got := bus.take()
	eq(got.size(), 2, "забрали всё")
	eq(got[0].text(), "Серпохвост поймал светляка", "текст по просканированному виду")
	eq(got[1].text(), "", "событие без текста")
	eq(bus.pending.size(), 0, "очередь пуста")


func test_far_events_not_heard() -> void:
	var bus := EcoBus.new()
	bus.emit("fish", "flee", Vector3(0, -10, 50))
	bus.emit("fish", "kelp", Vector3(0, -10, 200))
	var heard := bus.take_near(Vector3(0, -10, 0))
	eq(heard.size(), 1, "слышно одно")
	eq(heard[0].note, "flee", "ближнее")
	eq(bus.pending.size(), 0, "дальние выброшены")


# ---------- Существо: состояния и движение ----------

func test_agent_reaches_goal() -> void:
	var a := EcoAgent.new("pred", Vector3(0, -20, 0))
	var goal := Vector3(30, -20, -40)
	for i in 600:
		a.steer_to(goal, 6.0, 0.05)
	ok(a.distance_to(goal) < 0.5, "у цели: %f" % a.distance_to(goal))
	ok(a.v.length() < 0.5, "у цели почти стоит")


func test_agent_flees() -> void:
	var a := EcoAgent.new("fish", Vector3(0, -20, 0))
	var threat := Vector3(5, -20, 0)
	var d0 := a.distance_to(threat)
	for i in 40:
		a.steer_away(threat, 5.0, 0.05)
	ok(a.distance_to(threat) > d0 + 3.0, "ушла дальше")
	ok(a.p.x < 0.0, "уходит в сторону от угрозы")
	near(a.p.y, -20.0, 1e-4, "по горизонтали")


func test_agent_confined() -> void:
	var ground := func(_x: float, _z: float) -> float: return -30.0
	var a := EcoAgent.new("grazer", Vector3(0, -25, 0))
	for i in 200:
		a.steer_to(Vector3(0, -60, 0), 5.0, 0.05, ground)
	near(a.p.y, -30.0 + a.clearance, 1e-4, "держится над дном")
	for i in 200:
		a.steer_to(Vector3(0, 10, 0), 5.0, 0.05, ground)
	near(a.p.y, a.ceiling, 1e-4, "не выше потолка")
	for i in 2000:
		a.steer_to(Vector3(900, -10, -900), 9.0, 0.05, ground)
	near(a.p.x, EcoAgent.EDGE, 1e-4, "край по x")
	near(a.p.z, -EcoAgent.EDGE, 1e-4, "край по z")


func test_state_timer_expires() -> void:
	var a := EcoAgent.new("fish", Vector3.ZERO)
	var b := EcoAgent.new("pred", Vector3.ZERO)
	a.set_state(EcoAgent.State.HIDE, 1.0, b)
	eq(a.state, EcoAgent.State.HIDE, "прячется")
	ok(a.target == b, "от кого")
	a.tick(0.6)
	ok(not a.expired(), "ещё не истёк")
	a.tick(0.6)
	ok(a.expired(), "истёк")
	near(a.timer, 0.0, 1e-9, "не ниже нуля")


# ---------- Мир: шаг без рендера ----------

## Учебная связь двух видов для проверки ядра: скребуны пасутся у дома, серпохвост бродит и, заметив скребуна ближе
## 15 м, охотится; пойманный скребун гибнет. Скребун, к которому хищник ближе 8 м, убегает, потом прячется.
## Числа условные — настоящие виды придут своими задачами.
class Toy:
	extends EcoSystem
	var caught := 0

	func reset(w: EcoWorld) -> void:
		caught = 0
		var r := EcoWorld.seeded_for(1234)
		for i in 6:
			w.spawn("grazer", Vector3(r.range_f(-20, 20), -20, r.range_f(-20, 20)))
		w.spawn("pred", Vector3(0, -15, 40))

	func step(w: EcoWorld, dt: float) -> void:
		for a in w.agents:
			if not a.alive:
				continue
			if a.species == "pred":
				_pred(w, a, dt)
			else:
				_grazer(w, a, dt)

	func _pred(w: EcoWorld, p: EcoAgent, dt: float) -> void:
		if p.state != EcoAgent.State.HUNT:
			var prey := w.nearest("grazer", p.p, 15.0, func(g: EcoAgent): return g.state != EcoAgent.State.HIDE)
			if prey != null:
				p.set_state(EcoAgent.State.HUNT, 10.0, prey)
				w.emit("pred", "catch", p.p, func(): return "Хищник охотится")
			else:
				if p.expired() or p.p.distance_to(p.goal) < 2.0:
					p.goal = Vector3(w.random.range_f(-30, 30), -15, w.random.range_f(-30, 30))
					p.timer = 8.0
				p.steer_to(p.goal, 3.0, dt, w.ground)
			return
		var t := p.target
		if t == null or not t.alive or t.state == EcoAgent.State.HIDE or p.expired():
			p.set_state(EcoAgent.State.GRAZE)
			return
		p.steer_to(t.p, 7.0, dt, w.ground)
		if p.distance_to(t.p) < 1.2:
			t.alive = false
			caught += 1
			p.set_state(EcoAgent.State.GRAZE)

	func _grazer(w: EcoWorld, g: EcoAgent, dt: float) -> void:
		var pred := w.nearest("pred", g.p, 8.0)
		match g.state:
			EcoAgent.State.GRAZE:
				if pred != null:
					g.set_state(EcoAgent.State.FLEE, 3.0, pred)
					return
				if g.p.distance_to(g.goal) < 0.5:
					g.goal = g.home + Vector3(w.random.range_f(-3, 3), 0, w.random.range_f(-3, 3))
				g.steer_to(g.goal, 0.6, dt, w.ground)
			EcoAgent.State.FLEE:
				g.steer_away(g.target.p, 4.0, dt, w.ground)
				if g.expired():
					g.set_state(EcoAgent.State.HIDE, 6.0)
			EcoAgent.State.HIDE:
				g.hold(dt, w.ground)
				if g.expired():
					g.set_state(EcoAgent.State.SEEK)
			EcoAgent.State.SEEK:
				g.steer_to(g.home, 1.5, dt, w.ground)
				if g.p.distance_to(g.home) < 1.0:
					g.set_state(EcoAgent.State.GRAZE)
					g.goal = g.p


static func _snapshot(w: EcoWorld) -> String:
	var parts: PackedStringArray = []
	for a in w.agents:
		parts.append("%s:%d:%s:%.9f,%.9f,%.9f" % [a.species, a.state, a.alive, a.p.x, a.p.y, a.p.z])
	return "|".join(parts)


static func _toy_world(world_seed: int = EcoRandom.WORLD_SEED) -> EcoWorld:
	var w := EcoWorld.new(world_seed)
	w.ground = func(_x: float, _z: float) -> float: return -24.0
	w.add(Toy.new())
	return w


func test_step_splits_into_substeps() -> void:
	var w := EcoWorld.new()
	w.step(0.2)
	eq(w.steps, 4, "0,2 с — 4 подшага")
	near(w.time, 0.2, 1e-5, "время")
	w.step(0.05)
	eq(w.steps, 5, "0,05 с — один")
	w.step(0.0)
	eq(w.steps, 5, "нулевой шаг ничего не делает")


func test_world_deterministic() -> void:
	var a := _toy_world()
	var b := _toy_world()
	a.run(60.0)
	b.run(60.0)
	eq(_snapshot(a), _snapshot(b), "одно зерно — один и тот же мир")
	var c := _toy_world(99)
	c.run(60.0)
	ok(_snapshot(a) != _snapshot(c), "другое зерно — другой путь хищника")


func test_reset_returns_to_start() -> void:
	var w := _toy_world()
	var start := _snapshot(w)
	w.run(30.0)
	ok(start != _snapshot(w), "мир ожил")
	w.reset()
	eq(_snapshot(w), start, "сброс — как в начале")
	near(w.time, 0.0, 1e-9, "время с нуля")
	eq(w.bus.pending.size(), 0, "очередь пуста")
	w.run(30.0)
	var again := _toy_world()
	again.run(30.0)
	eq(_snapshot(w), _snapshot(again), "после сброса мир идёт тем же путём")


func test_all_five_states() -> void:
	var w := _toy_world()
	var seen := {}
	for i in 2400:
		w.step(0.05)
		for a in w.agents:
			seen[a.state] = true
	eq(seen.size(), EcoAgent.State.size(), "все пять состояний: %s" % str(seen.keys()))
	var toy: Toy = w.systems[0]
	ok(toy.caught > 0, "хищник кого-то поймал")
	eq(w.count("grazer"), 6 - toy.caught, "живых скребунов")
	eq(w.count("grazer", false), 6, "всего скребунов")
	ok(w.bus.take().size() > 0, "охота шлёт события")
	for a in w.agents:
		ok(a.p.y >= -24.0 + a.clearance - 1e-4, "никто не под дном")


# ---------- Связь с кораблём ----------

func test_take_link_hits_and_heard_messages() -> void:
	var w := EcoWorld.new()
	w.ship.pos = Vector3(0, -10, 0)
	w.hit_ship("Серпохвост", 0.12, Vector3(1, -10, 0))
	w.emit("pred", "catch", Vector3(0, -10, 30), func(): return "Серпохвост поймал рыбу")
	w.emit("fish", "flee", Vector3(0, -10, 10))
	w.emit("pred", "catch", Vector3(0, -10, 300), func(): return "далеко")
	var got := w.take_link()
	eq(got.size(), 2, "удар и одно слышимое сообщение")
	eq(got[0]["type"], EcoLink.HIT, "удар")
	near(got[0]["damage"], 0.12, 1e-6, "доля прочности")
	eq(got[1], EcoLink.message("Серпохвост поймал рыбу"), "сообщение рядом")
	eq(w.hits, 1, "ударов")
	eq(w.take_link().size(), 0, "очереди пусты")


func test_view_steps_world() -> void:
	var view := EcoView.new()
	view.ground = func(_x: float, _z: float) -> float: return -24.0
	ok(view.world.ground.is_valid(), "дно ушло в мир")
	var toy := Toy.new()
	view.world.add(toy)
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(0, -15, 0)
	ship.sonar_ping = true
	for i in 300:
		view.step(1.0 / 30.0, ship)
		ship.sonar_ping = false
	near(view.world.time, 10.0, 1e-3, "мир идёт со сценой")
	eq(view.world.steps, 300, "кадр 1/30 с — один подшаг")
	near(view.world.last_ping, 0.0, 1e-9, "импульс сонара отмечен")
	ok(view.world.ship == ship, "мир видит корабль")
	view.free()
