extends TestCase
## Светляки-полосники (updateFish в js/creatures.js, Unity EcoFishTests и EcoFishLookTests): стаи у кораллов, тревога
## от хищника и корабля, форма рыбки по ART-011, курс и цвет стаи, один MultiMesh в сцене.


## Всех рыбок: шесть стай рифа и две у кроны Каменного цветка по 22, молодь в костях — 14.
const ALL := EcoFish.PER_SHOAL * (6 + EcoFish.CROWN_SHOALS) + EcoFish.JUV_PER


func _world(world_seed: int = EcoRandom.WORLD_SEED) -> EcoWorld:
	var w := EcoWorld.new(world_seed)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)  # корабль далеко и не мешает
	w.add(EcoFish.new())
	return w


func _fish(w: EcoWorld) -> EcoFish:
	return w.systems[0] as EcoFish


## Оставить в мире одну стаю: остальные стаи с их рыбками убираем — проверке одной стаи они только тратят время
## (#1350, `--slow`). Своя стая шагает как прежде: очередь дальних — по номеру стаи и счётчику шагов, не по их числу.
func _only(w: EcoWorld, fish: EcoFish, keep: EcoFish.Shoal) -> void:
	for sh in fish.shoals:
		if sh != keep:
			for f: EcoFish.Fish in sh.members:
				w.agents.erase(f.agent)
	fish.shoals.assign([keep])
	fish.all.assign(keep.members)


func _mean_to(sh: EcoFish.Shoal, p: Vector3) -> float:
	var s := 0.0
	var n := 0
	for f: EcoFish.Fish in sh.members:
		if f.agent.alive:
			s += f.agent.p.distance_to(p)
			n += 1
	return s / n


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------- Поведение стай ----------

func test_six_shoals_of_22_at_corals() -> void:
	var w := _world()
	var fish := _fish(w)
	eq(fish.shoals.size(), 9, "шесть стай рифа, две у кроны и молодь в костях")
	eq(fish.all.size(), 190, "190 рыбок")
	eq(EcoFish.total(), 190)
	eq(w.count("fish"), 190, "все в мире")
	near(fish.shoals[0].home.x, 15.375, 0.01, "дом первой стаи — как в браузере")
	near(fish.shoals[0].home.z, 75.99, 0.01)
	for i in fish.all.size():
		var f := fish.all[i]
		eq(f.index, i, "номер рыбки")
		eq(f.agent.species, "fish")
		if f.shoal.crown or f.shoal.cage:
			continue  # стаи у кроны — test_crown_shoals_circle_flower, молодь — test_young_hide_between_ribs
		var d := f.agent.p - f.shoal.home
		if not ok(absf(d.x) <= 3.0 and d.y >= 0.0 and d.y <= 3.0 and absf(d.z) <= 3.0, "рыбка у дома: %s" % d):
			return
		ok(f.bright >= 0.75 and f.bright <= 1.15, "яркость 0,75…1,15")
	for sh in fish.shoals:
		if not sh.crown and not sh.cage:
			near(sh.home.y - Seabed.height(sh.home.x, sh.home.z), 3.5, 0.25, "дом стаи на 3,5 м над дном")




## #1400: стая с прохода 00 → 01 (коралл (56; 6)) живёт у рифа (55; −69) — на 3,5 м над дном, как остальные дома.
## Дальше 40 м от пути 00 → стоянка → 01: стая тянет хищников на путь (tools/quiet_map.gd).
func test_shoal_home_moved_off_route() -> void:
	var reef: Vector2 = EcoCoral.BASES[2]
	var h := EcoFish.HOMES[4]
	ok(Vector2(h.x, h.z).distance_to(reef) < 0.5, "стая 4 — у рифа (55; −69)")
	near(h.y, Seabed.height(h.x, h.z) + 3.5, 0.05, "дом на 3,5 м над дном")
	var tool: GDScript = load("res://tools/quiet_map.gd")
	var pts: Array[Vector2] = tool.route_points()
	var far := INF
	for p in pts:
		far = minf(far, Vector2(h.x, h.z).distance_to(p))
	ok(far > 40.0, "дом стаи 4 не у пути 00 → 01: %.1f м" % far)


## Проба расстановки #1400: дом стаи рифа переносится до сброса мира (`EcoFish.home_at`), остальные — на месте; по
## умолчанию переносов нет. Расчёт тихих мест на пути 00 → 01 — tools/quiet_map.gd.
func test_home_moves_only_for_probe() -> void:
	var to := Vector3(EcoCoral.BASES[2].x, -30.0, EcoCoral.BASES[2].y)
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var fish := EcoFish.new()
	ok(fish.home_at.is_empty(), "в игре переносов нет")
	fish.home_at[4] = to
	w.add(fish)
	eq(fish.shoals[4].home, to, "стая 4 — у другого рифа")
	eq(fish.shoals[3].home, EcoFish.HOMES[3], "остальные — дома")
	for f in fish.shoals[4].members:
		ok(_flat(f.agent.p, to) < 4.5, "рыбки стаи — у нового дома")
	var plain := _fish(_world())
	eq(plain.shoals[4].home, EcoFish.HOMES[4], "без пробы дом на месте")
	var tool: GDScript = load("res://tools/quiet_map.gd")
	var pts: Array[Vector2] = tool.route_points()
	eq(pts[0], Vector2(4.0, 80.0), "путь начинается у 00")
	eq(pts[-1], Vector2(33.0, -22.0), "и кончается у 01")
	eq(tool.REEF_FOR[4], EcoCoral.BASES[2], "дом (56; 6) — к существующему рифу (55; −69)")

## Б3 «плавность»: центр стаи после сброса — среднее рыбок, как в шаге; раньше стоял в доме, а рыбки — выше и
## вразброс, и на первом шаге центр (цель сканера и сонара, испуг, охота) прыгал до 1,9 м.
func test_center_is_mean_after_reset() -> void:
	var w := _world()
	var fish := _fish(w)
	for sh in fish.shoals:
		var sum := Vector3.ZERO
		for f: EcoFish.Fish in sh.members:
			sum += f.agent.p
		near(sh.center.distance_to(sum / sh.members.size()), 0.0, 1e-3, "центр стаи %d — среднее рыбок" % sh.index)
	w.reset()
	var sh0 := fish.shoals[0]
	var sum0 := Vector3.ZERO
	for f: EcoFish.Fish in sh0.members:
		sum0 += f.agent.p
	near(sh0.center.distance_to(sum0 / sh0.members.size()), 0.0, 1e-3, "и после сброса мира")


## Сброс мира, когда корабль стоит у стаи (у Костей 04 — в клетке молоди): рыбки встают снаружи корпуса сразу,
## а не выпрыгивают из него на первом шаге (было до 2,9 м за шаг — 86 м/с).
func test_no_jump_out_of_hull_after_reset() -> void:
	var w := _world()
	var fish := _fish(w)
	w.ship.pos = LayerMap.at("04")
	w.reset()
	var cage: EcoFish.Shoal = fish.shoals[fish.shoals.size() - 1]
	ok(cage.cage, "последняя стая — молодь в клетке")
	var before: Array[Vector3] = []
	for f in fish.all:
		before.append(f.agent.p)
		ok(not w.touches_ship(f.agent.p), "рыбка %d после сброса — снаружи корпуса" % f.index)
	w.step(1.0 / 30.0)
	var worst := 0.0
	for f in fish.all:
		worst = maxf(worst, f.agent.p.distance_to(before[f.index]))
	ok(worst < 0.5, "на первом шаге никто не прыгает: %.2f м" % worst)


## Три минуты спокойного мира рифа и кроны — одни на тесты стай рифа и стай кроны: раньше каждый гонял свои 180 с
## (по 3,7 с на тест). Мир детерминирован, цветок стаи рифа не трогает — итог общий (#1350).
## reef — все стаи у дома (как раньше, стаи кроны тоже), crown — у кроны; первая непройденная проверка ("" — все прошли), turned — сколько обошла крону каждая стая, рад;
## samples / inside — мест рыбок кроны всего и внутри ветвей; quiet — событий в шине к концу.
static var _calm_run := {}


static func _calm() -> Dictionary:
	if not _calm_run.is_empty():
		return _calm_run
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)  # корабль далеко и не мешает
	var fish := w.add(EcoFish.new()) as EcoFish
	var flower := w.add(EcoFlower.new()) as EcoFlower
	var foot := Vector3(EcoFlower.CENTER.x, Seabed.height(EcoFlower.CENTER.x, EcoFlower.CENTER.y), EcoFlower.CENTER.y)
	var crown: Array[EcoFish.Shoal] = []
	for sh in fish.shoals:
		if sh.crown:
			crown.append(sh)
	var reef := ""
	var bad := ""
	var turned: Array[float] = [0.0, 0.0]
	var last: Array[float] = []
	for sh in crown:
		last.append(atan2(sh.center.z - foot.z, sh.center.x - foot.x))
	var samples := 0
	var inside := 0
	for s in 360:
		w.run(0.5)
		if reef == "" and (s + 1) % 60 == 0:  # каждые 30 с — все стаи, как раньше
			for sh in fish.shoals:
				if sh.alive != sh.members.size() or sh.alarm != 0.0:
					reef = "стая %d, %d с: все живы и без тревоги (живых %d, тревога %.2f)" \
						% [sh.index, (s + 1) / 2, sh.alive, sh.alarm]
					break
				for f: EcoFish.Fish in sh.members:
					var p := f.agent.p
					var good := _flat(p, sh.home) < 30.0 and p.distance_to(sh.center) < 6.0 \
						and p.y - Seabed.height(p.x, p.z) > -0.5 and p.y < -3.0 \
						and f.agent.v.length() <= EcoFish.CALM_SPEED + 1e-3 and f.agent.state == EcoAgent.State.GRAZE
					if not good:
						reef = "стая %d, %d с: у дома, вместе, над дном, подо льдом, спокойно (p=%s, центр=%s)" \
							% [sh.index, (s + 1) / 2, p, sh.center] + " v=%s" % f.agent.v
						break
				if reef != "":
					break
		for i in crown.size():
			if bad != "":
				break
			var sh := crown[i]
			var r := _flat(sh.center, foot)
			var h := sh.center.y - foot.y
			if sh.alarm != 0.0 or not (r > 12.0 and r < 23.0 and h > 11.0 and h < 32.0):
				bad = "стая %d у кроны снаружи и спокойна: r=%.1f, h=%.1f, тревога %.2f" % [sh.index, r, h, sh.alarm]
				break
			var a := atan2(sh.center.z - foot.z, sh.center.x - foot.x)
			turned[i] += wrapf(a - last[i], -PI, PI)
			last[i] = a
			for f: EcoFish.Fish in sh.members:
				samples += 1
				if flower.solid(f.agent.p):
					inside += 1
	_calm_run = {"reef": reef, "crown": bad, "turned": turned, "samples": samples, "inside": inside,
		"quiet": w.bus.pending.size()}
	return _calm_run


func test_shoal_roams_near_home_and_keeps_together() -> void:
	var c := _calm()
	eq(c.reef, "", "три минуты все стаи у дома, вместе, над дном, подо льдом, спокойно")
	eq(c.quiet, 0, "спокойная стая молчит")


func test_predator_sends_shoal_home_to_hide() -> void:
	var w := _world()
	var fish := _fish(w)
	var sh := fish.shoals[0]
	w.ship.pos = sh.home + Vector3(0, 0, 40)  # ближе MID: стая шагает каждый шаг мира, не по очереди дальних (issue #803)
	w.run(8.0)  # стая отошла от дома
	ok(_mean_to(sh, sh.home) > 8.0, "стая отошла от дома")
	var pred := w.spawn("pred", sh.center + Vector3(5, 0, 0))  # стоит на месте
	w.step(0.05)
	ok(sh.alarm > 0.0, "тревога")
	for f: EcoFish.Fish in sh.members:
		if not ok(f.agent.state != EcoAgent.State.GRAZE, "в тревоге не пасётся"):
			break
	var ev := w.bus.take()
	eq(ev.size(), 1, "одно событие")
	eq(ev[0].species, "fish")
	eq(ev[0].note, "flee")
	ok(ev[0].is_observation(), "наблюдение для журнала")
	eq(ev[0].text(), "Мелкая рыба: стая уходит в кораллы — рядом хищник")

	w.run(8.0)
	ok(_mean_to(sh, sh.home) < 5.0, "стая у дома в кораллах")
	var hiding := 0
	for f: EcoFish.Fish in sh.members:
		if f.agent.state == EcoAgent.State.HIDE:
			hiding += 1
			ok(f.agent.v.length() <= EcoFish.HIDE_SPEED + 1e-3, "прячутся медленно")
	ok(hiding >= 15, "прячутся почти все: %d" % hiding)
	near(sh.flee_cd, EcoFish.FLEE_COOLDOWN - 8.0, 0.02, "сообщение не чаще раза в 30 с")
	eq(fish.shoals[4].alarm, 0.0, "дальняя стая спокойна")

	pred.alive = false  # хищник ушёл — тревога спадает
	w.run(4.0)
	eq(sh.alarm, 0.0, "тревога прошла")


## Стаи у кроны Каменного цветка (ART-027): кружат снаружи кроны, каждая в свою сторону, сквозь ветви почти не ходят.
func test_crown_shoals_circle_flower() -> void:
	var w := _world()
	var fish := _fish(w)
	var flower := w.add(EcoFlower.new()) as EcoFlower
	var foot := Vector3(EcoFlower.CENTER.x, Seabed.height(EcoFlower.CENTER.x, EcoFlower.CENTER.y), EcoFlower.CENTER.y)
	var crown: Array[EcoFish.Shoal] = []
	for sh in fish.shoals:
		if sh.crown:
			crown.append(sh)
	eq(crown.size(), EcoFish.CROWN_SHOALS, "две стаи у кроны")
	eq(fish.shoals[6], crown[0], "после шести стай рифа — их номера не сдвинулись")
	ok(crown[0].turn * crown[1].turn < 0.0, "кружат в разные стороны")
	for sh in crown:
		near(sh.home.distance_to(foot + Vector3(0, EcoFish.CROWN_HIDE, 0)), 0.0, 1e-3, "дом — в чаше на оси")
		ok(not flower.solid(sh.home), "в доме ветвей нет")
		ok(_flat(sh.center, foot) > EcoFlower.SPREAD, "начинают снаружи кроны")
	var c := _calm()  # три минуты того же мира
	eq(c.crown, "", "три минуты у кроны снаружи и спокойны")
	var turned: Array[float] = c.turned
	for i in crown.size():
		ok(turned[i] * crown[i].turn > TAU, "стая %d обошла крону в свою сторону: %.1f рад" % [i, turned[i]])
	ok(c.inside < c.samples * 0.01, "сквозь ветви почти не плывут: %d из %d" % [c.inside, c.samples])
	ok(c.samples > 0, "места рыбок кроны посчитаны")


