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
	eq(w.count("fish"), EcoFish.total() - 1, "рыбка съедена")
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


## Пять минут отмели с серпохвостами и стаями (корабль далеко) — одни на тесты жизни отмели, повторяемости мира
## и хода серпохвостов (`motion`, как `_walk`; вместо второй минуты полного мира «у 02», где серпохвосты в 100–190 м
## от корабля — тот же мир без корабля, #1350):
## раньше повторяемость гоняла свои три прогона по 40 с того же мира (#1350). В 40 с — места существ (`at40`),
## после пяти минут — сброс и снова 40 с (`again40`): сброс после долгой жизни отмели — та же история.
static var _shallow := {}


static func _shallows() -> Dictionary:
	if not _shallow.is_empty():
		return _shallow
	var w := _make()
	var preds := w.systems.filter(func(s): return s is EcoPred)[0] as EcoPred
	var r := {"catches": 0, "flees": 0, "closest": 1e9, "bad": "", "at40": []}
	var reef := preds.reef_axis()
	var m := _motion()
	for s in 300:
		for k in int(round(1.0 / EcoWorld.MAX_STEP)):   # то же, что w.run(1.0), с замером хода каждый шаг
			w.step(EcoWorld.MAX_STEP)
			_track(m, preds, EcoWorld.MAX_STEP)
		if s == 39:
			r["at40"] = w.agents.map(func(a): return a.p)
		for ev in w.bus.take():
			if ev.species == "pred" and ev.note == "catch":
				r["catches"] += 1
			if ev.species == "fish" and ev.note == "flee":
				r["flees"] += 1
		for pr in preds.all:
			var p := pr.agent.p
			var why := ""
			if p.y < Seabed.height(p.x, p.z) + 1.8 - 1e-3:
				why = "под дном"
			elif p.y > -4.0 + 1e-4:
				why = "выше потолка"
			elif absf(p.x) > EcoAgent.EDGE or absf(p.z) > EcoAgent.EDGE:
				why = "за пределами отмели"
			elif pr.hunger < 0.0 or pr.hunger > 1.0:
				why = "голод %.2f" % pr.hunger
			if why != "" and r["bad"] == "":
				r["bad"] = "%s на %d с: %s" % [why, s + 1, p]
			r["closest"] = minf(r["closest"], Vector2(p.x - reef.x, p.z - reef.z).length())
	r["hits"] = w.hits
	r["motion"] = m
	w.reset()
	w.run(40.0)
	r["again40"] = w.agents.map(func(a): return a.p)
	_shallow = r
	return r


func test_shallows_live_with_preds_and_shoals() -> void:
	var r := _shallows()
	eq(r["bad"], "", "серпохвосты над дном, подо льдом, в пределах отмели, голод в 0…1")
	ok(r["closest"] > EcoPred.REEF_KEEP - 4.0, "в риф у Каменного цветка не заходят (ближе всего %.1f м)" % r["closest"])
	ok(r["catches"] > 0, "за 5 минут серпохвосты кого-то поймали")
	ok(r["flees"] > 0, "стаи уходили в кораллы от хищников")
	eq(r["hits"], 0, "корабль далеко — ударов нет")


static func _make() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	w.add(EcoPred.new(f))
	return w


func test_same_seed_same_world() -> void:
	var r := _shallows()
	var at40: Array = r["at40"]
	var b := _make()
	b.run(40.0)
	eq(b.agents.size(), at40.size(), "столько же существ")
	for i in b.agents.size():
		if not eq(b.agents[i].p, at40[i], "новый мир с тем же зерном — то же"):
			return
	var again: Array = r["again40"]
	eq(again.size(), at40.size(), "после сброса столько же существ")
	for i in again.size():
		if not eq(again[i], at40[i], "после сброса и пяти минут — то же"):
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

func test_look_heading() -> void:
	var w := _alone()
	var pr := _preds(w).all[0]
	pr.agent.v = Vector3(3, 0, 0)
	for i in 100:
		EcoPred.turn(pr, 0.05)
	var b := EcoPredLook.basis(pr)
	ok((b * Vector3(0, 0, -1)).distance_to(Vector3(1, 0, 0)) < 1e-3, "голова модели (−Z) — по скорости")
	ok((b * Vector3.UP).y > 0.99, "на прямой — спина вверх, без крена")
	pr.agent.v = Vector3(0, 9, 1)
	ok(EcoPred.aim(pr).y <= sin(EcoPredLook.PITCH_MAX) + 1e-5, "наклон не больше 30°")
	for i in 100:
		EcoPred.turn(pr, 0.05)
	ok(EcoPredLook.forward(pr).y <= sin(EcoPredLook.PITCH_MAX) + 1e-4, "и у тела наклон не больше 30°")
	pr.agent.v = Vector3.ZERO
	for i in 100:
		EcoPred.turn(pr, 0.05)
	ok(EcoPredLook.forward(pr).distance_to(Vector3(0, 0, 1)) < 1e-3, "встал — держит курс, нос к горизонту")



## Плавание ANIM-001: смесь Swim → SwimFast и частота цикла растут со скоростью, в покое — реже Swim.
func test_swim_mix_by_speed() -> void:
	var pr := _preds(_alone()).all[0]
	var mix := -1.0
	var rate := 0.0
	for s in [0.0, 1.0, 3.0, 5.0, 7.6, 9.0]:
		pr.agent.v = Vector3(0, 0, s)
		var m := EcoPredLook.swim_mix(pr)
		var r := EcoPredLook.swim_rate(pr)
		ok(m >= mix and r > rate, "быстрее — больше броска и чаще волна (%.1f м/с: %.2f, %.2f)" % [s, m, r])
		mix = m
		rate = r
	pr.agent.v = Vector3(0, 0, EcoPred.PATROL_SPEED)
	near(EcoPredLook.swim_mix(pr), 0.0, 1e-6, "патруль — только Swim")
	near(EcoPredLook.swim_rate(pr), 1.0 / EcoPredLook.SWIM_LEN, 1e-6, "и в его родном темпе")
	pr.agent.v = Vector3(0, 0, EcoPred.CHARGE_SPEED)
	near(EcoPredLook.swim_mix(pr), 1.0, 1e-6, "бросок — только SwimFast")
	near(EcoPredLook.swim_rate(pr), 1.0 / EcoPredLook.SWIM_FAST_LEN, 1e-6, "в его родном темпе")
	pr.agent.v = Vector3.ZERO
	near(EcoPredLook.swim_rate(pr), EcoPredLook.REST_RATE_K / EcoPredLook.SWIM_LEN, 1e-6, "встал — волна вдвое реже")


