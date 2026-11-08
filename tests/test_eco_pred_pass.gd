extends TestCase
## Проход серпохвоста по сценарию тестера (#1401): EcoPred.pass_by ставит хищника и ведёт мимо куста огнецвета —
## кончики гаснут (#1339), ряд каменщиков прячет венчики (#1337), дальний куст не меняется; после ухода всё
## раскрывается. Шаг сценария «pred» разбирает QaScript.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world() -> Array:
	var w := EcoWorld.new()
	w.ground = _flat
	var ps := w.add(EcoPred.new()) as EcoPred
	var bases: Array[Vector2] = [Vector2(0, 0), Vector2(200, 0)]
	var c := w.add(EcoCoral.new(bases, ps)) as EcoCoral
	var k := w.add(EcoKamen.new(bases)) as EcoKamen
	w.reset()
	for pr in ps.all:   # остальные — далеко, не мешают
		pr.agent.p = FAR
		pr.agent.goal = FAR
	w.ship.pos = Vector3(0, -30, 30)
	w.ship.speed = 0.0
	return [w, ps, c, k]


## Строки на приборы за прогон.
var said: Array[String] = []


func _run(w: EcoWorld, secs: float) -> void:
	for i in roundi(secs / 0.1):
		w.step(0.1)
		for ev in w.take_link():
			said.append(str(ev.get("text", "")))


func _hidden(r: EcoKamen.Row) -> int:
	var n := 0
	for m in r.worms:
		if m.open < EcoKamen.HIDDEN:
			n += 1
	return n


func _said(part: String) -> bool:
	for t in said:
		if t.contains(part):
			return true
	return false


func test_pass_dims_bush_and_hides_row() -> void:
	var a := _world()
	var w: EcoWorld = a[0]
	var ps: EcoPred = a[1]
	var c: EcoCoral = a[2]
	var k: EcoKamen = a[3]
	var top := c.bushes[0].top + Vector3(0, 2, 0)
	ok(ps.pass_by(0, top - Vector3(30, 0, 0), top + Vector3(30, 0, 0)), "серпохвост 0 пошёл")
	eq(ps.all[0].mode, EcoPred.Mode.INVESTIGATE)
	_run(w, 7.0)
	ok(c.bushes[0].glow < EcoCoral.DARK, "ближний куст погас: %.2f" % c.bushes[0].glow)
	near(c.bushes[1].glow, 1.0, 1e-6, "дальний куст горит")
	ok(_hidden(k.rows[0]) > 0, "ряд у куста прячет венчики")
	eq(_hidden(k.rows[1]), 0, "дальний ряд раскрыт")
	ok(_said("Огнецвет гасит огни — рядом прошёл кто-то крупный"), "строка о проходе крупного: %s" % str(said))
	ok(not _said("корабль шумит"), "корабль стоит тихо — не он")
	eq(w.ship.pos, Vector3(0, -30, 30), "корабль стоит")
	# хищник ушёл далеко — всё раскрывается
	ps.pass_by(0, FAR, FAR + Vector3(30, 0, 0))
	_run(w, 30.0)
	ok(c.bushes[0].glow > 0.9, "куст разгорелся: %.2f" % c.bushes[0].glow)
	eq(_hidden(k.rows[0]), 0, "венчики снова снаружи")


func test_pass_is_calm_and_checks_index() -> void:
	var a := _world()
	var ps: EcoPred = a[1]
	ps.all[0].cooldown = 0.0
	ok(ps.pass_by(0, Vector3(0, -30, 0), Vector3(10, -30, 0)))
	ok(ps.all[0].cooldown >= EcoPred.PASS_CALM, "на проходе не нападает")
	ok(not ps.pass_by(-1, Vector3.ZERO, Vector3.ONE), "нет такого")
	ok(not ps.pass_by(ps.all.size(), Vector3.ZERO, Vector3.ONE), "нет такого")


func test_qa_step_parsed() -> void:
	var q := QaScript.parse('[{"do": "pred", "n": 1, "bush": 2}, {"do": "pred", "away": true}, {"do": "quit"}]')
	eq(q.errors.size(), 0, str(q.errors))
	var out := q.advance(0.0)
	var got: Array = []
	for cmd in out:
		if cmd[0] == "pred":
			got.append(cmd)
	eq(got, [["pred", 1, 2, false], ["pred", 0, 0, true]], "команды pred")
