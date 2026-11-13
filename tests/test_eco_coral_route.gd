extends TestCase
## Сцена 00 → 01 (`docs/urovni/sloj-1.md`, «Разведение наблюдения и угрозы»): «собственный пинг тоже меняет поведение:
## погасший огнецвет сам по себе не доказывает присутствие хищника». Куст у основания (33,3; 56,8) — `EcoCoral.BASES[1]`
## на пути: импульс сонара с выхода 00 и из середины гасит его и без серпохвоста рядом, строка называет импульс,
## а не «кого-то крупного»; в тишине куст разгорается. Мир — настоящие места кустов и стартовая расстановка
## серпохвостов, только всех серпохвостов увели далеко.

const BUSH := 1
const FAR := Vector3(500, -30, 500)
const FLOOR := 7.0   # корабль над дном, как в `tools/mid_calm.gd`


func _world() -> Array:
	var w := EcoWorld.new()
	w.ground = Seabed.mesh_height
	var ps := w.add(EcoPred.new()) as EcoPred
	var c := w.add(EcoCoral.new([], ps)) as EcoCoral
	w.reset()
	for pr in ps.all:
		pr.agent.p = FAR
		pr.agent.goal = FAR
	return [w, ps, c]


func _put(w: EcoWorld, xz: Vector2) -> void:
	w.ship.pos = Vector3(xz.x, Seabed.mesh_height(xz.x, xz.y) + FLOOR, xz.y)
	w.ship.speed = 0.0
	w.ship.light_on = true


## Шаги по 0,1 с; строки на приборы — в said. Ни на одном шаге куст не гас «от хищника».
func _run(w: EcoWorld, c: EcoCoral, secs: float, said: Array[String]) -> void:
	for i in roundi(secs / 0.1):
		w.step(0.1)
		ok(not c.bushes[BUSH].spooked, "куст гаснет не от хищника")
		for ev in w.take_link():
			said.append(str(ev.get("text", "")))


func _ping(w: EcoWorld, said: Array[String]) -> void:
	w.ship.sonar_ping = true
	w.step(0.05)
	w.ship.sonar_ping = false
	for ev in w.take_link():
		said.append(str(ev.get("text", "")))


func _has(said: Array[String], part: String) -> bool:
	for t in said:
		if t.contains(part):
			return true
	return false


func test_route_bush_is_the_one_from_levels() -> void:
	var c: EcoCoral = _world()[2]
	near(c.bushes[BUSH].base.x, 33.3, 1e-4)
	near(c.bushes[BUSH].base.z, 56.8, 1e-4)


## Середина (20; 22,5): стоянка со светом куст не гасит, импульс — гасит наполовину, повторный — до «погас» со строкой
## про импульс; дальние кусты не меняются; серпохвоста рядом нет — строки «прошёл кто-то крупный» нет; в тишине
## за 25 с куст снова горит.
func test_mid_ping_dims_bush_without_pred() -> void:
	var a := _world()
	var w: EcoWorld = a[0]
	var ps: EcoPred = a[1]
	var c: EcoCoral = a[2]
	var b := c.bushes[BUSH]
	var said: Array[String] = []
	_put(w, Vector2(20.0, 22.5))
	ok(w.ship.pos.distance_to(b.top) < EcoCoral.PING_R, "куст в досягаемости импульса из середины: %.1f м"
		% w.ship.pos.distance_to(b.top))
	_run(w, c, 3.0, said)
	near(b.glow, 1.0, 1e-6, "стоянка со светом — горит")
	ok(not EcoCoral.pred_near(ps, b.top), "серпохвоста у куста нет")
	_ping(w, said)
	near(b.glow, 1.0 - EcoCoral.PING_DIM, 0.01, "импульс гасит половину")
	for i in c.bushes.size():
		if i != BUSH and w.ship.pos.distance_to(c.bushes[i].top) >= EcoCoral.PING_R:
			near(c.bushes[i].glow, 1.0, 1e-6, "дальний куст %d горит" % i)
	_run(w, c, 1.0, said)
	_ping(w, said)
	ok(b.glow < EcoCoral.DARK, "второй импульс — погас: %.2f" % b.glow)
	ok(_has(said, "Огнецвет гасит огни от импульса сонара"), "строка называет импульс: %s" % str(said))
	ok(not _has(said, "кто-то крупный"), "не хищник: %s" % str(said))
	ok(not _has(said, "корабль шумит"), "корабль стоит тихо")
	_run(w, c, 25.0, said)
	near(b.glow, 1.0, 1e-6, "в тишине снова горит")
	ok(not _has(said, "кто-то крупный"), "и после — без строки о крупном")
	ok(not EcoCoral.pred_near(ps, b.top), "серпохвост так и не подошёл")