## Разовые клипы: укус раз за сближение в броске (раньше касания), снова — когда отошёл; жуёт, пока ест;
## удар серпом — раз на укус корпуса; вдали клипы не меняются и старый укус потом не отыгрывается.
func test_bite_and_strike_cues() -> void:
	var pr := _preds(_alone()).all[0]
	var c := EcoPredLook.Cues.new()
	var ship := pr.agent.p + Vector3(30, 0, 0)
	pr.mode = EcoPred.Mode.CHARGE
	ok(not c.update(pr, ship, 1.0)["bite"], "корабль далеко — пасть закрыта")
	ship = pr.agent.p + Vector3(EcoPredLook.BITE_SHIP_DIST - 0.5, 0, 0)
	ok(EcoPredLook.BITE_SHIP_DIST > EcoPred.BITE_DIST, "пасть раскрывается раньше касания")
	ok(c.update(pr, ship, 1.1)["bite"], "у корабля в броске — укус")
	ok(not c.update(pr, ship, 1.2)["bite"], "один раз за сближение")
	pr.bit_at = 1.3
	var cue := c.update(pr, ship, 1.35)
	ok(cue["strike"], "укус корпуса — удар серпом")
	ok(not c.update(pr, ship, 1.4)["strike"], "удар — раз на укус")
	pr.mode = EcoPred.Mode.RETREAT
	ok(not c.update(pr, ship, 1.5)["bite"], "уходит — не кусает")
	pr.mode = EcoPred.Mode.CHARGE
	ok(c.update(pr, ship, 30.0)["bite"], "новый бросок — новый укус")
	pr.mode = EcoPred.Mode.PATROL
	ok(not c.update(pr, ship, 31.0)["bite"], "в патруле у корабля — без укуса")
	pr.mode = EcoPred.Mode.EAT
	ok(c.update(pr, ship, 32.0)["bite"], "ест — жуёт")
	ok(not c.update(pr, ship, 32.0 + EcoPredLook.CHEW_EVERY * 0.5)["bite"], "не чаще CHEW_EVERY")
	ok(c.update(pr, ship, 32.0 + EcoPredLook.CHEW_EVERY)["bite"], "и снова")
	# вдали: без смены клипов, а подплыв — старый укус не играет
	pr.mode = EcoPred.Mode.PATROL
	pr.bit_at = 40.0
	cue = c.update(pr, ship, 40.1, true)
	ok(not cue["strike"] and not cue["bite"], "вдали — только плавание")
	ok(not c.update(pr, ship, 40.2)["strike"], "старый укус не отыгрывается")
	pr.bit_at = 50.0
	ok(not c.update(pr, ship, 50.0 + EcoPredLook.STRIKE_TIME + 0.1)["strike"], "укус старше клипа — не играет")


## Б3, плавность: тело не щёлкает за скоростью — догоняет её не быстрее TURN_MAX, в повороте ложится на бок.
func test_look_turns_smoothly_and_banks() -> void:
	var w := _alone()
	var pr := _preds(w).all[0]
	eq(pr.look, Vector3(0, 0, 1), "в начале смотрит по стартовой скорости")
	# скорость разом развернулась налево (нос +Z → +X: yaw растёт)
	pr.agent.v = Vector3(3, 0, 0)
	EcoPred.turn(pr, 0.05)
	var a1 := pr.look.angle_to(Vector3(0, 0, 1))
	ok(a1 > 0.0 and a1 <= EcoPred.TURN_MAX * 0.05 + 1e-5, "за шаг — не дальше TURN_MAX · dt: %.3f" % a1)
	var max_bank := 0.0
	var max_step := 0.0
	var prev := pr.look
	for i in 40:
		EcoPred.turn(pr, 0.05)
		max_step = maxf(max_step, prev.angle_to(pr.look))
		prev = pr.look
		max_bank = maxf(max_bank, pr.bank)
		ok(absf(pr.bank) <= EcoPred.BANK_MAX + 1e-6, "крен не больше 25°")
	ok(max_step <= EcoPred.TURN_MAX * 0.05 + 1e-5, "поворот без рывков")
	ok(max_bank > deg_to_rad(8.0), "в левом повороте ложится на левый бок: %.1f°" % rad_to_deg(max_bank))
	# левым боком вниз: спина смотрит влево от курса
	pr.bank = deg_to_rad(20.0)
	var flat := Basis.looking_at(pr.look, Vector3.UP)
	var up := EcoPredLook.basis(pr) * Vector3.UP
	ok(up.dot(flat * Vector3.LEFT) > 0.3, "крен > 0 — спина к левому борту")
	ok((EcoPredLook.basis(pr) * Vector3(0, 0, -1)).distance_to(pr.look) < 1e-4, "крен не сбивает курс")
	pr.bank = max_bank
	# прямо — крен уходит
	for i in 80:
		EcoPred.turn(pr, 0.05)
	ok(pr.look.distance_to(Vector3(1, 0, 0)) < 1e-3, "догнал скорость")
	near(pr.bank, 0.0, 0.01, "на прямой выровнялся")
	# направо (нос +X → +Z) — крен в другую сторону
	pr.agent.v = Vector3(0, 0, 3)
	var min_bank := 0.0
	for i in 20:
		EcoPred.turn(pr, 0.05)
		min_bank = minf(min_bank, pr.bank)
	ok(min_bank < -deg_to_rad(8.0), "в правом повороте — на правый бок")
	# ровно назад — тоже плавно, по горизонтали
	pr.agent.v = Vector3(0, 0, 3)
	pr.look = Vector3(0, 0, -1)
	EcoPred.turn(pr, 0.05)
	ok(pr.look.is_normalized() and absf(pr.look.y) < 1e-5, "разворот кругом — по горизонтали")
	ok(pr.look.angle_to(Vector3(0, 0, -1)) <= EcoPred.TURN_MAX * 0.05 + 1e-5, "и не щелчком")


