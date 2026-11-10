extends TestCase
## Ледокрылы (initRays/rayUpdate в js/creatures.js, Snd.song в js/soundscape.js): два ската на кругах подо льдом,
## над кораблём проходят поверху, водят стаи светляков, поют; цели сонара; один MultiMesh в сцене.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world(with_fish := false) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f: EcoFish = null
	if with_fish:
		f = w.add(EcoFish.new()) as EcoFish
	w.add(EcoRay.new(f))
	return w


func _rays(w: EcoWorld) -> EcoRay:
	for s in w.systems:
		if s is EcoRay:
			return s
	return null


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


# ---------- Круги и глубина ----------

func test_two_rays_on_their_circles() -> void:
	var w := _world()
	var r := _rays(w)
	eq(r.rays.size(), 2, "два ската")
	w.run(20.0)
	for ry in r.rays:
		var c: Vector3 = EcoRay.PATHS[ry.index]["c"]
		var R: float = EcoRay.PATHS[ry.index]["r"]
		near(Vector2(ry.p.x - c.x, ry.p.z - c.z).length(), R, 1e-3, "на своём круге")
		ok(ry.p.y <= EcoRay.TOP_Y + 1e-4, "не выше −5,5 м — подо льдом")
		ok(ry.p.y >= FLAT + EcoRay.ABOVE_FLOOR - 1e-3, "не ниже 7 м над дном")
		near(ry.dir.length(), 1.0, 1e-5, "курс — единичный")
		var tangent := Vector3(-(ry.p.z - c.z), 0, ry.p.x - c.x).normalized()
		near(ry.dir.dot(tangent), 1.0, 1e-4, "плывёт по касательной")


func test_speed_along_circle() -> void:
	var w := _world()
	var r := _rays(w)
	var a0 := r.rays[0].ang
	w.run(10.0)
	near((r.rays[0].ang - a0) * EcoRay.PATHS[0]["r"], EcoRay.PATHS[0]["sp"] * 10.0, 1e-3, "4,2 м/с по кругу")


## Б3, «плавность поведения»: скат на круге ложится на внутреннее крыло — крыло к центру круга ниже внешнего. Раньше
## крен был постоянный rotateZ(−0,22) браузера и опускал внешнее крыло: скат «падал» из поворота наружу. Тесный круг
## (35 м) — крен круче, чем на широком (85 м); оба не круче BANK_MAX.
func test_banks_into_turn() -> void:
	var w := _world()
	var r := _rays(w)
	w.run(7.0)
	var banks: Array[float] = []
	for ry in r.rays:
		var c: Vector3 = EcoRay.PATHS[ry.index]["c"]
		var x := EcoRay.xform(ry)
		var tip_l := x * Vector3(7.0, 0, 0)    # +X меша — левое крыло
		var tip_r := x * Vector3(-7.0, 0, 0)
		var to_c := Vector2(c.x - ry.p.x, c.z - ry.p.z)
		var inner := tip_l if Vector2(tip_l.x - ry.p.x, tip_l.z - ry.p.z).dot(to_c) > 0.0 else tip_r
		var outer := tip_r if inner == tip_l else tip_l
		ok(inner.y < outer.y - 0.5, "скат %d: крыло к центру круга ниже (%.2f против %.2f)" % [ry.index, inner.y, outer.y])
		ok(EcoRay.turn_rate(ry) < 0.0, "по кругу курс уходит вправо")
		ok(EcoRay.bank(ry) < 0.0, "крен на правое крыло — в поворот")
		ok(absf(EcoRay.bank(ry)) <= EcoRay.BANK_MAX + 1e-6, "не круче BANK_MAX")
		banks.append(absf(EcoRay.bank(ry)))
	ok(banks[1] > banks[0] * 1.4, "тесный круг — крен круче: %.2f против %.2f" % [banks[1], banks[0]])


func test_high_floor_lifts_ray() -> void:
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float: return -14.0
	w.ship.pos = FAR
	var r := w.add(EcoRay.new()) as EcoRay
	w.run(3.0)
	for ry in r.rays:
		ok(ry.p.y > -14.0 + EcoRay.ABOVE_FLOOR - 0.3, "над мелким дном держится на 7 м")
		ok(ry.p.y <= EcoRay.TOP_Y + 1e-4)


func test_reset_same_seed_same_path() -> void:
	var a := _world()
	var b := _world()
	a.run(7.0)
	b.run(7.0)
	eq(_rays(a).rays[1].p, _rays(b).rays[1].p, "детерминированно")
	a.reset()
	b.reset()
	eq(_rays(a).rays[0].ang, _rays(b).rays[0].ang)


# ---------- Корабль на пути ----------

