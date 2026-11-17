extends TestCase
## Панели решения экипажа (#1970, макет UX): кегль не мельче 12 sp (основной) и 10 sp (второй план) на 6", строки
## не выходят за рамку и на 16:9, панель — над кнопкой действия. Худшие значения: корпус 43 %, энергия 35,
## перегрев, ил, трюм 24, кооп со счётом голосов.

const SCREENS: Array[Vector2] = [Vector2(1600, 720), Vector2(1280, 720), Vector2(2400, 1080)]
const TALLY := "голосов 2 из 4 · 12 с"


## Все раскладки на экране vis: [имя, раскладка].
func _cases(vis: Vector2) -> Array:
	var out := []
	var worst := [Run.opinions(43.0, 35.0, false, true, 24), Run.opinions(43.0, 35.0, true, true, 24),
		Run.opinions(100.0, 100.0, false, false, 0)]
	for i in worst.size():
		for tally: String in ["", TALLY]:
			out.append(["голосование %d %s" % [i, tally], VoteLayout.vote(vis, "Глубже или наверх?",
				"Сейчас 12-й спуск", tally, worst[i], VoteLayout.FOOT)])
			var lore := LayerLore.new()
			out.append(["спуск %d %s" % [i, tally], VoteLayout.descent(vis, DescentVote.TITLE, DescentVote.SUB,
				DescentVote.unknown(lore), DescentVote.opinions(worst[i]), DescentVote.FOOT, tally)])
	var run := Run.new()
	run.begin(0.0, 0, 0, 0)
	run.depth = 11
	run.routes = 12
	out.append(["итог", VoteLayout.results(vis, "Экипаж поднялся наверх", "Очки экспедиции: 123456",
		Run.detail(run.results(60.0 * 180.0, 24, 30, 9, 100.0)), VoteLayout.FOOT_RESULTS)])
	return out


func test_sizes_not_below_limit() -> void:
	for vis in SCREENS:
		var k := vis.y / 720.0
		for c: Array in _cases(vis):
			for l: Dictionary in c[1]["lines"]:
				var least := (VoteLayout.MAIN if l["main"] else VoteLayout.SECOND) * k
				ok(l["px"] >= least - 0.001, "%s %s: «%s» %d px, предел %.1f" % [vis, c[0], l["t"], l["px"], least])
	eq(VoteLayout.MAIN, 22.0, "основной — 12 sp на 6\"")
	eq(VoteLayout.SECOND, 18.0, "второй план — 10 sp на 6\"")


