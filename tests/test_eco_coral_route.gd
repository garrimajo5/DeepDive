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
