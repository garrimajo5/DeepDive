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


func test_trapped_in_solid_moves_out() -> void:
	var s := Helm.Ship.new()
	s.pos = Vector3.ZERO
	s.solid = func(p: Vector3, _yaw: float) -> bool: return Vector2(p.x, p.z).length() < 10.0
	s.in_thrust = 1.0
	_run(s, 6.0)
	ok(s.pos.z < -10.0, "застрявший в твёрдом (существо подошло) выходит: z %.1f" % s.pos.z)
	var z := s.pos.z
	s.yaw = PI   # назад к твёрдому — снова не пускает
	_run(s, 10.0)
	ok(Vector2(s.pos.x, s.pos.z).length() >= 10.0, "обратно внутрь не пускает: %.1f" % Vector2(s.pos.x, s.pos.z).length())
	ok(z < 0.0)


## Насколько днище корабля ниже допустимого (грунт + зазор) в худшей точке `Helm.Ship.foot()`; ≤ 0 — не в грунте.
func _dig(s: Helm.Ship) -> float:
	var worst := -INF
	var gap := Helm.Ship.CLEARANCE + Helm.Ship.bottom()
	for q in Helm.Ship.foot():
		var w := s.pos + Vector3(q.x, 0.0, q.z).rotated(Vector3.UP, s.yaw)
		worst = maxf(worst, float(s.ground.call(w.x, w.z)) + gap - (s.pos.y + q.y))
	return worst


## Склон за кормой (#1481): грунт поднимается к +Z на 0,5 м/м. Раньше над дном держался только центр — корма
## (z до +29) уходила в грунт на ~14 м; теперь днище всего корпуса над грунтом.
func test_stern_stays_out_of_slope() -> void:
	var s := Helm.Ship.new()
	s.ground = func(_x: float, z: float) -> float: return -60.0 + maxf(0.0, z) * 0.5
	s.pos = Vector3(0.0, -20.0, 0.0)
	s.in_vert = -1.0
	_run(s, 30.0)
	ok(_dig(s) <= 1e-3, "корма не в грунте: %.2f м" % _dig(s))
	ok(s.pos.y > -60.0 + Helm.Ship.CLEARANCE + 10.0, "центр выше, чем держал бы один центр: %.1f" % s.pos.y)
	near(s.pos.y, s.floor_at(s.pos, s.yaw), 1e-4, "лежит на нижнем пределе")


func test_flat_floor_same_as_center() -> void:
	var s := Helm.Ship.new()
	s.ground = func(_x: float, _z: float) -> float: return -30.0
	near(s.floor_at(Vector3(5.0, 0.0, 7.0), 1.1), -30.0 + Helm.Ship.CLEARANCE, 1e-4, "на ровном — 3 м, как раньше")
	ok(Helm.Ship.foot().size() >= 30, "днище — не одна точка: %d" % Helm.Ship.foot().size())
	var zs := Helm.Ship.foot().map(func(q: Vector3) -> float: return q.z)
	ok(zs.min() <= HullPlan.NOSE_CUT + 1.0 and zs.max() >= HullPlan.STERN_END - 1.0, "от носа до кормы")


## Поворот и ход вперёд-назад на склоне вдоль дна: корпус не входит в грунт и не прыгает (подъём за шаг мал).
func test_turn_and_move_on_slope() -> void:
	var s := Helm.Ship.new()
	s.ground = func(x: float, z: float) -> float: return -80.0 + x * 0.3 + sin(z * 0.05) * 3.0
	s.pos = Vector3(0.0, -70.0, 0.0)
	s.in_vert = -1.0
	_run(s, 10.0)
	var dt := 1.0 / 60.0
	var worst_dig := -INF
	var worst_jump := 0.0
	for phase in [[0.0, 1.0], [1.0, 1.0], [-1.0, -1.0], [0.6, 0.0]]:
		s.in_thrust = phase[0]
		s.in_turn = phase[1]
		for i in 600:
			var y := s.pos.y
			s.update(dt)
			worst_dig = maxf(worst_dig, _dig(s))
			worst_jump = maxf(worst_jump, s.pos.y - y)
	ok(worst_dig <= 1e-3, "не в грунте: %.3f м" % worst_dig)
	ok(worst_jump < 0.3, "без выталкиваний: подъём за шаг до %.2f м" % worst_jump)


