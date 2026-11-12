extends TestCase
## `tools/mid_calm.gd` (#1400): спокойная середина 00 → 01 — раскрылся ли волнолист у прохода, какие стаи радужников
## вспыхнули в луче и звали ли серпохвоста. По этому расчёту решают перенос дома стаи радужников.


func _tool() -> GDScript:
	var tool: GDScript = load("res://tools/mid_calm.gd")
	for v in ["moves", "limit", "dark"]:
		ok(tool.get(v) != null, "в инструменте есть %s" % v)
	return tool


func _restore(tool: GDScript) -> void:
	tool.set("moves", {})
	tool.set("limit", tool.LIMIT)
	tool.set("dark", tool.DARK)


func test_parse_moves() -> void:
	var tool := _tool()
	var m: Dictionary = tool.parse_moves("1:80,5;2:-70.5,-60")
	eq(m, {1: Vector2(80, 5), 2: Vector2(-70.5, -60)})


func test_move_puts_swarm_home_there() -> void:
	var tool := _tool()
	tool.set("moves", {1: Vector2(80.0, 5.0)})
	var ev: EcoView = tool.make(7)
	_restore(tool)
	var h := ev.raduzh.swarms[1].home
	near(h.x, 80.0, 1e-4, "стая 1 — в новом доме по x")
	near(h.z, 5.0, 1e-4, "по z")
	near(ev.raduzh.swarms[0].home.x, EcoRaduzh.HOMES[0].x, 1e-4, "остальные — на месте")
	ev.free()


## Короткий проход (без тёмной стоянки, 12 с света): волнолист у прохода раскрывается на ~8 с, итог собран.
func test_short_pass_opens_route_fern_and_reports() -> void:
	var tool := _tool()
	tool.set("dark", 0.0)
	tool.set("limit", 12.0)
	var lines: Array[String] = tool.report(1)
	_restore(tool)
	eq(lines.size(), 3, "шапка, зерно, итог")
	ok(lines[0].begins_with("== дома радужников"), lines[0])
	ok(lines[1].contains("волнолист раскрыт на"), lines[1])
	ok(lines[2].begins_with("итог: волнолист 1/1") and lines[2].contains("стая 1 —"), lines[2])