func test_passes_over_ship_without_touching_hull() -> void:
	var w := _world()
	var r := _rays(w)
	var ry := r.rays[0]
	# корабль ставим на круг ската чуть впереди него, на глубине его пути
	var ahead := ry.ang + 6.0 / ry.radius
	w.ship.pos = Vector3(ry.center.x + cos(ahead) * ry.radius, -16.0, ry.center.z + sin(ahead) * ry.radius)
	w.ship.yaw = 0.7
	var was_over := false
	for i in 200:
		w.step(0.05)
		was_over = was_over or ry.over
		ok(not EcoHull.touches(ry.p, w.ship.pos, w.ship.yaw, 0.5), "тело не в корпусе (шаг %d)" % i)
	ok(was_over, "скат шёл над кораблём")


func test_over_ship_rises_above() -> void:
	var w := _world()
	var ry := _rays(w).rays[0]
	var at := ry.ang + 0.5 * 3.0 / ry.radius
	w.ship.pos = Vector3(ry.center.x + cos(at) * ry.radius, -20.0, ry.center.z + sin(at) * ry.radius)
	w.run(3.0)
	ok(ry.over, "над кораблём")
	ok(ry.p.y > w.ship.pos.y + EcoRay.SHIP_TOP + EcoRay.OVER - 1.0, "поднялся над корпусом: %.2f" % ry.p.y)


## Б3, плавность: над кораблём скат взмывает носом вверх и плавно выравнивается, а не всплывает «лифтом».
func test_climbs_nose_up_over_ship_smoothly() -> void:
	var w := _world()
	var ry := _rays(w).rays[0]
	var at := ry.ang + 6.0 / ry.radius
	w.ship.pos = Vector3(ry.center.x + cos(at) * ry.radius, -10.0, ry.center.z + sin(at) * ry.radius)
	var top := 0.0
	var prev := ry.pitch
	var dt := 0.05
	for i in 80:
		w.step(dt)
		top = maxf(top, ry.pitch)
		ok(absf(ry.pitch - prev) <= EcoRay.PITCH_MAX * 2.0 * EcoRay.PITCH_FOLLOW * dt + 1e-5,
			"тангаж меняется плавно (шаг %d)" % i)
		ok(absf(ry.pitch) <= EcoRay.PITCH_MAX + 1e-5, "не круче 20°")
		prev = ry.pitch
	ok(top > deg_to_rad(10.0), "взмыл над кораблём носом вверх: %.1f°" % rad_to_deg(top))
	var nose := EcoRay.xform(ry).basis.z.normalized()
	near(nose.y, sin(ry.pitch), 1e-4, "нос меша — по тангажу")
	near(Vector2(nose.x, nose.z).normalized().dot(Vector2(ry.dir.x, ry.dir.z)), 1.0, 1e-4, "и по курсу")


## Б3, плавность: корабль у самого льда (дно близко — под килем не пройти) — скат поднимается над ним ходом не больше CLIMB_MAX (раньше lerp 3/с срывал
## его вверх до 21 м/с за кадр), к высоте подходит без рывка и корпус не задевает.
func test_climb_over_ship_near_ice_without_jerk() -> void:
	for ship_y in [-8.0, -10.0]:
		var w := _world()
		w.ground = func(_x: float, _z: float) -> float: return -17.0   # под килем места нет — только поверху
		var ry := _rays(w).rays[0]
		var at := ry.ang + 25.0 / ry.radius
		w.ship.pos = Vector3(ry.center.x + cos(at) * ry.radius, ship_y, ry.center.z + sin(at) * ry.radius)
		var dt := 1.0 / 30.0
		var prev := ry.p
		var prev_vy := 0.0
		var top := ry.p.y
		var was_over := false
		var limit := Vector2(ry.speed, EcoRay.CLIMB_MAX).length() + 0.2
		for i in 400:
			w.step(dt)
			var v := (ry.p - prev) / dt
			ok(v.length() <= limit, "корабль на %.0f м, шаг %d: ход %.1f м/с" % [ship_y, i, v.length()])
			# + 0,7 м/с: у самого льда обшивка (push_out) держит ската на сантиметр выше нужной высоты — дрожь в 1 см
			ok(absf(v.y - prev_vy) <= EcoRay.CLIMB_ACCEL * dt + 0.7, "вертикальный ход без рывка (шаг %d): %.2f → %.2f, y %.2f, over %s" % [i, prev_vy, v.y, ry.p.y, ry.over])
			ok(not EcoHull.touches(ry.p, w.ship.pos, w.ship.yaw, 0.5), "тело не в корпусе (шаг %d)" % i)
			was_over = was_over or ry.over
			top = maxf(top, ry.p.y)
			prev_vy = v.y
			prev = ry.p
		ok(was_over, "шёл над кораблём (%.0f м)" % ship_y)
		ok(top >= minf(EcoRay.CEIL_Y, ship_y + EcoRay.SHIP_TOP + EcoRay.OVER) - 0.3,
			"поднялся над корпусом: %.2f" % top)