## Б3, плавность: поворот тела с инерцией — скорость поворота набирается и гаснет не быстрее TURN_ACCEL. Раньше
## хищник стоял у точки патруля, следующая — в 1,5 рад: тело срывалось с 0 до 3 рад/с за кадр (88 рад/с²).
func test_turn_rate_eases_in_and_out() -> void:
	var w := _alone()
	var pr := _preds(w).all[0]
	var dt := 1.0 / 30.0
	pr.look = Vector3(0, 0, 1)
	pr.spin = Vector3.ZERO
	pr.agent.v = Vector3(sin(1.5), 0, cos(1.5)) * 0.5  # тронулся к точке в 1,5 рад от носа
	var prev := pr.look
	var prev_rate := 0.0
	var max_rate := 0.0
	var max_acc := 0.0
	for i in 90:
		EcoPred.turn(pr, dt)
		var rate := prev.angle_to(pr.look) / dt
		max_acc = maxf(max_acc, absf(rate - prev_rate) / dt)
		max_rate = maxf(max_rate, rate)
		prev = pr.look
		prev_rate = rate
	ok(max_acc <= EcoPred.TURN_ACCEL * 1.02, "скорость поворота меняется плавно: %.1f рад/с²" % max_acc)
	ok(max_rate > 1.5 and max_rate <= EcoPred.TURN_MAX + 1e-4, "и всё же поворачивает быстро: %.2f рад/с" % max_rate)
	ok(pr.look.angle_to(EcoPred.aim(pr)) < 0.01, "довернул к курсу без перелёта")
	near(pr.spin.length(), 0.0, 0.05, "встал на курс — поворот погас")


## Мир сам: у старта 00 хищник встаёт у точек патруля и разворачивается — угловое ускорение тела по окну в 6 шагов
## не больше TURN_ACCEL (с запасом на окно); было до 14,6 рад/с² по окну, 88 — за кадр.
func test_world_turns_without_snap() -> void:
	var ev := EcoView.new()  # весь мир, как в игре: стаи, станции чистки, риф
	ev.world.ship.pos = LayerMap.at("00")
	ev.ground = Seabed.height
	var w := ev.world
	var pr := _preds(w).all[0]
	var dt := 1.0 / 30.0
	var hist: Array[Vector3] = []
	var worst := 0.0
	for i in 300:
		w.step(dt)
		hist.append(pr.look)
		if hist.size() > 13:
			hist.pop_front()
		if hist.size() == 13 and i > 30:
			var w1 := hist[0].angle_to(hist[6]) / (6 * dt)
			var w2 := hist[6].angle_to(hist[12]) / (6 * dt)
			worst = maxf(worst, absf(w2 - w1) / (6 * dt))
	ev.free()
	ok(worst <= EcoPred.TURN_ACCEL * 1.1, "угловое ускорение тела у 00: %.1f рад/с²" % worst)


## Мир ведёт поворот сам: после шагов курс близок к скорости, пиявник на теле — по тому же курсу.
func test_world_turns_preds() -> void:
	var w := _alone()
	for i in 200:
		_step(w)
	for pr in _preds(w).all:
		ok(pr.look.is_normalized(), "курс единичный")
		if pr.agent.v.length() > 1.0:
			ok(pr.look.angle_to(EcoPred.aim(pr)) < 0.6, "курс догоняет скорость: %.2f" % pr.look.angle_to(EcoPred.aim(pr)))


## Корабль в 60 м от зверя: он в кадре и машет хвостом каждый кадр (ближе EcoPredLook.ANIM_FAR), но корабля не
## замечает — тихо и без света.
func _beside(pr: EcoPred.Pred) -> Vector3:
	return pr.agent.p + Vector3(60, 0, 0)


## Мировая точка кости зверя i в его модели.
func _bone_at(pv: PredView, i: int, bone: String) -> Vector3:
	var sk: Skeleton3D = pv.bodies[i].find_children("*", "Skeleton3D", true, false)[0]
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin


func test_view_models_in_scene() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var pv := view.pred_view
	ok(pv != null and pv.get_parent() == view, "серпохвосты — в живом мире")
	eq(pv.bodies.size(), 3, "три хищника")
	eq(pv.find_children("*", "Skeleton3D", true, false).size(), 3, "у каждого — скелет ANIM-001")
	var meshes := pv.find_children("*", "MeshInstance3D", true, false)
	eq(meshes.size(), 9, "три сетки на зверя — 9 вызовов отрисовки")
	var tris := 0
	for m: MeshInstance3D in meshes:
		eq(m.layers, OceanView.LAYER_WORLD, "слой отмели")
		ok(m.skin != null, "%s на скелете" % m.name)
		var arr := m.mesh.surface_get_arrays(0)
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	eq(tris, 3 * (3988 + 986 + 745), "треугольники моделей MOD-011")

	var ship := EcoLink.ShipState.new()
	var pr := view.preds.all[1]
	for i in 20:
		ship.pos = _beside(pr)
		view.step(0.05, ship)
	var root := pv.bodies[1]
	var at := pv.trees[1]
	ok(root.position.distance_to(pr.agent.p) < 1e-4, "место — из мира")
	ok((root.basis * Vector3(0, 0, -1)).distance_to(EcoPredLook.forward(pr)) < 1e-3, "голова по курсу")
	near(at.get(PredView.P_MIX), EcoPredLook.swim_mix(pr), 1e-5, "смесь плавания — из EcoPredLook")
	near(at.get(PredView.P_SWIM) / at.get(PredView.P_FAST), EcoPredLook.SWIM_LEN / EcoPredLook.SWIM_FAST_LEN, 1e-5,
			"у Swim и SwimFast одна фаза")
	# хвост машет: кончик в осях зверя ходит вбок
	var side := 0.0
	var a0 := root.global_transform.affine_inverse() * _bone_at(pv, 1, "Tail03")
	for i in 30:
		ship.pos = _beside(pr)
		view.step(0.05, ship)
		var tip := root.global_transform.affine_inverse() * _bone_at(pv, 1, "Tail03")
		side = maxf(side, absf(tip.x - a0.x))
	ok(side > 0.05, "хвост волной вбок: %.2f м" % side)

	# бросок у корабля — укус, только челюсть
	pr.mode = EcoPred.Mode.CHARGE
	pr.agent.timer = 10.0
	pr.cooldown = 99.0
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var jaw_rest := sk.get_bone_pose_rotation(sk.find_bone("Jaw"))
	ship.pos = pr.agent.p + Vector3(EcoPredLook.BITE_SHIP_DIST - 1.0, 0, 0)
	view.step(0.05, ship)
	ok(at.get(PredView.P_BITE_ON), "укус играет")
	var opened := 0.0
	for i in 12:
		ship.pos = pr.agent.p + Vector3(EcoPredLook.BITE_SHIP_DIST - 1.0, 0, 0)
		view.step(0.05, ship)
		opened = maxf(opened, sk.get_bone_pose_rotation(sk.find_bone("Jaw")).angle_to(jaw_rest))
	ok(opened > deg_to_rad(20.0), "пасть раскрылась на %.0f°" % rad_to_deg(opened))

	# укус корпуса — удар серпом
	pr.bit_at = view.world.time
	view.step(0.05, ship)
	ok(at.get(PredView.P_STRIKE_ON), "удар серпом играет")
	view.queue_free()
	await frames(1)


