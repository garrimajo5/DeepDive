extends TestCase
## `tools/crown_wait.gd` (#1400, п. 2 (ю)): голодный серпохвост у 01, когда вся добыча в укрытии — сколько крона
## в тревоге на стоянке со светом и бывает ли «залипание» голодного хищника у края рифа.


func _tool() -> GDScript:
	var tool: GDScript = load("res://tools/crown_wait.gd")
	for v in ["dark", "mid", "stay", "live"]:
		ok(tool.get(v) != null, "в инструменте есть %s" % v)
	return tool


func _restore(tool: GDScript) -> void:
	tool.set("dark", tool.DARK)
	tool.set("mid", tool.MID)
	tool.set("stay", tool.STAY)
	tool.set("live", false)


## Короткий проход без стоянок у 00 и середины, 10 с у 01: шапка, строка зерна, итог; стая рифа у 01 найдена.
func test_short_run_reports() -> void:
	var tool := _tool()
	tool.set("dark", 0.0)
	tool.set("mid", 0.0)
	tool.set("stay", 10.0)
	var r: Dictionary = tool.run(0)
	var lines: Array[String] = tool.report(1)
	_restore(tool)
	for k in ["alarm", "episodes", "longest", "lines", "stuck", "stuck_r", "reef_hid", "hunger", "nearest", "reef", "first", "modes", "goal_in", "why", "transit", "transit_r"]:
		ok(r.has(k), "в итоге зерна есть %s" % k)
	ok(int(r["reef"]) >= 1, "стая рифа у 01 найдена: %d" % r["reef"])
	ok(float(r["alarm"]) <= 10.0 + tool.DT + 1e-3, "тревога не дольше стоянки: %.2f" % r["alarm"])
	ok(float(r["longest"]) <= float(r["alarm"]) + 1e-3, "самый долгий эпизод — не дольше всей тревоги")
	ok(float(r["stuck"]) <= float(r["longest"]) + 1e-3, "залипание — внутри тревоги")
	ok(float(r["nearest"]) < INF, "ближайший серпохвост к оси посчитан")
	var why := 0.0
	for k in tool.WHY:
		ok(r["why"].has(k), "причина %s в итоге зерна" % k)
		why += float(r["why"][k])
	near(why, float(r["alarm"]), 1e-3, "причины делят всю тревогу кроны")
	ok(float(r["transit"]) <= float(r["why"]["transit"]) + 1e-3, "отрезок транзита — не дольше транзита за стоянку")
	eq(lines.size(), 4, "шапка, зерно, причины, итог")
	ok(lines[0].begins_with("== голодный серпохвост у 01"), lines[0])
	ok(lines[1].begins_with("  зерно  0: крона в тревоге"), lines[1])
	ok(lines[1].contains("причины [транзит"), lines[1])
	ok(lines[2].begins_with("== причины тревоги кроны, сумма 1 зёрен"), lines[2])
	ok(lines[3].begins_with("== итог: крона в тревоге в"), lines[3])


## Причина тревоги по ближайшему серпохвосту: вне CROWN_ALARM — «ушёл», не патруль — «охота», патруль — по цели:
## внутри CROWN_ALARM — «цель у рифа», дальше — «транзит».
func test_cause_by_mode_and_goal() -> void:
	var tool := _tool()
	var axis := Vector3(33.0, 0.0, -22.0)
	var pr := EcoPred.Pred.new()
	pr.agent = EcoAgent.new(EcoPred.ID, axis + Vector3(38.0, 0.0, 0.0))
	pr.mode = EcoPred.Mode.PATROL
	pr.agent.goal = axis + Vector3(-120.0, 0.0, 0.0)
	eq(tool.cause(pr, 38.0, axis), "transit", "патруль к дальней цели у края рифа")
	pr.agent.goal = axis + Vector3(0.0, 0.0, 40.0)
	eq(tool.cause(pr, 38.0, axis), "goal_in", "патруль к цели внутри тревоги кроны")
	pr.mode = EcoPred.Mode.HUNT
	eq(tool.cause(pr, 38.0, axis), "hunt", "охота у рифа")
	eq(tool.cause(pr, EcoFish.CROWN_ALARM + 1.0, axis), "away", "дальше тревоги кроны")
	eq(tool.cause(null, 0.0, axis), "away", "серпохвостов нет")