## Корабль идёт навстречу ходом 3 м/с из 40 м впереди ската (yaw — курс корабля). Возвращает худшее ускорение тела
## (м/с², по трём точкам пути после 10-го шага) и было ли касание корпуса.
func _head_on(yaw: float, ship_y: float) -> Dictionary:
	var w := _world()
	var ry := _rays(w).rays[0]
	var at := ry.ang + 40.0 / ry.radius
	var c := Vector3(ry.center.x + cos(at) * ry.radius, ship_y, ry.center.z + sin(at) * ry.radius)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	w.ship.yaw = yaw
	w.ship.speed = 3.0
	w.ship.pos = c - fwd * 40.0
	var dt := 1.0 / 30.0
	var prev := ry.p
	var prev_v := Vector3.ZERO
	var worst := 0.0
	var touched := false
	var under := false
	for i in 400:
		w.ship.pos += fwd * w.ship.speed * dt
		w.step(dt)
		var v := (ry.p - prev) / dt
		if i > 10:
			worst = maxf(worst, (v - prev_v).length() / dt)
		touched = touched or EcoHull.touches(ry.p, w.ship.pos, w.ship.yaw, 0.5)
		under = under or ry.under
		prev_v = v
		prev = ry.p
	return {"a": worst, "touch": touched, "under": under}


## Б3, плавность: корабль идёт навстречу — скат видит его за LOOK вперёд и уходит с пути заранее; обшивка его не
## сдвигает. Раньше скат замечал корпус только под крылом, не успевал подняться, и push_out двигал тело до метра за
## кадр (ускорение 881 м/с² при курсе 7/8 оборота; снизу — 114…138 м/с²: скат тёрся под днищем и выскакивал у носа).
func test_ship_head_on_without_jerk() -> void:
	for c in [[7.0, -8.0], [3.0, -8.0], [3.0, -12.0], [0.0, -16.0], [5.0, -12.0]]:
		var r := _head_on(c[0] * TAU / 8.0, c[1])
		ok(r["a"] <= 40.0, "курс %d/8, корабль на %.0f м: ускорение тела %.1f м/с²" % [c[0], c[1], r["a"]])
		ok(not r["touch"], "курс %d/8, корабль на %.0f м: тело не в корпусе" % [c[0], c[1]])


## Скат ниже середины корпуса при встрече уходит под киль (OVER ниже низа), если над дном хватает места; у дна — поверху.
func test_passes_under_from_below() -> void:
	var r := _head_on(3.0 * TAU / 8.0, -8.0)
	ok(r["under"], "ниже корабля — проходит под килем")
	var w := _world()
	var ry := _rays(w).rays[0]
	ry.p.y = -12.0
	w.ship.pos = Vector3(ry.p.x, -8.0, ry.p.z)
	w.step(0.05)
	ok(ry.over and ry.under, "корпус над скатом — под киль")
	var low := EcoWorld.new()
	low.ground = func(_x: float, _z: float) -> float: return -18.0
	low.ship.pos = FAR
	low.add(EcoRay.new())
	var lr := _rays(low).rays[0]
	lr.p.y = -11.0
	low.ship.pos = Vector3(lr.p.x, -8.0, lr.p.z)
	low.step(0.05)
	ok(lr.over and not lr.under, "дно близко (под килем нет %.0f м) — поверху" % EcoRay.ABOVE_FLOOR)


## Корабль впереди по кругу ската — встреча видна заранее; корабль далеко в стороне — нет.
func test_foresees_ship_ahead() -> void:
	var w := _world()
	var ry := _rays(w).rays[0]
	var s := EcoLink.ShipState.new()
	s.pos = Vector3(ry.p.x, -10.0, ry.p.z) + ry.dir * 45.0   # впереди по ходу ската, носом к нему, ход 6 м/с
	var back := -ry.dir
	s.yaw = atan2(-back.x, -back.z)
	s.speed = 6.0
	ok(not EcoHull.touches(Vector3(ry.p.x, s.pos.y + 1.6, ry.p.z), s.pos, s.yaw, EcoRay.WING), "сейчас ещё не под крылом")
	ok(EcoRay.foresees(ry, s), "встреча за %.0f с видна заранее" % EcoRay.LOOK)
	s.speed = 0.0
	ok(not EcoRay.foresees(ry, s), "корабль стоит в 45 м — за %.0f с скат до него не дойдёт" % EcoRay.LOOK)
	var far := EcoLink.ShipState.new()
	far.pos = ry.p + Vector3(80, 0, 0)
	ok(not EcoRay.foresees(ry, far), "в 80 м в стороне — нет")