## Дыхание (Б3): тело шире и выше в такт, длина та же; в броске размах гаснет; у зверей ритм и фаза свои.
func test_look_breath() -> void:
	var w := _alone()
	var all := _preds(w).all
	var pr := all[0]
	pr.agent.v = Vector3.ZERO
	var lo := 1.0
	var hi := -1.0
	for i in 200:
		var k := EcoPredLook.breath(pr, i * 0.05)
		lo = minf(lo, k)
		hi = maxf(hi, k)
	ok(hi > 0.95 and lo < -0.95, "в покое дышит во весь размах: %.2f…%.2f" % [lo, hi])
	var sc := EcoPredLook.breath_scale(1.0)
	near(sc.x, 1.0 + EcoPredLook.BREATH_W, 1e-6, "шире")
	near(sc.y, 1.0 + EcoPredLook.BREATH_H, 1e-6, "выше")
	eq(sc.z, 1.0, "длина та же")
	# плавно: за 0,05 с доля не прыгает
	for i in 100:
		var d := absf(EcoPredLook.breath(pr, i * 0.05 + 0.05) - EcoPredLook.breath(pr, i * 0.05))
		ok(d < 0.1, "дыхание плавное")
		if d >= 0.1:
			break
	pr.agent.v = Vector3(EcoPredLook.MIX_TO, 0, 0)
	for i in 50:
		near(EcoPredLook.breath(pr, i * 0.1), 0.0, 1e-6, "в броске не дышит")
	if all.size() > 1:
		all[1].agent.v = Vector3.ZERO
		pr.agent.v = Vector3.ZERO
		var same := true
		for i in 20:
			if absf(EcoPredLook.breath(pr, i * 0.3) - EcoPredLook.breath(all[1], i * 0.3)) > 0.05:
				same = false
		ok(not same, "звери дышат не в лад")


## В сцене корень модели дышит: ширина по EcoPredLook.breath, голова по курсу.
func test_view_breathes() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var pv := view.pred_view
	var pr := view.preds.all[1]
	var ship := EcoLink.ShipState.new()
	var lo := 9.0
	var hi := 0.0
	for i in 60:
		ship.pos = _beside(pr)
		view.step(0.05, ship)
		var root := pv.bodies[1]
		var want := EcoPredLook.breath_scale(EcoPredLook.breath(pr, view.world.time))
		near(root.basis.x.length(), want.x, 1e-4, "ширина — по дыханию")
		near(root.basis.z.length(), 1.0, 1e-4, "длина та же")
		ok((root.basis * Vector3(0, 0, -1)).normalized().distance_to(EcoPredLook.forward(pr)) < 1e-3, "голова по курсу")
		lo = minf(lo, root.basis.x.length())
		hi = maxf(hi, root.basis.x.length())
	ok(hi - lo > 0.005 or EcoPredLook.swim_mix(pr) > 0.9, "тело шире и уже за 3 с: %.3f…%.3f" % [lo, hi])
	view.queue_free()
	await frames(1)


## Вдали (дальше CUE_FAR) клипы не меняются — только плавание.
func test_view_far_keeps_swimming() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var ship := EcoLink.ShipState.new()
	ship.pos = FAR
	view.step(0.05, ship)
	var pr := view.preds.all[0]
	pr.mode = EcoPred.Mode.EAT
	pr.bit_at = view.world.time
	view.pred_view.sync(view.world.time + 0.05, pr.agent.p + Vector3(EcoPredLook.CUE_FAR + 5.0, 0, 0))
	ok(not view.pred_view.trees[0].get(PredView.P_BITE_ON), "вдали не жуёт")
	ok(not view.pred_view.trees[0].get(PredView.P_STRIKE_ON), "и не бьёт")
	view.queue_free()
	await frames(1)


## LOD скелета (issue #850): вблизи — каждый кадр, вдали — набранным временем раз в ANIM_FAR_STEP, спрятанный стоит,
## пропущенное (не больше LAG_MAX) отдаёт, когда покажется.
func test_clock_lod() -> void:
	var c := EcoPredLook.Clock.new()
	near(c.tick(0.05, 30.0), 0.05, 1e-6, "вблизи — каждый кадр")
	var far := EcoPredLook.ANIM_FAR + 10.0
	var got := 0.0
	var calls := 0
	for i in 20:
		var s := c.tick(0.05, far)
		if s > 0.0:
			calls += 1
			got += s
	eq(calls, 5, "вдали — раз в %.1f с" % EcoPredLook.ANIM_FAR_STEP)
	near(got + c.lag, 1.0, 1e-5, "время не теряется")
	var hide := EcoPredLook.HIDE_FAR + 10.0
	c.lag = 0.0
	for i in 100:
		eq(c.tick(0.05, hide), 0.0, "спрятан — дерево стоит")
	near(c.tick(0.05, 30.0), EcoPredLook.LAG_MAX, 1e-6, "показался — пропущенное разом, не длиннее LAG_MAX")
	ok(EcoPredLook.CUE_FAR < EcoPredLook.ANIM_FAR, "укусы и удары — только там, где скелет идёт каждый кадр")


## «Экономно» (Б6): поза реже уже с ANIM_MID_LITE, дальше ANIM_FAR_LITE — как вдали; вблизи — каждый кадр; время не
## теряется; на «Обычно» прежний порядок.
func test_clock_lite() -> void:
	var c := EcoPredLook.Clock.new()
	near(c.tick(0.05, 10.0, true), 0.05, 1e-6, "вблизи и на «Экономно» — каждый кадр")
	eq(EcoPredLook.Clock.step_at(40.0), 0.0, "на «Обычно» в 40 м — каждый кадр")
	eq(EcoPredLook.Clock.step_at(40.0, true), EcoPredLook.ANIM_MID_STEP, "на «Экономно» в 40 м — реже")
	eq(EcoPredLook.Clock.step_at(70.0, true), EcoPredLook.ANIM_FAR_STEP, "дальше %.0f м — как вдали" % EcoPredLook.ANIM_FAR_LITE)
	var got := 0.0
	var calls := 0
	for i in 20:
		var s := c.tick(0.05, 40.0, true)
		if s > 0.0:
			calls += 1
			got += s
	eq(calls, 10, "в 40 м — раз в %.1f с" % EcoPredLook.ANIM_MID_STEP)
	near(got + c.lag, 1.0, 1e-5, "время не теряется")
	ok(EcoPredLook.ANIM_MID_LITE < EcoPredLook.ANIM_FAR_LITE and EcoPredLook.ANIM_FAR_LITE < EcoPredLook.ANIM_FAR,
		"пороги «Экономно» ближе обычных")
	c.lag = 0.0
	c.tick(0.05, 40.0, true)
	near(c.flush(), 0.05, 1e-6, "flush отдаёт набранное")
	eq(c.lag, 0.0, "и обнуляет")


