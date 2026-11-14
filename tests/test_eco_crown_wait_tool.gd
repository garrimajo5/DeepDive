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
	for k in ["alarm", "episodes", "longest", "lines", "stuck", "stuck_r", "reef_hid", "hunger", "nearest", "reef", "first", "modes", "goal_in"]:
		ok(r.has(k), "в итоге зерна есть %s" % k)
	ok(int(r["reef"]) >= 1, "стая рифа у 01 найдена: %d" % r["reef"])
	ok(float(r["alarm"]) <= 10.0 + tool.DT + 1e-3, "тревога не дольше стоянки: %.2f" % r["alarm"])
	ok(float(r["longest"]) <= float(r["alarm"]) + 1e-3, "самый долгий эпизод — не дольше всей тревоги")
	ok(float(r["stuck"]) <= float(r["longest"]) + 1e-3, "залипание — внутри тревоги")
	ok(float(r["nearest"]) < INF, "ближайший серпохвост к оси посчитан")
	eq(lines.size(), 3, "шапка, зерно, итог")
	ok(lines[0].begins_with("== голодный серпохвост у 01"), lines[0])
	ok(lines[1].begins_with("  зерно  0: крона в тревоге"), lines[1])
	ok(lines[2].begins_with("== итог: крона в тревоге в"), lines[2])