## Б3, плавность: взмывая над кораблём, скат машет сильнее и чаще, прошёл и опускается — планирует; доля размаха и
## частота меняются плавно, фаза не прыгает. Без этого крылья махали одинаково по TIME шейдера.
func test_flaps_harder_climbing_over_ship() -> void:
	var w := _world()
	var ry := _rays(w).rays[0]
	var at := ry.ang + 25.0 / ry.radius
	w.ship.pos = Vector3(ry.center.x + cos(at) * ry.radius, -10.0, ry.center.z + sin(at) * ry.radius)
	var dt := 1.0 / 30.0
	var top := 1.0
	var low := 1.0
	var prev_k := ry.flap_k
	var prev_ph := ry.flap
	var fast := 0.0
	for i in 900:
		w.step(dt)
		ok(absf(ry.flap_k - prev_k) <= (EcoRay.FLAP_HARD - EcoRay.FLAP_GLIDE) * EcoRay.FLAP_FOLLOW * dt + 1e-5,
			"размах меняется плавно (шаг %d): %.3f → %.3f" % [i, prev_k, ry.flap_k])
		var adv := fposmod(ry.flap - prev_ph, TAU)
		ok(adv >= EcoRay.FLAP_RATE * dt - 1e-5 and adv <= EcoRay.FLAP_RATE * EcoRay.FLAP_FAST * dt + 1e-5,
			"фаза идёт вперёд без скачка (шаг %d): %.4f" % [i, adv])
		fast = maxf(fast, adv / dt)
		top = maxf(top, ry.flap_k)
		low = minf(low, ry.flap_k)
		prev_k = ry.flap_k
		prev_ph = ry.flap
	ok(top > 1.3, "над кораблём машет сильнее: ×%.2f" % top)
	ok(fast > EcoRay.FLAP_RATE * 1.2, "и чаще: %.2f рад/с" % fast)
	ok(low < 0.9, "прошёл и опускается — планирует: ×%.2f" % low)


func test_flap_even_far_from_ship() -> void:
	var w := _world()
	w.run(30.0)
	for ry in _rays(w).rays:
		near(ry.flap_k, 1.0, 0.1, "корабль далеко — машет как обычно")
	eq(EcoRay.flap_want(0.0), 1.0, "ровно — обычный размах")
	near(EcoRay.flap_want(EcoRay.CLIMB_MAX * 2.0), EcoRay.FLAP_HARD, 1e-6, "вверх — не сильнее предела")
	near(EcoRay.flap_want(-EcoRay.CLIMB_MAX * 2.0), EcoRay.FLAP_GLIDE, 1e-6, "вниз — планирует")
	near(EcoRay.flap_rate(EcoRay.FLAP_GLIDE), EcoRay.FLAP_RATE, 1e-6, "планирует — частота обычная")
	near(EcoRay.flap_rate(EcoRay.FLAP_HARD), EcoRay.FLAP_RATE * EcoRay.FLAP_FAST, 1e-6, "сильный взмах — чаще")
	var w2 := _world()
	var r2 := _rays(w2)
	near(r2.rays[1].flap - r2.rays[0].flap, 1.0, 1e-6, "скаты машут вразнобой — сдвиг как номер ската")


func test_level_far_from_ship() -> void:
	var w := _world()
	var r := _rays(w)
	for ry in r.rays:
		eq(ry.pitch, 0.0, "в начале — ровно")
	w.run(30.0)
	for ry in r.rays:
		ok(absf(ry.pitch) < deg_to_rad(6.0), "на своей глубине почти ровно: %.1f°" % rad_to_deg(ry.pitch))
	near(EcoRay.pitch_for(1.0, 4.0), atan2(1.0, 4.0), 1e-6, "наклон пути")
	near(EcoRay.pitch_for(-50.0, 4.0), -EcoRay.PITCH_MAX, 1e-6, "вниз — не круче предела")


func test_far_ship_does_not_lift() -> void:
	var w := _world()
	w.run(5.0)
	for ry in _rays(w).rays:
		ok(not ry.over, "корабль далеко — скат на своей глубине")


# ---------- Ведёт стаю ----------