## «Экономно» у сцены: EcoView.set_lite доходит до серпохвостов; в 40 м поза меняется реже кадра, а укус между
## позами всё равно запускается.
func test_view_lite_skeleton_slower() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var pv := view.pred_view
	var pr := view.preds.all[1]
	var ship := EcoLink.ShipState.new()
	ship.pos = _beside(pr)
	view.step(0.05, ship)
	view.set_lite(true)
	ok(pv.lite, "серпохвосты — на «Экономно»")
	var sk: Skeleton3D = pv.bodies[1].find_children("*", "Skeleton3D", true, false)[0]
	var tail := sk.find_bone("Tail03")
	var mid := pr.agent.p + Vector3(40.0, 0, 0)
	var t0 := view.world.time + 0.6
	pv.sync(t0, mid)
	var changes := 0
	var last := sk.get_bone_pose_rotation(tail)
	for i in range(1, 21):
		pv.sync(t0 + 0.05 * i, mid)
		var q := sk.get_bone_pose_rotation(tail)
		if not q.is_equal_approx(last):
			changes += 1
		last = q
	ok(changes >= 8 and changes <= 11, "поза в 40 м сменилась %d раз за 20 кадров" % changes)
	# укус в такой кадр, где поза не меняется: клип всё равно идёт
	t0 += 1.1
	pv.sync(t0, mid)   # шаг 0,1 с — поза сменилась, набранного нет
	eq(pv.clocks[1].lag, 0.0, "набранное отдано")
	pr.mode = EcoPred.Mode.EAT
	pv.cues[1].bite_at = -99.0
	pv.sync(t0 + 0.05, mid)   # 0,05 с — между позами
	ok(pv.trees[1].get(PredView.P_BITE_ON), "укус между позами не потерян")
	view.set_lite(false)
	ok(not pv.lite, "назад — «Обычно»")
	view.queue_free()
	await frames(1)


## Дальше HIDE_FAR хищник спрятан и его скелет не считается; вдали — поза меняется реже кадра.
func test_view_far_hidden_and_still() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var pv := view.pred_view
	var pr := view.preds.all[1]
	var ship := EcoLink.ShipState.new()
	ship.pos = _beside(pr)
	view.step(0.05, ship)
	var sk: Skeleton3D = pv.bodies[1].find_children("*", "Skeleton3D", true, false)[0]
	var tail := sk.find_bone("Tail03")
	# спрятан: модель не рисуется, кость хвоста стоит
	var t0 := view.world.time
	pv.sync(t0 + 0.05, pr.agent.p + Vector3(EcoPredLook.HIDE_FAR + 20.0, 0, 0))
	ok(not pv.bodies[1].visible, "дальше %.0f м — спрятан" % EcoPredLook.HIDE_FAR)
	var rest := sk.get_bone_pose_rotation(tail)
	for i in range(2, 12):
		pv.sync(t0 + 0.05 * i, pr.agent.p + Vector3(EcoPredLook.HIDE_FAR + 20.0, 0, 0))
		ok(sk.get_bone_pose_rotation(tail).is_equal_approx(rest), "спрятанный не машет хвостом")
	# вдали (между ANIM_FAR и HIDE_FAR): виден, поза меняется не каждый кадр
	var mid := pr.agent.p + Vector3(EcoPredLook.ANIM_FAR + 20.0, 0, 0)
	t0 += 0.6
	pv.sync(t0, mid)  # отдаёт набранное
	ok(pv.bodies[1].visible, "вдали — виден")
	var changes := 0
	var last := sk.get_bone_pose_rotation(tail)
	for i in range(1, 21):
		pv.sync(t0 + 0.05 * i, mid)
		var q := sk.get_bone_pose_rotation(tail)
		if not q.is_equal_approx(last):
			changes += 1
		last = q
	ok(changes >= 3 and changes <= 6, "поза вдали сменилась %d раз за 20 кадров" % changes)
	view.queue_free()
	await frames(1)


# ---------- Риф у Каменного цветка 01 (#834, часть 2б) ----------

## Светляки и серпохвосты на ровном дне; хищники, кроме первого, далеко; корабль далеко.
func _reef_world() -> Array:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var fish := w.add(EcoFish.new()) as EcoFish
	var preds := w.add(EcoPred.new(fish)) as EcoPred
	for i in range(1, preds.all.size()):
		preds.all[i].agent.p = Vector3(-300 + 20 * i, -30, 300)
	return [w, preds, fish]


func _crown(fish: EcoFish) -> Array[EcoFish.Shoal]:
	var out: Array[EcoFish.Shoal] = []
	for sh in fish.shoals:
		if sh.crown:
			out.append(sh)
	return out


func test_crown_shoals_hide_before_pred_reaches_reef() -> void:
	var r := _reef_world()
	var w: EcoWorld = r[0]
	var preds: EcoPred = r[1]
	var fish: EcoFish = r[2]
	var axis := preds.reef_axis()
	ok(axis.is_finite(), "ось рифа — подножие цветка")
	near(axis.x, EcoFlower.CENTER.x, 1e-4)
	near(axis.z, EcoFlower.CENTER.y, 1e-4)
	var pr := preds.all[0]
	pr.agent.p = Vector3(axis.x + 90.0, -30.0, axis.z)  # далеко — стаи спокойны
	pr.agent.goal = pr.agent.p
	for i in 4:
		_step(w)
	for sh in _crown(fish):
		near(sh.alarm, 0.0, 1e-6, "хищник в 90 м — стая у кроны спокойна")
	pr.agent.p = Vector3(axis.x + EcoPred.REEF_EDGE + 5.0, -30.0, axis.z)  # снаружи края рифа
	pr.agent.goal = pr.agent.p
	w.bus.take()
	for i in 4:  # стаи вдали от корабля шагают через раз
		_step(w)
	var texts: Array[String] = []
	for ev in w.bus.take():
		if ev.species == "fish" and ev.note == "flee":
			texts.append(ev.text())
	for sh in _crown(fish):
		ok(sh.alarm > 0.0, "хищник ещё за краем рифа (47 м) — стая у кроны уже прячется в чашу")
		ok(sh.center.distance_to(pr.agent.p) > EcoFish.PRED_ALARM, "раньше, чем он подошёл на 16 м")
	ok(texts.size() >= 1 and "Каменного цветка" in texts[0] and "крону" in texts[0], "знак: стая прячется в крону")
	var f := fish.nearest_fish(pr.agent.p, 200.0, preds._hidden_fish())
	ok(f == null or not f.shoal.crown, "спрятавшуюся в крону стаю хищник не выбирает")


