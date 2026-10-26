extends TestCase
## Существа не проходят сквозь корабль (S.pushOut, S.hullDist в js/ship.js): форма — HullPlan потока А, EcoHull
## выталкивает наружу с запасом, светляки и серпохвосты им пользуются, серпохвост кусает, дотянувшись до корпуса.

const SHIP := Vector3(30, -20, -40)
const YAW := 0.7


## Сетка точек вокруг корпуса в осях корабля (шаг 1,5 м).
func _grid() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var x := -9.0
	while x <= 9.0:
		var y := -3.0
		while y <= 6.5:
			var z := -14.0
			while z <= 32.0:
				out.append(Vector3(x, y, z))
				z += 1.5
			y += 1.5
		x += 1.5
	return out


func _world_point(l: Vector3) -> Vector3:
	return l.rotated(Vector3.UP, YAW) + SHIP


# ---------- Форма ----------

func test_zero_gap_matches_hull_plan() -> void:
	var inside := 0
	for l in _grid():
		var p := _world_point(l)
		var want := HullPlan.inside_world(p, SHIP, YAW)
		if want:
			inside += 1
		if EcoHull.touches(p, SHIP, YAW) != want:
			ok(false, "без запаса — та же форма, что HullPlan.inside: %s" % l)
			return
	ok(inside > 200, "сетка задевает корпус (%d точек внутри)" % inside)


func test_gap_grows_hull() -> void:
	# борт корпуса на мостике: x = 6,4; нос — срез на z = −7,2 перед капсулой до −7
	ok(not EcoHull.touches(_world_point(Vector3(6.8, 1.6, 2)), SHIP, YAW), "в 0,4 м от борта — снаружи")
	ok(EcoHull.touches(_world_point(Vector3(6.8, 1.6, 2)), SHIP, YAW, 0.7), "с запасом 0,7 — у корпуса")
	ok(EcoHull.touches(_world_point(Vector3(0, 1.6, 30)), SHIP, YAW, 1.2), "за кормой в метре — дотянулся")
	ok(not EcoHull.touches(_world_point(Vector3(0, 1.6, 40)), SHIP, YAW, 1.2), "в 11 м за кормой — нет")
	ok(not EcoHull.touches(SHIP + Vector3(100, 0, 0), SHIP, YAW, 5.0), "далеко — нет")


func test_push_out_every_inside_point() -> void:
	var gap := 0.7
	var moved := 0
	for l in _grid():
		var p := _world_point(l)
		var res := EcoHull.push_out(p, SHIP, YAW, gap)
		if res.is_empty():
			ok(not EcoHull.touches(p, SHIP, YAW, gap), "не тронута — значит снаружи: %s" % l)
			continue
		moved += 1
		var q: Vector3 = res[0]
		var n: Vector3 = res[1]
		if EcoHull.touches(q, SHIP, YAW, gap) or HullPlan.inside_world(q, SHIP, YAW):
			ok(false, "после выталкивания снаружи с запасом: %s → %s" % [l, EcoHull.to_ship(q, SHIP, YAW)])
			return
		near(n.length(), 1.0, 1e-4, "нормаль единичная")
		ok(p.distance_to(q) < 7.5, "к ближней стенке, не насквозь: %s сдвинута на %.1f м" % [l, p.distance_to(q)])
	ok(moved > 200, "внутри было %d точек" % moved)


func test_push_goes_to_near_side() -> void:
	# чуть внутри правого борта — наружу вправо; чуть под днищем — вниз; у кормы — назад
	var q: Vector3 = EcoHull.push_local(Vector3(6.0, 1.6, 10), 0.3)[0]
	ok(q.x > 6.6 and absf(q.z - 10) < 0.5, "правый борт: %s" % q)
	q = EcoHull.push_local(Vector3(0, -1.2, 10), 0.3)[0]
	ok(q.y < -1.6 and absf(q.x) < 0.5, "днище: %s" % q)
	q = EcoHull.push_local(Vector3(0, 1.6, 28.8), 0.3)[0]
	ok(q.z > 28.8, "корма: %s" % q)
	ok(EcoHull.push_local(Vector3(0, 1.6, 60), 0.3).is_empty(), "далеко — пусто")