## Выход 00 (4; 80) — первый импульс на маршруте уже достаёт куст: он гаснет раньше, чем корабль подошёл.
func test_exit00_ping_reaches_bush() -> void:
	var a := _world()
	var w: EcoWorld = a[0]
	var c: EcoCoral = a[2]
	var b := c.bushes[BUSH]
	var said: Array[String] = []
	_put(w, Vector2(4.0, 80.0))
	ok(w.ship.pos.distance_to(b.top) < EcoCoral.PING_R, "куст в досягаемости импульса с выхода 00: %.1f м"
		% w.ship.pos.distance_to(b.top))
	ok(w.ship.pos.distance_to(b.top) > EcoCoral.NOISE_R, "и дальше шума хода")
	_ping(w, said)
	near(b.glow, 1.0 - EcoCoral.PING_DIM, 0.01, "импульс с выхода гасит половину")
	_run(w, c, 2.0, said)
	ok(not _has(said, "кто-то крупный"), "без строки о крупном: %s" % str(said))


## Мир с рядом каменщиков у кустов огнецвета (EcoKamen у каждого EcoCoral.BASES), серпохвосты далеко.
func _world_kamen() -> Array:
	var w := EcoWorld.new()
	w.ground = Seabed.mesh_height
	var ps := w.add(EcoPred.new()) as EcoPred
	var c := w.add(EcoCoral.new([], ps)) as EcoCoral
	var k := w.add(EcoKamen.new()) as EcoKamen
	w.reset()
	for pr in ps.all:
		pr.agent.p = FAR
		pr.agent.goal = FAR
	return [w, c, k]


## Ход 5 м/с (`tools/mid_calm.gd` SPEED) со светом от a к b на FLOOR над видимым дном, шаг 0,1 с. Строки на приборы и
## заметки каменщиков — в said; ближе всего к вершине куста и к гнёздам его ряда — в near ([куст, ряд]).
func _cruise(w: EcoWorld, c: EcoCoral, k: EcoKamen, a: Vector2, b: Vector2, said: Array[String],
		near_m: Array[float]) -> void:
	var dt := 0.1
	var speed := 5.0
	var n := ceili(a.distance_to(b) / (speed * dt))
	w.ship.light_on = true
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		w.ship.pos = Vector3(p.x, Seabed.mesh_height(p.x, p.y) + FLOOR, p.y)
		w.ship.speed = speed
		w.step(dt)
		near_m[0] = minf(near_m[0], w.ship.pos.distance_to(c.bushes[BUSH].top))
		for wm in k.rows[BUSH].worms:
			near_m[1] = minf(near_m[1], w.ship.pos.distance_to(wm.base))
		for ev in w.bus.pending:
			if ev.species == EcoKamen.ID:
				said.append("kamen:" + str(ev.note))
		for ev in w.take_link():
			said.append(str(ev.get("text", "")))