func test_crown_shoal_hides_in_chalice() -> void:
	var w := _world()
	var fish := _fish(w)
	var flower := w.add(EcoFlower.new()) as EcoFlower
	var sh := fish.shoals[6]
	w.run(10.0)
	var pred := w.spawn("pred", sh.center)
	for s in 30:  # хищник гонит стаю снаружи, со стороны от кроны
		var out := Vector3(sh.center.x - sh.home.x, 0, sh.center.z - sh.home.z)
		if out.length() > 6.0:  # у чаши хищник остаётся снаружи кроны
			pred.p = sh.center + out.normalized() * 5.0
		w.run(0.5)
	ok(_mean_to(sh, sh.home) < 5.0, "стая ушла в чашу кроны: %.1f м" % _mean_to(sh, sh.home))
	var hiding := 0
	var inside := 0
	for f: EcoFish.Fish in sh.members:
		if f.agent.state == EcoAgent.State.HIDE:
			hiding += 1
		if flower.solid(f.agent.p):
			inside += 1
	ok(hiding >= 15, "прячутся почти все: %d" % hiding)
	ok(inside <= 1, "в чаше, а не в ветвях: %d" % inside)


## Сцена 00→01 (решение ГД 08.11, `docs/urovni/sloj-1.md`): стая кроны — знак раньше хищника. Серпохвост ещё в 40 м
## от оси, за кроной (дальше тревоги стай рифа), — строка о бегстве, стая уходит в чашу; хищник ушёл дальше
## CROWN_ALARM — тревога спадает, стая снова кружит снаружи кроны. Последствие без укуса: хищник не ближе 30 м.
func test_crown_shoal_hides_early_and_returns_to_ring() -> void:
	var w := _world()
	var fish := _fish(w)
	var flower := w.add(EcoFlower.new()) as EcoFlower
	var sh := fish.shoals[6]
	_only(w, fish, sh)
	w.run(5.0)
	ok(sh.alarm == 0.0 and w.bus.pending.is_empty(), "без хищника спокойна")
	var out := Vector3(sh.center.x - sh.axis.x, 0, sh.center.z - sh.axis.z).normalized()
	var far := 40.0
	ok(far > EcoFlower.SPREAD + EcoFish.PRED_ALARM and far < EcoFish.CROWN_ALARM, "40 м: за кроной, но в тревоге кроны")
	var pred := w.spawn("pred", sh.axis - out * far + Vector3(0, 18, 0))  # с другой стороны кроны
	w.step(0.05)
	ok(sh.alarm > 0.0, "тревога сразу")
	eq(w.bus.pending.size(), 1, "одна строка")
	eq(w.bus.pending[0].note, "flee")
	eq(w.bus.pending[0].text(), "Мелкая рыба: стая у Каменного цветка прячется в крону — где-то рядом хищник")
	var closest := INF
	for s in 20:
		w.run(0.5)
		for f: EcoFish.Fish in sh.members:
			closest = minf(closest, f.agent.p.distance_to(pred.p))
	ok(_mean_to(sh, sh.home) < 5.0, "стая в чаше: %.1f м" % _mean_to(sh, sh.home))
	var inside := 0
	for f: EcoFish.Fish in sh.members:
		if flower.solid(f.agent.p):
			inside += 1
	ok(inside <= 1, "в чаше, а не в ветвях: %d" % inside)
	ok(closest > 30.0, "хищник до стаи не дошёл: %.1f м" % closest)
	eq(w.bus.pending.size(), 1, "строка раз за тревогу")

	pred.p = sh.axis - out * (EcoFish.CROWN_ALARM + 10.0) + Vector3(0, 18, 0)  # ушёл дальше тревоги кроны
	w.run(4.0)
	eq(sh.alarm, 0.0, "тревога прошла")
	w.run(16.0)
	var ring := 0
	for f: EcoFish.Fish in sh.members:
		if _flat(f.agent.p, sh.axis) > EcoFlower.SPREAD:
			ring += 1
	ok(ring >= sh.members.size() - 2, "снова снаружи кроны: %d из %d" % [ring, sh.members.size()])
	var r := _flat(sh.center, sh.axis)
	ok(r > EcoFish.CROWN_RING.x - 3.0 and r < EcoFish.CROWN_RING.y + 3.0, "центр стаи — на кольце: %.1f м" % r)
	eq(w.bus.pending.size(), 1, "возврат без строки")


## Сцена 00→01 (решение ГД 08.11, `docs/urovni/sloj-1.md`): стоянка у 01 (33; −22) со светом на крону сама стаи не
## тревожит — ни стаи кроны (кружат в 10–20 м от корабля), ни стаю рифа (55; −69). Тревога и строка — только от
## хищника: иначе «стая → бегство» у 01 перестаёт быть знаком угрозы.
func test_parked_at_01_with_light_does_not_alarm() -> void:
	var w := _world()
	var fish := _fish(w)
	w.add(EcoFlower.new())
	var stand := Vector2(33.0, -22.0)
	w.ship.pos = Vector3(stand.x, Seabed.height(stand.x, stand.y) + 7.0, stand.y)
	var to := EcoFlower.CENTER - stand
	w.ship.yaw = atan2(-to.x, -to.y)  # нос — на крону
	w.ship.speed = 0.0
	w.ship.light_on = true
	w.ship.light_range = 40.0
	w.ship.hull_noise = 0.2  # стоит с работающими машинами
	var watch: Array[EcoFish.Shoal] = [fish.shoals[4]]
	for sh in fish.shoals:
		if sh.crown:
			watch.append(sh)
	eq(watch.size(), 1 + EcoFish.CROWN_SHOALS, "стая рифа и стаи кроны")
	var closest := INF
	var alarms := 0
	for s in 60 * 20:
		w.step(0.05)
		for sh in watch:
			closest = minf(closest, w.ship.pos.distance_to(sh.center))
			if sh.alarm > 0.0 or sh.threat_is_ship:
				alarms += 1
	ok(closest < 20.0, "стаи кроны подходят к кораблю: %.1f м" % closest)
	eq(alarms, 0, "минута стоянки со светом — без тревоги")
	eq(w.bus.pending.size(), 0, "и без строки")

	w.spawn("pred", Vector3(EcoFlower.CENTER.x, w.ship.pos.y, EcoFlower.CENTER.y) + Vector3(0, 0, -40.0))
	w.step(0.05)
	var crown_alarm := 0
	for sh in watch:
		if sh.crown and sh.alarm > 0.0:
			crown_alarm += 1
	eq(crown_alarm, EcoFish.CROWN_SHOALS, "хищник в 40 м за кроной — обе стаи кроны в тревоге")
	ok(w.bus.pending.size() >= 1 and w.bus.pending[0].note == "flee", "строка о бегстве — от хищника")


## Сцена 00→01 (решение ГД 08.11, `docs/urovni/sloj-1.md`): минута стоянки у 01 (33; −22) со светом, без хищника, в
## течении отмели (EcoCurrent, как в EcoView): стаи кроны всё время кружат на кольце — центр в CROWN_RING ± 3 м от
## оси, течение (0,3 м/с — за минуту 18 м) их с кольца не сносит, а корабль со светом к себе не тянет: ближе всего к
## нему центр стаи подходит не ближе, чем кольцо проходит мимо стоянки. Крона у 01 — постоянная живая картинка.
func test_parked_at_01_crown_keeps_ring_in_current() -> void:
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	var cur := w.add(EcoCurrent.new()) as EcoCurrent
	var fish := w.add(EcoFish.new()) as EcoFish
	w.add(EcoFlower.new())
	var stand := Vector2(33.0, -22.0)
	w.ship.pos = Vector3(stand.x, Seabed.height(stand.x, stand.y) + 7.0, stand.y)
	var to := EcoFlower.CENTER - stand
	w.ship.yaw = atan2(-to.x, -to.y)  # нос — на крону
	w.ship.speed = 0.0
	w.ship.light_on = true
	w.ship.light_range = 40.0
	w.ship.hull_noise = 0.2
	var crown: Array[EcoFish.Shoal] = []
	for sh in fish.shoals:
		if sh.crown:
			crown.append(sh)
	eq(crown.size(), EcoFish.CROWN_SHOALS, "стаи кроны")
	near(cur.vel().length(), EcoCurrent.SPEED, 1e-4, "течение идёт")
	var axis := crown[0].axis
	var ship_axis := _flat(w.ship.pos, axis)
	var r_min := INF
	var r_max := 0.0
	var ship_min := INF
	var turned: Array[float] = []
	var last: Array[float] = []
	for sh in crown:
		turned.append(0.0)
		last.append(atan2(sh.center.z - axis.z, sh.center.x - axis.x))
	for s in 60 * 20:
		w.step(0.05)
		if s % 10 != 9:
			continue
		for i in crown.size():
			var sh := crown[i]
			var r := _flat(sh.center, axis)
			r_min = minf(r_min, r)
			r_max = maxf(r_max, r)
			ship_min = minf(ship_min, _flat(sh.center, w.ship.pos))
			var a := atan2(sh.center.z - axis.z, sh.center.x - axis.x)
			turned[i] += wrapf(a - last[i], -PI, PI)
			last[i] = a
	print("    стоянка у 01 в течении: центр стаи %.1f–%.1f м от оси, к кораблю не ближе %.1f м (ось в %.1f м), обход %.2f / %.2f рад" % [
		r_min, r_max, ship_min, ship_axis, turned[0], turned[1]])
	ok(r_min > EcoFish.CROWN_RING.x - 3.0, "с кольца внутрь не сносит: %.1f м" % r_min)
	ok(r_max < EcoFish.CROWN_RING.y + 3.0, "с кольца наружу не сносит: %.1f м" % r_max)
	ok(ship_min > ship_axis - EcoFish.CROWN_RING.y - 1.5, "к кораблю не тянет: %.1f м" % ship_min)
	for i in crown.size():
		ok(turned[i] * crown[i].turn > 0.5, "стая %d кружит в свою сторону: %.2f рад" % [i, turned[i]])
	eq(w.bus.pending.size(), 0, "минута — без строки")


## Сцена 00→01 (решение ГД 08.11, `docs/urovni/sloj-1.md`, кандидат (т)): течение отмели сменилось на стоянке у 01
## (33; −22) со светом — EcoCurrent через PERIOD берёт следующее из DIRS и плавно (TURN_RATE) поворачивает. Веерник у
## огнецвета (54,9; −68,7) — в 51 м, ближе TURN_R — разворачивается следом без рывка и шлёт одну строку «turn»;
## колыхание (EcoCurrent.sway по vel) ложится по новому потоку. Стаи кроны течения не читают (у EcoFish его нет):
## остаются на кольце CROWN_RING ± 3 м и не теряют сторону обхода — смена течения у 01 видна по флоре, а не по рыбам.
func test_current_turn_at_01_turns_fans_crown_keeps_ring() -> void:
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	var cur := w.add(EcoCurrent.new()) as EcoCurrent
	var fans := w.add(EcoFan.new(cur)) as EcoFan
	var fish := w.add(EcoFish.new()) as EcoFish
	w.add(EcoFlower.new())
	var stand := Vector2(33.0, -22.0)
	w.ship.pos = Vector3(stand.x, Seabed.height(stand.x, stand.y) + 7.0, stand.y)
	var to := EcoFlower.CENTER - stand
	w.ship.yaw = atan2(-to.x, -to.y)  # нос — на крону
	w.ship.speed = 0.0
	w.ship.light_on = true
	w.ship.light_range = 40.0
	w.ship.hull_noise = 0.2
	cur.timer = 2.0  # смена — через 2 с стоянки, а не через 180
	var fan: EcoFan.Fan = null
	for f in fans.fans:
		if Vector2(f.pos.x, f.pos.z).distance_to(stand) < EcoFan.TURN_R and (fan == null
				or Vector2(f.pos.x, f.pos.z).distance_to(stand) < Vector2(fan.pos.x, fan.pos.z).distance_to(stand)):
			fan = f
	ok(fan != null, "у стоянки 01 есть веерник ближе TURN_R")
	if fan == null:
		return
	var fan_d := Vector2(fan.pos.x, fan.pos.z).distance_to(stand)
	var crown: Array[EcoFish.Shoal] = []
	for sh in fish.shoals:
		if sh.crown:
			crown.append(sh)
	eq(crown.size(), EcoFish.CROWN_SHOALS, "стаи кроны")
	var axis := crown[0].axis
	var flow0 := cur.vel()
	var yaw0 := fan.yaw
	var r_min := INF
	var r_max := 0.0
	var turned: Array[float] = []
	var last: Array[float] = []
	for sh in crown:
		turned.append(0.0)
		last.append(atan2(sh.center.z - axis.z, sh.center.x - axis.x))
	var fan_jump := 0.0
	var flow_jump := 0.0
	var prev := fan.yaw
	var prev_flow := cur.angle
	for s in 60 * 20:
		w.step(0.05)
		fan_jump = maxf(fan_jump, absf(wrapf(fan.yaw - prev, -PI, PI)))
		flow_jump = maxf(flow_jump, absf(wrapf(cur.angle - prev_flow, -PI, PI)))
		prev = fan.yaw
		prev_flow = cur.angle
		if s % 10 != 9:
			continue
		for i in crown.size():
			var sh := crown[i]
			var r := _flat(sh.center, axis)
			r_min = minf(r_min, r)
			r_max = maxf(r_max, r)
			var a := atan2(sh.center.z - axis.z, sh.center.x - axis.x)
			turned[i] += wrapf(a - last[i], -PI, PI)
			last[i] = a
	var flow1 := cur.vel()
	var fan_turn := absf(wrapf(fan.yaw - yaw0, -PI, PI))
	var fan_off := absf(wrapf(EcoFan.aim(fan, cur.angle) - fan.yaw, -PI, PI))
	var turn_lines := 0
	for e in w.bus.pending:
		if e.species == EcoFan.ID and e.note == "turn":
			turn_lines += 1
	print("    смена течения у 01: поток повернул на %.2f рад, веерник в %.0f м — на %.2f рад (до цели %.3f, шаг не больше %.4f при шаге потока %.4f), центр кроны %.1f–%.1f м, обход %.2f / %.2f рад, строк «turn» %d" % [
		flow0.angle_to(flow1), fan_d, fan_turn, fan_off, fan_jump, flow_jump, r_min, r_max, turned[0], turned[1], turn_lines])
	eq(cur.turns, 1, "течение сменилось один раз")
	ok(flow0.angle_to(flow1) > 1.0, "поток повернул заметно: %.2f рад" % flow0.angle_to(flow1))
	ok(fan_turn > 1.0, "веерник развернулся следом: %.2f рад" % fan_turn)
	ok(fan_off < 0.1, "веерник встал поперёк нового потока: до цели %.3f рад" % fan_off)
	ok(fan_jump < 0.8 * flow_jump, "веерник медленно идёт следом, не рывком за потоком: шаг %.4f при %.4f рад" % [
		fan_jump, flow_jump])
	eq(turn_lines, 1, "одна строка «разворачивается следом за течением»")
	var sway0 := EcoCurrent.sway(fan.pos, 1.0, EcoFan.HEIGHT, 0.0, flow0, Vector3(0.3, 0.0, 0.0))
	var sway1 := EcoCurrent.sway(fan.pos, 1.0, EcoFan.HEIGHT, 0.0, flow1, Vector3(0.3, 0.0, 0.0))
	ok(Vector2(sway1.x, sway1.z).normalized().dot(Vector2(flow1.x, flow1.z).normalized()) > 0.99
			and Vector2(sway0.x, sway0.z).angle_to(Vector2(sway1.x, sway1.z)) != 0.0, "колыхание легло по новому потоку")
	ok(r_min > EcoFish.CROWN_RING.x - 3.0, "крону с кольца внутрь не сносит: %.1f м" % r_min)
	ok(r_max < EcoFish.CROWN_RING.y + 3.0, "крону с кольца наружу не сносит: %.1f м" % r_max)
	for i in crown.size():
		ok(turned[i] * crown[i].turn > 0.5, "стая %d кружит в свою сторону и после смены: %.2f рад" % [i, turned[i]])