func test_leads_nearest_reef_shoal() -> void:
	var w := _world(true)
	var r := _rays(w)
	var fish := w.systems[0] as EcoFish
	var ry := r.rays[0]
	# скат — у стаи 4 (дом (56, 6)), зов сейчас
	var sh := fish.shoals[4]
	w.ship.pos = sh.home + Vector3(0, 0, 40)  # ближе MID: стая шагает каждый шаг мира, не по очереди дальних (issue #803)
	ry.center = Vector3(sh.center.x - 20.0, ry.center.y, sh.center.z)
	ry.radius = 20.0
	ry.ang = 0.0
	ry.lead_cd = 0.0
	w.step(0.05)
	ok(sh.leader() == ry, "стая пошла за скатом")
	near(sh.lead_t, EcoRay.LEAD_T, 1e-6, "на 18 с")
	eq(_notes(w, EcoRay.ID, "follow").size(), 1, "наблюдение «follow»")
	eq(_notes(w, EcoFish.ID, "follow").size(), 1, "и заметка светляков")
	# светляки шагают раньше скатов: цель — по месту ската до его шага
	var want := ry.p - ry.dir * EcoFish.LEAD_BEHIND + Vector3(0, -EcoFish.LEAD_BELOW, 0)
	w.step(0.05)
	near(sh.goal.distance_to(want), 0.0, 1e-3, "цель — в 12 м за скатом и на 3 м ниже")
	w.run(EcoRay.LEAD_T)
	ok(sh.leader() == null or sh.lead_t > 0.0, "через 18 с отпускает (или позвал снова)")


func test_shoal_follows_ray() -> void:
	var w := _world(true)
	var r := _rays(w)
	var fish := w.systems[0] as EcoFish
	var ry := r.rays[0]
	var sh := fish.shoals[4]
	ry.center = Vector3(sh.center.x - ry.radius, ry.center.y, sh.center.z)
	ry.ang = 0.0
	ry.lead_cd = 0.0
	w.step(0.05)
	ok(sh.leader() == ry)
	var home := sh.home
	w.run(15.0)
	var want := ry.p - ry.dir * EcoFish.LEAD_BEHIND
	ok(sh.center.distance_to(home) > 15.0, "стая ушла от дома: %.1f м" % sh.center.distance_to(home))
	var way := (sh.center - home).normalized().dot((want - home).normalized())
	ok(way > 0.7, "и уходит туда, куда скат: %.2f" % way)


func test_does_not_lead_far_crown_or_cage() -> void:
	var w := _world(true)
	var r := _rays(w)
	var fish := w.systems[0] as EcoFish
	for ry in r.rays:
		ry.center = Vector3(1000, -9, 1000)
		ry.lead_cd = 0.0
	w.step(0.05)
	for sh in fish.shoals:
		ok(sh.leader() == null, "стаи дальше 45 м не зовут")
	# скат у кроны цветка: стаи кроны не идут
	var crown := fish.shoals[EcoFish.HOMES.size()]
	var ry := r.rays[0]
	ry.center = crown.center + Vector3(-5, 0, 0)
	ry.radius = 5.0
	ry.ang = 0.0
	ry.lead_cd = 0.0
	w.step(0.05)
	ok(crown.leader() == null, "стая у кроны остаётся у кроны")


func test_lead_is_weak_and_overrides_goal() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var fish := w.add(EcoFish.new()) as EcoFish
	var sh := fish.shoals[0]
	var lead := EcoRay.Ray.new()
	lead.p = sh.center + Vector3(30, 0, 0)
	lead.dir = Vector3.RIGHT
	sh.follow(lead, 10.0)
	w.step(0.05)
	near(sh.goal.distance_to(lead.p - lead.dir * EcoFish.LEAD_BEHIND + Vector3(0, -EcoFish.LEAD_BELOW, 0)), 0.0, 1e-4,
		"за ведущим, а не к своей цели")
	lead = null
	w.step(0.05)
	ok(sh.leader() == null, "ведущего нет (слабая ссылка) — стая свободна")


# ---------- Песня ----------

func test_sings_to_near_ship_with_side() -> void:
	var w := _world()
	var r := _rays(w)
	var ry := r.rays[0]
	ry.speed = 0.0
	w.run(0.05)
	# корабль в 40 м от ската, нос на −Z (yaw 0): скат справа по +X
	w.ship.pos = ry.p - Vector3(40, 0, 0)
	w.ship.yaw = 0.0
	w.bus.pending.clear()
	w.run(EcoRay.SONG_FIRST)
	ok(not r.song.is_empty(), "спел")
	eq(r.phrase, 1)
	var notes: Array = r.song["notes"]
	ok(notes.size() >= 3 and notes.size() <= 5, "3–5 нот")
	ok(float(r.song["pan"]) > 0.3, "справа от корабля")
	var ev := _notes(w, EcoRay.ID, "song")
	eq(ev.size(), 1, "наблюдение «song»")
	ok(ev[0].text().contains("справа"), ev[0].text())
	ok(ev[0].pos.distance_to(w.ship.pos) < EcoBus.HEARING, "слышно с корабля")


