extends TestCase
## Руки на постах (CrewHands): пульт энергии, голостол, рычаг разряда, вентиль, лебёдка, сканер, щиток;
## фигура тянется к точкам хвата, в снимке для сети руки передаются.


func _stand(x: float, z: float, yaw: float, g: Array[Vector3]) -> Dictionary:
	var m := Crew.Member.new()
	m.hold(g[0], g[1])
	m.follow(x, z, yaw, false, 0.0, 0.1)
	return m.joints()


func _hand(j: Dictionary, k: String) -> Vector3:
	return (j["wrist_" + k] + j["hand_" + k]) * 0.5


func test_energy_hand_on_selected_slider() -> void:
	var g := CrewHands.energy(0, 0.3)
	ok(g[0].x > -4.7 and g[0].x < -4.4 and g[0].y > 0.6 and g[0].y < 1.4, "ползунок двигателей на пульте: %s" % g[0])
	ok(g[0].z > g[1].z, "двигатели — левый для смотрящего паз (к корме, +z), левой рукой")
	var g4 := CrewHands.energy(4, 0.3)
	ok(g4[1].z < g4[0].z, "прожектор — правый паз, правой рукой")
	ok(CrewHands.energy(0, 1.0)[0].y > g[0].y + 0.3, "рука идёт за ползунком вверх")
	var j := _stand(-3.9, -2.0, PI / 2.0, g)
	ok(_hand(j, "l").distance_to(g[0]) < 0.06, "левая кисть на ползунке (%.3f)" % _hand(j, "l").distance_to(g[0]))
	ok(_hand(j, "r").distance_to(g[1]) < 0.06, "правая — на крае пульта")


func test_table_hands_face_player() -> void:
	var g := CrewHands.table(0.0, 0.4)
	for h in g:
		ok(h.z > BridgeProps.TABLE_Z + 0.9 and absf(h.y - CrewHands.TABLE_Y) < 1e-4, "ладонь на ближнем крае стола: %s" % h)
	ok(g[0].x < g[1].x, "лицом к носу: левая рука — к левому борту")
	var j := _stand(0.0, 0.4, 0.0, g)
	ok(_hand(j, "r").distance_to(g[1]) < 0.06, "дотянулся до края")


func test_lever_follows_angle() -> void:
	var up := CrewHands.lever(Zap.LEVER_UP)[1]
	var down := CrewHands.lever(Zap.LEVER_DOWN)[1]
	ok(up.y > Zap.LEVER_POS.y + 0.05 and down.y < Zap.LEVER_POS.y - 0.05, "набалдашник вверху и внизу")
	ok(up.x > Zap.LEVER_POS.x, "рукоять — в отсек")
	ok(not CrewHands.lever(0.0)[0].is_finite(), "левая рука свободна")
	var j := _stand(Zap.POST_AT.x, Zap.POST_AT.y, PI / 2.0, CrewHands.lever(Zap.LEVER_DOWN))
	ok(_hand(j, "r").distance_to(down) < 0.08, "правая на рычаге (%.3f)" % _hand(j, "r").distance_to(down))


func test_engine_room_and_hold_posts() -> void:
	var v := CrewHands.valve()
	ok(v[0].distance_to(EngineRoom.VALVE_WHEEL) < 0.25 and v[1].distance_to(EngineRoom.VALVE_WHEEL) < 0.25, "руки на колесе вентиля")
	var w := CrewHands.winch(-0.6, 22.2)
	for h in w:
		near(Vector2(h.x, h.z).distance_to(Vector2(Samples.BASE.x, Samples.BASE.z)), Samples.COLUMN_R + 0.04, 0.03, "на опоре лебёдки")
		ok(h.z < Samples.BASE.z, "со стороны игрока")
	var s := CrewHands.scanner()
	ok(s[0].z < s[1].z and s[0].x < BridgeProps.SCANNER_POS.x, "ладони на раме сканера")
	ok(not CrewHands.scram()[0].is_finite() and CrewHands.scram()[1].is_finite(), "щиток — правой рукой")