## Сцена 00→01 (п. 2 (щ)): течение сменилось, пока стаи кроны у 01 прячутся от хищника, — строка веерника «turn» и
## строка бегства приходят почти разом (0,3 с). Обе доходят до приборов по очереди: шина отдаёт обе (`take_link`), а
## `Status.Message` (как `Main._world_say`) не глотает ни одну — каждая видна не меньше `MIN_SHOW` (без одного шага:
## строка встаёт и считает время в том же кадре). Порядок — оба. Мутация: очередь `Status` без `MIN_SHOW` — 0,3 с.
func test_current_turn_during_crown_flee_both_lines_shown() -> void:
	for turn_first: bool in [true, false]:
		var w := EcoWorld.new(EcoRandom.WORLD_SEED)
		w.ground = Seabed.height
		var cur := w.add(EcoCurrent.new()) as EcoCurrent
		w.add(EcoFan.new(cur))
		var fish := w.add(EcoFish.new()) as EcoFish
		w.add(EcoFlower.new())
		var stand := Vector2(33.0, -22.0)
		w.ship.pos = Vector3(stand.x, Seabed.height(stand.x, stand.y) + 7.0, stand.y)
		var to := EcoFlower.CENTER - stand
		w.ship.yaw = atan2(-to.x, -to.y)
		w.ship.speed = 0.0
		w.ship.light_on = true
		w.ship.light_range = 40.0
		w.ship.hull_noise = 0.2
		cur.timer = 1000.0
		var crown: EcoFish.Shoal = null
		for sh in fish.shoals:
			if sh.crown:
				crown = sh
				break
		var msg := Status.Message.new()
		var shown: Array = []   # [текст, когда встал, сколько виден]
		var at := {"turn": -1.0, "flee": -1.0}
		var t := 0.0
		var pred: EcoAgent = null
		while t < 14.0:
			var turn_at := 2.0 if turn_first else 2.3
			var pred_at := 2.3 if turn_first else 2.0
			if cur.timer > 100.0 and t >= turn_at - 0.001:
				cur.timer = 0.01
			if pred == null and t >= pred_at - 0.001:
				var out := Vector3(crown.center.x - crown.axis.x, 0, crown.center.z - crown.axis.z).normalized()
				pred = w.spawn("pred", crown.axis - out * 30.0 + Vector3(0, 18, 0))
			w.step(0.05)
			t += 0.05
			for e in w.take_link():
				if e.get("type") != EcoLink.MESSAGE and e.get("type") != EcoLink.OBSERVE:
					continue
				var text := String(e.get("text", ""))
				if text == "":
					continue
				if e.get("note") == "turn" and at["turn"] < 0.0:
					at["turn"] = t
				if e.get("note") == "flee" and at["flee"] < 0.0:
					at["flee"] = t
				msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)))
			msg.update(0.05)
			if msg.text != "" and (shown.is_empty() or shown[-1][0] != msg.text):
				shown.append([msg.text, t, 0.0])
			if msg.text != "":
				shown[-1][2] = t - float(shown[-1][1]) + 0.05   # кадр t виден до следующего шага
		var turn_seen := 0.0
		var flee_seen := 0.0
		for s: Array in shown:
			if String(s[0]).contains("течением"):
				turn_seen = maxf(turn_seen, float(s[2]))
			elif String(s[0]).contains("в крону"):
				flee_seen = maxf(flee_seen, float(s[2]))
		var lines := PackedStringArray()
		for s: Array in shown:
			lines.append("%.2f с «%s» %.2f с" % [s[1], String(s[0]).left(40), s[2]])
		print("    %s: «turn» на %.2f с, «flee» на %.2f с; на приборах: %s" % [
			"сначала течение" if turn_first else "сначала хищник", at["turn"], at["flee"], " | ".join(lines)])
		ok(at["turn"] > 0.0 and at["flee"] > 0.0, "обе строки пришли с шины")
		ok(absf(float(at["turn"]) - float(at["flee"])) < Status.Message.MIN_SHOW,
			"строки пришли ближе MIN_SHOW — проверка не пустая: %.2f с" % absf(float(at["turn"]) - float(at["flee"])))
		ok(turn_seen >= Status.Message.MIN_SHOW - 0.051, "строка течения видна %.2f с" % turn_seen)
		ok(flee_seen >= Status.Message.MIN_SHOW - 0.051, "строка бегства видна %.2f с" % flee_seen)

## Сцена 00→01 (решение ГД 08.11, `docs/urovni/sloj-1.md`): хищник ходит у границы CROWN_ALARM — то в 45 м от оси
## кроны, то в 55 м. Строка о бегстве — не чаще FLEE_COOLDOWN (без перерыва тревоги — одна), а стая не мечется между чашей и кольцом: короткий
## выход за границу (2 с) тревогу не снимает, длинный (8 с) снимает, но переключения не чаще удержания тревоги (3 с).
func test_crown_alarm_edge_no_flicker() -> void:
	for half: float in [2.0, 8.0]:
		var w := _world()
		var fish := _fish(w)
		w.add(EcoFlower.new())
		var sh := fish.shoals[6]
		_only(w, fish, sh)
		w.run(5.0)
		var out := Vector3(sh.center.x - sh.axis.x, 0, sh.center.z - sh.axis.z).normalized()
		var pred := w.spawn("pred", sh.axis - out * 45.0 + Vector3(0, 18, 0))
		var lines: Array[float] = []
		var flips: Array[float] = []
		var was := false
		var t := 0.0
		while t < 64.0:
			var inside := fmod(t, 2.0 * half) < half
			var r := EcoFish.CROWN_ALARM + (-5.0 if inside else 5.0)
			pred.p = sh.axis - out * r + Vector3(0, 18, 0)
			var before := w.bus.pending.size()
			w.step(0.05)
			t += 0.05
			for i in range(before, w.bus.pending.size()):
				if w.bus.pending[i].note == "flee":
					lines.append(t)
			var now := sh.alarm > 0.0
			if now != was:
				flips.append(t)
				was = now
		if half < 3.0:
			eq(lines.size(), 1, "тревога не прерывалась — одна строка за эпизод")
		else:
			ok(lines.size() >= 2 and lines.size() <= 3, "полупериод 8 с: строк %d" % lines.size())
		for i in range(1, lines.size()):
			ok(lines[i] - lines[i - 1] >= EcoFish.FLEE_COOLDOWN - 0.1, "строки через %.1f с" % (lines[i] - lines[i - 1]))
		if half < 3.0:
			eq(flips.size(), 1, "короткие выходы тревогу не снимают")
		else:
			ok(flips.size() >= 5, "длинные выходы снимают тревогу: %d" % flips.size())
			for i in range(1, flips.size()):
				ok(flips[i] - flips[i - 1] >= 3.0 - 0.1, "переключение через %.1f с" % (flips[i] - flips[i - 1]))


## Обе стаи кроны (`CROWN_SHOALS`) меряют тревогу от одной оси цветка и в одном круге `CROWN_ALARM` — хищник входит
## в него разом для обеих. Строка «прячется в крону» за такую тревогу — одна на цветок, не по строке от каждой стаи
## (#1400, п. 2 (ав): по `tools/lines_01.gd` вторая такая же строка сменяла первую в очереди). Тревога спала и
## хищник вернулся через `FLEE_COOLDOWN` — строка снова одна.
func test_crown_alarm_one_line_for_both_crown_shoals() -> void:
	var w := _world()
	var fish := _fish(w)
	w.add(EcoFlower.new())
	var crown: Array[EcoFish.Shoal] = []
	for sh in fish.shoals:
		if sh.crown:
			crown.append(sh)
	eq(crown.size(), EcoFish.CROWN_SHOALS)
	for sh in fish.shoals:
		if not sh.crown:
			for f: EcoFish.Fish in sh.members:
				w.agents.erase(f.agent)
	fish.shoals.assign(crown)
	var keep: Array[EcoFish.Fish] = []
	for sh in crown:
		keep.append_array(sh.members)
	fish.all.assign(keep)
	var axis := crown[0].axis
	eq(crown[1].axis, axis, "обе стаи кроны — у одной оси")
	var pred := w.spawn("pred", axis + Vector3(200, 18, 0))
	w.ship.pos = axis + Vector3(0, 10, 30)   # корабль у цветка: стаи кроны шагают каждый шаг
	w.run(5.0)
	var lines: Array[float] = []
	var t := 0.0
	# два захода: 20 с внутри, 40 с снаружи (тревога спала, FLEE_COOLDOWN прошёл), снова 20 с внутри
	while t < 80.0:
		var inside := t < 20.0 or t >= 60.0
		pred.p = axis + Vector3(EcoFish.CROWN_ALARM + (-10.0 if inside else 60.0), 18, 0)
		var before := w.bus.pending.size()
		w.step(0.05)
		t += 0.05
		for i in range(before, w.bus.pending.size()):
			var e: EcoBus.Event = w.bus.pending[i]
			if e.note == "flee":
				lines.append(t)
	print("  строки кроны: ", lines)
	eq(lines.size(), 2, "два захода хищника — две строки, а не по строке от каждой стаи")
	if lines.size() == 2:
		ok(lines[0] < 1.0 and lines[1] >= 60.0 and lines[1] < 61.0, "строка — при входе хищника в круг")


## Сцена 00→01 (решение ГД 08.11, `docs/urovni/sloj-1.md`): импульсы сонара на стоянке у 01 (33; −22) сами стаи кроны
## и стаю рифа не будят — минута импульсов раз в 3 с без тревоги и строки, даже когда серпохвост в 90 м за кроной
## (дальше CROWN_ALARM). Тревога — только когда хищник подошёл: сонар не расширяет круг тревоги стаи.
func test_ping_at_01_does_not_alarm() -> void:
	var w := _world()
	var fish := _fish(w)
	w.add(EcoFlower.new())
	var stand := Vector2(33.0, -22.0)
	w.ship.pos = Vector3(stand.x, Seabed.height(stand.x, stand.y) + 7.0, stand.y)
	var to := EcoFlower.CENTER - stand
	w.ship.yaw = atan2(-to.x, -to.y)  # нос — на крону
	w.ship.speed = 0.0
	w.ship.light_on = true
	w.ship.light_range = 40.0
	w.ship.hull_noise = 0.2
	w.ship.sonar_range = 120.0
	var watch: Array[EcoFish.Shoal] = [fish.shoals[4]]
	for sh in fish.shoals:
		if sh.crown:
			watch.append(sh)
	eq(watch.size(), 1 + EcoFish.CROWN_SHOALS, "стая рифа и стаи кроны")
	var far := Vector3(EcoFlower.CENTER.x, w.ship.pos.y, EcoFlower.CENTER.y - 90.0)
	var pred := w.spawn("pred", far)
	var pings := 0
	var blips := 0
	var alarms := 0
	var nearest := INF
	for s in 60 * 20:
		pred.p = far  # стоит за кроной: без модуля хищника его не уводит никто
		w.ship.sonar_ping = s % 60 == 0
		w.step(0.05)
		if w.ship.sonar_ping:
			pings += 1
			near(w.last_ping, w.time - 0.05, 1e-3, "импульс дошёл до мира")
		w.ship.sonar_ping = false
		for ev in w.take_link():
			if ev.get("type") == EcoLink.NEAR:
				blips += 1
		for sh in watch:
			nearest = minf(nearest, pred.p.distance_to(sh.center))
			if sh.alarm > 0.0 or sh.threat_is_ship:
				alarms += 1
	eq(pings, 20, "минута — 20 импульсов")
	ok(blips > 0, "сонар видит существ: %d отметок" % blips)
	ok(nearest > EcoFish.CROWN_ALARM, "хищник дальше круга тревоги кроны: %.1f м" % nearest)
	eq(alarms, 0, "импульсы на стоянке — без тревоги")
	eq(w.bus.pending.size(), 0, "и без строки")

	pred.p = far + Vector3(0, 0, 50.0)  # в 40 м за кроной
	w.step(0.05)
	var crown_alarm := 0
	for sh in watch:
		if sh.crown and sh.alarm > 0.0:
			crown_alarm += 1
	eq(crown_alarm, EcoFish.CROWN_SHOALS, "хищник в 40 м за кроной — обе стаи кроны в тревоге")
	ok(w.bus.pending.size() >= 1 and w.bus.pending[0].note == "flee", "строка о бегстве — от хищника")


## Сцена 00→01 (решение ГД 08.11, `docs/urovni/sloj-1.md`): стая рифа у 01 (55; −69) при корабле на стоянке (33; −22)
## бежит от хищника в кораллы со строкой, а когда он ушёл дальше PRED_ALARM — тревога спадает, стая выходит из
## укрытия и снова бродит у дома без новой строки. Хищник вернулся раньше FLEE_COOLDOWN — тревога снова, строки нет;
## после паузы — строка снова: «стая → бегство» остаётся знаком угрозы, а не шумом.
func test_reef_shoal_at_01_calms_after_pred_leaves() -> void:
	var w := _world()
	var fish := _fish(w)
	var sh := fish.shoals[4]
	_only(w, fish, sh)
	var stand := Vector2(33.0, -22.0)
	w.ship.pos = Vector3(stand.x, Seabed.height(stand.x, stand.y) + 7.0, stand.y)
	w.ship.speed = 0.0
	w.ship.light_on = true
	w.ship.light_range = 40.0
	w.ship.hull_noise = 0.2
	ok(_flat(sh.home, w.ship.pos) < 60.0, "стая рифа у 01: %.1f м от стоянки" % _flat(sh.home, w.ship.pos))
	w.run(8.0)
	ok(sh.alarm == 0.0 and w.bus.pending.is_empty(), "без хищника спокойна")
	var side := Vector3(sh.home.x - stand.x, 0, sh.home.z - stand.y).normalized()  # хищник — по ту сторону стаи
	var close := sh.center + side * 8.0  # рядом со стаей, где она бродит
	var away := sh.home + side * 30.0 + Vector3(0, sh.center.y - sh.home.y, 0)
	var pred := w.spawn("pred", close)
	w.run(0.1)  # стая в ~50 м от стоянки — дальше MID, шагает через шаг мира
	ok(sh.alarm > 0.0, "тревога от хищника")
	eq(w.bus.pending.size(), 1, "одна строка")
	eq(w.bus.pending[0].note, "flee")
	w.run(8.0)
	ok(_mean_to(sh, sh.home) < 5.0, "стая в кораллах: %.1f м" % _mean_to(sh, sh.home))

	pred.p = away
	var nearest := INF
	var t := 0.0
	var calm_at := -1.0
	while t < 16.0:
		w.step(0.05)
		t += 0.05
		nearest = minf(nearest, pred.p.distance_to(sh.center))
		if calm_at < 0.0 and sh.alarm <= 0.0:
			calm_at = t
	print("    хищник ушёл: тревога спала через %.2f с, ближе всего %.1f м до центра стаи, стая в %.1f м от дома" % [
		calm_at, nearest, _mean_to(sh, sh.home)])
	ok(nearest > EcoFish.PRED_ALARM, "хищник дальше тревоги: %.1f м" % nearest)
	ok(calm_at > 0.0 and calm_at <= 3.0 + 0.1, "тревога спала за удержание: %.2f с" % calm_at)
	var hiding := 0
	var grazing := 0
	for f: EcoFish.Fish in sh.members:
		if f.agent.state == EcoAgent.State.HIDE:
			hiding += 1
		elif f.agent.state == EcoAgent.State.GRAZE:
			grazing += 1
	eq(hiding, 0, "из укрытия вышли")
	eq(grazing, sh.members.size(), "бродят спокойно: %d из %d" % [grazing, sh.members.size()])
	ok(_flat(sh.center, sh.home) < sh.range_m + 2.0, "у дома: %.1f м" % _flat(sh.center, sh.home))
	eq(w.bus.pending.size(), 1, "выход из укрытия — без строки")

	pred.p = sh.center + side * 8.0  # вернулся через 24 с после строки — раньше FLEE_COOLDOWN
	w.run(0.1)
	ok(sh.alarm > 0.0, "снова тревога")
	eq(w.bus.pending.size(), 1, "раньше паузы — без новой строки")
	pred.p = away
	w.run(8.0)
	eq(sh.alarm, 0.0, "ушёл — спокойна")
	pred.p = sh.center + side * 8.0  # 32 с после строки
	w.run(0.1)
	eq(w.bus.pending.size(), 2, "после паузы — строка снова")


