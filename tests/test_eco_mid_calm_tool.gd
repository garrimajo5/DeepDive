extends TestCase
## `tools/mid_calm.gd` (#1400): спокойная середина 00 → 01 — раскрылся ли волнолист у прохода, какие стаи радужников
## вспыхнули в луче и звали ли серпохвоста, какие угрозы слышал экипаж (засада глазуна, охота серпохвоста). По этому
## расчёту решают перенос дома стаи радужников и постановку середины.


func _tool() -> GDScript:
	var tool: GDScript = load("res://tools/mid_calm.gd")
	for v in ["moves", "limit", "dark", "probe", "answer", "delay", "hold", "start0", "band0", "fish_moves", "watch", "sites", "repeat", "live"]:
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
	tool.set("fish_moves", {})
	tool.set("watch", [tool.WATCH_SHOAL] as Array[int])
	tool.set("sites", false)
	tool.set("repeat", false)
	tool.set("live", false)


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
	eq(lines.size(), 10, "шапка, дом стаи 0, зерно, итог, угрозы середины и подхода к 01, порядок, цели №0, стая 0, погони")
	ok(lines[0].begins_with("== дома радужников"), lines[0])
	ok(lines[1].begins_with("== дом стаи светляков 0 (15; 76), тёмная стоянка 0 с"), lines[1])
	ok(lines[2].contains("волнолист раскрыт на"), lines[2])
	ok(lines[3].begins_with("итог: волнолист 1/1") and lines[3].contains("стая 1 —"), lines[3])
	ok(lines[4].begins_with("угрозы в середине (зёрен из 1)") and lines[4].contains("серпохвост ближе всего"), lines[4])
	ok(lines[5].begins_with("угрозы на подходе к 01 (зёрен из 1)"), lines[5])
	ok(lines[6].begins_with("порядок: моллюски до первого «замера»"), lines[6])
	ok(lines[2].contains("свет 0 → луч на волнолисте") and lines[2].contains("путь №0 (при свете — ") \
		and lines[2].contains("): старт (-60; 20)"), lines[2])
	ok(lines[2].contains("цели №0: ") and lines[2].contains("охота на рыб"), lines[2])
	ok(lines[2].contains("стая 0: до ") and lines[2].contains("кадров погони"), lines[2])
	ok(lines[0].contains("цели №0 как в игре"), lines[0])
	ok(lines[7].begins_with("путь середины") and lines[7].contains("отрезок между целями"), lines[7])
	ok(lines[8].begins_with("стая 0: дальше всего от дома макс "), lines[8])
	ok(lines[9].begins_with("погони (HUNT, все серпохвосты): "), lines[9])


## fish= (#1400, 12.11): дом стаи рифа 0 — в новом месте на HOME_LIFT над дном, остальные стаи на месте.
func test_fish_move_puts_shoal_home_there() -> void:
	var tool := _tool()
	tool.set("fish_moves", tool.parse_moves("0:100,90"))
	var ev: EcoView = tool.make(7)
	_restore(tool)
	var h := ev.fish.shoals[0].home
	near(h.x, 100.0, 1e-4, "стая 0 — в новом доме по x")
	near(h.z, 90.0, 1e-4, "по z")
	near(h.y, Seabed.height(100.0, 90.0) + tool.HOME_LIFT, 1e-4, "на HOME_LIFT над дном")
	near(ev.fish.shoals[1].home.x, EcoFish.HOMES[1].x, 1e-4, "стая 1 — на месте")
	ev.free()


## Среда у дома: у прежнего дома стаи 0 — флора рядом (папоротники волнолиста), у пустой точки — «ничего».
func test_site_line_counts_life_near() -> void:
	var tool := _tool()
	var old: String = tool.site_line("прежний", Vector2(EcoFish.HOMES[0].x, EcoFish.HOMES[0].z))
	ok(old.begins_with("== прежний (15; 76): дно ") and old.contains("EcoFern.ferns ×"), old)
	var empty: String = tool.site_line("пусто", Vector2(100.0, 90.0))
	ok(empty.contains("грунт песок ") and empty.ends_with("ближе 25 м: ничего"), empty)


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


