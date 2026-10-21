extends TestCase
## Серпохвосты (initPreds/predUpdate, E.onPing, E.onZap в js/creatures.js; Unity EcoPredTests): патруль, охота на
## светляков, бросок на корабль на свет, сонар и шум, укус — EcoLink.HIT, разряд отпугивает; вид MOD-011 в сцене.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Ровное дно на −40 м, только серпохвосты; корабль далеко, тихо и без света.
func _alone() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	w.add(EcoPred.new())
	return w


func _preds(w: EcoWorld) -> EcoPred:
	for s in w.systems:
		if s is EcoPred:
			return s
	return null


## Первый хищник голоден и готов напасть, корабль — в dist м по +X на его высоте.
func _ready_pred(w: EcoWorld, dist: float) -> EcoPred.Pred:
	var pr := _preds(w).all[0]
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.pos = pr.agent.p + Vector3(dist, 0, 0)
	return pr


func _notes(w: EcoWorld, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == "pred" and ev.note == note:
			out.append(ev)
	return out


func _step(w: EcoWorld) -> void:
	w.step(EcoWorld.MAX_STEP)


# ---------- Поведение ----------

func test_three_preds_at_browser_spots() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var preds := w.add(EcoPred.new()) as EcoPred
	eq(preds.all.size(), 3)
	eq(w.count("pred"), 3)
	var js := [Vector2(-60, 20), Vector2(70, -20), Vector2(10, -110)]
	for i in 3:
		var pr := preds.all[i]
		near(pr.agent.p.x, js[i].x, 1e-4, "x как в браузере")
		near(pr.agent.p.z, js[i].y, 1e-4)
		near(pr.agent.p.y, minf(Seabed.height(pr.agent.p.x, pr.agent.p.z) + 8.0, -6.0), 1e-4, "8 м над дном, не выше −6")
		eq(pr.mode, EcoPred.Mode.PATROL)
		ok(pr.hunger >= 0.1 and pr.hunger <= 0.5, "голод 0,1…0,5")
		near(pr.cooldown, 20.0, 1e-5, "первые 20 с на корабль не нападает")


func test_light_lures_closer_than_32() -> void:
	var w := _alone()
	var pr := _ready_pred(w, 40.0)
	w.ship.light_on = true
	_step(w)
	eq(pr.mode, EcoPred.Mode.PATROL, "дальше 32 м свет не видит")

	w = _alone()
	pr = _ready_pred(w, 25.0)
	w.ship.light_on = true
	_step(w)
	eq(pr.mode, EcoPred.Mode.CHARGE, "свет ближе 32 м — бросок")
	eq(pr.agent.state, EcoAgent.State.HUNT)
	var ev := _notes(w, "ship")
	eq(ev.size(), 1)
	ok(ev[0].text().contains("привлёк свет"), ev[0].text())
	ok(ev[0].is_observation(), "заметка журнала «идёт на таран, если горит прожектор»")


## Глубже — чутьё острее (js/creatures.js:275, R.predK): на третьем спуске (dive = 2) свет виден с 32 × 1,3 = 41,6 м.
func test_deeper_dive_sees_light_farther() -> void:
	var w := _alone()
	var pr := _ready_pred(w, 38.0)
	w.ship.light_on = true
	_step(w)
	eq(pr.mode, EcoPred.Mode.PATROL, "первый спуск: за 38 м свет не видит")

	w = _alone()
	w.ship.dive = 2
	pr = _ready_pred(w, 38.0)
	w.ship.light_on = true
	_step(w)
	eq(pr.mode, EcoPred.Mode.CHARGE, "dive = 2: свет за 38 м — бросок")

	w = _alone()
	w.ship.dive = 2
	pr = _ready_pred(w, 43.0)
	w.ship.light_on = true
	_step(w)
	eq(pr.mode, EcoPred.Mode.PATROL, "дальше 41,6 м и на третьем спуске не видит")

	near(EcoPred.reach(pr, w.ship.pred_k()), 32.0 * 1.3, 1e-4)
	pr.leech = true
	near(EcoPred.reach(pr, w.ship.pred_k()), 48.0 * 1.3, 1e-4, "заражённый пиявником — 48 × predK")
	eq(EcoPred.reach(pr), 48.0, "без множителя — как раньше")


func test_dark_and_quiet_no_attack() -> void:
	var w := _alone()
	var pr := _ready_pred(w, 15.0)
	w.run(60.0)
	eq(w.hits, 0, "тёмный тихий корабль хищник не трогает")
	ok(pr.mode != EcoPred.Mode.CHARGE)
	eq(_notes(w, "ship").size() + _notes(w, "hear").size() + _notes(w, "ping").size(), 0)


func test_fed_or_cooling_no_attack() -> void:
	var w := _alone()
	var pr := _ready_pred(w, 20.0)
	pr.hunger = 0.1
	w.ship.light_on = true
	_step(w)
	eq(pr.mode, EcoPred.Mode.PATROL, "сытый (голод ≤ 0,2) не нападает")

	w = _alone()
	pr = _ready_pred(w, 20.0)
	pr.cooldown = 5.0
	w.ship.light_on = true
	_step(w)
	eq(pr.mode, EcoPred.Mode.PATROL, "пауза не прошла — не нападает")


func test_hears_engines_closer_than_24() -> void:
	var w := _alone()
	var pr := _ready_pred(w, 30.0)
	w.ship.speed = 4.0
	_step(w)
	eq(pr.mode, EcoPred.Mode.PATROL, "дальше 24 м двигатели не слышно")

	w = _alone()
	pr = _ready_pred(w, 20.0)
	w.ship.speed = 2.5
	_step(w)
	eq(pr.mode, EcoPred.Mode.PATROL, "малый ход (≤ 3 м/с) не слышно")

	w = _alone()
	pr = _ready_pred(w, 20.0)
	w.ship.speed = -4.0  # задний ход шумит так же
	_step(w)
	eq(pr.mode, EcoPred.Mode.CHARGE)
	var ev := _notes(w, "hear")
	eq(ev.size(), 1)
	ok(ev[0].text().contains("услышал двигатели"), ev[0].text())


func test_bite_is_link_hit() -> void:
	var w := _alone()
	var pr := _ready_pred(w, 25.0)
	w.ship.light_on = true
	var t := 0.0
	while t < 10.0 and w.hits == 0:
		_step(w)
		t += EcoWorld.MAX_STEP
	eq(w.hits, 1, "за 10 с броска хищник дотянулся до корабля")
	var hit := w.last_hit
	eq(hit["type"], EcoLink.HIT)
	eq(hit["by"], "Крупный хищник", "вид не просканирован — описательное название")
	near(hit["damage"], 0.12, 1e-9, "как Game.hullHit(12, 'bite') в браузере")
	ok((hit["at"] as Vector3).distance_to(w.ship.pos) < EcoPred.BITE_DIST)
	var bite := _notes(w, "bite")
	eq(bite.size(), 1, "укус слышен на приборах")
	ok(bite[0].text().contains("укусил корпус"), bite[0].text())
	eq(pr.mode, EcoPred.Mode.RETREAT, "после укуса уходит")
	eq(pr.agent.state, EcoAgent.State.FLEE)
	near(pr.cooldown, EcoPred.BITE_COOLDOWN, 1e-4)
	near(pr.bit_at, w.time, 1e-6)
	var link := w.take_link()
	ok(link.any(func(e: Dictionary) -> bool: return e["type"] == EcoLink.HIT), "удар уходит кораблю через EcoLink")
	ok(link.any(func(e: Dictionary) -> bool: return e["type"] == EcoLink.MESSAGE and str(e["text"]).contains("укусил")),
		"и строка на приборы")

	w.run(14.0)
	ok(pr.agent.distance_to(w.ship.pos) > 50.0, "отошёл от корабля: %.1f" % pr.agent.distance_to(w.ship.pos))
	w.run(6.0)
	eq(w.hits, 1, "25 с после укуса не нападает, хотя свет горит")


func test_scanned_name_in_hit() -> void:
	var w := _alone()
	w.scanned = func(id: String) -> bool: return id == "pred"
	_ready_pred(w, 9.0)
	w.ship.light_on = true
	w.run(2.0)
	eq(w.last_hit.get("by", ""), "Серпохвост", "просканирован — настоящее название")


func test_charge_ends_after_10s() -> void:
	var w := _alone()
	var pr := _ready_pred(w, 25.0)
	w.ship.light_on = true
	_step(w)
	eq(pr.mode, EcoPred.Mode.CHARGE)
	w.ship.pos = FAR  # корабль ушёл далеко
	w.run(10.1)
	eq(pr.mode, EcoPred.Mode.PATROL)
	eq(w.hits, 0)
	ok(pr.cooldown > 0.0, "после неудачного броска короткая пауза")


func test_sonar_calls_to_check() -> void:
	var w := _alone()
	var preds := _preds(w)
	var pr := preds.all[0]
	var pos := pr.agent.p + Vector3(0, 0, 100)
	preds.on_ping(w, pos)
	eq(pr.mode, EcoPred.Mode.INVESTIGATE)
	eq(pr.agent.state, EcoAgent.State.SEEK)
	eq(pr.agent.goal, pos)
	near(w.last_ping, w.time, 1e-6)
	var ev := _notes(w, "ping")
	eq(ev.size(), 1, "ближе 110 м — экипаж слышит, что хищник идёт на звук")
	ok(ev[0].text().contains("услышал сонар"), ev[0].text())
	eq(preds.all[2].mode, EcoPred.Mode.PATROL, "дальше 150 м сонар не слышат")
	var d0 := pr.agent.distance_to(pos)
	w.run(5.0)
	ok(pr.agent.distance_to(pos) < d0 - 15.0, "плывёт на звук")


func test_ship_ping_reaches_preds_once() -> void:
	# импульс сонара корабля (ShipState.sonar_ping) зовёт хищников в начале шага, один раз на шаг
	var w := _alone()
	var pr := _preds(w).all[0]
	w.ship.pos = pr.agent.p + Vector3(0, 0, 80)
	w.ship.sonar_ping = true
	w.step(0.2)  # 4 подшага
	eq(pr.mode, EcoPred.Mode.INVESTIGATE, "хищник идёт на звук корабля")
	near(w.last_ping, 0.0, 1e-6, "импульс отмечен в начале шага")
	eq(_notes(w, "ping").size(), 1, "одно событие на импульс")


func test_after_sonar_ship_lures_without_light() -> void:
	var w := _alone()
	var pr := _ready_pred(w, 25.0)
	w.run(1.0)
	eq(pr.mode, EcoPred.Mode.PATROL)
	w.ship.pos = pr.agent.p + Vector3(25, 0, 0)
	w.last_ping = w.time  # импульс с корабля, хищник дальше 150 м от других
	_step(w)
	eq(pr.mode, EcoPred.Mode.CHARGE)
	ok(_notes(w, "ping")[0].text().contains("привлёк сонар"))

	w = _alone()
	pr = _ready_pred(w, 25.0)
	w.last_ping = -20.0  # импульс давно (больше 12 с назад)
	_step(w)
	eq(pr.mode, EcoPred.Mode.PATROL)


func test_zap_scares() -> void:
	var w := _alone()
	var preds := _preds(w)
	var pr := _ready_pred(w, 15.0)
	w.ship.light_on = true
	_step(w)
	eq(pr.mode, EcoPred.Mode.CHARGE)
	preds.on_zap(w)
	eq(pr.mode, EcoPred.Mode.FLEE)
	near(pr.cooldown, 30.0, 1e-4)
	eq(_notes(w, "zap").size(), 1)
	ok(_notes(w, "zap")[0].text().contains("Разряд отпугнул крупного хищника"), _notes(w, "zap")[0].text())
	w.run(8.2)
	eq(w.hits, 0, "отпугнутый не кусает")
	ok(pr.agent.distance_to(w.ship.pos) > 25.0)
	eq(pr.mode, EcoPred.Mode.PATROL)

	w = _alone()
	preds = _preds(w)
	pr = _ready_pred(w, 25.0)
	preds.on_zap(w, 20.0)
	eq(pr.mode, EcoPred.Mode.PATROL, "дальше 20 м разряд не достаёт")
	preds.on_zap(w, 30.0)
	eq(pr.mode, EcoPred.Mode.FLEE, "с большей долей реактора — дальше")


func test_ship_zap_from_link() -> void:
	# разряд корабля (ShipState.zap, zap_radius) доходит до хищников в этот же шаг
	var w := _alone()
	var pr := _ready_pred(w, 25.0)
	w.ship.zap = true
	w.ship.zap_radius = 20.0
	_step(w)
	eq(pr.mode, EcoPred.Mode.PATROL, "радиус 20 м не достаёт до 25 м")
	w = _alone()
	pr = _ready_pred(w, 25.0)
	w.ship.zap = true
	w.ship.zap_radius = 30.0
	w.step(0.2)
	eq(pr.mode, EcoPred.Mode.FLEE, "радиус 30 м — отпугнул")
	eq(_notes(w, "zap").size(), 1, "одно событие на разряд, сколько бы ни было подшагов")


## Мир со светляками на дне отмели; хищники, кроме первого, не голодают.
func _with_fish() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = FAR
	var fish := w.add(EcoFish.new()) as EcoFish
	var preds := w.add(EcoPred.new(fish)) as EcoPred
	for i in range(1, preds.all.size()):
		preds.all[i].hunger = -10.0
	var pr := preds.all[0]
	pr.cooldown = 100.0
	pr.agent.p = EcoFish.HOMES[0] + Vector3(10, 2, 0)
	pr.agent.goal = pr.agent.p
	return w


func test_hungry_catches_fish() -> void:
	var w := _with_fish()
	var pr := _preds(w).all[0]
	pr.hunger = 0.9
	var hunted := false
	var t := 0.0
	while t < 60.0 and _notes(w, "catch").is_empty():
		_step(w)
		hunted = hunted or pr.mode == EcoPred.Mode.HUNT
		t += EcoWorld.MAX_STEP
	ok(hunted, "голодный (> 0,45) охотится на светляков рядом")
	var ev := _notes(w, "catch")
	eq(ev.size(), 1, "поймал рыбку за минуту")
	eq(ev[0].text(), "Крупный хищник поймал мелкую рыбу")
	eq(w.count("fish"), EcoFish.PER_SHOAL * (EcoFish.HOMES.size() + EcoFish.CROWN_SHOALS) - 1, "рыбка съедена")
	eq(pr.mode, EcoPred.Mode.EAT)
	near(pr.hunger, 0.0, 1e-5, "наелся")
	ok(pr.prey == null)
	w.run(5.1)
	eq(pr.mode, EcoPred.Mode.PATROL, "5 с ест, потом патрулирует")


func test_fed_does_not_hunt() -> void:
	var w := _with_fish()
	var pr := _preds(w).all[0]
	pr.hunger = 0.0
	for i in 200:
		_step(w)
		if not ok(pr.mode != EcoPred.Mode.HUNT, "за 10 с голод только 0,3"):
			return
	near(pr.hunger, 0.3, 1e-3)
	eq(_notes(w, "catch").size(), 0)


func test_shallows_live_with_preds_and_shoals() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = FAR
	var fish := w.add(EcoFish.new()) as EcoFish
	var preds := w.add(EcoPred.new(fish)) as EcoPred
	var catches := 0
	var flees := 0
	for s in 300:
		w.run(1.0)
		for ev in w.bus.take():
			if ev.species == "pred" and ev.note == "catch":
				catches += 1
			if ev.species == "fish" and ev.note == "flee":
				flees += 1
		for pr in preds.all:
			var p := pr.agent.p
			if not ok(p.y >= Seabed.height(p.x, p.z) + 1.8 - 1e-3, "не под дном"):
				return
			ok(p.y <= -4.0 + 1e-4, "не выше потолка")
			ok(absf(p.x) <= EcoAgent.EDGE and absf(p.z) <= EcoAgent.EDGE, "в пределах отмели")
			ok(pr.hunger >= 0.0 and pr.hunger <= 1.0)
	ok(catches > 0, "за 5 минут серпохвосты кого-то поймали")
	ok(flees > 0, "стаи уходили в кораллы от хищников")
	eq(w.hits, 0, "корабль далеко — ударов нет")


func _make() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	w.add(EcoPred.new(f))
	return w


func test_same_seed_same_world() -> void:
	var a := _make()
	var b := _make()
	a.run(40.0)
	b.run(40.0)
	for i in a.agents.size():
		if not eq(a.agents[i].p, b.agents[i].p):
			return
	a.reset()
	a.run(40.0)
	for i in a.agents.size():
		if not eq(b.agents[i].p, a.agents[i].p, "после сброса — то же"):
			return


func test_reset_returns_preds_and_forgets_hits() -> void:
	var w := _alone()
	_ready_pred(w, 25.0)
	w.ship.light_on = true
	w.run(5.0)
	eq(w.hits, 1)
	w.ship.light_on = false
	w.ship.pos = FAR
	w.reset()
	eq(w.hits, 0)
	ok(w.last_hit.is_empty())
	near(w.last_ping, -99.0, 1e-6)
	var preds := _preds(w)
	eq(preds.all.size(), 3)
	near(preds.all[0].agent.p.x, -60.0, 1e-4)
	eq(preds.all[0].mode, EcoPred.Mode.PATROL)
	w.run(1.0)
	eq(w.hits, 0, "после сброса удар не повторяется сам")


# ---------- Вид ----------

func test_look_heading_tail_and_jaw() -> void:
	var w := _alone()
	var pr := _preds(w).all[0]
	pr.agent.v = Vector3(3, 0, 0)
	var b := EcoPredLook.basis(pr)
	ok((b * Vector3(0, 0, -1)).distance_to(Vector3(1, 0, 0)) < 1e-4, "голова модели (−Z) — по скорости")
	ok((b * Vector3.UP).y > 0.99, "спина вверх")
	pr.agent.v = Vector3(0, 9, 1)
	ok(EcoPredLook.forward(pr).y <= sin(EcoPredLook.PITCH_MAX) + 1e-5, "наклон не больше 30°")
	pr.agent.v = Vector3.ZERO
	eq(EcoPredLook.forward(pr), Vector3(0, 0, 1), "стоит — смотрит на +Z")

	# хвост: волна в пределах модели, быстрее — шире
	var slow := 0.0
	var fast := 0.0
	for i in 400:
		var t := i * 0.01
		pr.agent.v = Vector3(0, 0, 1)
		slow = maxf(slow, absf(EcoPredLook.tail_angle(pr, t)))
		pr.agent.v = Vector3(0, 0, 9.5)
		var a := EcoPredLook.tail_angle(pr, t)
		fast = maxf(fast, absf(a))
		if not ok(absf(a) <= EcoPredLook.TAIL_MAX + 1e-6, "хвост не дальше 35°"):
			return
	ok(fast > slow + 0.1, "в броске хвост машет шире: %.2f > %.2f" % [fast, slow])
	# удар серпом сразу после укуса — до 35°
	pr.bit_at = 10.0
	near(EcoPredLook.tail_angle(pr, 10.0 + EcoPredLook.STRIKE_TIME / 2.0), EcoPredLook.TAIL_MAX, 1e-5, "взмах серпом")

	# пасть: закрыта в патруле, раскрыта в броске у корабля, жуёт во время еды
	pr.mode = EcoPred.Mode.PATROL
	near(EcoPredLook.jaw_angle(pr, pr.agent.p, 0.0), 0.0, 1e-9)
	pr.mode = EcoPred.Mode.CHARGE
	near(EcoPredLook.jaw_angle(pr, pr.agent.p + Vector3(15, 0, 0), 0.0), EcoPredLook.JAW_MAX, 1e-9, "бросок — пасть открыта")
	near(EcoPredLook.jaw_angle(pr, pr.agent.p + Vector3(30, 0, 0), 0.0), 0.0, 1e-9, "корабль далеко — закрыта")
	pr.mode = EcoPred.Mode.EAT
	var chew := EcoPredLook.jaw_angle(pr, FAR, 0.3)
	ok(chew >= 0.0 and chew <= EcoPredLook.JAW_MAX * EcoPredLook.CHEW_OPEN, "жуёт вполсилы")


func test_view_models_in_scene() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var pv := view.pred_view
	ok(pv != null and pv.get_parent() == view, "серпохвосты — в живом мире")
	eq(pv.bodies.size(), 3, "три хищника")
	var meshes := pv.find_children("*", "MeshInstance3D", true, false)
	eq(meshes.size(), 9, "по три части на зверя — 9 вызовов отрисовки")
	var tris := 0
	for m: MeshInstance3D in meshes:
		eq(m.layers, OceanView.LAYER_WORLD, "слой отмели")
		var arr := m.mesh.surface_get_arrays(0)
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	eq(tris, 3 * (3988 + 986 + 745), "треугольники моделей MOD-011")

	var ship := EcoLink.ShipState.new()
	ship.pos = FAR
	for i in 20:
		view.step(0.05, ship)
	var pr := view.preds.all[1]
	var root := pv.bodies[1]
	ok(root.position.distance_to(pr.agent.p) < 1e-4, "место — из мира")
	ok((root.basis * Vector3(0, 0, -1)).distance_to(EcoPredLook.forward(pr)) < 1e-3, "голова по курсу")
	near(pv.tails[1].rotation.y, EcoPredLook.tail_angle(pr, view.world.time), 1e-5, "хвост — из EcoPredLook")
	ok(pv.tails[1].position.distance_to(EcoPredLook.TAIL_ROOT) < 1e-6, "хвост у корня")
	ok(pv.jaws[1].position.distance_to(EcoPredLook.JAW_HINGE) < 1e-6, "челюсть на шарнире")

	# бросок у корабля — пасть раскрывается
	pr.mode = EcoPred.Mode.CHARGE
	pr.agent.timer = 10.0
	pr.cooldown = 99.0
	ship.pos = pr.agent.p + Vector3(18, 0, 0)
	for i in 10:
		view.step(0.05, ship)
	ok(-pv.jaws[1].rotation.x > EcoPredLook.JAW_MAX * 0.9, "пасть открыта: %.2f" % -pv.jaws[1].rotation.x)
	view.queue_free()
	await frames(1)