## Сцена 00→01 (решение ГД 08.11, `docs/urovni/sloj-1.md`): корабль на стоянке у 01 (33; −22), серпохвост у рифа
## между кораблём и краем тревоги кроны — стая кроны прячется в чашу со строкой. Разряд по корпусу (ShipState.zap)
## уводит его дальше CROWN_ALARM — тревога кроны спадает, стая снова кружит на кольце, новой строки о бегстве нет
## (только «Разряд отпугнул»): ответ экипажа читается последствием у цветка, а не шумом строк.
func test_zap_at_01_sends_pred_off_and_crown_returns() -> void:
	var w := _world()
	var fish := _fish(w)
	w.add(EcoFlower.new())
	var preds := w.add(EcoPred.new()) as EcoPred
	preds.alert = EcoPred.ALERT_ON  # явно: здесь не чутьё и бросок, хищник сыт
	var sh := fish.shoals[6]
	_only(w, fish, sh)
	var pr := preds.all[0]
	for other in preds.all.slice(1):  # остальные серпохвосты — далеко и не доплывут за проверку
		other.agent.p = Vector3(-400, -30, 400)
		other.agent.goal = other.agent.p
	var stand := Vector2(33.0, -22.0)
	w.ship.pos = Vector3(stand.x, Seabed.height(stand.x, stand.y) + 7.0, stand.y)
	w.ship.speed = 0.0
	w.ship.light_on = true
	w.ship.light_range = 40.0
	pr.agent.p = Vector3(-300, -30, -300)  # пока — далеко
	pr.agent.goal = pr.agent.p
	w.run(5.0)
	ok(sh.alarm == 0.0 and w.bus.pending.is_empty(), "без хищника спокойна")

	var out := Vector3(stand.x - sh.axis.x, 0, stand.y - sh.axis.z).normalized()  # от оси к стоянке и дальше
	pr.hunger = 0.0
	pr.cooldown = 30.0
	pr.agent.p = w.ship.pos + out * 12.0
	pr.agent.goal = pr.agent.p
	pr.agent.timer = 60.0
	var r0 := _flat(pr.agent.p, sh.axis)
	ok(r0 > EcoPred.REEF_KEEP and r0 < EcoFish.CROWN_ALARM, "хищник снаружи рифа, в тревоге кроны: %.1f м от оси" % r0)
	ok(pr.agent.distance_to(w.ship.pos) < EcoWorld.ZAP_RADIUS, "в радиусе разряда")
	w.step(0.05)
	ok(sh.alarm > 0.0, "тревога кроны")
	eq(w.bus.pending.size(), 1, "одна строка")
	eq(w.bus.pending[0].note, "flee")
	w.run(6.0)
	ok(sh.alarm > 0.0, "хищник у рифа — стая в тревоге")

	w.ship.zap = true
	w.step(0.05)
	w.ship.zap = false
	eq(pr.mode, EcoPred.Mode.FLEE, "разряд отпугнул")
	var calm_at := -1.0
	var nearest := INF  # ближе всего к оси после того, как тревога спала
	var back := 0  # шагов с тревогой после того, как она спала
	var t := 0.0
	while t < 30.0:
		w.step(0.05)
		t += 0.05
		if calm_at < 0.0 and sh.alarm <= 0.0:
			calm_at = t
		if calm_at >= 0.0:
			nearest = minf(nearest, _flat(pr.agent.p, sh.axis))
			if sh.alarm > 0.0:
				back += 1
	var ring := 0
	for f: EcoFish.Fish in sh.members:
		if _flat(f.agent.p, sh.axis) > EcoFlower.SPREAD:
			ring += 1
	var r := _flat(sh.center, sh.axis)
	print("    разряд: тревога кроны спала через %.2f с, хищник потом не ближе %.1f м к оси, на кольце %d из %d, центр %.1f м" % [
		calm_at, nearest, ring, sh.members.size(), r])
	ok(calm_at > 0.0 and calm_at < 12.0, "тревога спала: %.2f с" % calm_at)
	ok(nearest > EcoFish.CROWN_ALARM, "хищник не вернулся в тревогу кроны: %.1f м" % nearest)
	eq(back, 0, "стая не металась обратно в чашу")
	ok(ring >= sh.members.size() - 2, "снова снаружи кроны: %d из %d" % [ring, sh.members.size()])
	ok(r > EcoFish.CROWN_RING.x - 3.0 and r < EcoFish.CROWN_RING.y + 3.0, "центр стаи — на кольце: %.1f м" % r)
	var flee := 0
	var zap := 0
	for ev in w.bus.pending:
		if ev.note == "flee":
			flee += 1
		elif ev.note == "zap":
			zap += 1
	eq(flee, 1, "возврат без новой строки о бегстве")
	eq(zap, 1, "строка разряда — одна")


## Сцена 00→01, разбор (р): тест выше строит `EcoPred.new()` без стай, как отдельную проверку разряда. В игре
## (`EcoView`) хищник видит все стаи — `EcoPred.new(fish)`. Если оставить ему одну крону (`_only`), сытость кончается,
## а вся добыча спрятана в чаше и внутри REEF_KEEP: голодный патруль водит его по краю рифа (36–40 м от оси, внутри
## CROWN_ALARM), и крона прячется снова — это следствие пустого мира, не сцены. В полном мире после разряда он уходит
## и охотится на стаи вне рифа: крона спокойна, на кольце, строки кроны нет — так и закреплено. Мутация: разряд
## на хищника не действует (`on_zap` сразу `return`) — тревога кроны спадает только через 22,7 с.
func test_zap_at_01_in_full_world_pred_hunts_away_crown_stays() -> void:
	var w := _world()
	var fish := _fish(w)
	w.add(EcoFlower.new())
	var preds := w.add(EcoPred.new(fish)) as EcoPred  # как в EcoView: хищник видит все стаи
	preds.alert = EcoPred.ALERT_ON
	var sh := fish.shoals[6]
	ok(sh.crown, "стая 6 — у кроны")
	var pr := preds.all[0]
	for other in preds.all.slice(1):
		other.agent.p = Vector3(-400, -30, 400)
		other.agent.goal = other.agent.p
	var stand := Vector2(33.0, -22.0)
	w.ship.pos = Vector3(stand.x, Seabed.height(stand.x, stand.y) + 7.0, stand.y)
	w.ship.speed = 0.0
	w.ship.light_on = true
	w.ship.light_range = 40.0
	pr.agent.p = Vector3(-300, -30, -300)
	pr.agent.goal = pr.agent.p
	w.run(5.0)
	var out := Vector3(stand.x - sh.axis.x, 0, stand.y - sh.axis.z).normalized()
	pr.hunger = 0.0
	pr.cooldown = 30.0
	pr.agent.p = w.ship.pos + out * 12.0
	pr.agent.goal = pr.agent.p
	pr.agent.timer = 60.0
	w.step(0.05)
	w.run(6.0)
	ok(sh.alarm > 0.0, "хищник у рифа — крона в тревоге")
	var crown_lines := func() -> int:
		var n := 0
		for ev in w.bus.pending:
			if ev.note == "flee" and _flat(ev.pos, sh.axis) < EcoFish.CROWN_RING.y + 6.0:
				n += 1
		return n
	var lines0: int = crown_lines.call()
	ok(lines0 >= 1, "строка кроны есть: %d" % lines0)

	w.ship.zap = true
	w.step(0.05)
	w.ship.zap = false
	var calm_at := -1.0
	var nearest := INF
	var back := 0
	var hungry := 0.0  # самый сильный голод за минуту: голодный хищник выбирал, кого ловить
	var t := 0.0
	while t < 60.0:
		w.step(0.05)
		t += 0.05
		hungry = maxf(hungry, pr.hunger)
		if calm_at < 0.0 and sh.alarm <= 0.0:
			calm_at = t
		if calm_at >= 0.0:
			nearest = minf(nearest, _flat(pr.agent.p, sh.axis))
			if sh.alarm > 0.0:
				back += 1
	var ring := 0
	for f: EcoFish.Fish in sh.members:
		if _flat(f.agent.p, sh.axis) > EcoFlower.SPREAD:
			ring += 1
	var r := _flat(sh.center, sh.axis)
	print("    полный мир: тревога кроны спала через %.2f с, хищник потом не ближе %.1f м к оси, голод до %.2f, на кольце %d из %d, центр %.1f м" % [
		calm_at, nearest, hungry, ring, sh.members.size(), r])
	ok(calm_at > 0.0 and calm_at < 12.0, "тревога спала: %.2f с" % calm_at)
	ok(hungry > EcoPred.HUNT_HUNGER, "проверка не пустая: хищник был голоден (%.2f) и выбирал добычу" % hungry)
	ok(nearest > EcoFish.CROWN_ALARM, "минуту не возвращается в тревогу кроны: %.1f м" % nearest)
	eq(back, 0, "крона не прячется снова")
	ok(ring >= sh.members.size() - 2, "снаружи кроны: %d из %d" % [ring, sh.members.size()])
	ok(r > EcoFish.CROWN_RING.x - 3.0 and r < EcoFish.CROWN_RING.y + 3.0, "центр — на кольце: %.1f м" % r)
	eq(crown_lines.call(), lines0, "новой строки кроны нет")


## Сцена 00→01 (решение ГД 08.11, `docs/urovni/sloj-1.md`): у цветка угроза читается последствием, а не потерей —
## голодный серпохвост ходит у края рифа рядом со стоянкой (33; −22), но рыбок кроны не берёт: на кольце они внутри
## REEF_KEEP (кольцо 15–19 м от оси, риф — 32 м), в тревоге — в чаше. Он уходит за край тревоги кроны и
## возвращается — стаи то в чаше, то на кольце, но целы (22 из 22), добычей он их не выбирает и в риф за ними не
## заходит. Других, кто ест рыбок кроны, у 01 нет (вуали — у (85; 25) и (−28; 42), угорь — у (−62; −8)).
func test_hungry_pred_at_01_takes_no_crown_fish() -> void:
	var w := _world()
	var fish := _fish(w)
	w.add(EcoFlower.new())
	var preds := w.add(EcoPred.new(fish)) as EcoPred
	preds.alert = EcoPred.ALERT_ON  # явно: корабль в рифе, бросков нет — здесь только охота на рыбок
	var crown: Array[EcoFish.Shoal] = []
	for sh in fish.shoals:
		if sh.crown:
			crown.append(sh)
		else:
			for f: EcoFish.Fish in sh.members:
				w.agents.erase(f.agent)
	eq(crown.size(), EcoFish.CROWN_SHOALS)
	fish.shoals.assign(crown)
	var keep: Array[EcoFish.Fish] = []
	for sh in crown:
		keep.append_array(sh.members)
	fish.all.assign(keep)
	var pr := preds.all[0]
	for other in preds.all.slice(1):  # остальные серпохвосты — далеко и не доплывут за проверку
		other.agent.p = Vector3(-400, -30, 400)
		other.agent.goal = other.agent.p
	var stand := Vector2(33.0, -22.0)
	w.ship.pos = Vector3(stand.x, Seabed.height(stand.x, stand.y) + 7.0, stand.y)
	w.ship.speed = 0.0
	w.ship.light_on = true
	w.ship.light_range = 40.0
	var axis := crown[0].axis
	ok(_flat(w.ship.pos, axis) < EcoPred.REEF_KEEP, "стоянка — в рифе: корабль хищнику не цель")
	var out := Vector3(stand.x - axis.x, 0, stand.y - axis.z).normalized()
	pr.agent.p = Vector3(axis.x, -30.0, axis.z) + out * EcoPred.REEF_EDGE  # у края рифа со стороны стоянки
	pr.agent.goal = pr.agent.p
	pr.hunger = 1.0
	pr.cooldown = 30.0
	var nearest := INF  # ближе всего хищник к оси
	var lost := 0  # рыбок кроны съедено
	var crown_prey := 0  # шагов охоты за рыбкой кроны
	var hunts := 0  # шагов охоты вообще
	var on_ring := 0.0  # секунд, когда хищник за краем тревоги кроны, а стаи на кольце в его досягаемости
	var t := 0.0
	var hold := Vector3.INF
	while t < 60.0:
		pr.hunger = 1.0  # голоден всё время
		if t >= 20.0 and t < 35.0:  # 15 с держится за краем тревоги кроны со стороны стаи: та выходит на кольцо
			if not hold.is_finite():
				var side := Vector3(crown[0].center.x - axis.x, 0, crown[0].center.z - axis.z)
				side = side.normalized() if side.length() > 1.0 else out
				hold = Vector3(axis.x, -30.0, axis.z) + side * (EcoFish.CROWN_ALARM + 6.0)
			pr.agent.p = hold
			pr.agent.goal = hold
		w.step(0.05)
		t += 0.05
		nearest = minf(nearest, _flat(pr.agent.p, axis))
		if pr.mode == EcoPred.Mode.HUNT:
			hunts += 1
			if pr.prey != null and pr.prey.shoal.crown:
				crown_prey += 1
		if _flat(pr.agent.p, axis) > EcoFish.CROWN_ALARM and crown[0].alarm <= 0.0 \
				and pr.agent.p.distance_to(crown[0].center) < EcoPred.HUNT_RADIUS:
			on_ring += 0.05
		for ev in w.bus.pending:
			if ev.species == "pred" and ev.note == "catch":
				lost += 1
		w.bus.pending.clear()
	var alive := 0
	for f: EcoFish.Fish in fish.all:
		if f.agent.alive:
			alive += 1
	print("    голодный у 01: 60 с, ближе всего %.1f м к оси, охоты %.1f с (за кроной %.1f с), стаи на кольце в досягаемости %.1f с, живых %d из %d" % [
		nearest, hunts * 0.05, crown_prey * 0.05, on_ring, alive, fish.all.size()])
	ok(on_ring > 5.0, "стаи на кольце бывали в досягаемости хищника: %.1f с" % on_ring)
	eq(crown_prey, 0, "рыбку кроны добычей не выбирает")
	eq(lost, 0, "улова нет")
	eq(alive, fish.all.size(), "стаи кроны целы")
	ok(nearest > EcoPred.REEF_KEEP - 1.0, "в риф не заходит: %.1f м" % nearest)


