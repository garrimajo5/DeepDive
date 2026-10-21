extends TestCase
## Экипаж: фигура члена экипажа (заглушка до модели ART-014) — поза стоя, на ходу и в кресле пилота, свой игрок
## видит руки и ноги, другие видят всю фигуру; снимок для сети.


func _walk(m: Crew.Member, steps: int, dz: float, dt: float = 1.0 / 30.0) -> void:
	for i in steps:
		m.follow(m.x, m.z + dz, m.yaw, false, 0.0, dt)


func test_standing_figure_fits_height() -> void:
	var m := Crew.Member.new()
	m.follow(1.0, -2.0, 0.0, false, 0.0, 0.1)
	var j := m.joints()
	near(j["head"].y, Deck.Walker.EYE, 0.01, "голова на высоте глаз")
	ok(j["ankle_l"].y > 0.0 and j["ankle_l"].y < 0.1, "лодыжка у пола")
	near(j["toe_l"].y, 0.0, 0.05, "носок на полу")
	ok(j["toe_l"].z < j["ankle_l"].z, "носок к носу корабля (курс 0)")
	ok(j["hand_r"].y > 0.6 and j["hand_r"].y < 0.95, "руки вдоль тела")
	ok(j["shoulder_r"].x > j["shoulder_l"].x, "правое плечо — к правому борту")
	var top := 0.0
	for t in m.parts().values():
		var xf: Transform3D = t
		top = maxf(top, xf.origin.y + xf.basis.y.length() * 0.5)
	ok(top <= Crew.HEIGHT + 0.03 and top > Crew.HEIGHT - 0.1, "рост 1,8 м (%.2f)" % top)


func test_figure_turns_with_yaw() -> void:
	var m := Crew.Member.new()
	m.follow(0.0, 0.0, PI / 2.0, false, 0.0, 0.1)  # лицом к левому борту (−X)
	var j := m.joints()
	ok(j["toe_l"].x < j["ankle_l"].x - 0.1, "носки к левому борту")
	ok(j["shoulder_l"].z > j["shoulder_r"].z, "левое плечо к корме")


func test_walk_swings_legs_and_stops() -> void:
	var m := Crew.Member.new()
	m.follow(0.0, 0.0, 0.0, false, 0.0, 1.0 / 30.0)
	_walk(m, 20, -Deck.Walker.SPEED / 30.0)
	ok(m.swing > 0.9, "идёт полным шагом (%.2f)" % m.swing)
	var seen_l := false
	var seen_r := false
	for i in 30:
		_walk(m, 1, -Deck.Walker.SPEED / 30.0)
		var j := m.joints()
		var dl: float = j["ankle_l"].z - j["ankle_r"].z
		seen_l = seen_l or dl < -0.2
		seen_r = seen_r or dl > 0.2
	ok(seen_l and seen_r, "ноги идут поочерёдно")
	for i in 30:
		m.follow(m.x, m.z, 0.0, false, 0.0, 1.0 / 30.0)
	near(m.swing, 0.0, 1e-6, "остановился")
	var j := m.joints()
	near(j["ankle_l"].z, j["ankle_r"].z, 0.03, "стоит ровно")


func test_seated_hands_on_wheel() -> void:
	var m := Crew.Member.new()
	for turn in [0.0, 1.0, -0.6]:
		m.follow(0.0, Deck.SEAT_Z, 0.0, true, turn, 0.1)
		var j := m.joints()
		var g := Crew.wheel_grips(turn)
		near(j["hand_l"].distance_to(g[0]), 0.0, 0.06, "левая рука на ободе (поворот %s)" % turn)
		near(j["hand_r"].distance_to(g[1]), 0.0, 0.06, "правая рука на ободе (поворот %s)" % turn)
		near(absf(j["elbow_l"].distance_to(j["shoulder_l"])), Crew.UPPER_ARM, 1e-3, "длина плеча")
	var g0 := Crew.wheel_grips(0.0)
	var g1 := Crew.wheel_grips(1.0)
	ok(g1[0].y > g0[0].y and g1[1].y < g0[1].y, "штурвал вправо: левая рука вверх, правая вниз")
	near(g0[0].distance_to(Vector3(0, BridgeProps.WHEEL_Y, BridgeProps.WHEEL_Z)), Crew.RIM, 1e-5, "хват на ободе")


func test_seated_in_chair() -> void:
	var m := Crew.Member.new()
	m.follow(0.0, Deck.SEAT_Z, 0.0, true, 0.0, 0.1)
	var j := m.joints()
	near(j["head"].y, Deck.SEAT_EYE, 0.02, "голова на высоте глаз пилота")
	near(m.eye().z, Deck.SEAT_Z, 1e-6, "глаза — как у камеры пилота")
	var hip: Vector3 = j["hip"]
	ok(hip.y > 0.5 and hip.y < 0.7, "таз над сиденьем (%.2f)" % hip.y)
	ok(absf(hip.z - Deck.CHAIR_Z) < 0.35, "таз в кресле (z %.2f)" % hip.z)
	ok(j["knee_l"].z < hip.z - 0.3, "колени вперёд")
	ok(j["toe_l"].y > -0.01, "ноги не под полом")