## watch=1,5 (#1400, уровни и ГД 13.11 — совместная проба домов стай 1 и 5): по строке разброса и погонь на каждую
## стаю; стая 5 — на спине гротовика, её дом ходит по `EcoGrot.ROUTE`, перенос `fish=5` не действует — так и в шапке.
func test_watch_two_shoals_reports_each() -> void:
	var tool := _tool()
	eq(tool.parse_watch("1,5"), [1, 5] as Array[int])
	tool.set("watch", tool.parse_watch("1,5"))
	tool.set("dark", 0.0)
	tool.set("limit", 6.0)
	var lines: Array[String] = tool.report(1)
	_restore(tool)
	eq(lines.size(), 12, "шапка, две стаи, зерно, итог, угрозы ×2, порядок, цели №0, стаи 1 и 5, погони")
	ok(lines[1].begins_with("== дом стаи светляков 1 (-26; 24)"), lines[1])
	ok(lines[2].begins_with("== стая светляков 5 — на спине гротовика") and lines[2].contains("fish=5 не действует"), lines[2])
	ok(lines[3].contains("стая 1: до ") and lines[3].contains("; стая 5: до "), lines[3])
	ok(lines[9].begins_with("стая 1: дальше всего от дома") and lines[9].contains("погонь на неё "), lines[9])
	ok(lines[10].begins_with("стая 5: дальше всего от дома"), lines[10])
	eq(EcoGrot.RIDERS, 5, "стая гротовика — 5")


## Погоня на стаю из watch — строкой: кто, на кого, с какой по какую секунду от света, откуда куда, ближе всего к
## выходу 00 и к пути середины.
func test_chases_line() -> void:
	var tool := _tool()
	tool.set("dark", 30.0)
	var s: String = tool.chases_line([{"who": 1, "shoal": 5, "t0": 18.0, "t1": 34.0, "from": Vector2(60, 40),
		"to": Vector2(70, 52), "exit": 70.4, "path": 45.0}])
	_restore(tool)
	eq(s, "№1→5 -12…4 с (60; 40)→(70; 52), к выходу 00 70 м, к пути середины 45 м")


## sites=1: среда у дома стаи 1, у четырёх точек круга гротовика (стая 5) и у существующих рифов — кандидаты
## совместной расстановки (уровни 13.11: «site_line существующих участков со средой»).
func test_sites_list_homes_grot_and_reefs() -> void:
	var tool := _tool()
	tool.set("watch", tool.parse_watch("1,5"))
	tool.set("sites", true)
	var lines: Array[String] = tool.report(0)
	_restore(tool)
	var got := lines.filter(func(l: String) -> bool: return l.begins_with("== дом стаи 1 (") \
		or l.begins_with("== точка круга гротовика (стая 5)") or l.begins_with("== риф ("))
	eq(got.size(), 1 + EcoGrot.ROUTE.size() + EcoCoral.BASES.size(), "\n".join(lines))


## grot= — круг гротовика на пробу (уровни и ГД 13.11, #1400): точки круга в среде (sites=1) — пробные, путь
## (`grot_path`) — круг целиком, гротовик замыкает его и печатает, кто ближе всего. В игре круг — `EcoGrot.ROUTE`.
func test_grot_probe_route_sites_and_path() -> void:
	var tool := _tool()
	eq(tool.parse_route("43,75;55,65;55,49;43,39"), [Vector2(43, 75), Vector2(55, 65), Vector2(55, 49), Vector2(43, 39)] as Array[Vector2])
	ok(EcoGrot.route == EcoGrot.ROUTE, "в игре — прежний круг")
	EcoGrot.route = tool.parse_route("43,75;55,65;55,49;43,39")
	tool.set("watch", tool.parse_watch("5"))
	tool.set("sites", true)
	var lines: Array[String] = tool.report(0)
	var path: Array[String] = tool.grot_path()
	EcoGrot.route = EcoGrot.ROUTE
	_restore(tool)
	var got := lines.filter(func(l: String) -> bool: return l.begins_with("== точка круга гротовика (стая 5) (55; 65)"))
	eq(got.size(), 1, "\n".join(lines))
	ok(lines.any(func(l: String) -> bool: return "проба grot=" in l), "заголовок говорит о пробе")
	ok(path[0].begins_with("== круг гротовика [(43.0, 75.0)"), path[0])
	ok(not ("НЕ замкнулся" in path[0]), path[0])
	eq(path.size(), 4, "\n".join(path))