## Сцена 00→01 (решение ГД 08.11, `docs/urovni/sloj-1.md`; #834 «читаемая встреча»): корабль на стоянке у 01
## (33; −22) носом к цветку, луч на полной силе (45 м), серпохвост далеко за рифом. Импульс сонара у цветка зовёт его к внешнему краю
## рифа (EcoPred.REEF_EDGE, 42 м от оси) со своей стороны, а не к кораблю. С какой бы стороны он ни шёл, стая кроны
## прячется в чашу со строкой раньше, чем он дошёл до края (на 1,2–1,8 с при CROWN_ALARM 50 м; при 42 м — после),
## внутрь кольца EcoPred.REEF_KEEP он не заходит и в луч (EcoWorld.in_beam) за 30 с не входит: угрозу видно
## последствием у цветка, а не встречей.
func test_ping_at_01_calls_pred_to_edge_crown_hides_first() -> void:
	for k in 8:
		_ping_at_01_from(TAU * k / 8.0)


func _ping_at_01_from(bearing: float) -> void:
	var w := _world()
	var fish := _fish(w)
	w.add(EcoFlower.new())
	var preds := w.add(EcoPred.new(fish)) as EcoPred  # как в игре (EcoView): риф у цветка знает стаи кроны
	preds.alert = EcoPred.ALERT_ON  # явно: здесь не чутьё и бросок, хищник сыт
	var sh := fish.shoals[6]
	ok(sh.crown, "стая кроны")
	_only(w, fish, sh)
	var pr := preds.all[0]
	for other in preds.all.slice(1):  # остальные серпохвосты — далеко и не доплывут за проверку
		other.agent.p = Vector3(-400, -30, 400)
		other.agent.goal = other.agent.p
	var stand := Vector2(33.0, -22.0)
	w.ship.pos = Vector3(stand.x, Seabed.height(stand.x, stand.y) + 7.0, stand.y)
	w.ship.yaw = atan2(-(sh.axis.x - stand.x), -(sh.axis.z - stand.y))  # нос к цветку
	w.ship.speed = 0.0
	w.ship.light_on = true
	w.ship.light_range = Searchlight.BASE_RANGE  # полная сила лампы: луч EcoWorld.BEAM_R = 45 м
	ok(w.in_beam(Vector3(sh.axis.x, w.ship.pos.y - 4.0, sh.axis.z)), "луч смотрит на цветок")
	ok(_flat(w.ship.pos, sh.axis) < EcoPred.REEF_KEEP, "стоянка — в рифе")
	pr.hunger = -2.0  # сыт весь прогон — не бросается
	pr.cooldown = 60.0
	pr.agent.p = Vector3(sh.axis.x + cos(bearing) * 110.0, -30.0, sh.axis.z + sin(bearing) * 110.0)
	pr.agent.goal = pr.agent.p
	pr.agent.timer = 60.0
	w.run(3.0)
	ok(sh.alarm == 0.0 and w.bus.pending.is_empty(), "до импульса стая спокойна, строк нет")
	ok(not w.in_beam(pr.agent.p), "хищник не в луче")

	preds.on_ping(w, w.ship.pos)
	eq(pr.mode, EcoPred.Mode.INVESTIGATE, "услышал импульс")
	near(_flat(pr.agent.goal, sh.axis), EcoPred.REEF_EDGE, 1e-3, "плывёт к внешнему краю рифа")
	ok(_flat(pr.agent.goal, w.ship.pos) > 10.0, "не к кораблю")
	var hide_at := -1.0
	var beam_at := -1.0
	var edge_at := -1.0
	var nearest := INF  # ближе всего к оси рифа за прогон
	var t := 0.0
	while t < 30.0:
		w.step(0.05)
		t += 0.05
		if hide_at < 0.0 and sh.alarm > 0.0:
			hide_at = t
		if beam_at < 0.0 and w.in_beam(pr.agent.p):
			beam_at = t
		var r := _flat(pr.agent.p, sh.axis)
		if edge_at < 0.0 and r < EcoPred.REEF_EDGE + 3.0:
			edge_at = t
		nearest = minf(nearest, r)
	var flee: Array[String] = []
	for ev in w.bus.pending:
		if ev.note == "flee":
			flee.append(ev.text())
	print("    импульс у 01, хищник с %3d°: крона прячется через %.2f с, в луче через %.2f с, у края через %.2f с, к оси не ближе %.1f м" % [
		int(round(rad_to_deg(bearing))), hide_at, beam_at, edge_at, nearest])
	ok(edge_at > 0.0, "дошёл до края рифа")
	ok(hide_at > 0.0, "стая кроны спряталась")
	ok(hide_at < edge_at, "раньше, чем хищник дошёл до края рифа: %.2f < %.2f с" % [hide_at, edge_at])
	ok(beam_at < 0.0, "в луч он так и не вошёл: %.2f с" % beam_at)
	ok(nearest > EcoPred.REEF_KEEP, "в риф не зашёл: %.1f м от оси" % nearest)
	eq(flee.size(), 1, "одна строка о бегстве")
	ok(flee.size() == 1 and "крону" in flee[0], "строка: прячется в крону")
	eq(w.hits, 0, "удара нет")


func test_ship_under_way_scares_without_message() -> void:
	var w := _world()
	var fish := _fish(w)
	var sh := fish.shoals[0]
	w.run(8.0)
	w.ship.pos = sh.center + Vector3(3, 0, 0)
	w.ship.speed = 0.5  # медленно — не пугает
	w.step(0.05)
	eq(sh.alarm, 0.0, "медленный корабль не пугает")
	w.ship.speed = -2.0  # задний ход тоже шумит
	w.step(0.05)
	ok(sh.alarm > 0.0, "быстрый — пугает")
	ok(sh.threat_is_ship, "угроза — корабль")
	var close := _mean_to(sh, w.ship.pos)
	w.run(2.0)
	ok(_mean_to(sh, w.ship.pos) > close + 4.0, "рыбки шарахаются от корабля")
	eq(w.bus.pending.size(), 0, "корабль не хищник — сообщения нет")


func test_eaten_fish_returns_home() -> void:
	var w := _world()
	var fish := _fish(w)
	w.run(1.0)
	var f := fish.all[5]
	var at := f.agent.p
	fish.kill(f)
	ok(not f.agent.alive, "съедена")
	eq(w.count("fish"), ALL - 1)
	ok(fish.nearest_fish(at, 50.0) != f, "съеденную не ловят")
	ok(fish.nearest_fish(at, 50.0, func(_x: EcoFish.Fish) -> bool: return true) == null, "все в укрытии — ловить некого")
	w.run(24.0)
	ok(not f.agent.alive, "не раньше 25 с")
	w.run(16.5)
	ok(f.agent.alive, "вернулась")
	eq(w.count("fish"), ALL)
	ok(f.agent.p.distance_to(f.shoal.home) < 32.0, "вернулась к своей стае")


func _snapshot(fish: EcoFish) -> String:
	var parts := PackedStringArray()
	for f in fish.all:
		parts.append(var_to_str(f.agent.p))
	return "|".join(parts)


func test_same_seed_same_shoals() -> void:
	var a := _world()
	var b := _world()
	var c := _world(7)
	a.run(10.0)
	b.run(10.0)
	c.run(10.0)
	eq(_snapshot(_fish(a)), _snapshot(_fish(b)), "одно зерно — одни стаи")
	ok(_snapshot(_fish(a)) != _snapshot(_fish(c)), "другое зерно — другие")
	a.reset()
	eq(_fish(a).all.size(), ALL)
	a.run(10.0)
	eq(_snapshot(_fish(b)), _snapshot(_fish(a)), "сброс возвращает стаи в начало")


func test_scanned_fish_is_named() -> void:
	var w := _world()
	w.scanned = func(sp: String) -> bool: return sp == "fish"
	w.ship.pos = _fish(w).shoals[2].home + Vector3(0, 0, 40)  # ближе MID: стая шагает каждый шаг мира, не по очереди дальних (issue #803)
	w.spawn("pred", _fish(w).shoals[2].center)
	w.step(0.05)
	var ev := w.bus.take()
	eq(ev.size(), 1)
	eq(ev[0].text(), "Светляк-полосник: стая уходит в кораллы — рядом хищник")


func test_flee_message_reaches_ship_nearby() -> void:
	var w := _world()
	var sh := _fish(w).shoals[0]
	w.ship.pos = sh.home + Vector3(0, 10, 40)  # в 80 м слышно, корабль стоит
	w.spawn("pred", sh.center + Vector3(4, 0, 0))
	w.step(0.05)
	var link := w.take_link()
	eq(link.size(), 1, "одно событие: наблюдение и текст вместе")
	eq(link[0]["type"], EcoLink.OBSERVE)
	eq([link[0]["species"], link[0]["note"]], ["fish", "flee"], "заметка журнала")
	eq(link[0]["text"], "Мелкая рыба: стая уходит в кораллы — рядом хищник")


## Сцена 00→01, п. 2 (у) dev-b.md: строка бегства стаи рифа и стаи кроны у 01 собирается, когда корабль забирает
## события (`take_link` → `EcoBus.Event.text()`), а не когда стая испугалась: вид изучен сканером между событием и
## показом — на приборах уже настоящее имя. Без мира (`w` = null в замыкании) — описательное. Без Main.
func test_flee_text_names_fish_scanned_after_event() -> void:
	for k in [0, EcoFish.HOMES.size()]:  # стая рифа и первая стая кроны (после HOMES)
		var w := _world()
		var known := [false]
		w.scanned = func(sp: String) -> bool: return known[0] and sp == "fish"
		var sh := _fish(w).shoals[k]
		eq(sh.crown, k > 0, "стая %d — %s" % [k, "крона" if k > 0 else "риф"])
		w.ship.pos = sh.home + Vector3(0, 10, 40)
		w.spawn("pred", sh.center + Vector3(4, 0, 0))
		w.step(0.05)
		var pending := w.bus.pending.filter(func(e: EcoBus.Event) -> bool: return e.note == "flee")
		eq(pending.size(), 1, "стая %d испугалась — событие в очереди, корабль его ещё не забрал" % k)
		known[0] = true  # биолог изучил вид, пока строка не показана
		var link := w.take_link()
		eq(link.size(), 1)
		var text: String = link[0]["text"]
		print("  стая %d: «%s»" % [k, text])
		ok(text.begins_with(Species.cap(Species.called("fish", Species.Case.NOM, true)) + ":"),
				"имя — изученное, на момент показа")
		ok(not text.contains(Species.cap(Species.called("fish", Species.Case.NOM, false))), "описательного имени нет")


# ---------- Вид рыбки (EcoFishLook) ----------

func _find(x: float, y: float, z: float) -> int:
	for i in EcoFishLook.shape.size():
		if EcoFishLook.shape[i].distance_to(Vector3(x, y, z)) < 1e-4:
			return i
	ok(false, "нет вершины (%f, %f, %f)" % [x, y, z])
	return 0


## Момент, когда рыбка не виляет: sin(t·частота особи + фаза) = 0.
func _straight(f: EcoFish.Fish) -> float:
	return -f.phase / EcoFishLook.wiggle_rate(f)


func _close(want: Vector3, got: Vector3, msg: String) -> void:
	ok(want.distance_to(got) < 1e-3, "%s: ждали %s, вышло %s" % [msg, want, got])


func test_spindle_with_four_stripes() -> void:
	var s := EcoFishLook.shape
	eq(EcoFishLook.paints.size(), s.size())
	eq(EcoFishLook.normals.size(), s.size())
	ok(EcoFishLook.tris.size() / 3 < 150, "до 150 треугольников, как в ART-011")
	for i in EcoFishLook.tris:
		if not ok(i >= 0 and i < s.size(), "номер вершины в форме"):
			return
	var stripes := 0
	for b in EcoFishLook.RING_STRIPE:
		if b:
			stripes += 1
	eq(stripes, 4, "четыре полосы")
	eq(EcoFishLook.paints[EcoFishLook.stripe_vertex], EcoFishLook.Paint.STRIPE)
	var mx := 0.0
	var my := 0.0
	var mn_z := 0.0
	var mx_z := 0.0
	for p in s:
		mx = maxf(mx, p.x)
		my = maxf(my, p.y)
		mn_z = minf(mn_z, p.z)
		mx_z = maxf(mx_z, p.z)
	near(mx_z, 0.28, 1e-5, "нос")
	near(mn_z, -0.42, 1e-5, "хвост")
	ok(mx >= 0.06 and mx <= 0.07, "полуширина")
	ok(my >= 0.1 and my <= 0.121, "спина и хвост")
	eq(EcoFishLook.paints[_find(0, 0.12, -0.42)], EcoFishLook.Paint.FIN, "концы хвоста светятся")
	eq(EcoFishLook.paints[_find(0, 0, 0.28)], EcoFishLook.Paint.BODY, "нос тёмный")


func test_body_closed_faces_out_by_godot_rule() -> void:
	var s := EcoFishLook.shape
	var t := EcoFishLook.tris
	var fin := _find(0, 0.12, -0.42)
	var vol := 0.0
	var edges := {}
	var fin_tris := 0
	for i in range(0, t.size(), 3):
		if t[i] == fin or t[i + 1] == fin or t[i + 2] == fin:
			fin_tris += 1
			continue
		vol += s[t[i]].dot(s[t[i + 1]].cross(s[t[i + 2]])) / 6.0
		for k in 3:
			var e := t[i + k] * 1000 + t[i + (k + 1) % 3]
			edges[e] = edges.get(e, 0) + 1
	# по правилу Godot (b − a) × (c − a) смотрит внутрь — объём со знаком минус
	ok(vol < 0.0, "грани тела смотрят наружу по правилу Godot: %f" % vol)
	for e: int in edges:
		if not eq(edges[e], 1, "ребро тела один раз в каждую сторону"):
			return
		if not ok(edges.has((e % 1000) * 1000 + e / 1000), "тело замкнуто"):
			return
	eq(fin_tris, 2, "хвост — один треугольник в обе стороны")


func test_nose_follows_velocity() -> void:
	var w := _world()
	var f := _fish(w).all[0]
	f.agent.v = Vector3(3, 0, 0)
	var p := f.agent.p
	var t := _straight(f)
	var k := EcoFishLook.scale(f)
	_close(p + Vector3(0.28, 0, 0) * k, EcoFishLook.place(f, t, _find(0, 0, 0.28)), "нос по ходу")
	_close(p + Vector3(-0.25, 0, 0) * k, EcoFishLook.place(f, t, _find(0, 0, -0.25)), "корма сзади")
	_close(p + Vector3(-0.42, 0.12, 0) * k, EcoFishLook.place(f, t, _find(0, 0.12, -0.42)), "хвост позади и вверх")
	var side := EcoFishLook.shape[EcoFishLook.stripe_vertex]
	ok(side.x > 0.05, "вершина полосы — на боку")
	_close(p + Vector3(side.z, 0, -side.x) * k, EcoFishLook.place(f, t, EcoFishLook.stripe_vertex), "бок поперёк хода")
	near(EcoFishLook.basis(f, t).determinant(), k * k * k, 1e-3, "поворот без зеркала — грани не выворачиваются")


