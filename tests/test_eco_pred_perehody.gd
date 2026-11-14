extends TestCase
## Переходы серпохвоста ANIM-005 в игре (#1753, #1766): взвод Coil в начале броска, отход Recoil после удара серпом,
## замер Hover плавно поверх плавания, изгиб BendL/BendR по крену тела.

const FAR := Vector3(1e6, 0, 1e6)


func _flat(_x: float, _z: float) -> float:
	return 0.0


func _pred() -> EcoPred.Pred:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var p := w.add(EcoPred.new()) as EcoPred
	return p.all[0]


## Взвод — раз в начале броска (не при первом взгляде на зверя и не вдали).
func test_coil_once_when_charge_starts() -> void:
	var pr := _pred()
	var c := EcoPredLook.Cues.new()
	var ship := pr.agent.p + Vector3(30, 0, 0)
	pr.mode = EcoPred.Mode.CHARGE
	ok(not c.update(pr, ship, 1.0)["coil"], "первый взгляд на зверя в броске — без взвода")
	pr.mode = EcoPred.Mode.ALERT
	ok(not c.update(pr, ship, 2.0)["coil"], "замер — без взвода")
	pr.mode = EcoPred.Mode.CHARGE
	ok(c.update(pr, ship, 2.1)["coil"], "бросок начался — взвод")
	ok(not c.update(pr, ship, 2.2)["coil"], "раз за бросок")
	pr.mode = EcoPred.Mode.RETREAT
	c.update(pr, ship, 3.0)
	pr.mode = EcoPred.Mode.CHARGE
	ok(not c.update(pr, ship, 3.1, true)["coil"], "вдали — без взвода")


## Отход — раз на укус корпуса, когда удар серпом начал гаснуть; старый укус не отыгрывает.
func test_recoil_after_strike() -> void:
	var pr := _pred()
	var c := EcoPredLook.Cues.new()
	var ship := pr.agent.p + Vector3(9, 0, 0)
	pr.mode = EcoPred.Mode.RETREAT
	ok(EcoPredLook.RECOIL_AT > 0.0 and EcoPredLook.RECOIL_AT < EcoPredLook.STRIKE_TIME,
			"отход — пока удар ещё гаснет: %.2f с" % EcoPredLook.RECOIL_AT)
	pr.bit_at = 10.0
	var cue := c.update(pr, ship, 10.0)
	ok(cue["strike"] and not cue["recoil"], "сначала удар серпом")
	ok(not c.update(pr, ship, 10.0 + EcoPredLook.RECOIL_AT - 0.02)["recoil"], "до конца удара — без отхода")
	ok(c.update(pr, ship, 10.0 + EcoPredLook.RECOIL_AT + 0.02)["recoil"], "удар гаснет — отход")
	ok(not c.update(pr, ship, 10.0 + EcoPredLook.RECOIL_AT + 0.1)["recoil"], "раз на укус")
	pr.bit_at = 20.0
	ok(not c.update(pr, ship, 20.0 + EcoPredLook.RECOIL_AT + EcoPredLook.RECOIL_TIME)["recoil"],
			"укус давно — отход не догоняет")
	pr.bit_at = 30.0
	ok(not c.update(pr, ship, 30.0 + EcoPredLook.RECOIL_AT + 0.02, true)["recoil"], "вдали — без отхода")


## Замер: вес Hover растёт и гаснет не быстрее, чем за HOVER_IN, — поза не скачет.
func test_hover_weight_is_gradual() -> void:
	var pr := _pred()
	var c := EcoPredLook.Cues.new()
	var ship := pr.agent.p + Vector3(30, 0, 0)
	pr.mode = EcoPred.Mode.PATROL
	c.update(pr, ship, 0.0)
	eq(c.hover, 0.0, "в патруле — без замера")
	pr.mode = EcoPred.Mode.ALERT
	var t := 0.0
	var worst := 0.0
	var prev := c.hover
	while t < EcoPredLook.HOVER_IN - 0.06:
		t += 0.05
		c.update(pr, ship, t)
		worst = maxf(worst, c.hover - prev)
		prev = c.hover
	ok(c.hover > 0.5 and c.hover < 1.0, "набирает постепенно: %.2f" % c.hover)
	ok(worst <= 1.5 * 0.05 / EcoPredLook.HOVER_IN + 1e-5, "за шаг не больше smoothstep 1,5 · 0,05/HOVER_IN: %.3f" % worst)
	for i in 4:
		t += 0.05
		c.update(pr, ship, t)
	near(c.hover, 1.0, 1e-6, "за HOVER_IN — весь замер")
	pr.mode = EcoPred.Mode.CHARGE
	t += 0.05
	c.update(pr, ship, t)
	ok(c.hover > 0.85, "бросок — замер гаснет плавно, не разом: %.2f" % c.hover)
	for i in 20:
		t += 0.05
		c.update(pr, ship, t)
	eq(c.hover, 0.0, "и гаснет весь")


