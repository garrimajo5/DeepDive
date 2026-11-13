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