func test_wiggle_within_025() -> void:
	var w := _world()
	var f := _fish(w).all[3]
	f.agent.v = Vector3(0, 0, -2)
	var mx := 0.0
	for i in 200:
		var fw := EcoFishLook.forward(f, i * 0.013)
		if not near(fw.length(), 1.0, 1e-4, "курс единичный"):
			return
		mx = maxf(mx, acos(minf(1.0, -fw.z)))
	ok(mx <= EcoFishLook.WIGGLE + 1e-3, "не больше 0,25 рад")
	ok(mx > 0.2, "виляет заметно")


func test_vertical_and_still_do_not_break() -> void:
	var w := _world()
	var f := _fish(w).all[5]
	f.agent.v = Vector3(0, 2, 0)
	_close(f.agent.p + Vector3(0, 0.28 * EcoFishLook.scale(f), 0), EcoFishLook.place(f, 1.3, _find(0, 0, 0.28)),
		"плывёт вверх — нос вверх")
	f.agent.v = Vector3.ZERO
	var b := EcoFishLook.basis(f, 1.3)
	for v in [b.x, b.y, b.z]:
		ok(not (is_nan(v.x) or is_nan(v.y) or is_nan(v.z)), "без NaN")


func test_eaten_fish_invisible() -> void:
	var w := _world()
	var fish := _fish(w)
	var f := fish.all[7]
	fish.kill(f)
	for i in EcoFishLook.verts_per_fish():
		if not eq(EcoFishLook.place(f, 0.0, i), f.agent.p, "все вершины в одной точке"):
			return


func test_stripes_shoal_colour_body_dark() -> void:
	var w := _world()
	var fish := _fish(w)
	for s in fish.shoals.size():
		var f: EcoFish.Fish = fish.shoals[s].members[0]
		var c := EcoFish.COLORS[s % EcoFish.COLORS.size()]
		ok(c.b > c.r, "полосы в голубой гамме: синего больше красного")
		var st := EcoFishLook.stripe(f)
		near(st.r, c.r * f.bright, 1e-4)
		near(st.g, c.g * f.bright, 1e-4)
		near(st.b, c.b * f.bright, 1e-4)
		near(EcoFishLook.vertex_color(f, EcoFishLook.Paint.FIN).g, st.g * EcoFishLook.FIN_GLOW, 1e-4, "концы хвоста тише")
		var body := EcoFishLook.vertex_color(f, EcoFishLook.Paint.BODY)
		var sd := EcoFishLook.shade(f)
		near(body.r, 0x34 / 255.0 * sd, 1e-4, "тело #344F63 своего оттенка")
		near(body.g, 0x4F / 255.0 * sd, 1e-4)
		near(body.b, 0x63 / 255.0 * sd, 1e-4)
	var f0: EcoFish.Fish = fish.shoals[0].members[0]
	var g0 := EcoFishLook.stripe(f0).g
	fish.shoals[0].alarm = 2.0
	eq(EcoFishLook.vertex_color(f0, EcoFishLook.Paint.BODY), EcoFishLook.body_color(f0), "в тревоге тело не меняется")
	near(EcoFishLook.stripe(f0).g, g0 * EcoFishLook.ALARM_GLOW, 1e-4, "полосы ярче")


func test_ship_under_way_lights_shoal_up() -> void:
	var w := _world()
	var sh := _fish(w).shoals[2]
	var f: EcoFish.Fish = sh.members[0]
	near(EcoFishLook.brightness(f), f.bright, 1e-6, "спокойная стая — своя яркость")
	w.ship.pos = sh.center + Vector3(3, 0, 0)
	w.ship.speed = 3.0
	w.step(0.05)
	near(EcoFishLook.brightness(f), f.bright * EcoFishLook.ALARM_GLOW, 1e-5, "в тревоге ярче")
	w.ship.pos = Vector3(500, 0, 500)
	w.run(3.0)
	near(EcoFishLook.brightness(f), f.bright, 1e-6, "угроза ушла — гаснет обратно")


## Волна хвоста (Б3): голова жёсткая, изгиб растёт к кончику хвоста; волна бежит к хвосту; «Экономно» гасит.
func test_tail_wave_bends_tail_not_head() -> void:
	eq(EcoFishLook.tail_bend(EcoFishLook.NOSE), 0.0, "нос не гнётся")
	eq(EcoFishLook.tail_bend(EcoFishLook.TAIL_FROM), 0.0, "голова до TAIL_FROM жёсткая")
	near(EcoFishLook.tail_bend(EcoFishLook.TAIL_TIP), 1.0, 1e-6, "кончик хвоста гнётся целиком")
	ok(EcoFishLook.tail_bend(-0.22) < EcoFishLook.tail_bend(-0.35), "к кончику сильнее")
	var most := 0.0
	var head := 0.0
	for k in 200:
		var t := k * 0.013
		most = maxf(most, absf(EcoFishLook.tail_wave(EcoFishLook.TAIL_TIP, t, 0.3)))
		head = maxf(head, absf(EcoFishLook.tail_wave(0.2, t, 0.3)))
	eq(head, 0.0, "голова стоит")
	ok(most > EcoFishLook.TAIL_AMP * 0.9 and most <= EcoFishLook.TAIL_AMP + 1e-6, "кончик ходит на ±TAIL_AMP")
	eq(EcoFishLook.tail_wave(EcoFishLook.TAIL_TIP, 0.7, 0.3, 0.0), 0.0, "«Экономно» — без волны")
	# бегущая волна: гребень у корня хвоста догоняется кончиком чуть позже
	var a := 0.3
	var rate := EcoFishLook.TAIL_RATE * (1.0 - EcoFishLook.TAIL_RATE_SPREAD
		+ 2.0 * EcoFishLook.TAIL_RATE_SPREAD * fposmod(a * 7.13, 1.0))
	var dt := (-0.1 - EcoFishLook.TAIL_TIP) * EcoFishLook.TAIL_K / rate
	var root := EcoFishLook.tail_wave(-0.1, 0.5, a) / EcoFishLook.tail_bend(-0.1)
	var tip := EcoFishLook.tail_wave(EcoFishLook.TAIL_TIP, 0.5 + dt, a) / EcoFishLook.TAIL_AMP
	near(root / EcoFishLook.TAIL_AMP, tip, 1e-4, "волна бежит к кончику")


## У рыбок одной стаи фазы хвоста разные — машут вразнобой.
func test_tail_phase_differs_in_shoal() -> void:
	var w := _world()
	var fish := _fish(w)
	var phases := {}
	for f: EcoFish.Fish in fish.shoals[0].members:
		var a := EcoFishLook.tail_phase(f)
		ok(a >= 0.0 and a < 1.0, "фаза — доля оборота")
		phases[snappedf(a, 0.01)] = true
	ok(phases.size() > fish.shoals[0].members.size() / 2, "фазы разные")


# ---------- В сцене ----------

func test_view_one_multimesh_follows_world() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var fv := view.fish_view
	ok(fv != null and fv.get_parent() == view, "светляки — в живом мире")
	eq(fv.multimesh.instance_count, ALL, "один MultiMesh на всех")
	eq(fv.layers, OceanView.LAYER_WORLD, "слой отмели")
	var ship := EcoLink.ShipState.new()
	var f := view.fish.all[10]
	ship.pos = f.shoal.home + Vector3(0, 0, 40)  # ближе MID: стая шагает каждый шаг мира, не по очереди дальних (issue #803)
	for i in 20:
		view.step(0.05, ship)
	var tr := FishView.transform_at(fv.buffer, f.index)
	ok(tr.origin.distance_to(f.agent.p) < 1e-3, "место рыбки — из мира")
	_close(EcoFishLook.forward(f, view.world.time) * EcoFishLook.scale(f), tr.basis * Vector3(0, 0, 1), "нос по курсу")
	_close(EcoFishLook.basis(f, view.world.time).x, tr.basis.x, "расстановка — как EcoFishLook.basis")
	_close(EcoFishLook.basis(f, view.world.time).y, tr.basis.y, "спина с креном — как EcoFishLook.basis")
	near(FishView.shade_at(fv.buffer, f.index), EcoFishLook.shade(f), 1e-5, "оттенок тела особи")
	near(FishView.tail_phase_at(fv.buffer, f.index), EcoFishLook.tail_phase(f), 1e-5, "фаза хвоста — в альфе цвета")
	var mat := fv.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	var code := mat.shader.code
	ok(code.contains("VERTEX.x +=") and code.contains("%.5f" % EcoFishLook.TAIL_K)
		and code.contains("%.5f" % EcoFishLook.TAIL_AMP), "волна хвоста в шейдере — числа из EcoFishLook")
	EcoShaders.set_sway_lite(true)
	eq(mat.get_shader_parameter("sway_k"), 0.0, "«Экономно» гасит волну хвоста")
	EcoShaders.set_sway_lite(false)
	eq(mat.get_shader_parameter("sway_k"), 1.0, "и возвращает")
	ok(fv.buffer.size() == ALL * FishView.STRIDE, "буфер на всех рыбок")
	var c := FishView.stripe_at(fv.buffer, f.index)
	near(c.g, EcoFishLook.stripe(f).g, 1e-3, "цвет полос стаи")
	view.fish.kill(f)
	view.step(0.05, ship)
	eq(FishView.transform_at(fv.buffer, f.index).basis, Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO),
		"съеденная стянута в точку")
	view.queue_free()
	await frames(1)



## «Экономно» (Б6): в каждой стае рисуются две рыбки из трёх — видимые в начале буфера; мир считает всех, назад —
## буфер снова по номеру рыбки.
func test_view_lite_draws_two_of_three_per_shoal() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var fv := view.fish_view
	eq(fv.drawn(), ALL, "на «Обычно» — все рыбки")
	view.set_lite(true)
	ok(fv.lite, "вид рыбок — на «Экономно»")
	var shown := 0
	for sh: EcoFish.Shoal in view.fish.shoals:
		var n := 0
		for f: EcoFish.Fish in sh.members:
			if fv.slot_of(f.index) < fv.drawn():
				n += 1
		eq(n, sh.members.size() - sh.members.size() / FishView.LITE_SKIP, "в стае %d — две из трёх" % sh.members.size())
		ok(n > 0, "каждая стая видна")
		shown += n
	eq(fv.drawn(), shown, "рисуются ровно видимые")
	ok(fv.drawn() < ALL * 0.7, "рыбок меньше на треть: %d из %d" % [fv.drawn(), ALL])
	var seen := {}
	for f: EcoFish.Fish in view.fish.all:
		seen[fv.slot_of(f.index)] = true
	eq(seen.size(), ALL, "места в буфере не повторяются")
	var f: EcoFish.Fish = view.fish.shoals[0].members[0]
	var ship := EcoLink.ShipState.new()
	ship.pos = f.shoal.home + Vector3(0, 0, 40)
	for i in 10:
		view.step(0.05, ship)
	ok(FishView.transform_at(fv.buffer, fv.slot_of(f.index)).origin.distance_to(f.agent.p) < 1e-3,
		"видимая рыбка — на своём месте буфера")
	view.set_lite(false)
	view.step(0.05, ship)
	eq(fv.drawn(), ALL, "назад — все рыбки")
	eq(fv.slot_of(f.index), f.index, "буфер снова по номеру")
	ok(FishView.transform_at(fv.buffer, f.index).origin.distance_to(f.agent.p) < 1e-3, "и места переписаны")
	view.queue_free()
	await frames(1)

## «Между рёбрами прячется молодь» (ART-030): стайка мелких светляков бродит внутри чистого прохода клетки
## Костей левиафана, в кость не заходит, от хищника прячется в середине клетки.
func test_young_hide_between_ribs() -> void:
	var w := _world()
	var fish := _fish(w)
	var bones := w.add(EcoBones.new()) as EcoBones
	var sh: EcoFish.Shoal = fish.shoals[8]
	ok(sh.cage and not sh.crown, "девятая стая — молодь в костях, номера прежних не сдвинулись")
	eq(sh.members.size(), EcoFish.JUV_PER, "14 мальков")
	_only(w, fish, sh)  # у молоди свой генератор (cage_rnd) — без других стай она идёт так же
	for f: EcoFish.Fish in sh.members:
		near(f.size, EcoFish.JUV_SIZE, 1e-6, "мельче взрослых")
		near(EcoFishLook.basis(f, 0.0).x.length(), EcoFish.JUV_SIZE * EcoFishLook.scale(f) / f.size, 1e-4, "и в форме")
		ok(EcoFishLook.scale(f) <= EcoFish.JUV_SIZE * (1.0 + EcoFishLook.SIZE_SPREAD) + 1e-5, "малёк мельче взрослых")
	var hl := bones.to_local(sh.home)
	ok(absf(hl.x) < 0.01 and absf(hl.z) < 0.01, "дом — в середине клетки")
	ok(not bones.solid(sh.home), "в доме костей нет")
	var samples := 0
	var in_bone := 0
	var halves := [0, 0]
	for s in 240:
		w.run(0.5)
		var c := bones.to_local(sh.center)
		if not ok(absf(c.x) < EcoBones.PASS_W * 0.5 and absf(c.z) < EcoBones.CAGE_LEN * 0.5 + 1.0
				and c.y > bones.floor_y(sh.center.x, sh.center.z) and c.y < bones.pass_floor(c.z) + EcoBones.PASS_H,
				"%d с: стая в проходе клетки (%s)" % [s / 2, c]):
			return
		halves[0 if c.z < 0.0 else 1] += 1
		for f: EcoFish.Fish in sh.members:
			samples += 1
			if bones.solid(f.agent.p):
				in_bone += 1
	ok(halves[0] > 20 and halves[1] > 20, "бродит по всей клетке: %s" % [halves])
	ok(in_bone * 100 <= samples, "сквозь кость почти не плывут: %d из %d" % [in_bone, samples])
	eq(sh.alarm, 0.0, "без угроз спокойна")
	var pred := w.spawn("pred", sh.center + Vector3(6, 0, 0))
	w.run(8.0)
	ok(sh.alarm > 0.0, "хищник рядом — тревога")
	ok(_mean_to(sh, sh.home) < 4.0, "прячется в середине клетки")
	pred.alive = false


## Б3, tools/jerk.gd place=01: рыбка всплывает почти отвесно, ход по горизонтали мал и меняет знак — нос не проходит
## через вертикаль, бок тела не переворачивается за кадр (раньше — до 3 рад за кадр), тангаж не круче PITCH_MAX.
func test_steep_swim_keeps_side() -> void:
	var dt := 1.0 / 30.0
	var look := Vector3.ZERO
	var side := Vector3.ZERO
	var worst := 0.0
	var steep := 0.0
	for i in 300:
		var sway := 0.12 * (1.0 if (i / 7) % 2 == 0 else -1.0)   # ход вбок дёргается туда-сюда
		var v := Vector3(sway, 0.5 if i < 150 else -0.5, 0.03 * sin(i * 0.3))
		look = EcoFish.turn(look, v, dt)
		near(look.length(), 1.0, 1e-5, "нос единичный")
		steep = maxf(steep, absf(asin(clampf(look.y, -1.0, 1.0))))
		var s := Vector3(look.z, 0.0, -look.x).normalized()
		if side != Vector3.ZERO:
			worst = maxf(worst, side.angle_to(s))
		side = s
	ok(steep <= EcoFish.PITCH_MAX + 1e-4, "тангаж носа не круче PITCH_MAX: %.2f" % steep)
	ok(worst <= EcoFish.LOOK_MAX * dt + 1e-3, "бок за кадр — не больше LOOK_MAX · dt: %.3f рад" % worst)
	look = EcoFish.turn(Vector3(0, 0, 1), Vector3(0, 2, 0), dt)
	ok(Vector2(look.x, look.z).length() > 0.5 and look.z > 0.0, "отвесно вверх — курс прежний, нос поднимается")


