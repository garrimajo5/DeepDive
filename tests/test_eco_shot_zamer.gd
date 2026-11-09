extends TestCase
## Ключ `tools/shot.gd zamer=` (#1498, кадры знака для #1400): где встаёт хищник и что в мире снимка он «замирает».

const ShotSetup := preload("res://tools/shot_setup.gd")


func test_spot_sides_follow_ship_axes() -> void:
	var ship := Vector3(20, -35, 22)
	for yaw in [0.0, 0.7, -2.1]:
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var nos := ShotSetup.zamer_spot(ship, yaw, "nos")
		var bok := ShotSetup.zamer_spot(ship, yaw, "bok")
		var korma := ShotSetup.zamer_spot(ship, yaw, "korma")
		var flat := func(p: Vector3) -> Vector3: return Vector3(p.x - ship.x, 0.0, p.z - ship.z)
		near(flat.call(nos).dot(fwd), ShotSetup.ZAMER_DIST, 1e-3, "nos — перед носом")
		near(flat.call(korma).dot(fwd), -ShotSetup.ZAMER_DIST, 1e-3, "korma — за кормой")
		near(flat.call(bok).dot(right), ShotSetup.ZAMER_DIST, 1e-3, "bok — правый борт")
		for p: Vector3 in [nos, bok, korma]:
			ok(p.y >= Seabed.mesh_height(p.x, p.z) + ShotSetup.ZAMER_FLOOR - 1e-3, "не в грунте")
	ok(ShotSetup.ZAMER_DIST < EcoPred.REACH, "ближе дальности чутья — свет зовёт")
	eq(ShotSetup.zamer_spot(ship, 0.0, "нет"), Vector3.INF, "неизвестная сторона")


## Мир как в снимке: хищник в zamer_spot, свет горит — сначала «замер», не бросок; свет погас — отход.
func test_world_alerts_then_retreats() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.mesh_height
	var ps := EcoPred.new()
	w.add(ps)
	ps.alert = ShotSetup.ZAMER_ALERT
	ps.alert_leave = ShotSetup.ZAMER_LEAVE
	var ship := Vector3(20, Seabed.mesh_height(20, 22.5) + 10.0, 22.5)
	w.ship.pos = ship
	w.ship.light_on = true
	for pr in ps.all:
		pr.cooldown = 999.0 if pr.index != 0 else 0.0
		pr.agent.p = ShotSetup.zamer_spot(ship, 0.0, "korma") if pr.index == 0 else ship + Vector3(400.0 + 30.0 * pr.index, 0, 0)
		pr.agent.goal = pr.agent.p
		EcoPred._set_mode(pr, EcoPred.Mode.PATROL, 30.0)
	var p0 := ps.all[0]
	p0.hunger = 0.5
	w.step(EcoWorld.MAX_STEP)
	eq(p0.mode, EcoPred.Mode.ALERT, "за кормой со светом — замер")
	w.ship.light_on = false
	for i in 3:
		w.step(EcoWorld.MAX_STEP)
	eq(p0.mode, EcoPred.Mode.RETREAT, "свет погас — отход")


## Ключ strah= (#1400, реакция стаи у 01): хищник за стаей — с дальней от корабля стороны, на нужном расстоянии.
func test_strah_spot_behind_shoal() -> void:
	var ship := Vector3(27.6, -34.4, -2.5)
	var c := EcoFish.HOMES[ShotSetup.STRAH_SHOAL]
	var at := ShotSetup.strah_spot(ship, c, 40.0)
	near(Vector2(at.x - c.x, at.z - c.z).length(), 40.0, 1e-3, "на 40 м от стаи")
	ok(Vector2(at.x - ship.x, at.z - ship.z).length() > Vector2(c.x - ship.x, c.z - ship.z).length() + 39.0,
		"дальше стаи от корабля")
	ok(at.y >= Seabed.mesh_height(at.x, at.z) + ShotSetup.ZAMER_FLOOR - 1e-3, "не в грунте")


## Мир как в снимке strah=40: хищник идёт к краю рифа против стаи у 01 (в кольцо не заходит), стая за 20 с —
## в тревоге и прячется у дома; корабль далеко — хищник на него не идёт.
func test_strah_shoal_hides() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.mesh_height
	var fs := EcoFish.new()
	w.add(fs)
	var ps := EcoPred.new(fs)
	w.add(ps)
	var ship := Vector3(27.6, -34.4, -2.5)
	w.ship.pos = ship
	w.ship.light_on = true
	var sh: EcoFish.Shoal = fs.shoals[ShotSetup.STRAH_SHOAL]
	near(Vector2(sh.home.x, sh.home.z).distance_to(Vector2(EcoFish.HOMES[4].x, EcoFish.HOMES[4].z)), 0.0, 0.5,
		"пятая стая — у рифа (55; −69)")
	var at := ShotSetup.strah_spot(ship, sh.center, 40.0)
	for pr in ps.all:
		pr.cooldown = 999.0 if pr.index != 0 else 0.0
		pr.agent.p = at if pr.index == 0 else ship + Vector3(400.0 + 30.0 * pr.index, 0, 0)
		pr.agent.goal = ShotSetup.strah_goal(ps, sh.center) if pr.index == 0 else pr.agent.p
		EcoPred._set_mode(pr, EcoPred.Mode.PATROL, 30.0)
	ps.all[0].hunger = 0.5
	var alarmed := false
	var hid := 0
	for i in int(20.0 / EcoWorld.MAX_STEP):
		w.step(EcoWorld.MAX_STEP)
		alarmed = alarmed or sh.alarm > 0.0
		var n := 0
		for f in sh.members:
			if f.agent.alive and f.agent.state == EcoAgent.State.HIDE:
				n += 1
		hid = maxi(hid, n)
	ok(EcoPred._flat_dist(ShotSetup.strah_goal(ps, sh.center), ps.reef_axis()) >= EcoPred.REEF_KEEP - 1e-3,
		"цель — на краю рифа, не внутри")
	ok(alarmed, "стая в тревоге — рядом хищник")
	ok(hid > 0, "рыбки прячутся у дома (%d)" % hid)
	ok(ps.all[0].agent.distance_to(ship) > EcoPred.REACH, "хищник не подошёл к кораблю на свет")