func test_lines_fit_width() -> void:
	var f := ThemeDB.fallback_font
	for vis in SCREENS:
		var k := vis.y / 720.0
		for c: Array in _cases(vis):
			var b: Rect2 = c[1]["box"]
			var right := b.end.x - VoteLayout.PAD * k
			ok(b.end.x <= vis.x, "%s %s: панель на экране" % [vis, c[0]])
			var by_y := {}   # строки одной базовой линии (название и значение итога) — вместе
			for l: Dictionary in c[1]["lines"]:
				var w := f.get_string_size(l["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, l["px"]).x
				ok(l["at"].x >= b.position.x + VoteLayout.PAD * k - 0.01, "%s %s: «%s» не левее поля" % [vis, c[0], l["t"]])
				if l["w"] <= 0.0:
					ok(l["at"].x + w <= right, "%s %s: «%s» %d px, до поля %d" % [vis, c[0], l["t"], w, right - l["at"].x])
				by_y[l["at"].y] = float(by_y.get(l["at"].y, 0.0)) + w
			for y: float in by_y:
				ok(by_y[y] + 12.0 * k <= b.size.x - 2.0 * VoteLayout.PAD * k or by_y.size() == c[1]["lines"].size(),
					"%s %s: строка и значение рядом — %d px" % [vis, c[0], by_y[y]])


func test_lines_fit_height_and_clear_button() -> void:
	for vis in SCREENS:
		var k := vis.y / 720.0
		var limit := DescentVote.action_top(vis) - DescentVote.GAP * vis.y / 1080.0
		for c: Array in _cases(vis):
			var b: Rect2 = c[1]["box"]
			ok(b.end.y <= limit + 0.01, "%s %s: низ %d выше кнопки действия %d" % [vis, c[0], b.end.y, limit])
			var last := 0.0
			var prev := b.position.y
			for l: Dictionary in c[1]["lines"]:
				if l["at"].y > prev + 0.01:   # следующая строка не наезжает на прошлую
					ok(l["at"].y - prev >= l["px"] * 0.95, "%s %s: «%s» шаг %.1f при кегле %d" % [vis, c[0], l["t"],
						l["at"].y - prev, l["px"]])
				prev = l["at"].y
				last = maxf(last, l["at"].y)
			ok(last + 5.0 * k <= b.end.y, "%s %s: последняя строка %d внутри рамки %d" % [vis, c[0], last, b.end.y])
			for d: Dictionary in c[1]["dots"]:
				ok(b.has_point(d["at"]), "%s %s: точка в рамке" % [vis, c[0]])


func test_width_by_screen() -> void:
	near(DescentVote.width(Vector2(1280, 720)), 420.0, 0.01, "16:9 — не уже 420")
	near(DescentVote.width(Vector2(1600, 720)), 470.0, 0.01, "широкий — не шире 470")
	near(DescentVote.width(Vector2(2400, 1080)), 705.0, 0.01, "ширина — по высоте экрана")
	near(VoteLayout.room(Vector2(1600, 720), VoteLayout.TOP).position.y, 0.17 * 720.0, 0.01, "верх — 17 % высоты")


func test_tight_room_squeezes_gaps_not_size() -> void:
	eq(VoteLayout.fit(300.0, 400.0), 1.0)
	near(VoteLayout.fit(400.0, 300.0), 0.75, 0.0001)
	var p := VoteLayout.Pen.new(Vector2(1600, 720), Rect2(100, 100, 470, 60))
	p.add(30.0, "а", VoteLayout.MAIN, VoteLayout.TEAL, true)
	p.add(60.0, "б", VoteLayout.SECOND, VoteLayout.DIM, false)
	var l := p.done(30.0)
	near(l["box"].size.y, 60.0, 0.01, "рамка — не выше места")
	near(l["lines"][1]["at"].y, 100.0 + 45.0, 0.01, "шаги сжаты вдвое")
	eq(l["lines"][1]["px"], 18, "кегль тот же")


func test_hints_and_opinions_short() -> void:
	eq(VoteLayout.FOOT, "вниз — глубже · вверх — наверх")
	eq(DescentVote.FOOT, "вниз — спуститься")
	ok(not "кнопка" in VoteLayout.FOOT and not "кнопка" in DescentVote.FOOT, "«позже» — только на кнопке действия")
	var ops := Run.opinions(100.0, 100.0, false, false, 4)
	eq(ops[0][2], "корабль слушается")
	eq(ops[3][2], "в трюме 4 — пора наверх", "без «4 образцов»")
	eq(Run.opinions(100.0, 100.0, false, false, 0)[3][2], "образцов мало, внизу больше")


func test_scene_panel_uses_layout() -> void:
	var p := VotePanel.new()
	tree.root.add_child(p)
	await frames(1)
	var vis := p.get_viewport_rect().size
	p.show_vote(0, Run.opinions(43.0, 35.0, false, true, 24))
	p.set_tally(TALLY)
	eq(p.foot, VoteLayout.FOOT)
	eq(p.box(), VoteLayout.vote(vis, p.title, p.sub, TALLY, p.rows, p.foot)["box"], "голосование — по раскладке")
	p.show_results([["Спусков", "2"]], 10)
	eq(p.layout()["lines"].size(), 5, "итог: заголовок, очки, название и значение, подсказка")
	p.show_descent(DescentVote.unknown(LayerLore.new()), [])
	ok(p.box().end.y <= DescentVote.action_top(vis), "спуск — над кнопкой действия")
	for px in VoteLayout.sizes(vis):
		ok(px in p.warm_sizes(), "кегль %d прогрет" % px)
	p.queue_free()
	await frames(1)