## #1400: стая кроны в тревоге всплывает почти отвесно, снос вбок 0,03–0,15 м/с меняет знак — курс носа не мотает за
## ним (было: ±0,3 рад за 0,1 с, угловое ускорение до 170 рад/с² в tools/jerk.gd scena=3). По горизонтали — как было.
func test_near_vertical_swim_does_not_wobble_heading() -> void:
	var dt := 1.0 / 30.0
	var look := Vector3(0, 0, 1)
	var yaws: Array[float] = []
	for i in 240:
		var sway := 0.1 * (1.0 if (i / 6) % 2 == 0 else -1.0)
		look = EcoFish.turn(look, Vector3(sway, 0.55, 0.02), dt)
		yaws.append(atan2(look.x, look.z))
	var worst := 0.0   # угловое ускорение курса по отсчётам через 3 кадра, как tools/jerk.gd
	var k := 3.0 * dt
	for i in range(6, yaws.size()):
		var w1 := wrapf(yaws[i - 3] - yaws[i - 6], -PI, PI) / k
		var w2 := wrapf(yaws[i] - yaws[i - 3], -PI, PI) / k
		worst = maxf(worst, absf(w2 - w1) / k)
	ok(worst < 30.0, "курс почти отвесной рыбки не мотает: %.1f рад/с²" % worst)
	near(EcoFish.flat_k(1.0), 1.0, 1e-6, "по горизонтали — курс в полную силу")
	near(EcoFish.flat_k(EcoFish.FLAT_MIN), 0.0, 1e-6, "у FLAT_MIN — курс стоит, как отвесно")
	var flat := EcoFish.turn(Vector3(1, 0, 0), Vector3(0, 0, 3), dt)
	near(Vector3(1, 0, 0).angle_to(flat), EcoFish.LOOK_MAX * dt, 1e-4, "по горизонтали поворот прежний")


## Б3, вторичное движение (#1400): в повороте рыбка ложится на бок спиной к центру поворота, крен копится и
## уходит плавно — разворот стаи кроны читается вспышкой боков, а не поворотом плоских фигурок.
func test_tail_arcs_into_turn() -> void:
	# оттенок и ступень изгиба в одном числе INSTANCE_CUSTOM.a: туда и обратно, и в half float Compatibility
	for shade in [1.0 - EcoFishLook.SHADE_SPREAD, 1.0, 1.0 + EcoFishLook.SHADE_SPREAD]:
		for bank in [-1.0, -EcoFishLook.BANK_MAX, -0.11, 0.0, 0.03, 0.26, EcoFishLook.BANK_MAX]:
			var a := EcoFishLook.pack_shade(shade, bank)
			var lv := EcoFishLook.arc_level(bank)
			if not near(EcoFishLook.unpack_shade(a), shade, 1e-5, "оттенок цел: %.2f / %.2f" % [shade, bank]):
				return
			if not near(EcoFishLook.unpack_arc(a), float(lv) / EcoFishLook.ARC_LEVELS, 1e-6, "ступень цела"):
				return
			var h := _half(a)
			if not near(EcoFishLook.unpack_shade(h), shade, 0.02, "оттенок в half float: %.2f / %.2f" % [shade, bank]):
				return
			if not near(EcoFishLook.unpack_arc(h), float(lv) / EcoFishLook.ARC_LEVELS, 1e-6, "ступень в half float"):
				return
	near(EcoFishLook.unpack_arc(EcoFishLook.pack_shade(1.0, 99.0)), 1.0, 1e-6, "не больше полного изгиба")
	near(EcoFishLook.unpack_shade(1.0), 1.0, 1e-6, "пестрянки (1.0) — свой оттенок")
	eq(EcoFishLook.unpack_arc(1.0), 0.0, "у пестрянок хвост не гнётся по дуге")
	# хвост, а не голова: нос не сдвигается, кончик — на ARC_AMP при полном изгибе
	eq(EcoFishLook.tail_arc(EcoFishLook.NOSE, 1.0), 0.0, "голова жёсткая")
	near(EcoFishLook.tail_arc(EcoFishLook.TAIL_TIP, 1.0), EcoFishLook.ARC_AMP, 1e-6, "кончик — ARC_AMP")
	eq(EcoFishLook.tail_arc(EcoFishLook.TAIL_TIP, 1.0, 0.0), 0.0, "«Экономно» — без изгиба")
	# долгий поворот к боку +x — хвост к центру поворота (+x), плавно; прямо — выпрямляется
	var dt := 1.0 / 30.0
	var w := _world()
	var fish := _fish(w)
	var f := fish.all[2]
	f.look = Vector3(0, 0, 1)
	f.bank = 0.0
	f.bank_v = 0.0
	var prev := 0.0
	var worst := 0.0
	for i in 60:
		var was := f.look
		var yaw := atan2(was.x, was.z) + 2.0 * dt
		f.look = Vector3(sin(yaw), 0, cos(yaw))
		EcoFishLook.bank_step(f, was, f.look, dt)
		var tip := EcoFishLook.tail_arc(EcoFishLook.TAIL_TIP, EcoFishLook.unpack_arc(
			EcoFishLook.pack_shade(1.0, f.bank)))
		worst = maxf(worst, absf(tip - prev))
		prev = tip
	ok(prev > 0.5 * EcoFishLook.ARC_AMP, "в повороте хвост к центру (+x): %.3f м" % prev)
	ok(worst < 0.01, "изгиб копится плавно: за кадр кончик не дальше %.4f м" % worst)
	f.agent.v = f.look * 2.0
	var buf := FishView.pack(fish, 1.0)
	near(FishView.arc_at(buf, f.index), float(EcoFishLook.arc_level(f.bank)) / EcoFishLook.ARC_LEVELS, 1e-6,
		"изгиб — в буфере экземпляра")
	near(FishView.shade_at(buf, f.index), EcoFishLook.shade(f), 1e-5, "оттенок в буфере — прежний")
	for i in 60:
		EcoFishLook.bank_step(f, f.look, f.look, dt)
	eq(FishView.arc_at(FishView.pack(fish, 2.0), f.index), 0.0, "прямо — хвост прямой")
	var code := FishView.shader_code()
	ok(code.contains("half_a *") and code.contains("floor(INSTANCE_CUSTOM.a * 0.5)"), "шейдер гнёт хвост по дуге")


## Округлить до half float (11 бит мантиссы) — так Compatibility хранит INSTANCE_CUSTOM.
static func _half(x: float) -> float:
	if x == 0.0:
		return 0.0
	var e := floorf(log(absf(x)) / log(2.0))
	var step := pow(2.0, e - 10.0)
	return roundf(x / step) * step


func test_bank_leans_into_turn_smoothly() -> void:
	var dt := 1.0 / 30.0
	var w := _world()
	var f := _fish(w).all[2]
	f.look = Vector3(0, 0, 1)
	var rate := 2.0   # курс растёт 2 рад/с — поворот к боку формы +x
	var prev := 0.0
	var worst := 0.0
	for i in 60:
		var was := f.look
		var yaw := atan2(was.x, was.z) + rate * dt
		f.look = Vector3(sin(yaw), 0, cos(yaw))
		EcoFishLook.bank_step(f, was, f.look, dt)
		worst = maxf(worst, absf(f.bank - prev))
		prev = f.bank
	near(f.bank, EcoFishLook.bank_want(rate), 0.01, "в долгом повороте — нужный крен")
	ok(f.bank > 0.25 and f.bank <= EcoFishLook.BANK_MAX + 1e-6, "крен заметный, не больше BANK_MAX: %.2f" % f.bank)
	ok(worst < 0.05, "крен копится плавно: за кадр не больше %.3f рад" % worst)
	f.agent.v = f.look * 2.0
	var b := EcoFishLook.basis(f, _straight(f))
	var k := EcoFishLook.scale(f)
	var center := Vector3(f.look.z, 0, -f.look.x)   # центр поворота — к боку +x формы
	ok(b.y.normalized().dot(center) > 0.3, "спина наклонена к центру поворота")
	near(b.determinant(), k * k * k, 1e-3, "крен без зеркала — грани не выворачиваются")
	near(b.x.normalized().dot(b.z.normalized()), 0.0, 1e-4, "бок поперёк носа")
	near(EcoFishLook.bank_want(-100.0), -EcoFishLook.BANK_MAX, 1e-6, "в обратную сторону — не больше BANK_MAX")
	for i in 60:   # пошла прямо — выпрямляется
		EcoFishLook.bank_step(f, f.look, f.look, dt)
	ok(absf(f.bank) < 0.01, "прямо — без крена: %.3f" % f.bank)
	f.bank = 0.4
	EcoFishLook.bank_step(f, Vector3.ZERO, Vector3(0, 0, 1), dt)
	eq(f.bank, 0.0, "не плыла — крена нет")
	# в тревоге курс мечется влево-вправо каждые 0,1 с на полном LOOK_MAX — крен не перекидывается за кадр
	f.bank = 0.0
	f.bank_v = 0.0
	var banks: Array[float] = []
	for i in 90:
		var was2 := f.look
		var yaw2 := atan2(was2.x, was2.z) + EcoFish.LOOK_MAX * dt * (1.0 if (i / 3) % 2 == 0 else -1.0)
		f.look = Vector3(sin(yaw2), 0, cos(yaw2))
		EcoFishLook.bank_step(f, was2, f.look, dt)
		banks.append(f.bank)
	var acc := 0.0   # угловое ускорение крена по отсчётам через 3 кадра, как tools/jerk.gd
	var k3 := 3.0 * dt
	for i in range(6, banks.size()):
		acc = maxf(acc, absf((banks[i] - banks[i - 3]) / k3 - (banks[i - 3] - banks[i - 6]) / k3) / k3)
	ok(acc < 20.0, "мечется — крен без рывков: %.1f рад/с²" % acc)
	f.bank = 0.0
	f.bank_v = 0.0
	EcoFishLook.bank_step(f, Vector3(0, 0, 1), Vector3(sin(0.5), 0, cos(0.5)), 2.0)
	ok(f.bank > 0.0 and f.bank <= EcoFishLook.BANK_MAX + 1e-6, "длинный шаг дальней стаи — без перелёта: %.3f" % f.bank)
	for i in 120:
		w.step(dt)
	var any := false
	for g: EcoFish.Fish in _fish(w).all:
		any = any or absf(g.bank) > 0.02
		if absf(g.bank) > EcoFishLook.BANK_MAX + 1e-6:
			ok(false, "крен в мире не больше BANK_MAX")
			return
	ok(any, "мир ведёт крен рыбок")


## Б3: нос `Fish.look` догоняет скорость — рывок от хищника разворачивает тело за доли секунды, а не за кадр.
func test_nose_turns_smoothly() -> void:
	var dt := 1.0 / 30.0
	near(EcoFish.turn(Vector3.ZERO, Vector3(0, 0, -2), dt).z, -1.0, 1e-6, "не плыла — нос сразу по скорости")
	var look := Vector3(1, 0, 0)
	var after := EcoFish.turn(look, Vector3(-3, 0, 0), dt)   # скорость развернулась навстречу за кадр
	near(after.length(), 1.0, 1e-5, "нос единичный")
	near(look.angle_to(after), EcoFish.LOOK_MAX * dt, 1e-4, "за кадр — не больше LOOK_MAX · dt")
	var steps := 0
	while look.angle_to(Vector3(-1, 0, 0)) > 0.05 and steps < 100:
		look = EcoFish.turn(look, Vector3(-3, 0, 0), dt)
		steps += 1
	ok(steps > 6 and steps < 30, "разворот за 0,2–1 с: %d кадров" % steps)
	eq(EcoFish.turn(look, Vector3.ZERO, dt), look, "скорости нет — держит нос")
	var w := _world()
	var fish := _fish(w)
	for i in 60:
		w.step(dt)
	var f := fish.all[0]
	ok(f.look.length_squared() > 0.9, "мир ведёт нос рыбки")
	ok(f.look.angle_to(f.agent.v) < 0.6, "нос близко к курсу")
	var fw := EcoFishLook.forward(f, 0.0)
	var flat := Vector3(f.look.x, 0, f.look.z)
	ok(flat.length() < 1e-3 or fw.angle_to(f.look) <= EcoFishLook.WIGGLE + 1e-3, "тело — по носу с вилянием")


## Б3: съеденная рыбка возвращается у дома стаи не во весь размер за кадр — вырастает за FishView.FISH_RISE; откат
## времени (сброс) — сразу во весь размер.
func test_view_returned_fish_grows() -> void:
	var w := _world()
	var fish := _fish(w)
	w.run(1.0)
	var f := fish.all[5]
	var full := FishView.transform_at(FishView.pack(fish, w.time), f.index).basis.x.length()
	ok(full > 0.01, "живая во весь размер: %.4f" % full)
	near(FishView.grow_k(f, w.time), 1.0, 1e-6, "не съедали — во весь размер")
	fish.kill(f)
	w.run(24.0)
	ok(_run_until_alive(w, f, 20.0), "вернулась")
	near(f.born, w.time, 0.2, "время возвращения — время мира")
	var first := FishView.transform_at(FishView.pack(fish, f.born), f.index).basis.x.length()
	ok(first < full * 0.05, "появилась крошечной: %.4f" % first)
	var dt := 1.0 / 30.0
	var last := first
	var worst := 0.0
	var t := f.born
	for i in int(FishView.FISH_RISE / dt) + 2:
		t += dt
		var sz := FishView.grow_k(f, t)
		worst = maxf(worst, sz - last / full)
		last = sz * full
	ok(worst < 0.1, "за кадр растёт на %.3f < 10 %%" % worst)
	near(FishView.grow_k(f, f.born + FishView.FISH_RISE), 1.0, 1e-6, "выросла за FISH_RISE")
	near(FishView.grow_k(f, f.born - 3.0), 1.0, 1e-6, "время назад — сразу во весь размер")
	ok(FishView.grow_k(fish.all[6], t) == 1.0, "соседи не тронуты")


func _run_until_alive(w: EcoWorld, f: EcoFish.Fish, max_s: float) -> bool:
	var s := 0.0
	while s < max_s and not f.agent.alive:
		w.step(EcoWorld.MAX_STEP)
		s += EcoWorld.MAX_STEP
	return f.agent.alive