func test_own_figure_hides_head() -> void:
	var m := Crew.Member.new()
	m.follow(0.0, -3.0, 0.0, false, 0.0, 0.1)
	var other := m.parts(false)
	var own := m.parts(true)
	eq(other.size(), Crew.ORDER.size(), "другие видят всю фигуру")
	ok(not own.has("head") and not own.has("visor"), "своя голова не рисуется")
	ok(not own.has("torso") and own.has("shin_l") and own.has("foot_r") and own.has("hand_l"),
		"стоя свои ноги и руки видны, грудь — нет")
	m.follow(0.0, Deck.SEAT_Z, 0.0, true, 0.0, 0.1)
	own = m.parts(true)
	ok(own.has("arm_l") and own.has("hand_r") and not own.has("head"), "в кресле видны руки на штурвале")


func test_snapshot_round_trip() -> void:
	var a := Crew.Member.new(Crew.Role.ENGINEER, "Вера")
	a.look = 1
	a.post = "energy"
	a.follow(0.0, 0.0, 0.3, false, 0.0, 1.0 / 30.0)
	for i in 7:
		a.follow(a.x, a.z - 0.08, 0.3, false, 0.0, 1.0 / 30.0)
	var b := Crew.Member.new()
	b.apply(a.snapshot())
	eq(b.role, Crew.Role.ENGINEER, "роль")
	eq(b.name, "Вера", "имя")
	eq(b.look, 1, "внешность")
	eq(b.post, "energy", "занятый пост — в снимке")
	var pa := a.parts()
	var pb := b.parts()
	for k in pa:
		ok(pa[k].is_equal_approx(pb[k]), "поза %s совпадает" % k)
	eq(Crew.part_color("torso", Crew.Role.ENGINEER), Crew.ROLE_COLORS[Crew.Role.ENGINEER], "цвет роли на груди")


func test_welding_arm_holds_torch() -> void:
	var m := Crew.Member.new(Crew.Role.ENGINEER)
	var s: Breach.Spot = Breach.spots()[0]
	var at := Vector2(s.p.x + 0.55, s.p.z)   # вплотную: дотянуться можно
	m.follow(at.x, at.y, atan2(s.n.x, s.n.z), false, 0.0, 0.1)
	var j0 := m.joints()
	var free_l: Vector3 = j0["hand_l"] - j0["shoulder_l"]
	ok(not m.welding(), "без сварки резака нет")
	m.weld(s.p, s.n)
	ok(m.welding(), "варит")
	var t := m.torch_xform()
	var nozzle := t * Crew.TORCH_NOZZLE
	near(nozzle.distance_to(s.p), Crew.TORCH_GAP, 0.02, "сопло у шва")
	ok((t.basis * Vector3.FORWARD).dot(-s.n) > 0.99, "сопло смотрит в борт")
	var jw := m.joints()
	ok((jw["hand_l"] - jw["shoulder_l"]).is_equal_approx(free_l), "левая рука как была")
	ok(m.crouch() > 0.1 and m.crouch() <= Crew.CROUCH_MAX, "шов на 1 м — присел (%.2f)" % m.crouch())
	near(jw["hip"].y, Crew.HIP - m.crouch(), 1e-4, "таз ниже")
	for k in ["l", "r"]:
		ok(jw["ankle_" + k].y > 0.0 and jw["ankle_" + k].y < 0.12, "присед: ступня %s на полу" % k)
		ok((jw["knee_" + k] - jw["hip_" + k]).dot(jw["fwd"]) > 0.1, "колено %s вперёд" % k)
	m.follow(s.at.x + 0.5, s.at.y, atan2(s.n.x, s.n.z), false, 0.0, 0.1)   # далеко — рука вытянута к шву
	var j := m.joints()
	near(j["shoulder_r"].distance_to(j["wrist_r"]), Crew.UPPER_ARM + Crew.FOREARM, 0.02, "рука вытянута")
	ok(m.torch_xform().origin.distance_to(s.p) < j["shoulder_r"].distance_to(s.p), "резак ближе к шву, чем плечо")
	var other := Crew.Member.new()
	other.apply(m.snapshot())
	ok(other.welding() and other.torch_xform().is_equal_approx(m.torch_xform()), "сварка — в снимке для сети")
	m.weld(Vector3.INF)
	other.apply(m.snapshot())
	ok(not other.welding(), "закончил — в снимке без резака")
	m.weld(s.p, s.n)
	m.follow(0.0, Deck.SEAT_Z, 0.0, true, 0.0, 0.1)
	ok(not m.welding(), "в кресле не варят")


func test_busy_posts() -> void:
	var me := Crew.Member.new(Crew.Role.PILOT)
	var sonar := Crew.Member.new(Crew.Role.SONAR)
	var crew := [me, sonar]
	eq(Crew.holder(crew, me, "helm"), null, "штурвал свободен")
	sonar.follow(0.0, Deck.SEAT_Z, 0.0, true, 0.0, 0.1)
	eq(Crew.holder(crew, me, "helm"), sonar, "другой сидит за штурвалом — занят")
	eq(Crew.busy_text("helm", sonar), "Штурвал занят: Сонарщик", "строка на приборах")
	eq(Crew.holder(crew, sonar, "helm"), null, "себе свой пост не занят")
	sonar.post = "energy"
	eq(Crew.holder(crew, me, "energy"), sonar, "пульт энергии держит другой")
	eq(Crew.holder(crew, me, "sonar"), null, "сонар — общий пост, не занимается")
	eq(Crew.holder([me], me, "helm"), null, "один на борту — всё свободно")