## repeat=1 (уровни и ГД 14.11, #1400): настоящий повтор 00→01→00→01 — корабль проходит все пять участков по порядку,
## на каждом своя строка (угрозы, «замер», серпохвост ближе всего), засады глазуна в слышимости — отдельными строками
## с местом корабля и ближайшим серпохвостом; итог по каждому участку.
func test_repeat_walks_there_back_and_again() -> void:
	var tool := _tool()
	tool.set("repeat", true)
	tool.set("dark", 0.0)
	tool.set("limit", tool.LIMIT_REPEAT)
	var lines: Array[String] = tool.report(1)
	_restore(tool)
	ok(lines[0].contains("повтор 00→01→00→01"), lines[0])
	var seg: Array = lines.filter(func(l: String) -> bool: return l.begins_with("    участки: "))
	eq(seg.size(), 1, "\n".join(lines))
	var at := -1
	for sg in tool.SEGS:
		var i: int = (seg[0] as String).find(sg + ": с ")
		ok(i > at, "участок %s пройден после прежнего: %s" % [sg, seg[0]])
		at = i
	ok(not (seg[0] as String).contains("не дошёл"), seg[0])
	for sg in tool.SEGS:
		var tot := lines.filter(func(l: String) -> bool: return l.begins_with("участок %s (прошли 1/1)" % sg))
		eq(tot.size(), 1, "итог участка %s" % sg)
	var amb := lines.filter(func(l: String) -> bool: return l.begins_with("    засада "))
	print("  засад глазуна в слышимости за повтор: %d" % amb.size())
	ok(amb.size() > 0, "глазуны охотятся и за повтор их слышно")


## Строка засады: участок, время, глазун и корабль, свет и ход, ближайший серпохвост, монетники.
func test_ambush_line() -> void:
	var tool := _tool()
	var s: String = tool.ambush_line({"seg": "back", "t": 22.5, "gz": 0, "at": Vector2(32, 96), "ship": Vector2(4, 80),
		"d": 33.2, "light": true, "speed": 0.0, "pred": {"who": 2, "mode": "eat", "d": 24.0}, "coins": 7})
	eq(s, "back 22.5 с: глазун 0 (32; 96), корабль (4; 80) в 33 м, свет, стоит; серпохвост №2 eat в 24 м; монетников 7")


## answer=1 и repeat=1 (#1350, 14.11 01:08): каждый ответ экипажа — hold с без света и хода, поэтому предел прохода
## растёт на hold за ответ (`pass_limit`); с постоянным пределом повтор с ответами молча обрывался, не дойдя до 012.
## Предел `lim` здесь — с запасом на один ход без ответов, но меньше хода с двумя ответами.
func test_answer_extends_pass_limit() -> void:
	var tool := _tool()
	tool.set("hold", tool.HOLD)
	eq(tool.pass_limit(0), tool.limit, "без ответов — предел lim")
	near(tool.pass_limit(3) - tool.pass_limit(2), tool.HOLD, 1e-6, "ответ — ещё hold")
	tool.set("repeat", true)
	tool.set("answer", true)
	tool.set("dark", 0.0)
	tool.set("limit", 200.0)
	var lines: Array[String] = tool.report(1)
	_restore(tool)
	ok(lines[0].contains("предел 200 с + 25 с на ответ"), lines[0])
	var seed_line: Array = lines.filter(func(l: String) -> bool: return l.begins_with("  зерно 0: "))
	var answers := -1
	var m := RegEx.create_from_string("ответов (\\d+)").search(seed_line[0])
	if m != null:
		answers = int(m.get_string(1))
	print("  ответов экипажа за повтор: %d (предел %.0f с + %d × %.0f с)" % [answers, 200.0, answers, tool.HOLD])
	ok(answers >= 2, "ответов больше одного — без продления предел 200 с не хватает: %s" % seed_line[0])
	for sg in tool.SEGS:
		eq(lines.filter(func(l: String) -> bool: return l.begins_with("участок %s (прошли 1/1)" % sg)).size(), 1,
			"с ответами дошли до участка %s:\n%s" % [sg, "\n".join(lines)])
