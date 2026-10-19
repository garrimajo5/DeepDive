extends TestCase
## Ход корабля и течение (js/ship.js, creatures.js).


func _run(ship: Helm.Ship, secs: float, k: float = 1.0, cur: Vector3 = Vector3.ZERO) -> void:
	var dt := 1.0 / 60.0
	for i in int(secs / dt):
		ship.update(dt, k, cur)


func test_full_ahead_reaches_top_speed() -> void:
	var s := Helm.Ship.new()
	s.in_thrust = 1.0
	_run(s, 30.0)
	near(s.speed, Helm.Ship.FORWARD / Helm.Ship.DRAG, 0.01, "полный ход ≈ 6,7 м/с")
	ok(s.pos.z < Helm.Ship.START.z - 100.0, "ушли к носу (−Z)")


func test_reverse_is_slower() -> void:
	var s := Helm.Ship.new()
	s.in_thrust = -1.0
	_run(s, 30.0)
	near(s.speed, -Helm.Ship.REVERSE / Helm.Ship.DRAG, 0.01, "задний ход ≈ 3,6 м/с")


func test_no_power_only_drift() -> void:
	var s := Helm.Ship.new()
	s.in_thrust = 1.0
	_run(s, 10.0, 0.0, Vector3(0.3, 0, 0))
	near(s.speed, 0.0, 1e-6, "без двигателей хода нет")
	near(s.pos.x, 3.0, 0.05, "течение сносит 0,3 м/с")


func test_wheel_right_turns_right() -> void:
	var s := Helm.Ship.new()
	s.in_thrust = 1.0
	s.in_turn = 1.0
	_run(s, 3.0)
	ok(s.yaw < 0.0, "yaw уменьшается")
	ok(s.pos.x > 0.0, "нос ушёл вправо (+X)")


func test_keeps_clear_of_bottom_and_ice() -> void:
	var s := Helm.Ship.new()
	s.ground = func(_x: float, _z: float) -> float: return -30.0
	s.in_vert = -1.0
	_run(s, 20.0)
	near(s.pos.y, -30.0 + Helm.Ship.CLEARANCE, 1e-4, "над дном 3 м")
	s.in_vert = 1.0
	_run(s, 40.0)
	near(s.pos.y, Helm.Ship.CEILING, 1e-4, "подо льдом не выше −5 м")


func test_current_changes_every_three_minutes() -> void:
	var c := Helm.SeaCurrent.new()
	var got: Array[int] = []
	c.changed.connect(func(i: int) -> void: got.append(i))
	near(c.vel().length(), Helm.SeaCurrent.SPEED, 1e-6, "0,3 м/с")
	for i in 181:
		c.update(1.0)
	eq(got, [1] as Array[int], "сменилось один раз")
	for i in 600:
		c.update(1.0)
	near(wrapf(c.angle - Helm.SeaCurrent.DIRS[c.index], -PI, PI), 0.0, 0.05, "довернуло к новому направлению")
