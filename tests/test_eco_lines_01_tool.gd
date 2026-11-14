extends TestCase
## `tools/lines_01.gd` (#1400, п. 2 (э)): строки мира почти разом на приборах — сколько пришло и сколько потеряно
## (видны меньше `Status.Message.MIN_SHOW`) на проходе 00 → середина → 01.


func _tool() -> GDScript:
	var tool: GDScript = load("res://tools/lines_01.gd")
	for v in ["dark", "mid", "stay", "turn", "live"]:
		ok(tool.get(v) != null, "в инструменте есть %s" % v)
	return tool


func _restore(tool: GDScript) -> void:
	tool.set("dark", tool.DARK)
	tool.set("mid", tool.MID)
	tool.set("stay", tool.STAY)
	tool.set("turn", -1.0)
	tool.set("live", false)


## Короткий проход без стоянок у 00 и середины, 10 с у 01, течение повёрнуто на 2-й секунде: участки, поворот, строки.
func test_short_run_reports() -> void:
	var tool := _tool()
	tool.set("dark", 0.0)
	tool.set("mid", 0.0)
	tool.set("stay", 10.0)
	tool.set("turn", 2.0)
	var r: Dictionary = tool.run(0)
	var lines: Array[String] = tool.report(1)
	_restore(tool)
	for k in ["00", "mid", "01"]:
		ok(r.has(k), "участок %s в итоге" % k)
		var a: Dictionary = r[k]
		ok(int(a["lost"]) <= int(a["got"]), "%s: потеряно не больше пришедшего (%d из %d)" % [k, a["lost"], a["got"]])
		var n := 0
		for lab in a["lost_what"]:
			n += int(a["lost_what"][lab])
		eq(n, int(a["lost"]), "%s: потерянные разложены по видам" % k)
		var m := 0
		for pair: String in a["lost_by"]:
			m += int(a["lost_by"][pair])
			ok(pair.contains(" <- "), "%s: у потерянной названа сменившая: %s" % [k, pair])
		eq(m, int(a["lost"]), "%s: у каждой потерянной — сменившая" % k)
		for lab: String in a["lost_what"]:
			ok(lab != "fish/flee", "%s: бегство рыб разделено на крону и риф: %s" % [k, lab])
	ok(int(r["mid"]["got"]) > 0, "на ходу к 01 строки мира есть: %d" % r["mid"]["got"])
	near(float(r["turn_at"]), 2.0, 0.1, "течение повернуло, когда велено")
	for s: Array in r["shown"]:
		ok(float(s[2]) <= tool.WINDOW + 1e-3, "строка видна не дольше окна: %.2f" % s[2])
		ok(String(s[1]) != "?", "у строки найден вид: %s" % s[1])
	eq(lines.size(), 3, "шапка, зерно, итог")
	ok(lines[0].begins_with("== строки мира почти разом"), lines[0])
	ok(lines[1].begins_with("  зерно  0: 00: строк"), lines[1])
	ok(lines[2].begins_with("== итог: 00 — строк"), lines[2])


## Метка бегства рыб: крона и риф — по тексту кроны того же мира; прочие заметки — как были.
func test_flee_label_splits_crown_and_reef() -> void:
	var tool := _tool()
	var w := EcoWorld.new(1)
	w.add(EcoFish.new())
	w.emit(EcoFish.ID, "flee", Vector3.ZERO, EcoFish._crown_text(w))
	w.emit(EcoFish.ID, "flee", Vector3.ZERO, EcoFish._flee_text(w))
	var evs := w.bus.pending.duplicate()
	eq(evs.size(), 2, "два события бегства")
	var crown := String(EcoFish._crown_text(w).call())
	var reef := String(EcoFish._flee_text(w).call())
	ok(crown != reef, "тексты кроны и рифа разные")
	eq(String(tool._label(crown, evs, w)), "%s/flee-krona" % EcoFish.ID, "крона")
	eq(String(tool._label(reef, evs, w)), "%s/flee-rif" % EcoFish.ID, "риф")
	eq(String(tool._label(reef, evs)), "%s/flee" % EcoFish.ID, "без мира — без деления")
	eq(String(tool._label("нет такой", evs, w)), "?", "чужой текст")
	eq(String(tool._by_text({})), "", "без потерь — пусто")
	eq(String(tool._by_text({"a <- b": 2})), ", сменили: a <- b ×2", "сменившие строкой")
	eq(String(tool._by_text({"c <- d": 1, "a <- b": 3, "e <- f": 1})), ", сменили: a <- b ×3, c <- d ×1, e <- f ×1",
		"чаще — раньше")