func test_agent_loses_velocity_into_hull() -> void:
	var w := EcoWorld.new()
	w.ship.pos = SHIP
	w.ship.yaw = YAW
	var a := w.spawn("fish", _world_point(Vector3(6.2, 1.6, 10)))
	var into := Vector3(-3, 0, 0).rotated(Vector3.UP, YAW)
	a.v = into + Vector3(0, 0, 0)
	ok(w.push_out(a, 0.3), "был внутри")
	ok(not w.touches_ship(a.p, 0.3), "теперь снаружи")
	ok(a.v.dot(into) < 0.3, "скорость внутрь погашена: %s" % a.v)
	ok(not w.push_out(a, 0.3), "второй раз — уже снаружи")


# ---------- Существа ----------

static func _deep(_x: float, _z: float) -> float:
	return -200.0


## Корабль стоит на доме первой стаи: рыбки обтекают корпус и ни на шаге не оказываются внутри.
func test_fish_never_inside_hull() -> void:
	var w := EcoWorld.new()
	w.ground = _deep
	w.ship.pos = Vector3(500, 0, 500)
	var fish := w.add(EcoFish.new()) as EcoFish
	var sh := fish.shoals[0]
	w.ship.pos = sh.home + Vector3(0, -1.6, -9)  # центр корпуса — на доме стаи
	w.ship.yaw = 0.3
	var worst := 0
	for i in 200:
		w.step(EcoWorld.MAX_STEP)
		var n := 0
		for f: EcoFish.Fish in sh.members:
			if f.agent.alive and HullPlan.inside_world(f.agent.p, w.ship.pos, w.ship.yaw):
				n += 1
		worst = maxi(worst, n)
	eq(worst, 0, "ни одной рыбки внутри корпуса")
	ok(_mean_dist(sh, w.ship.pos + Vector3(0, 1.6, 9).rotated(Vector3.UP, 0.3)) < 30.0, "стая держится рядом, у корпуса")


func _mean_dist(sh: EcoFish.Shoal, p: Vector3) -> float:
	var s := 0.0
	for f: EcoFish.Fish in sh.members:
		s += f.agent.p.distance_to(p)
	return s / sh.members.size()


## Бросок с кормы: серпохвост упирается в корпус, а не проходит к мостику насквозь, и кусает корпус.
func test_pred_bites_stern_not_through() -> void:
	var w := EcoWorld.new()
	w.ground = _deep
	w.ship.pos = Vector3(500, 0, 500)
	var preds := w.add(EcoPred.new()) as EcoPred
	var pr := preds.all[0]
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.pos = pr.agent.p + Vector3(0, -1.6, -36)  # хищник в 7 м за кормой, на оси корабля
	preds._start_charge(w, pr)
	var bit := false
	for i in 200:
		w.step(EcoWorld.MAX_STEP)
		ok(not HullPlan.inside_world(pr.agent.p, w.ship.pos, w.ship.yaw) or bit, "не внутри корпуса")
		if w.hits > 0:
			bit = true
			break
	ok(bit, "укусил корпус")
	ok(pr.agent.p.distance_to(w.ship.pos) > 20.0, "укусил у кормы, а не у мостика")
	eq(pr.mode, EcoPred.Mode.RETREAT, "после укуса уходит")


# ---------- Цена ----------

## Рыбка, заплывшая в корпус, стоила ~0,25 мс на ПК: семь путей наружу делились пополам по 14 раз, а каждая
## проверка детали заново считала синусы её поворотов (issue #653 — всплески шага мира, когда стая у корабля).
## Теперь пути сравниваются грубо и точно досчитывается только лучший: проверок на точку — меньше 85 (было 115).
func test_push_out_checks_few_parts() -> void:
	var n := 0
	var before := EcoHull.checks
	for l in _grid():
		if not EcoHull.push_local(l, 0.7).is_empty():
			n += 1
	var per := float(EcoHull.checks - before) / n
	ok(n > 200, "внутри было %d точек" % n)
	ok(per < 85.0, "проверок деталей на точку внутри: %.1f" % per)


## Детали с готовой матрицей — та же форма, что HullPlan.Part.contains (повороты и размер собраны верно).
func test_shape_matches_part() -> void:
	for r in [0.0, 0.7]:
		var list := EcoHull.shapes(r)
		for l in _grid():
			for d in [Vector3.ZERO, Vector3(0.37, 0.21, 0.53)]:
				var p: Vector3 = l + d
				var want := false
				for part: HullPlan.Part in EcoHull.parts(r):
					want = want or part.contains(p)
				var sh := EcoHull._shape_at(p, list)
				if (sh != null) != want or (sh != null and not sh.part.contains(p)):
					ok(false, "запас %.1f: %s" % [r, p])
					return
	ok(true)
