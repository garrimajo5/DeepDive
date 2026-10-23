extends TestCase
## Плавность у клиента (NetSmooth): между кадрами хоста корабль и фигуры идут плавно, пачка и пауза пакетов
## не дают рывка, телепорт не тянется через стены, курс — коротким путём, новый забег начинается заново.

const DT := 1.0 / 60.0


func _member(x: float, z: float, yaw: float) -> Crew.Member:
	var m := Crew.Member.new()
	m.place(x, z, yaw)
	return m


## Корабль идёт по −Z со скоростью v; кадры хоста — 20 в секунду.
func _push(s: NetSmooth, i: int, v := 4.0) -> void:
	var t := i * NetSnap.SEND_DT
	s.push(t, Vector3(0.0, -30.0, -v * t), 0.0, [_member(0.5, -v * t * 0.25, 0.0)])


func test_between_frames_is_smooth() -> void:
	var s := NetSmooth.new()
	var helm := Helm.Ship.new()
	var crew: Array = [Crew.Member.new()]
	var last := Vector3.INF
	var worst := 0.0
	var steps := 0
	for i in 40:   # 2 с: кадр раз в три шага экрана
		_push(s, i)
		for j in 3:
			s.step(DT)
			s.apply(helm, crew, null)
			if last != Vector3.INF and i > 4:
				worst = maxf(worst, last.distance_to(helm.pos))
				steps += 1
			last = helm.pos
	ok(steps > 50)
	ok(worst < 4.0 * DT * 1.3, "шаг показа ровный: %.3f м за кадр экрана (ход %.3f)" % [worst, 4.0 * DT])
	var lag := absf(helm.pos.z - (-4.0 * 39 * NetSnap.SEND_DT))
	ok(lag < 4.0 * NetSmooth.DELAY * 1.6, "отставание около DELAY: %.2f м" % lag)
	ok((crew[0] as Crew.Member).z < -1.0, "фигура тоже идёт")


func test_burst_and_gap_have_no_jerk() -> void:
	var s := NetSmooth.new()
	var helm := Helm.Ship.new()
	var crew: Array = []
	var i := 0
	var last := Vector3.INF
	var worst := 0.0
	for round in 12:   # пакеты пачкой по два, потом пауза на два кадра хоста — неровная сеть
		_push(s, i)
		_push(s, i + 1)
		i += 2
		for j in 6:
			s.step(DT)
			s.apply(helm, crew, null)
			if last != Vector3.INF and round > 2:
				worst = maxf(worst, last.distance_to(helm.pos))
			last = helm.pos
	ok(worst < 4.0 * DT * 1.6, "пачка и пауза без рывка: %.3f м за кадр (ход %.3f)" % [worst, 4.0 * DT])


func test_teleport_snaps() -> void:
	var s := NetSmooth.new()
	s.push(0.0, Vector3.ZERO, 0.0, [_member(0.0, 0.0, 0.0)])
	s.push(0.05, Vector3(0.0, 0.0, -50.0), 0.0, [_member(0.0, 10.0, 0.0)])
	s.clock = 0.01
	var ship := s.ship()
	near((ship[0] as Vector3).z, -50.0, 0.001, "корабль перескочил — сразу")
	near(s.member(0)[1], 10.0, 0.001, "фигура перескочила — сразу, не сквозь переборки")


func test_yaw_short_way() -> void:
	var s := NetSmooth.new()
	s.push(0.0, Vector3.ZERO, PI - 0.1, [_member(0.0, 0.0, -PI + 0.1)])
	s.push(0.1, Vector3.ZERO, -PI + 0.1, [_member(0.0, 0.0, PI - 0.1)])
	s.clock = 0.05
	ok(absf(wrapf(float(s.ship()[1]) - PI, -PI, PI)) < 0.01, "курс корабля через ±π, не через 0")
	ok(absf(wrapf(s.member(0)[2] - PI, -PI, PI)) < 0.01, "курс фигуры тоже")