func test_ping_at_flower_calls_pred_to_reef_edge_not_ship() -> void:
	var r := _reef_world()
	var w: EcoWorld = r[0]
	var preds: EcoPred = r[1]
	var axis := preds.reef_axis()
	var pr := preds.all[0]
	pr.agent.p = Vector3(axis.x + 80.0, -30.0, axis.z + 20.0)
	w.ship.pos = Vector3(axis.x - 10.0, -30.0, axis.z)
	preds.on_ping(w, w.ship.pos)
	eq(pr.mode, EcoPred.Mode.INVESTIGATE, "услышал импульс")
	var g := pr.agent.goal
	near(Vector2(g.x - axis.x, g.z - axis.z).length(), EcoPred.REEF_EDGE, 1e-3, "плывёт к внешнему краю рифа")
	ok(g.x > axis.x, "со своей стороны рифа")
	ok(g.distance_to(w.ship.pos) > 40.0, "не к кораблю")
	var pings := _notes(w, "ping")
	ok(pings.size() == 1 and "края рифа" in pings[0].text(), "строка: кружит у края рифа")
	# импульс вдали от цветка — по-старому, на звук
	r = _reef_world()
	w = r[0]
	pr = (r[1] as EcoPred).all[0]
	pr.agent.p = Vector3(axis.x + 100.0, -30.0, axis.z + 20.0)
	w.ship.pos = Vector3(axis.x + 70.0, -30.0, axis.z)
	(r[1] as EcoPred).on_ping(w, w.ship.pos)
	ok(pr.agent.goal.distance_to(w.ship.pos) < 1e-3, "дальше 60 м от цветка — плывёт на звук")


func test_ship_in_reef_is_safe() -> void:
	for inside in [true, false]:
		var r := _reef_world()
		var w: EcoWorld = r[0]
		var preds: EcoPred = r[1]
		var axis := preds.reef_axis()
		var pr := preds.all[0]
		pr.hunger = 0.5
		pr.cooldown = 0.0
		var ship_x := 20.0 if inside else 60.0
		w.ship.pos = Vector3(axis.x + ship_x, -30.0, axis.z)
		pr.agent.p = w.ship.pos + Vector3(25.0, 0, 0)
		pr.agent.goal = pr.agent.p
		w.ship.light_on = true
		_step(w)
		if inside:
			ok(pr.mode != EcoPred.Mode.CHARGE, "корабль в рифе у цветка — хищник не бросается")
		else:
			eq(pr.mode, EcoPred.Mode.CHARGE, "за рифом свет ближе 32 м — бросок, как везде")


func test_charge_breaks_off_at_reef() -> void:
	var r := _reef_world()
	var w: EcoWorld = r[0]
	var preds: EcoPred = r[1]
	var axis := preds.reef_axis()
	var pr := preds.all[0]
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.pos = Vector3(axis.x + 60.0, -30.0, axis.z)
	pr.agent.p = w.ship.pos + Vector3(25.0, 0, 0)
	w.ship.light_on = true
	_step(w)
	eq(pr.mode, EcoPred.Mode.CHARGE)
	w.bus.take()
	w.ship.pos = Vector3(axis.x + 10.0, -30.0, axis.z)  # корабль ушёл в риф
	_step(w)
	eq(pr.mode, EcoPred.Mode.RETREAT, "отвернул от рифа")
	near(Vector2(pr.agent.goal.x - axis.x, pr.agent.goal.z - axis.z).length(), EcoPred.REEF_EDGE, 1e-3, "к краю рифа")
	eq(_notes(w, "reef").size(), 1, "строка: не идёт в риф")
	eq(w.hits, 0)


func test_patrol_goes_around_reef() -> void:
	var r := _reef_world()
	var w: EcoWorld = r[0]
	var preds: EcoPred = r[1]
	var axis := preds.reef_axis()
	var pr := preds.all[0]
	pr.hunger = -2.0  # сыт весь прогон — не отвлекается на охоту
	ok(preds.outside_reef(axis, axis + Vector3(5, 0, 0), EcoPred.REEF_KEEP).distance_to(axis) >= EcoPred.REEF_KEEP - 1e-3,
		"цель патруля внутри рифа выносится на кольцо")
	pr.agent.p = Vector3(axis.x - 60.0, -30.0, axis.z + 3.0)
	pr.agent.goal = Vector3(axis.x + 60.0, -30.0, axis.z - 3.0)  # путь прямо через цветок
	pr.agent.timer = 120.0
	var closest := 1e9
	var target := pr.agent.goal
	var reached := false
	for i in 1600:  # 80 с: 120 м пути и дуга вокруг рифа на 3 м/с
		_step(w)
		var p := pr.agent.p
		closest = minf(closest, Vector2(p.x - axis.x, p.z - axis.z).length())
		reached = reached or Vector2(p.x - target.x, p.z - target.z).length() < 5.0
	ok(closest > EcoPred.REEF_KEEP - 4.0, "огибает риф, а не плывёт сквозь крону (ближе всего %.1f м)" % closest)
	ok(reached, "и доплывает до цели на той стороне (%s)" % pr.agent.p)


## Самый резкий вертикальный разгон (м/с², по окну 3 шага) и шагов вплотную ко дну у серпохвостов за seconds с мира
## у места id.
## Минута полного мира у места (EcoView, шаг 1/30 с) — одна на тесты разворота и вертикали серпохвостов: раньше
## каждый гонял свою (60 и 50 с), 17 с на две одинаковые прогулки. Мир детерминирован — итог общий (#1350).
## Только 01: у 02 серпохвосты в 100–190 м от корабля — это отмель без корабля, её дают пять минут `_shallows`.
## tail — худший угол носа к ходу на ходу ≥ 1 м/с; jerk — худший вертикальный разгон, м/с²; touch — шагов вплотную
## ко дну.
static var _walks := {}


static func _walk(id: String) -> Dictionary:
	if _walks.has(id):
		return _walks[id]
	var dt := 1.0 / 30.0
	var ev := EcoView.new()
	ev.world.ship.pos = LayerMap.at(id)
	ev.ground = Seabed.height
	var m := _motion()
	for i in int(60.0 / dt):
		ev.world.step(dt)
		_track(m, ev.preds, dt)
	ev.free()
	_walks[id] = m
	return m