## Скала впереди (уступ 20 м): корабль у дна не вспрыгивает на неё под нос, а стоит у подножия.
func test_cliff_blocks_instead_of_lifting() -> void:
	var s := Helm.Ship.new()
	s.ground = func(_x: float, z: float) -> float: return -40.0 if z < -40.0 else -60.0
	s.pos = Vector3(0.0, -57.0, 0.0)
	s.in_thrust = 1.0
	var worst_dig := -INF
	for i in 1200:
		s.update(1.0 / 60.0)
		worst_dig = maxf(worst_dig, _dig(s))
	ok(s.pos.y < -50.0, "не на скале: y %.1f" % s.pos.y)
	var nose_z: float = Helm.Ship.foot().map(func(q: Vector3) -> float: return q.z).min()
	ok(s.pos.z + nose_z > -41.0 and s.pos.z + nose_z < -35.0, "нос у подножия: z %.1f" % (s.pos.z + nose_z))
	ok(worst_dig <= 1e-3, "в скалу не вошёл: %.3f м" % worst_dig)
	s.in_vert = 1.0   # поднялся над скалой — проходит
	_run(s, 20.0)
	ok(s.pos.z < -60.0, "над скалой пускает: z %.1f" % s.pos.z)


## Дно поднялось под стоящим кораблём (загрузка, оползень) — выходит вверх, а не застревает.
func test_buried_ship_comes_up() -> void:
	var s := Helm.Ship.new()
	s.ground = func(_x: float, z: float) -> float: return -30.0 if z > 10.0 else -60.0
	s.pos = Vector3(0.0, -57.0, 0.0)
	s.update(1.0 / 60.0)
	ok(_dig(s) <= 1e-3, "вытолкнуло: %.3f м" % _dig(s))


## Гряда поперёк хода (гаусс, гребень 8 м над дном): корабль у дна на ходу вперёд.
func _ridge(z0: float) -> Callable:
	return func(_x: float, z: float) -> float: return -40.0 + 8.0 * exp(-pow((z - z0) / 6.0, 2.0))


## Гребень проходит под килём от носа к корме: днище сплошное, предел не «пилит» между точками днища (#1481) —
## подъём за метр хода мал, пока гребень под серединой корпуса (не у носа и не у выступов кормы).
func test_crest_under_keel_is_smooth() -> void:
	var s := Helm.Ship.new()
	s.ground = _ridge(0.0)
	var worst := 0.0
	var prev := s.floor_at(Vector3(0.0, 0.0, 4.0), 0.0)
	var z := 4.0
	while z > -14.0:   # гребень в осях корабля — от z −4 до +18 (носовая оболочка до кормового перехода)
		z -= 0.1
		var f := s.floor_at(Vector3(0.0, 0.0, z), 0.0)
		worst = maxf(worst, (f - prev) / 0.1)
		prev = f
	ok(worst * 4.0 < Vitals.SCRAPE_LIFT, "на 4 м/с гребень под килём поднимает на %.2f м/с" % (worst * 4.0))


## У места 00 корма стоит на гряде (#1481, отчёт тестера fe65b4e): полный ход вперёд — корму тянет через гребень,
## корабль поднимается, но удара «о дно» нет. В гряду носом — удар есть.
func test_stern_on_ridge_no_scrape() -> void:
	var s := Helm.Ship.new()
	s.ground = _ridge(26.0)
	s.pos = Vector3(0.0, -20.0, 0.0)
	s.in_vert = -1.0
	_run(s, 10.0)
	s.in_vert = 0.0
	near(s.pos.y, s.floor_at(s.pos, s.yaw), 1e-3, "корма легла на гряду")
	ok(s.top_z > 0.0, "держит корма: z %.1f" % s.top_z)
	s.in_thrust = 1.0
	var dt := 1.0 / 60.0
	var hits := 0
	var v := Vitals.new()
	for i in 360:
		s.update(dt)
		v.update(dt, 1.0, 0.0, false, 1.0)
		if v.scrape(s.bump / dt, s.speed) != s.speed:
			hits += 1
	eq(hits, 0, "через гряду кормой — без удара")
	var r := Helm.Ship.new()
	r.ground = _ridge(-30.0)
	r.pos = Vector3(0.0, -33.0, 0.0)
	r.in_thrust = 1.0
	r.speed = 6.0
	var worst := 0.0
	for i in 240:
		r.update(dt)
		worst = maxf(worst, r.bump / dt)
	ok(worst > Vitals.SCRAPE_LIFT, "носом в гряду — удар: %.2f м/с" % worst)
