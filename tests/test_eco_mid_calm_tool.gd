extends TestCase
## `tools/mid_calm.gd` (#1400): спокойная середина 00 → 01 — раскрылся ли волнолист у прохода, какие стаи радужников
## вспыхнули в луче и звали ли серпохвоста, какие угрозы слышал экипаж (засада глазуна, охота серпохвоста). По этому
## расчёту решают перенос дома стаи радужников и постановку середины.


func _tool() -> GDScript:
	var tool: GDScript = load("res://tools/mid_calm.gd")
	for v in ["moves", "limit", "dark", "probe", "answer", "delay", "hold", "start0", "band0"]:
		ok(tool.get(v) != null, "в инструменте есть %s" % v)
	return tool


func _restore(tool: GDScript) -> void:
	tool.set("moves", {})
	tool.set("limit", tool.LIMIT)
	tool.set("dark", tool.DARK)
	tool.set("probe", false)
	tool.set("answer", false)
	tool.set("delay", tool.DELAY)
	tool.set("hold", tool.HOLD)
	tool.set("start0", Vector2.INF)
	tool.set("band0", Rect2())


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
	eq(lines.size(), 7, "шапка, зерно, итог, угрозы середины и подхода к 01, порядок, цели №0 против пути середины")
	ok(lines[0].begins_with("== дома радужников"), lines[0])
	ok(lines[1].contains("волнолист раскрыт на"), lines[1])
	ok(lines[2].begins_with("итог: волнолист 1/1") and lines[2].contains("стая 1 —"), lines[2])
	ok(lines[3].begins_with("угрозы в середине (зёрен из 1)") and lines[3].contains("серпохвост ближе всего"), lines[3])
	ok(lines[4].begins_with("угрозы на подходе к 01 (зёрен из 1)"), lines[4])
	ok(lines[5].begins_with("порядок: моллюски до первого «замера»"), lines[5])
	ok(lines[1].contains("свет 0 → луч на волнолисте") and lines[1].contains("путь №0 (при свете — ") \
		and lines[1].contains("): старт (-60; 20)"), lines[1])
	ok(lines[1].contains("цели №0: ") and lines[1].contains("охота на рыб"), lines[1])
	ok(lines[0].contains("цели №0 как в игре"), lines[0])
	ok(lines[6].begins_with("путь середины") and lines[6].contains("отрезок между целями"), lines[6])


## Угрозы — события шины из THREATS ближе слышимости экипажа: засада глазуна, «замер» и укус серпохвоста.
func test_threat_key_counts_heard_threats_only() -> void:
	var tool := _tool()
	var ship := Vector3(20, -30, 22.5)
	eq(tool.threat_key(EcoBus.Event.new(EcoCoins.GLAZUN, "ambush", ship + Vector3(60, 0, 0)), ship), "glazun:ambush")
	eq(tool.threat_key(EcoBus.Event.new(EcoPred.ID, "bite", ship), ship), "pred:bite")
	eq(tool.threat_key(EcoBus.Event.new(EcoPred.ID, "alert", ship + Vector3(0, 0, EcoBus.HEARING + 1)), ship), "",
		"дальше слышимости — не угроза")
	eq(tool.threat_key(EcoBus.Event.new(EcoPred.ID, "catch", ship), ship), "", "охота на светляков — не угроза кораблю")
	eq(tool.threat_key(EcoBus.Event.new(EcoCoins.ID, "ambush", ship), ship), "", "заметка чужого вида")
	for sp in tool.THREATS:
		ok(Species.has(sp), "вид %s в реестре" % sp)


## probe=1 включает тихий круг серпохвоста до сброса мира: хищник дуги появляется в ARC[0].
func test_probe_puts_arc_pred_on_arc() -> void:
	var tool := _tool()
	tool.set("probe", true)
	var ev: EcoView = tool.make(7)
	_restore(tool)
	ok(ev.preds.probe, "проба включена")
	var p := ev.preds.all[EcoPred.ARC_PRED].start
	near(Vector2(p.x, p.z).distance_to(EcoPred.ARC[0]), 0.0, 1.0, "хищник дуги — в начале дуги")
	ev.free()
	var ev2: EcoView = tool.make(7)
	ok(not ev2.preds.probe, "без probe — выключена")
	ev2.free()


## answer=1 (ответ экипажа на «замер» через delay с, hold с без света) — в шапке расчёта; без зёрен итог пустой.
func test_answer_in_header() -> void:
	var tool := _tool()
	tool.set("answer", true)
	var lines: Array[String] = tool.report(0)
	_restore(tool)
	ok(lines[0].contains("ответ экипажа через 1.5 с, 25 с без света"), lines[0])
	ok(lines[3].contains("нет"), lines[3])
	ok(tool.report(0)[0].contains("ответ экипажа нет"), "без answer — нет")