## Изгиб по крену: влево (крен > 0) — BendL, вправо — BendR, не больше BEND_W.
func test_bend_follows_bank() -> void:
	var pr := _pred()
	pr.bank = 0.0
	eq(EcoPredLook.bend(pr), 0.0, "прямо — без изгиба")
	pr.bank = EcoPred.BANK_MAX * 0.5
	near(EcoPredLook.bend(pr), EcoPredLook.BEND_W * 0.5, 1e-6, "влево — половина")
	pr.bank = -EcoPred.BANK_MAX * 2.0
	near(EcoPredLook.bend(pr), -EcoPredLook.BEND_W, 1e-6, "вправо — не больше BEND_W")
	ok(EcoPredLook.BEND_W < 1.0, "хвост и в повороте машет")
	# в сцене вес догоняет крен ещё одним сглаживанием: крен разом — изгиб не разом
	var c := EcoPredLook.Cues.new()
	var ship := pr.agent.p + Vector3(30, 0, 0)
	pr.bank = 0.0
	c.update(pr, ship, 0.0)
	pr.bank = EcoPred.BANK_MAX
	c.update(pr, ship, 0.05)
	ok(c.bend > 0.0 and c.bend < EcoPredLook.BEND_W * 0.2, "крен разом — изгиб растёт плавно: %.3f" % c.bend)
	for i in 60:
		c.update(pr, ship, 0.1 + i * 0.05)
	near(c.bend, EcoPredLook.BEND_W, 0.01, "и догоняет")


## Кончик хвоста (Tail03) в осях скелета зверя i.
func _tip(pv: PredView, i: int) -> Vector3:
	var sk: Skeleton3D = pv.bodies[i].find_children("*", "Skeleton3D", true, false)[0]
	return sk.get_bone_global_pose(sk.find_bone("Tail03")).origin


## Сцена: дерево анимации играет переходы — взвод, отход, замер тише плавания, изгиб в сторону поворота.
func test_view_plays_transitions() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var pv := view.pred_view
	var pr := view.preds.all[1]
	var at := pv.trees[1]
	var ship := pr.agent.p + Vector3(30, 0, 0)
	var t := [100.0]
	var go := func(sec: float) -> void:
		var n := int(round(sec / 0.05))
		for k in n:
			t[0] += 0.05
			pv.sync(t[0], ship)
	pr.bit_at = -99.0
	pr.bank = 0.0
	pr.mode = EcoPred.Mode.PATROL
	pr.agent.v = Vector3(0, 0, EcoPred.PATROL_SPEED)
	go.call(0.5)
	ok(not at.get(PredView.P_COIL_ON), "в патруле взвода нет")
	# плавание: размах кончика хвоста вбок за цикл
	var swim := _sway(pv, go)
	# замер: вес растёт, хвост почти стоит
	pr.mode = EcoPred.Mode.ALERT
	pr.agent.v = Vector3(0, 0, EcoPred.ALERT_SPEED)
	go.call(EcoPredLook.HOVER_IN + 0.1)
	near(at.get(PredView.P_HOVER), 1.0, 1e-6, "замер — Hover во весь вес")
	var hover := _sway(pv, go)
	ok(hover < swim * 0.5, "в замере хвост тише плавания: %.2f м против %.2f" % [hover, swim])
	# бросок — взвод
	pr.mode = EcoPred.Mode.CHARGE
	pr.agent.v = Vector3(0, 0, EcoPred.CHARGE_SPEED)
	go.call(0.05)
	ok(at.get(PredView.P_COIL_ON), "бросок начался — взвод Coil")
	# укус корпуса — удар, потом отход
	pr.mode = EcoPred.Mode.RETREAT
	pr.bit_at = t[0] + 0.05
	go.call(0.05)
	ok(at.get(PredView.P_STRIKE_ON), "удар серпом")
	ok(not at.get(PredView.P_RECOIL_ON), "отход — после удара")
	go.call(EcoPredLook.RECOIL_AT + 0.05)
	ok(at.get(PredView.P_RECOIL_ON), "удар гаснет — отход Recoil")
	go.call(EcoPredLook.RECOIL_TIME + 0.4)
	ok(not at.get(PredView.P_RECOIL_ON), "отход кончился")
	# изгиб: средняя точка кончика хвоста за цикл сдвигается в разные стороны при повороте влево и вправо
	pr.mode = EcoPred.Mode.PATROL
	pr.agent.v = Vector3(0, 0, EcoPred.PATROL_SPEED)
	pr.bank = 0.0
	go.call(0.5)
	var mid := _mean_x(pv, go)
	pr.bank = EcoPred.BANK_MAX
	go.call(2.5)
	near(at.get(PredView.P_BEND_L), EcoPredLook.BEND_W, 0.01, "влево — BendL")
	var left := _mean_x(pv, go)
	pr.bank = -EcoPred.BANK_MAX
	go.call(2.5)
	near(at.get(PredView.P_BEND_R), EcoPredLook.BEND_W, 0.01, "вправо — BendR")
	eq(at.get(PredView.P_BEND_L), 0.0, "и без BendL")
	var right := _mean_x(pv, go)
	print("    хвост, средний x: прямо %.2f, влево %.2f, вправо %.2f м" % [mid, left, right])
	ok(left < mid - 0.2 and right > mid + 0.2, "хвост дугой в сторону поворота: влево к −X, вправо к +X")
	view.queue_free()
	await frames(1)


## Размах кончика хвоста вбок (м) за цикл Swim.
func _sway(pv: PredView, go: Callable) -> float:
	var lo := 1e9
	var hi := -1e9
	for k in 48:
		go.call(0.05)
		var x := _tip(pv, 1).x
		lo = minf(lo, x)
		hi = maxf(hi, x)
	return hi - lo


## Средний x кончика хвоста за цикл Swim.
func _mean_x(pv: PredView, go: Callable) -> float:
	var s := 0.0
	for k in 48:
		go.call(0.05)
		s += _tip(pv, 1).x
	return s / 48.0