## Замер хода серпохвостов по шагам мира: tail, jerk, touch (см. `_walk`); история высот — по окну 7 шагов,
## разгон — после первых 2 с (раньше — разгон с места).
static func _motion() -> Dictionary:
	return {"tail": 0.0, "jerk": 0.0, "touch": 0, "hist": {}, "i": 0, "t": 0.0}


static func _track(m: Dictionary, preds: EcoPred, dt: float) -> void:
	m["i"] += 1
	m["t"] += dt
	var hist: Dictionary = m["hist"]
	for k in preds.all.size():
		var pr: EcoPred.Pred = preds.all[k]
		var a := pr.agent
		var f := Vector2(a.v.x, a.v.z)
		if f.length() >= 1.0:
			m["tail"] = maxf(m["tail"], absf(Vector2(pr.look.x, pr.look.z).angle_to(f)))
		var h: Array = hist.get(k, [])
		h.append(a.p.y)
		if h.size() > 7:
			h.pop_front()
		hist[k] = h
		if a.p.y - (Seabed.height(a.p.x, a.p.z) + a.clearance) < 0.01:
			m["touch"] += 1
		if h.size() == 7 and m["t"] > 2.0 + 1.5 * dt:
			var v1: float = (h[3] - h[0]) / (3.0 * dt)
			var v2: float = (h[6] - h[3]) / (3.0 * dt)
			m["jerk"] = maxf(m["jerk"], absf(v2 - v1) / (3.0 * dt))


func test_looks_ahead_at_rising_floor() -> void:
	# дно — ступенька 3 м через 12 м пути: смотрит вперёд — набирает высоту заранее и не касается её
	var ground := func(x: float, _z: float) -> float: return -40.0 if x < 12.0 else -37.0
	for look in [0.0, EcoPred.LOOK]:
		var a := EcoAgent.new(EcoPred.ID, Vector3(0, -40.0 + 1.8, 0))
		a.look = look
		a.v = Vector3(6, 0, 0)
		var touch := 0
		var vy_jump := 0.0
		for i in 90:
			var vy0 := a.v.y
			var y0 := a.p.y
			a.drive(Vector3(6, 0, 0), 1.0 / 30.0, ground)
			vy_jump = maxf(vy_jump, absf((a.p.y - y0) * 30.0 - vy0))
			if a.p.y - (float(ground.call(a.p.x, a.p.z)) + a.clearance) < 0.01 and a.p.x > 12.0:
				touch += 1
		if look == 0.0:
			ok(touch > 0, "без взгляда вперёд — вплотную ко дну на ступеньке")
		else:
			eq(touch, 0, "смотрит вперёд — над ступенькой с запасом")
			ok(vy_jump < 0.5, "без скачка вертикальной скорости за шаг (%.2f м/с)" % vy_jump)


func test_no_vertical_jerk_over_reef_and_ridges() -> void:
	# у 01 и по всей отмели серпохвосты охотятся у склонов: раньше взлетали по дну до 12 м/с вверх и вставали
	# за кадр (107 м/с²). Отмель — пять минут без корабля (`_shallows`, шаг 0,05 с) вместо минуты у 02 (#1350)
	var runs := {"у 01": _walk("01"), "на отмели": _shallows()["motion"]}
	for at in runs:
		var r: Dictionary = runs[at]
		ok(r["jerk"] < 15.0, "%s вертикальный разгон серпохвоста плавный: %.1f м/с²" % [at, r["jerk"]])
		eq(r["touch"], 0, "%s не ползёт вплотную по дну" % at)


func test_swim_turns_round_instead_of_backing() -> void:
	# цель патруля за спиной: ход поворачивает дугой (`EcoAgent.swim`), а не гаснет до нуля и не идёт назад
	var dt := 1.0 / 30.0
	var a := EcoAgent.new(EcoPred.ID, Vector3(0, -20, 0))
	a.agility = 1.1
	a.v = Vector3(0, 0, EcoPred.PATROL_SPEED)
	var slowest := INF
	var worst_turn := 0.0
	for i in int(4.0 / dt):
		var before := Vector2(a.v.x, a.v.z)
		a.swim(Vector3(0, 0, -EcoPred.PATROL_SPEED), dt, EcoPred.SWIM_TURN, EcoPred.SWIM_TURN_MAX, EcoPred.SWIM_SLOW)
		var after := Vector2(a.v.x, a.v.z)
		slowest = minf(slowest, after.length())
		worst_turn = maxf(worst_turn, absf(before.angle_to(after)) / dt)
	ok(slowest > 0.5, "в развороте не встаёт: самый медленный ход %.2f м/с" % slowest)
	ok(worst_turn <= EcoPred.SWIM_TURN_MAX + 1e-3, "курс хода — не быстрее %.1f рад/с: %.2f" % [EcoPred.SWIM_TURN_MAX, worst_turn])
	ok(a.v.z < -0.9 * EcoPred.PATROL_SPEED, "развернулся и идёт к цели: %.2f м/с" % a.v.z)
	# drive (lerp векторов) — проходит через ноль: так было у серпохвоста
	var b := EcoAgent.new(EcoPred.ID, Vector3(0, -20, 0))
	b.agility = 1.1
	b.v = Vector3(0, 0, EcoPred.PATROL_SPEED)
	var b_slowest := INF
	for i in int(4.0 / dt):
		b.drive(Vector3(0, 0, -EcoPred.PATROL_SPEED), dt)
		b_slowest = minf(b_slowest, b.v.length())
	ok(b_slowest < 0.2, "lerp векторов гасит ход до нуля: %.2f м/с" % b_slowest)


func test_swim_arrives_without_circling() -> void:
	# вне охоты у цели — встаёт, а не кружит дугой разворота вокруг неё
	var dt := 1.0 / 30.0
	var a := EcoAgent.new(EcoPred.ID, Vector3(0, -20, 0))
	a.agility = 1.1
	a.v = Vector3(0, 0, EcoPred.RETREAT_SPEED)
	var goal := Vector3(0, -20, 20)
	for i in int(20.0 / dt):
		var d := goal - a.p
		var want := d.normalized() * EcoPred.RETREAT_SPEED * minf(1.0, d.length() * EcoPred.ARRIVE_K / EcoPred.RETREAT_SPEED) \
			if d.length_squared() > 1e-4 else Vector3.ZERO
		a.swim(want, dt, EcoPred.SWIM_TURN, EcoPred.SWIM_TURN_MAX, EcoPred.SWIM_SLOW)
	ok(a.p.distance_to(goal) < 2.0, "встал у цели: %.1f м" % a.p.distance_to(goal))
	ok(a.v.length() < 0.5, "почти стоит: %.2f м/с" % a.v.length())