func test_far_ship_hears_no_song() -> void:
	var w := _world()
	var r := _rays(w)
	w.run(30.0)
	ok(r.song.is_empty(), "дальше 160 м песни нет")
	eq(_notes(w, EcoRay.ID, "song").size(), 0)


func test_song_note_only_closer_110() -> void:
	var w := _world()
	var r := _rays(w)
	var ry := r.rays[1]
	ry.speed = 0.0
	w.run(0.05)
	w.ship.pos = ry.p + Vector3(0, 0, 130)
	r.rays[0].center = Vector3(2000, -9, 2000)
	w.bus.pending.clear()
	w.run(EcoRay.SONG_FIRST)
	ok(not r.song.is_empty(), "песню слышно за 130 м")
	eq(_notes(w, EcoRay.ID, "song").size(), 0, "но наблюдения нет — дальше 110 м")


# ---------- Цели ----------

func test_rays_are_scan_targets() -> void:
	var w := _world()
	var t := w.scan_targets()
	eq(t.size(), 2)
	for x in t:
		eq(x["species"], EcoRay.ID)
		near(float(x["r"]), EcoRay.TARGET_R, 1e-6)


func test_ray_does_not_shift_fish_without_lead() -> void:
	var a := EcoWorld.new()
	a.ground = Seabed.height
	var fa := a.add(EcoFish.new()) as EcoFish
	var ra := a.add(EcoRay.new(fa)) as EcoRay
	for ry in ra.rays:
		ry.lead_cd = 1e9
	var b := EcoWorld.new()
	b.ground = Seabed.height
	var fb := b.add(EcoFish.new()) as EcoFish
	a.run(5.0)
	b.run(5.0)
	eq(fa.shoals[3].center, fb.shoals[3].center, "свои числа случая — стаи те же")


# ---------- В сцене ----------

