extends TestCase
## Шаг тестера «jerk» (#1753): рывки серпохвоста числом в лог — разбор шага и счёт ускорения по неровным кадрам.


func test_step_parses_and_takes_no_time() -> void:
	var q := QaScript.parse('[{"do": "jerk", "n": 1, "s": 2.5, "lite": true}, {"do": "jerk"}, {"do": "wait", "s": 1}]')
	eq(q.errors.size(), 0, "шаг jerk известен сценарию")
	var cmds := q.advance(0.01)
	eq(cmds.size(), 2, "оба шага jerk — в одном кадре, времени не берут")
	if cmds.size() == 2:
		eq(cmds[0], ["jerk", 1, 2.5, true], "хищник, секунды, «Экономно»")
		eq(cmds[1], ["jerk", 0, 3.0, false], "по умолчанию — хищник 0, 3 с, скелет по уровню")


func test_steady_motion_has_no_accel() -> void:
	var pts: Array[Vector3] = []
	var dts: Array[float] = []
	var x := 0.0
	for i in 40:
		var dt := 1.0 / 30.0 if i % 3 else 1.0 / 20.0   # неровные кадры телефона
		x += 4.0 * dt
		pts.append(Vector3(x, 1.0, 0.0))
		dts.append(dt)
	var a := QaRunner.accel(pts, dts)
	eq(a.size(), 38, "ускорение — на каждый внутренний кадр")
	near(QaRunner.p99(a), 0.0, 1e-3, "ровный ход на неровных кадрах — без ускорения")


func test_parabola_gives_its_accel() -> void:
	var pts: Array[Vector3] = []
	var dts: Array[float] = []
	var t := 0.0
	for i in 60:
		var dt := 1.0 / 30.0 if i % 2 else 1.0 / 45.0
		t += dt
		pts.append(Vector3(0.0, 0.5 * 6.0 * t * t, 0.0))
		dts.append(dt)
	var a := QaRunner.accel(pts, dts)
	near(a[0], 6.0, 1e-2, "наименьшее — 6 м/с²")
	near(a[a.size() - 1], 6.0, 1e-2, "наибольшее — 6 м/с²: неровный шаг не даёт ложного рывка")


func test_held_pose_is_a_jerk() -> void:
	# поза раз в 0,1 с при 30 кадр/с (прореживание «Экономно» до #1756): хвост стоит, потом прыгает
	var pts: Array[Vector3] = []
	var dts: Array[float] = []
	for i in 90:
		var t := floorf(i / 3.0) * 0.1
		pts.append(Vector3(0.3 * sin(t * 2.6), 0.0, 0.0))
		dts.append(1.0 / 30.0)
	var line := QaRunner.jerk_line(0, 3.0, true, pts.size(), QaRunner.accel(pts, dts), [] as Array[float], 24.0, 27.0)
	ok(line.contains("РЫВОК"), "поза ступеньками — рывок: %s" % line)
	ok(line.begins_with("рывки: хищник 0 за 3.0 с, скелет «Экономно», 90 кадров, 24–27 м"), line)


func test_smooth_wave_is_in_norm() -> void:
	var pts: Array[Vector3] = []
	var dts: Array[float] = []
	for i in 90:
		pts.append(Vector3(0.3 * sin(i / 30.0 * 2.6), 0.0, 0.0))   # волна хвоста 0,4 Гц, 0,3 м — 2 м/с²
		dts.append(1.0 / 30.0)
	var line := QaRunner.jerk_line(0, 3.0, false, pts.size(), QaRunner.accel(pts, dts), [] as Array[float], 24.0, 27.0)
	ok(line.contains("хвост в норме"), line)
	ok(line.contains("скелет полный"), line)


## Центр тела (#1350, 13.11: 18 → 29 → 33 за три прогона) — своя норма, тестер отличает рост от разброса.
func test_core_turn_at_full_speed_is_in_norm() -> void:
	# поворот на полном ходу броска — предел логики хода: 9,5 м/с × 3 рад/с = 28,5 м/с²
	var pts: Array[Vector3] = []
	var dts: Array[float] = []
	var r := EcoPred.CHARGE_SPEED / EcoPred.SWIM_TURN_SHARP
	for i in 90:
		var a := (i * 0.04) * EcoPred.SWIM_TURN_SHARP   # кадры по 40 мс — 25 кадр/с телефона
		pts.append(Vector3(r * cos(a), 0.0, r * sin(a)))
		dts.append(0.04)
	var line := QaRunner.jerk_line(0, 3.0, false, pts.size(), [] as Array[float], QaRunner.accel(pts, dts), 24.0, 27.0)
	print("  поворот на полном ходу: %s" % line)
	ok(line.contains("центр в норме (≤ 40)"), line)
	ok(line.contains("центр тела 99 % 28 (макс 28)"), "по хорде кадра — чуть меньше 28,5: %s" % line)


func test_core_pose_jump_is_a_jerk() -> void:
	# ход 6 м/с, на одном кадре тело перескакивает на 0,5 м (сбой шага) — центр «РЫВОК», хвост не судит его
	var pts: Array[Vector3] = []
	var dts: Array[float] = []
	var x := 0.0
	for i in 90:
		x += 6.0 / 30.0 + (0.5 if i == 45 else 0.0)
		pts.append(Vector3(x, 0.0, 0.0))
		dts.append(1.0 / 30.0)
	var line := QaRunner.jerk_line(0, 3.0, false, pts.size(), [] as Array[float], QaRunner.accel(pts, dts), 24.0, 27.0)
	print("  скачок 0,5 м: %s" % line)
	ok(line.contains("центр РЫВОК"), line)
	ok(line.contains("хвост в норме"), "хвост без рядов — в норме: %s" % line)


func test_core_limit_above_swim_bound() -> void:
	# норма центра выше того, что даёт логика хода серпохвоста: поворот, разгон lerp-ом (agility броска 1,6) и подъём
	# перед дном — вместе; поменяли скорость или поворот — норму пересчитать (`pred_jerk.gd`)
	var turn := EcoPred.CHARGE_SPEED * EcoPred.SWIM_TURN_SHARP
	var gain := 1.6 * EcoPred.CHARGE_SPEED
	var bound := sqrt(turn * turn + gain * gain + EcoAgent.LOOK_ACCEL * EcoAgent.LOOK_ACCEL)
	print("  предел логики хода %.1f м/с², норма центра %.0f" % [bound, QaRunner.JERK_CORE_LIMIT])
	ok(bound < QaRunner.JERK_CORE_LIMIT, "предел %.1f < нормы %.0f" % [bound, QaRunner.JERK_CORE_LIMIT])
	ok(QaRunner.JERK_CORE_LIMIT - bound < 10.0, "норма не слишком свободна: запас %.1f" % (QaRunner.JERK_CORE_LIMIT - bound))