## Спокойная середина (решение гейм-дизайнера 08.11, #1400): шумный ход 5 м/с от выхода 00 к стоянке (20; 22,5) идёт
## дальше слуха куста у прохода и ряда каменщиков у него — огнецвет горит, венчики раскрыты, строк «корабль шумит» и
## «прячет венчики» нет; цепочку «прожектор → волнолист → моллюски» шум хода не перебивает. Контроль: тот же ход в
## 8 м от куста гасит его и прячет ряд — проверка не пустая.
func test_mid_cruise_keeps_bush_and_kamen_calm() -> void:
	var a := _world_kamen()
	var w: EcoWorld = a[0]
	var c: EcoCoral = a[1]
	var k: EcoKamen = a[2]
	var said: Array[String] = []
	var near_m: Array[float] = [INF, INF]
	ok(5.0 > EcoCoral.NOISE_SPEED and 5.0 > EcoKamen.NOISE_SPEED, "ход середины шумный")
	_cruise(w, c, k, Vector2(4.0, 80.0), Vector2(20.0, 22.5), said, near_m)
	ok(near_m[0] > EcoCoral.NOISE_R + 2.0, "путь дальше слуха куста: %.1f м" % near_m[0])
	ok(near_m[1] > EcoKamen.NOISE_R + 2.0, "и ряда каменщиков: %.1f м" % near_m[1])
	for b in c.bushes:
		near(b.glow, 1.0, 1e-6, "куст у (%.0f; %.0f) горит" % [b.base.x, b.base.z])
	for r in k.rows:
		eq(k.hidden_in(r), 0, "ряд %d раскрыт" % r.index)
	ok(not _has(said, "корабль шумит"), "без строки о шуме: %s" % str(said))
	ok(not _has(said, "kamen:"), "без заметок каменщиков: %s" % str(said))
	# контроль: тот же ход мимо куста в 8 м — гаснет и прячется
	var b2 := _world_kamen()
	var w2: EcoWorld = b2[0]
	var c2: EcoCoral = b2[1]
	var k2: EcoKamen = b2[2]
	var said2: Array[String] = []
	var near2: Array[float] = [INF, INF]
	var base := Vector2(c2.bushes[BUSH].base.x, c2.bushes[BUSH].base.z)
	_cruise(w2, c2, k2, base + Vector2(-8.0, 30.0), base + Vector2(-8.0, -30.0), said2, near2)
	ok(c2.bushes[BUSH].glow < EcoCoral.DARK, "вплотную куст гаснет: %.2f" % c2.bushes[BUSH].glow)
	ok(k2.hidden_in(k2.rows[BUSH]) > 0, "и ряд прячется")
	ok(_has(said2, "корабль шумит"), "строка о шуме: %s" % str(said2))
	ok(_has(said2, "kamen:hide"), "и заметка каменщиков: %s" % str(said2))


## Стоянка у самого куста (кандидат (ц), `docs/roles/dev-b.md`): два импульса сонара гасят куст у основания (33,3; 56,8)
## до тления; корабль стоит рядом в 8 м со светом — ближе слуха NOISE_R, но тихо — и куст разгорается сам за
## (1 − MIN_GLOW) / RELIGHT ≈ 23 с, как в тишине; ползком 2 м/с (тише NOISE_SPEED) — так же. Свет и близость сами куст
## погашенным не держат — держит только шум хода: контроль 4 м/с в том же месте оставляет его тлеть.
func test_bush_relights_beside_quiet_lit_ship() -> void:
	var full := (1.0 - EcoCoral.MIN_GLOW) / EcoCoral.RELIGHT
	for crawl in [0.0, 2.0, 4.0]:
		var a := _world()
		var w: EcoWorld = a[0]
		var c: EcoCoral = a[2]
		var b := c.bushes[BUSH]
		var said: Array[String] = []
		_put(w, Vector2(b.base.x - 8.0, b.base.z))
		var d := w.ship.pos.distance_to(b.top)
		ok(d < EcoCoral.NOISE_R, "корабль ближе слуха куста: %.1f м" % d)
		_ping(w, said)
		_run(w, c, 0.5, said)
		_ping(w, said)
		near(b.glow, EcoCoral.MIN_GLOW, 0.01, "два импульса — куст тлеет")
		ok(_has(said, "от импульса сонара"), "строка называет импульс: %s" % str(said))
		w.ship.speed = crawl
		var lit_at := -1.0
		var t := 0.0
		while t < full + 5.0:
			_run(w, c, 0.1, said)
			t += 0.1
			if lit_at < 0.0 and b.glow >= 1.0 - 1e-6:
				lit_at = t
		print("    ход %.0f м/с в %.1f м от вершины: горит снова через %.1f с (свет %.2f, в тишине %.1f с)"
			% [crawl, d, lit_at, b.glow, full])
		if crawl < EcoCoral.NOISE_SPEED:
			ok(lit_at > 0.0 and lit_at <= full + 0.2, "ход %.0f м/с со светом рядом — куст разгорается сам: %.1f с"
				% [crawl, lit_at])
			ok(not _has(said, "корабль шумит"), "стоянка рядом без строки о шуме: %s" % str(said))
		else:
			near(b.glow, EcoCoral.MIN_GLOW, 1e-6, "контроль: шумный ход %.0f м/с держит куст погасшим" % crawl)
			ok(not _has(said, "корабль шумит"), "строки нет: куст погас раньше, от импульса")