func test_view_one_multimesh() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var rv := view.ray_view
	ok(rv != null and rv.get_parent() == view, "ледокрылы — в живом мире")
	eq(rv.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(rv.multimesh.instance_count, 2, "оба ската — один MultiMesh")
	eq(rv.multimesh.mesh.get_surface_count(), 1, "один вызов отрисовки")
	ok(rv.tris < 600, "треугольников на ската: %d" % rv.tris)
	var ship := EcoLink.ShipState.new()
	ship.pos = FAR
	view.step(0.05, ship)
	var ry := view.rays.rays[1]
	var x := rv.placed[1]
	near(x.origin.distance_to(ry.p), 0.0, 1e-4, "скат на месте")
	near((x.basis.z.normalized()).dot(ry.dir), 1.0, 0.05, "нос по курсу")
	var span := 0.0
	for v in rv.verts:
		span = maxf(span, absf(v.x))
	near(span * 2.0, RayView.SPAN, 0.8, "размах около 14 м")
	view.queue_free()
	await frames(1)


## Взмах в шейдере — по фазе и доле размаха мира (INSTANCE_CUSTOM.y/z), а не по TIME; двойник — EcoRay.wing_lift.
func test_view_flap_from_world() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var rv := view.ray_view
	var ship := EcoLink.ShipState.new()
	ship.pos = FAR
	for i in 10:
		view.step(0.05, ship)
	for ry in view.rays.rays:
		var c := rv.customs[ry.index]
		near(c.r, RayView.breath(ry.index, view.world.time), 1e-6, "доля дыхания — по времени мира")
		near(c.a, RayView.tail_phase(view.world.time, ry.index), 1e-5, "фаза хлыста — по времени мира")
		ok(c.a >= 0.0 and c.a < TAU, "по модулю TAU — точность на долгом забеге")
		near(c.g, ry.flap, 1e-6, "фаза взмаха — с мира")
		near(c.b, ry.flap_k, 1e-6, "доля размаха — с мира")
	var code := (rv.multimesh.mesh.surface_get_material(0) as ShaderMaterial).shader.code
	ok(code.contains("float ph = INSTANCE_CUSTOM.y - ax * 0.32;"), "фаза — из экземпляра")
	ok(code.contains("float k = pow(ax / 7.0, 1.4) * 1.8 * INSTANCE_CUSTOM.z;"), "размах — из экземпляра")
	ok(not code.contains("TIME * 1.3"), "не по часам шейдера")
	near(EcoRay.wing_lift(0.0, 1.0, 1.0), 0.0, 1e-9, "середина не машет")
	near(EcoRay.wing_lift(7.0, 2.24 + PI * 0.5, 1.0), 1.8, 1e-5, "кончик крыла — на 1,8 м")
	near(EcoRay.wing_lift(7.0, 2.24 + PI * 0.5, EcoRay.FLAP_HARD), 1.8 * EcoRay.FLAP_HARD, 1e-5, "сильный взмах — выше")
	view.queue_free()
	await frames(1)


## Б3: ледокрыл дышит брызгальцами — горб спины поднимается и опадает (± BREATH_H), края крыльев и хвост стоят;
## у скатов свой ритм и фаза, по времени мира (у гостя то же), в шейдере — по INSTANCE_CUSTOM.x.
func test_view_hump_breathes() -> void:
	var rv := RayView.new(_rays(_world()))
	tree.root.add_child(rv)
	await frames(1)
	var lo := 1.0
	var hi := -1.0
	for i in 200:
		var k := RayView.breath(0, i * 0.05)
		lo = minf(lo, k)
		hi = maxf(hi, k)
	ok(lo < -0.95 and hi > 0.95, "за 10 с — полный вдох и выдох")
	ok(absf(RayView.breath(0, 1.0) - RayView.breath(1, 1.0)) > 0.05, "скаты дышат вразнобой")
	for i in 100:
		var t := i * 0.1
		ok(absf(RayView.breath(0, t + 0.05) - RayView.breath(0, t)) < 0.1, "плавно, без скачков")
	near(RayView.hump(0.5, 1.0), 0.5 * (1.0 + RayView.BREATH_H), 1e-9, "горб выше на вдохе")
	near(RayView.hump(0.5, -1.0), 0.5 * (1.0 - RayView.BREATH_H), 1e-9, "и ниже на выдохе")
	near(RayView.hump(0.0, 1.0), 0.0, 1e-9, "кромка крыла стоит")
	near(RayView.hump(0.1, 1.0, 0.5), 0.1, 1e-9, "хвост не дышит")
	ok(RayView.BREATH_H * 0.5 < 0.06, "спина на 0,5 м поднимается не больше 6 см — присоски на спине не отрываются")
	rv.sync(3.0)
	for ry in rv.rays.rays:
		near(rv.customs[ry.index].r, RayView.breath(ry.index, 3.0), 1e-6, "доля — в экземпляре")
	var code := (rv.multimesh.mesh.surface_get_material(0) as ShaderMaterial).shader.code
	ok(code.contains("VERTEX.y *= 1.0 + %s * INSTANCE_CUSTOM.x" % str(RayView.BREATH_H)), "шейдер — с тем же размахом")
	rv.queue_free()


func test_tail_whips() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var rv := view.ray_view
	var mesh := rv.multimesh.mesh
	var arr := mesh.surface_get_arrays(0)
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	eq(uv.size(), v.size(), "доля длины хвоста — у каждой вершины")
	var z0 := RayView.TAIL_Z + RayView.TAIL_L * 0.5
	var tail := 0
	for i in v.size():
		if uv[i].x > 0.0:
			tail += 1
			near(v[i].z, z0 - RayView.TAIL_L * uv[i].x, 1e-4, "доля длины растёт к кончику")
			ok(absf(v[i].x) < 0.2, "это хвост, а не крыло")
	ok(tail >= (RayView.TAIL_RINGS - 1) * 6, "хвост из %d колец гнётся: %d вершин" % [RayView.TAIL_RINGS, tail])
	var mat := mesh.surface_get_material(0) as ShaderMaterial
	ok(mat.shader.code.contains(
		"VERTEX.x += sin(INSTANCE_CUSTOM.w - UV.x * 5.0) * 0.8 * UV.x * UV.x * sway_k"),
		"волна хвоста — в шейдере, числа как у двойника")
	ok(not mat.shader.code.contains("TIME"), "хлыст — по времени мира, не по часам шейдера")
	near(RayView.TAIL_RATE, 2.4, 1e-6, "частота")
	near(RayView.TAIL_PHASE, 2.1, 1e-6, "сдвиг между скатами")
	near(RayView.TAIL_K, 5.0, 1e-6, "волн на длину")
	near(RayView.TAIL_AMP, 0.8, 1e-6, "размах")
	var most := 0.0
	var apart := 0.0
	var mid := 0.0
	for k in 300:
		var t := k * 0.1
		near(RayView.tail_wave(0.0, t, 0), 0.0, 1e-6, "у тела хвост стоит")
		var tip := RayView.tail_wave(1.0, t, 0)
		most = maxf(most, absf(tip))
		mid = maxf(mid, absf(RayView.tail_wave(0.5, t, 0)))
		apart = maxf(apart, absf(tip - RayView.tail_wave(1.0, t, 1)))
	ok(most > 0.5 and most <= RayView.TAIL_AMP + 1e-6, "кончик хлещет: %.2f м" % most)
	ok(mid < most * 0.5, "у середины размах меньше: %.2f" % mid)
	ok(apart > 0.3, "два ската — вразнобой: %.2f" % apart)
	EcoShaders.set_sway_lite(true)
	eq(float(mat.get_shader_parameter("sway_k")), 0.0, "«Экономно» — хвост не гнётся")
	near(RayView.tail_wave(1.0, 0.7, 0, 0.0), 0.0, 1e-9, "двойник тоже стоит")
	EcoShaders.set_sway_lite(false)
	eq(float(mat.get_shader_parameter("sway_k")), 1.0, "выключили — снова хлещет")
	view.queue_free()
	await frames(1)


# ---------- Световой колодец 05 (#836) ----------

## Корабль держится у колодца 05 на 20 м (и в точке снимка тестера `32n-mol-kolodec`): ледокрыл второго круга
## проходит вдалеке — в виду из окна, но корабль не задевает и над ним не поднимается.
func test_passes_far_from_well() -> void:
	var well := LayerMap.POINTS["05"]
	for ship: Vector3 in [Vector3(well["x"], -float(well["depth"]), well["z"]), Vector3(-149.2, -14.0, -71.1)]:
		var w := _world()
		var r := _rays(w)
		w.ship.pos = ship
		w.ship.yaw = 0.0
		var closest := INF
		for i in 1200:   # 120 с — круг второго ската (55 м при 3,6 м/с) проходит целиком
			w.step(0.1)
			for ry in r.rays:
				ok(not ry.over, "у колодца (%.0f, %.0f) скат не поднимается над кораблём" % [ship.x, ship.z])
				ok(not EcoHull.touches(ry.p, ship, 0.0, 6.0), "тело далеко от корпуса")
				closest = minf(closest, Vector2(ry.p.x - ship.x, ry.p.z - ship.z).length())
		ok(closest > EcoRay.WING + 6.0, "проходит вдалеке: ближе всего %.0f м" % closest)
		ok(closest < 60.0, "но в виду из окна: %.0f м" % closest)


# ---------- «Экономно» (Б6) ----------

func _hump(rv: RayView) -> float:
	var top := 0.0
	for v in rv.verts:
		top = maxf(top, v.y if absf(v.z) < 5.0 and absf(v.x) < 3.0 else 0.0)
	return top


func test_view_lite_coarser_same_material() -> void:
	var w := _world()
	var rv := RayView.new(_rays(w))
	tree.root.add_child(rv)
	await frames(1)
	var full := rv.tris
	eq(full, 480, "полный скат: пластина 288, хвост 80, пятнышки 112")
	var mat := rv.multimesh.mesh.surface_get_material(0)
	var box := rv.multimesh.mesh.get_aabb()
	var hump := _hump(rv)
	var dust := rv.dust_view
	var placed := rv.placed.duplicate()
	rv.set_lite(true)
	ok(rv.lite, "скаты — на «Экономно»")
	eq(rv.tris, RayView.LITE_CELLS_X * RayView.LITE_CELLS_Z * 2 + (RayView.LITE_TAIL_RINGS - 1) * 10
		+ RayView.SPOTS * 8, "треугольников: %d → %d" % [full, rv.tris])
	ok(rv.tris * 100 <= full * 65, "не больше 65 %")
	ok(rv.multimesh.mesh.surface_get_material(0) == mat, "материал тот же (взмах, хлыст, пятнышки)")
	eq(rv.multimesh.mesh.get_surface_count(), 1, "один вызов отрисовки")
	eq(rv.multimesh.instance_count, 2, "оба ската на месте")
	ok(rv.dust_view == dust, "муть та же")
	var lb := rv.multimesh.mesh.get_aabb()
	near(lb.size.x, box.size.x, 0.15, "размах тот же")
	near(lb.size.z, box.size.z, 0.01, "длина с хвостом та же")
	near(_hump(rv), hump, 0.05, "горб посередине не срезан")
	var spots := 0
	for c in rv.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		spots += 1 if c.a > 0.5 else 0
	eq(spots, RayView.SPOTS * 6, "все пятнышки светятся")
	rv.sync()
	eq(rv.placed, placed, "места скатов те же")
	rv.set_lite(false)
	eq(rv.tris, full, "назад — полный скат")
	rv.queue_free()
	await frames(1)


func test_lite_kept_after_world_reset() -> void:
	var ev := EcoView.new()
	ev.ground = Seabed.height
	ev.set_lite(true)
	ok(ev.ray_view.lite, "уровень дошёл до скатов")
	var t := ev.ray_view.tris
	ev.ground = Seabed.height
	ok(ev.ray_view.lite, "после сброса мира — по-прежнему «Экономно»")
	eq(ev.ray_view.tris, t, "и пластина грубая")
	ev.set_lite(false)
	ev.free()