func test_never_swims_tail_first() -> void:
	# у 01 за минуту и на отмели за пять: на ходу быстрее 1 м/с нос (`Pred.look`) не дальше 90° от хода. Раньше на развороте
	# патруля ход шёл через ноль и обратно — до 176°, десятки шагов хвостом вперёд
	var runs := {"у 01": _walk("01"), "на отмели": _shallows()["motion"]}
	for at in runs:
		var worst: float = runs[at]["tail"]
		ok(worst < deg_to_rad(90.0), "%s нос не дальше 90° от хода: %.0f°" % [at, rad_to_deg(worst)])


func test_dive_to_prey_at_floor_brakes_above_floor() -> void:
	# Б3: добыча у самого дна (ниже clearance) — нырок тормозит над дном, а не ложится на него с отскоком: раньше lerp
	# к want.y съедал торможение LOOK_ACCEL, у 02 серпохвост бился о дно (17,8 м/с²), найдено после EcoFish.BRAKE
	var dt := 1.0 / 30.0
	var ground := func(_x: float, _z: float) -> float: return -40.0
	var a := EcoAgent.new(EcoPred.ID, Vector3(0, -40.0 + 1.8 + 4.0, 0))
	a.look = EcoPred.LOOK
	a.agility = 1.6
	a.v = Vector3(0.3, -2.0, 0)
	var prey := Vector3(1.5, -39.8, 0)  # почти под носом, у дна
	var touch := 0
	var bounce := false
	for i in int(3.0 / dt):
		var want := (prey - a.p).normalized() * EcoPred.HUNT_SPEED
		var vy0 := a.v.y
		a.swim(want, dt, EcoPred.SWIM_TURN, EcoPred.SWIM_TURN_SHARP, EcoPred.SWIM_SLOW, ground)
		if a.p.y - (-40.0 + a.clearance) < 0.01:
			touch += 1
		if vy0 < -0.5 and a.v.y > 0.0:
			bounce = true
	eq(touch, 0, "не ложится на дно")
	ok(not bounce, "без отскока от дна")


## Светляк, прижатый к дну (clearance 0,4), ловится сверху: хищник сам ниже clearance + LOOK_GAP над дном не
## опускается — бросок вниз добирает разницу (план Б3; раньше ловил, только когда светляк подскакивал на зажиме).
func test_catches_fish_pressed_to_floor() -> void:
	var a := EcoAgent.new("pred", Vector3(0, -30.0 + 1.8 + EcoAgent.LOOK_GAP, 0))
	var b := EcoAgent.new("fish", Vector3(0.5, -30.0 + 0.4, 0))
	b.clearance = 0.4
	ok(EcoPred.can_catch(a, b), "прямо над прижатым к дну — достаёт")
	b.p.x = 2.0
	ok(not EcoPred.can_catch(a, b), "в стороне дальше CATCH_DIST — нет")
	b.p = a.p + Vector3(0, 2.5, 0)
	ok(not EcoPred.can_catch(a, b), "выше хищника на 2,5 м — бросок вниз не помогает")
	b.p = a.p + Vector3(0, 1.2, 0)
	ok(EcoPred.can_catch(a, b), "ближе CATCH_DIST — как прежде")


## #1400: стая рифа (55; −69) живёт внутри кольца рифа у цветка — хищник её там не ловит (бросок не ведёт его в
## кольцо REEF_KEEP); стаи вне кольца — добыча как раньше.
func test_reef_ring_fish_hidden() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = FAR
	var fish := w.add(EcoFish.new()) as EcoFish
	var preds := w.add(EcoPred.new(fish)) as EcoPred
	preds._reef = preds.reef_axis()
	ok(preds._reef.is_finite(), "риф у цветка есть")
	var skip: Callable = preds._hidden_fish()
	ok(skip.is_valid())
	for f in fish.shoals[4].members:
		ok(EcoPred._flat_dist(f.agent.p, preds._reef) < EcoPred.REEF_KEEP, "стая 4 — в кольце рифа")
		ok(skip.call(f), "рыбку в рифе хищник не видит")
	for f in fish.shoals[3].members:
		ok(not skip.call(f), "стая 3 вне рифа — добыча")



## Б3: укус корпуса на ходу корабля — после укуса тело по инерции не входит в обшивку и не встаёт о неё за шаг
## (`EcoPred.hull_soften`; раньше 8 → 5 м/с за кадр, 183 м/с², tools/jerk.gd scena=1 move=3). Корабль идёт 3 м/с
## курсом yaw, хищник в dist м по −X от него и side м по Z, свет горит. Худшее ускорение со следующего шага после
## укуса и 2 с — сам удар броска о корпус в шаге укуса — контакт, его не меряем; без `hull_soften` сбоку было
## 110–118 м/с², с ним 11–38. [время укуса, худшее, м/с²]
func _bite_on_the_move(dist: float, side: float, yaw: float) -> Array:
	var w := _alone()
	var pr := _ready_pred(w, dist)
	w.ship.pos += Vector3(0, 0, side)
	w.ship.yaw = yaw
	w.ship.light_on = true
	w.ship.light_range = 60.0
	w.ship.speed = 3.0
	w.ship.hull_noise = 0.45
	var dt := EcoWorld.MAX_STEP
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var t := 0.0
	var worst := 0.0
	var was := pr.agent.v
	var bit := -1.0
	while t < 14.0:
		w.ship.pos += fwd * w.ship.speed * dt
		_step(w)
		t += dt
		if bit >= 0.0:
			worst = maxf(worst, (pr.agent.v - was).length() / dt)
			if t - bit >= 2.0:
				break
		elif w.hits > 0:
			bit = t
		was = pr.agent.v
	return [bit, worst]


func test_bite_on_the_move_no_hull_stop() -> void:
	# сбоку и наискось к носу; лоб в лоб нос корабля сам толкает зверя (3 м/с навстречу) — это удар, не скольжение
	for c: Vector3 in [Vector3(30, -4, PI / 2.0), Vector3(30, 12, 0.0), Vector3(30, -12, PI), Vector3(25, 8, 0.0),
			Vector3(25, -8, PI)]:
		var r := _bite_on_the_move(c.x, c.y, c.z)
		ok(r[0] >= 0.0, "бросок дотянулся до корабля на ходу (%s)" % c)
		ok(r[1] < 60.0, "после укуса не встаёт о обшивку за шаг: %.0f м/с² (%s)" % [r[1], c])