func test_own_yaw_untouched() -> void:
	var s := NetSmooth.new()
	var me := _member(0.0, 0.0, 0.0)
	s.push(0.0, Vector3.ZERO, 0.0, [_member(1.0, 2.0, 1.0)])
	me.yaw = 2.5
	me.walker.yaw = 2.5
	s.apply(Helm.Ship.new(), [me], me)
	near(me.x, 1.0, 0.001, "место — по кадру")
	near(me.walker.z, 2.0, 0.001, "ходок там же")
	near(me.yaw, 2.5, 0.001, "курс свой")


func test_time_back_restarts() -> void:
	var s := NetSmooth.new()
	for i in 5:
		_push(s, i)
	s.push(0.0, Vector3(7.0, 0.0, 0.0), 0.0, [])
	eq(s.shots.size(), 1, "новый забег — с этого кадра")
	near((s.ship()[0] as Vector3).x, 7.0, 0.001)
	eq(s.member(0).size(), 0, "фигуры нет — пусто")


func test_fewer_members_later() -> void:
	var s := NetSmooth.new()
	s.push(0.0, Vector3.ZERO, 0.0, [_member(0.0, 0.0, 0.0), _member(1.0, 0.0, 0.0)])
	s.push(0.05, Vector3.ZERO, 0.0, [_member(0.0, 0.0, 0.0)])
	s.clock = 0.025
	eq(s.member(1).size(), 0, "ушедший не показывается")
	var crew: Array = [Crew.Member.new(), Crew.Member.new()]
	s.apply(Helm.Ship.new(), crew, null)   # экипаж длиннее кадра — не падает
	ok(true)


func _eco(i: int) -> PackedFloat32Array:
	return PackedFloat32Array([3, 16, float(i), 0, 0, 0, 0, 0])


## Живой мир у гостя — на тех же часах, что корабль: пакет существ из свежего кадра ждёт, пока до него дойдёт показ.
func test_eco_waits_for_show_clock() -> void:
	var s := NetSmooth.new()
	s.push(0.0, Vector3.ZERO, 0.0, [], _eco(0))
	eq(s.take_eco(), _eco(0), "первый пакет — сразу, как первый кадр корабля")
	var shown: Array[float] = []
	for i in range(1, 40):
		s.push(i * NetSnap.SEND_DT, Vector3.ZERO, 0.0, [], _eco(i))
		for j in 3:
			s.step(DT)
			var e := s.take_eco()
			if not e.is_empty():
				ok(e[2] * NetSnap.SEND_DT <= s.clock + 1e-5, "пакет не раньше часов показа")
				shown.append(e[2])
	var newest := 39.0
	ok(shown.size() > 30, "пакеты показываются: %d" % shown.size())
	var lag := (newest - shown[-1]) * NetSnap.SEND_DT
	ok(lag >= NetSmooth.DELAY - NetSnap.SEND_DT - 1e-4 and lag <= NetSmooth.DELAY + NetSnap.SEND_DT,
		"существа отстают от свежего кадра как корабль: %.3f с" % lag)
	var ship_t := s.clock
	ok(absf(shown[-1] * NetSnap.SEND_DT - ship_t) <= NetSnap.SEND_DT + 1e-4, "мир и корабль на одних часах")


func test_eco_burst_takes_newest_due() -> void:
	var s := NetSmooth.new()
	for i in 5:
		s.push(i * NetSnap.SEND_DT, Vector3.ZERO, 0.0, [], _eco(i))
	s.take_eco()
	s.clock = 0.11   # показ дошёл до кадра 2: пакеты 1 и 2 настали, полный — свежий из них
	eq(s.take_eco()[2], 2.0, "из наставших — самый свежий")
	eq(s.take_eco().size(), 0, "до кадра 3 — ничего нового")
	eq(s.eco.size(), 2, "ждут кадры 3 и 4")


func test_eco_restart_clears_queue() -> void:
	var s := NetSmooth.new()
	for i in 5:
		s.push(i * NetSnap.SEND_DT, Vector3.ZERO, 0.0, [], _eco(i))
	s.push(0.0, Vector3.ZERO, 0.0, [], _eco(7))   # новый забег: время хоста назад
	eq(s.eco.size(), 1, "старые пакеты сброшены")
	eq(s.take_eco()[2], 7.0, "первый пакет нового забега — сразу")
	s.push(0.05, Vector3.ZERO, 0.0, [])   # кадр без существ — очередь не растёт
	eq(s.eco.size(), 0)