func test_free_hands_swing_and_snapshot() -> void:
	var m := Crew.Member.new()
	m.follow(0.0, 0.0, 0.0, false, 0.0, 0.1)
	var free_hand: Vector3 = m.joints()["hand_l"]
	m.hold(Vector3.INF, Vector3(0.3, 1.2, -0.5))
	ok(m.holding(), "держит правой")
	near(m.joints()["hand_l"].distance_to(free_hand), 0.0, 1e-5, "левая висит как раньше")
	var b := Crew.Member.new()
	b.apply(JSON.parse_string(JSON.stringify(m.snapshot())))
	ok(not b.hands[0].is_finite() and b.hands[1].is_equal_approx(m.hands[1]), "руки — в снимке через JSON")
	m.hold()
	b.apply(m.snapshot())
	ok(not b.holding(), "отпустил — и в снимке")


## Плавный наклон своего игрока: к посту не быстрее LEAN_RATE, глаз сдвигается вместе с головой.
func test_smooth_lean_and_eye() -> void:
	var m := Crew.Member.new()
	m.smooth_lean = true
	m.follow(0.0, 0.0, 0.0, false, 0.0, 0.1)
	m.hold(Vector3(-0.2, 0.9, -1.0), Vector3(0.2, 0.9, -1.0))
	var want := m.lean_target()
	ok(want > 0.3, "до стола надо наклониться (%.2f рад)" % want)
	eq(m.eye_offset(), Vector3.ZERO, "сразу не наклонился")
	m.ease_lean(0.05)
	near(m.lean, Crew.LEAN_RATE * 0.05, 1e-5, "наклон растёт плавно")
	for i in 20:
		m.ease_lean(0.05)
	near(m.lean, want, 1e-5, "дотянулся")
	var j := m.joints()
	var eye := m.eye() + m.eye_offset()
	ok(eye.distance_to(j["head"] + (j["fwd"] as Vector3) * 0.04) < 1e-4, "глаз в голове")
	ok(eye.z < -0.2 and eye.y < Deck.Walker.EYE, "глаз впереди и ниже")
	m.hold()
	for i in 20:
		m.ease_lean(0.05)
	eq(m.eye_offset(), Vector3.ZERO, "выпрямился")


## По issue #137: своя фигура стоя позади глаза (back) и с руками на посте — кисти всё равно в точках хвата.
func test_own_back_still_reaches_posts() -> void:
	var cases := [
		[Main.POWER_STAND, PI / 2.0, CrewHands.energy(0, 0.3)],
		[Vector2(0.0, 0.4), 0.0, CrewHands.table(0.0, 0.4)],
		[Main.ZAP_STAND, PI / 2.0, CrewHands.lever(Zap.LEVER_DOWN)],
		[Main.ZAP_STAND, PI / 2.0, CrewHands.lever(Zap.LEVER_UP)],
		[EngineRoom.VALVE_POST, PI / 2.0, CrewHands.valve()],
		[Main.SCRAM_STAND, -PI / 2.0, CrewHands.scram()],
	]
	for c in cases:
		var m := Crew.Member.new()
		m.back = CrewView.OWN_BACK
		var g: Array[Vector3] = c[2]
		m.hold(g[0], g[1])
		m.follow(c[0].x, c[0].y, c[1], false, 0.0, 0.1)
		ok(m.lean_target() < Crew.LEAN_MAX, "%s: наклон %.2f рад" % [c[0], m.lean_target()])
		var j := m.joints()
		for side in 2:
			if g[side].is_finite():
				var d := _hand(j, "l" if side == 0 else "r").distance_to(g[side])
				ok(d < 0.08, "%s: кисть на хвате (%.3f м)" % [c[0], d])
		var eye := m.eye() + m.eye_offset()
		near((eye - j["head"]).dot(j["fwd"]), 0.04 + CrewView.OWN_BACK, 1e-4, "%s: голова позади глаза" % c[0])


func test_press_lets_go_when_walked_away() -> void:   # issue #349
	var at := Vector2(0.9, 0.0)
	ok(CrewHands.pressing(0.5, at, at), "нажал и стоит — руки на посте")
	ok(CrewHands.pressing(0.5, at, at + Vector2(0.3, 0.0)), "шагнул у стола — держит")
	ok(not CrewHands.pressing(0.5, at, Vector2(0.0, -3.0)), "ушёл к окну — отпустил")
	ok(not CrewHands.pressing(0.0, at, at), "время вышло — отпустил")
