extends TestCase
## Фаза «замер» включена в игре (#1498, вариант 1 гейм-дизайнера): у каждого из трёх серпохвостов по умолчанию
## замер 4 с перед броском, после «потерял корабль» — отход 20 с. Проверки из описания #1498: все три хищника,
## свет после 30 с ожидания в темноте, повторный подход, свет рядом с уже присутствующим хищником, импульс сонара.

const FLAT := -40.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Мир с тремя хищниками по умолчанию; корабль далеко и тёмный.
func _world() -> Array:
	var w := EcoWorld.new()
	w.ground = _flat
	var ps := EcoPred.new()
	w.add(ps)
	w.ship.pos = Vector3(-300, -30, 300)
	w.ship.light_on = false
	return [w, ps]


## Хищник i голоден и готов; остальные уведены далеко; корабль тёмный в 25 м по +X от него.
func _near(i: int) -> Array:
	var r := _world()
	var w: EcoWorld = r[0]
	var ps: EcoPred = r[1]
	for j in ps.all.size():
		var o := ps.all[j]
		if j != i:
			o.agent.p = Vector3(600 + 100 * j, FLAT + 6.0, -600)
			o.cooldown = 999.0
	var pr := ps.all[i]
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.pos = pr.agent.p + Vector3(25, 0, 0)
	return [w, pr, ps]


func _secs(w: EcoWorld, s: float) -> void:
	for k in int(round(s / EcoWorld.MAX_STEP)):
		w.step(EcoWorld.MAX_STEP)


func test_defaults_are_variant_1() -> void:
	var ps := EcoPred.new()
	near(ps.alert, 4.0, 1e-6, "замер 4 с")
	near(ps.alert_leave, 20.0, 1e-6, "отход 20 с")
	near(EcoPred.ALERT_LOSE_CD, 8.0, 1e-6, "пауза 8 с после отхода")


## Каждый из трёх: свет рядом — замер, а не бросок; свет горит 4 с — бросок.
func test_each_pred_alerts_then_charges() -> void:
	for i in 3:
		var r := _near(i)
		var w: EcoWorld = r[0]
		var pr: EcoPred.Pred = r[1]
		w.ship.light_on = true
		w.step(EcoWorld.MAX_STEP)
		eq(pr.mode, EcoPred.Mode.ALERT, "№%d: сначала замер" % i)
		_secs(w, 3.5)
		eq(pr.mode, EcoPred.Mode.ALERT, "№%d: замер держится 4 с" % i)
		_secs(w, 1.0)
		eq(pr.mode, EcoPred.Mode.CHARGE, "№%d: свет так и горит — бросок" % i)


## Каждый из трёх: экипаж гасит свет через 1,5 с — «потерял корабль», отход, броска нет.
func test_each_pred_answer_light_off() -> void:
	for i in 3:
		var r := _near(i)
		var w: EcoWorld = r[0]
		var pr: EcoPred.Pred = r[1]
		w.ship.light_on = true
		w.step(EcoWorld.MAX_STEP)
		_secs(w, 1.5)
		w.ship.light_on = false
		w.step(EcoWorld.MAX_STEP)
		eq(pr.mode, EcoPred.Mode.RETREAT, "№%d: потерял корабль — отходит" % i)
		for k in int(10.0 / EcoWorld.MAX_STEP):
			w.step(EcoWorld.MAX_STEP)
			ok(pr.mode != EcoPred.Mode.CHARGE, "№%d: в темноте не бросается" % i)
		ok(pr.agent.distance_to(w.ship.pos) > EcoPred.REACH, "№%d: за 10 с ушёл дальше чутья на свет" % i)


## Корабль 30 с стоит тёмный рядом с хищником, потом включает свет — замер с предупреждением, не мгновенный бросок.
func test_light_after_30s_wait_alerts_first() -> void:
	var r := _near(0)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	var ps: EcoPred = r[2]
	_secs(w, 30.0)
	ok(pr.mode != EcoPred.Mode.CHARGE, "тёмный корабль не манит")
	w.ship.pos = pr.agent.p + Vector3(25, 0, 0)   # хищник за 30 с ушёл по патрулю — корабль снова рядом
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.light_on = true
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "свет после ожидания — замер")
	ok(ps.alert > 0.0)


## Повторный подход после отхода: корабль со светом догоняет того же хищника — снова замер, не бросок сразу.
func test_repeat_approach_alerts_again() -> void:
	var r := _near(1)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	w.ship.light_on = true
	w.step(EcoWorld.MAX_STEP)
	w.ship.light_on = false
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.RETREAT)
	_secs(w, 5.0)
	w.ship.light_on = true
	w.ship.pos = pr.agent.p + Vector3(20, 0, 0)
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "повторный подход — новый замер")


## Импульс сонара рядом — осознанная провокация: тоже замер с причиной «сонар», не бросок сразу.
func test_ping_alerts_with_reason() -> void:
	var r := _near(2)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	var ps: EcoPred = r[2]
	ps.on_ping(w, w.ship.pos)
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "импульс — замер")
	var text := ""
	for ev in w.bus.pending:
		if ev.species == EcoPred.ID and ev.note == "alert":
			text = ev.text()
	ok(text.contains("сонар"), "строка с причиной: %s" % text)


## Постановка шага `zamer` сценария тестера и `shot.gd zamer=` (#1498): хищник n в stage_spot — голодный, без паузы,
## остальные далеко с паузой; со светом мир сам начинает замер с игровыми числами, свет погас — отход.
func test_stage_near_alerts_with_game_numbers() -> void:
	var r := _world()
	var w: EcoWorld = r[0]
	var ps: EcoPred = r[1]
	var ship := Vector3(20, FLAT + 7.0, 22.5)
	w.ship.pos = ship
	w.ship.light_on = true
	var yaw := deg_to_rad(-15.0)
	var at := EcoPred.stage_spot(ship, yaw, "nos")
	ok(not ps.stage_near(ps.all.size(), at, ship), "нет такого хищника — false")
	ok(ps.stage_near(1, at, ship), "хищник 1 поставлен")
	var pr := ps.all[1]
	eq(pr.agent.p, at, "в точке постановки")
	near(Vector2(at.x - ship.x, at.z - ship.z).length(), EcoPred.STAGE_DIST, 1e-3, "26 м от корабля")
	ok(EcoPred.STAGE_DIST < EcoPred.REACH, "ближе дальности чутья")
	for o in ps.all:
		if o != pr:
			ok(o.agent.distance_to(ship) >= EcoPred.STAGE_FAR, "хищник %d уведён" % o.index)
			eq(o.cooldown, EcoPred.STAGE_CALM, "и не нападает")
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "со светом — замер, не бросок")
	near(pr.agent.timer, EcoPred.ALERT_ON, 0.1, "замер по числам игры")
	w.ship.light_on = false
	_secs(w, 0.2)
	eq(pr.mode, EcoPred.Mode.RETREAT, "свет погас — отход")