## Б3: центр стаи — цель сканера и сонара, испуг, охота — не прыгает, когда меняется состав: съеденная рыбка и
## вернувшаяся у дома сдвигают среднее разом, центр доплывает к нему за CENTER_EASE (было до 0,25–0,6 м за шаг).
func test_center_glides_when_fish_eaten_or_back() -> void:
	var w := _world()
	var fish := _fish(w)
	w.ship.pos = fish.shoals[0].home + Vector3(0, 0, 40)  # ближе MID: стая шагает каждый шаг мира
	w.reset()
	var sh := fish.shoals[0]
	for i in 240:
		w.step(DT)
	# съедена самая дальняя от центра
	var far: EcoFish.Fish = null
	for f: EcoFish.Fish in sh.members:
		if far == null or f.agent.p.distance_to(sh.center) > far.agent.p.distance_to(sh.center):
			far = f
	var jump := _center_jump(w, sh, func(): fish.kill(far))
	ok(jump[1] > 0.05, "среднее рыбок прыгнуло: %.3f м" % jump[1])
	ok(jump[0] < jump[1] * 0.2, "съели рыбку — центр не прыгает: %.3f м при скачке среднего %.3f" % jump)
	for i in 60:
		w.step(DT)
	near(sh.center.distance_to(sh.mean), 0.0, 0.01, "через 2 с центр — снова среднее рыбок")
	# вернулась у дома, а стая ушла от него
	ok(sh.mean.distance_to(sh.home) > 3.0, "стая ушла от дома")
	far.agent.timer = 0.0
	jump = _center_jump(w, sh, func(): pass)
	ok(far.agent.alive, "рыбка вернулась")
	ok(jump[1] > 0.3, "среднее рыбок прыгнуло: %.3f м" % jump[1])
	ok(jump[0] < jump[1] * 0.2, "вернулась у дома — центр не прыгает: %.3f м при скачке среднего %.3f" % jump)


const DT := 1.0 / 30.0


## Перемена состава стаи и три шага мира: насколько ход за шаг отличается от хода на шаге до перемены (м) — у центра
## и у среднего рыбок `Shoal.mean`: у плывущей стаи ход за шаг меняется на миллиметры, у среднего это скачок
## состава. Перемена — до шага (kill) или в шаге (возвращение у дома — в шаге рыбок, центр увидит её на следующем).
func _center_jump(w: EcoWorld, sh: EcoFish.Shoal, change: Callable) -> Array[float]:
	var c0 := sh.center
	var m0 := sh.mean
	w.step(DT)
	var last := sh.center - c0
	var last_m := sh.mean - m0
	change.call()
	var worst: Array[float] = [0.0, 0.0]
	for k in 3:
		var c := sh.center
		var m := sh.mean
		w.step(DT)
		var d := sh.center - c
		var dm := sh.mean - m
		worst[0] = maxf(worst[0], (d - last).length())
		worst[1] = maxf(worst[1], (dm - last_m).length())
		last = d
		last_m = dm
	return worst


## Б3: тревога прошла или стая доплыла до дома — рыбки тормозят скольжением, не быстрее EcoFish.BRAKE, а не встают
## за кадр: раньше предел скорости срезал 6,5 → 2,4 и 6,5 → 1 м/с за шаг (до 165 м/с²).
func test_brakes_smoothly_after_alarm() -> void:
	var dt := 1.0 / 30.0
	near(EcoFish.cap_speed(6.5, 6.5, 1.0, dt), 6.5 - EcoFish.BRAKE * dt, 1e-6, "выше предела — гаснет на BRAKE · dt")
	near(EcoFish.cap_speed(3.0, 0.9, 1.0, dt), 1.0, 1e-6, "разгон за предел — срезан до предела")
	near(EcoFish.cap_speed(7.0, 6.5, 6.5, dt), 6.5, 1e-6, "на пределе — предел")
	near(EcoFish.cap_speed(1.05, 1.2, 1.0, dt), 1.0, 1e-6, "почти у предела — не ниже предела")
	var w := _world()
	var fish := _fish(w)
	var sh := fish.shoals[0]
	w.ship.pos = sh.home + Vector3(0, 0, 40)  # ближе MID: стая шагает каждый шаг мира
	w.run(8.0)
	var pred := w.spawn("pred", sh.center + Vector3(5, 0, 0))
	var was := {}
	var worst := 0.0
	var fast := 0.0
	for i in int(14.0 / dt):
		if i == int(6.0 / dt):
			pred.alive = false  # хищник ушёл — тревога спадает, стая разгоняется из кораллов спокойно
		w.step(dt)
		for f: EcoFish.Fish in sh.members:
			var s := f.agent.v.length()
			fast = maxf(fast, s)
			if was.has(f) and f.agent.alive:
				worst = maxf(worst, (was[f] - s) / dt)
			was[f] = s if f.agent.alive else 0.0
	ok(fast > EcoFish.CALM_SPEED + 1.0, "в тревоге рыбки разгонялись: %.1f м/с" % fast)
	ok(worst < 2.5 * EcoFish.BRAKE, "тормозят не за кадр: %.1f м/с²" % worst)


## Б3: у дна рыбка тормозит вниз заранее, по дну впереди по ходу (`EcoFish.floor_brake`), а не встаёт на зажиме
## clearance за кадр. Раньше в тревоге у 01 рыбка шла вниз 5,7 м/с и вставала на дне за кадр (107 м/с²), в нырке
## к дому по склону — до 450 м/с². Ускорение — по местам рыбок (зажим двигает место, а не скорость), окно 3 шага.
func test_no_bounce_on_floor_clamp() -> void:
	var dt := 1.0 / 30.0
	near(EcoFish.floor_brake(-6.0, 10.0, 0.0), -6.0, 1e-6, "высоко над дном — ход не трогаем")
	ok(EcoFish.floor_brake(-6.0, 0.3, 0.0) > -3.0, "у самого дна вниз быстро нельзя")
	near(EcoFish.floor_brake(-6.0, 0.0, 2.0), 0.0, 1e-6, "на зажиме вниз нельзя")
	near(EcoFish.floor_lift(0.0, 3.0, 0.1), EcoFish.FLOOR_LIFT * 0.1, 1e-6, "вверх к дну впереди — не за кадр")
	near(EcoFish.floor_lift(2.0, 1.0, 0.1), 2.0, 1e-6, "уже поднимается быстрее — не трогаем")
	var up := EcoFish.climb_cap(Vector3(2.4, 1.5, 0), 2.4)
	near(up.length(), 2.4, 1e-5, "вверх к гребню — не быстрее предела стаи")
	near(up.y, 1.5, 1e-6, "подъём сохранён, ход вперёд меньше")
	var worst := 0.0
	var under := -INF
	var fast := 0.0
	for k in 6:
		var w := _world()
		var fish := _fish(w)
		var sh := fish.shoals[k]
		_only(w, fish, sh)
		w.ship.pos = sh.home + Vector3(0, 0, 40)  # ближе MID: стая шагает каждый шаг мира
		w.run(4.0)
		var pred := w.spawn("pred", sh.center + Vector3(6, 3, 0))
		var hist := {}
		for i in int(10.0 / dt):
			if i == int(5.0 / dt):
				pred.alive = false
				for f: EcoFish.Fish in sh.members:  # пробный нырок всей стаи к дому
					f.agent.v = (sh.home - f.agent.p).normalized() * 6.0
			w.step(dt)
			for f: EcoFish.Fish in sh.members:
				var a := f.agent
				if not a.alive:
					hist.erase(f)
					continue
				under = maxf(under, Seabed.height(a.p.x, a.p.z) + 0.05 - a.p.y)
				var ps: Array = hist.get(f, [])
				ps.append(a.p)
				if ps.size() > 7:
					ps.pop_front()
				hist[f] = ps
				if ps.size() == 7 and absi(i - int(5.0 / dt)) > 7:  # кроме самого толчка нырка
					var v0: float = (ps[3].y - ps[0].y) / (3.0 * dt)
					var v1: float = (ps[6].y - ps[3].y) / (3.0 * dt)
					fast = maxf(fast, -v0)
					var acc := absf(v1 - v0) / (3.0 * dt)
					worst = maxf(worst, acc)
	ok(fast > 2.0, "рыбки шли вниз: %.1f м/с" % fast)
	ok(worst < 40.0, "у дна не подскакивают: %.1f м/с²" % worst)
	ok(under < 0.0, "под дно не уходят: %.2f м" % under)


## Б3, плавность: размах виляния тела — по ходу. Медленная рыбка едва шевелит телом, от спокойного хода — полный.
func test_wiggle_follows_speed() -> void:
	near(EcoFishLook.wag_want(0.0), EcoFishLook.WIGGLE_SLOW, 1e-6, "стоит — малая доля")
	near(EcoFishLook.wag_want(EcoFish.MIN_SPEED), EcoFishLook.WIGGLE_SLOW, 1e-6, "самый тихий ход — малая доля")
	near(EcoFishLook.wag_want(EcoFish.CALM_SPEED), 1.0, 1e-6, "спокойный ход — полный размах")
	near(EcoFishLook.wag_want(EcoFish.ALARM_SPEED), 1.0, 1e-6, "в тревоге не больше полного")
	var prev := 0.0
	for i in 40:
		var k := EcoFishLook.wag_want(i * 0.1)
		ok(k >= prev - 1e-6, "растёт с ходом")
		prev = k
	var w := _world()
	var f := _fish(w).all[3]
	f.agent.v = Vector3(0, 0, -EcoFish.MIN_SPEED)
	f.wag = EcoFishLook.wag_step(f.wag, f.agent.v.length(), 0.1)
	near(f.wag, EcoFishLook.WIGGLE_SLOW, 1e-6, "первый шаг — сразу нужная доля")
	var mx := 0.0
	for i in 200:
		mx = maxf(mx, acos(clampf(-EcoFishLook.forward(f, i * 0.013).z, -1.0, 1.0)))
	ok(mx < EcoFishLook.WIGGLE * 0.5, "медленная рыбка виляет слабо: %.3f рад" % mx)
	ok(mx > EcoFishLook.WIGGLE * EcoFishLook.WIGGLE_SLOW * 0.8, "но виляет: %.3f рад" % mx)
	var buf := FishView.pack(_fish(w), 0.7)
	var fw := FishView.transform_at(buf, f.index).basis.z.normalized()
	_close(EcoFishLook.forward(f, 0.7), fw, "буфер вида — та же доля, что двойник")


## Доля размаха меняется не быстрее WAG_FOLLOW в секунду: рванула или встала — тело разгоняет виляние плавно.
func test_wag_eases_in_world() -> void:
	near(EcoFishLook.wag_step(EcoFishLook.WIGGLE_SLOW, EcoFish.ALARM_SPEED, 0.1),
		EcoFishLook.WIGGLE_SLOW + EcoFishLook.WAG_FOLLOW * 0.1, 1e-6, "рывок — разгон долей, не за кадр")
	var w := _world()
	var fish := _fish(w)
	w.ship.pos = EcoFish.HOMES[0] + Vector3(0, 6, 8)   # корабль у стаи — стая шагает каждый кадр
	w.run(1.0)
	var was := PackedFloat32Array()
	for f in fish.all:
		was.append(f.wag)
	var dt := 1.0 / 30.0
	var lo := 1.0
	var worst := 0.0
	for s in 600:
		if s == 200:
			w.ship.pos = EcoFish.HOMES[0] + Vector3(0, 2, 2)   # подошёл вплотную — тревога, рывок
			w.ship.speed = 3.0
		w.step(dt)
		for f in fish.all:
			if f.agent.alive and was[f.index] >= 0.0 and f.wag >= 0.0 and f.shoal.lag <= 0.0:
				worst = maxf(worst, absf(f.wag - was[f.index]))
			if f.wag >= 0.0:
				ok(f.wag >= EcoFishLook.WIGGLE_SLOW - 1e-6 and f.wag <= 1.0 + 1e-6, "доля в пределах")
				lo = minf(lo, f.wag)
			was[f.index] = f.wag
	ok(worst <= EcoFishLook.WAG_FOLLOW * (dt + EcoFish.LAG_MAX) + 1e-5, "за шаг не больше WAG_FOLLOW · dt: %.4f" % worst)
	ok(lo < 0.99, "есть рыбки на тихом ходу — виляют слабее: %.3f" % lo)


## Б3: корабль на ходу 6 м/с (дно + 3 м) идёт сквозь стаи от 01 к 07 — рыбки отплывают от обшивки, а не едут по
## ней: центр и цель стаи оказывались в корпусе, рыбку тянуло в обшивку, и она скользила по борту и под днищем
## (без хищников — до 19 с подряд, 3,1 тыс. шагов касаний на пути; с исправлением — 2,3 с и 0,6 тыс.).
func test_fish_shed_off_hull_under_way() -> void:
	var w := _world()
	w.ground = Seabed.height
	var fish := _fish(w)
	var a0 := LayerMap.at("01")
	var b0 := LayerMap.at("07")
	w.ship.pos = a0
	w.reset()
	var dt := 1.0 / 30.0
	var dir := Vector3(b0.x - a0.x, 0, b0.z - a0.z).normalized()
	var n := int(Vector2(a0.x, a0.z).distance_to(Vector2(b0.x, b0.z)) / 6.0 / dt)
	var run := {}
	var worst := 0
	var total := 0
	for j in n:
		var q := a0.lerp(b0, float(j) / n)
		q.y = Seabed.height(q.x, q.z) + Helm.Ship.CLEARANCE
		w.ship.pos = q
		w.ship.yaw = atan2(-dir.x, -dir.z)
		w.ship.speed = 6.0
		w.step(dt)
		for f in fish.all:
			if f.agent.alive and w.touches_ship(f.agent.p, EcoFish.HULL_GAP + 0.05):
				run[f.index] = int(run.get(f.index, 0)) + 1
				worst = maxi(worst, run[f.index])
				total += 1
			else:
				run[f.index] = 0
	ok(total > 0, "корабль прошёл сквозь стаю")
	ok(worst * dt < 3.0, "рыбка у обшивки не дольше 3 с подряд: %.2f с" % (worst * dt))
	ok(total < 1200, "касаний обшивки меньше прежнего: %d шагов" % total)


func test_shed_dir_under_keel_and_at_nose_goes_aside() -> void:
	var up := EcoFish.shed_dir(Vector3.UP, Vector3(1, 2, 0), 0.0)
	near(up.distance_to(Vector3.UP), 0.0, 1e-6, "над корпусом — по нормали")
	var keel := EcoFish.shed_dir(Vector3.DOWN, Vector3(-0.5, -2, 3), 0.0)
	ok(keel.x < -0.9 and absf(keel.y) < 1e-6, "под днищем — вбок к своему борту: %s" % keel)
	var nose := EcoFish.shed_dir(Vector3.FORWARD, Vector3(0.4, 0, -8), 0.0)
	ok(nose.x > 0.8, "на носу — вбок, а не вперёд перед кораблём: %s" % nose)
	var steer := EcoFish.hull_steer(Vector3(0, 0, -5), Vector3.BACK, EcoFish.HULL_KEEP)
	near(steer.z, EcoFish.HULL_SHED, 1e-5, "тяга в корпус снята, от обшивки — HULL_SHED")
	var goal := EcoFish.goal_clear(Vector3(0, HullPlan.CENTER_Y, 9), Vector3.ZERO, 0.0)
	ok(not EcoHull.touches(goal, Vector3.ZERO, 0.0, EcoFish.GOAL_PAD - 0.1), "цель стаи из корпуса — наружу")
