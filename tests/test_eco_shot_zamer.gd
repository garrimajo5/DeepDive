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
