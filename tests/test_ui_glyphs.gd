extends TestCase
## Строки игры — только знаками шрифта игры (ThemeDB.fallback_font). Знака нет в шрифте (▲▼◀▶, →) — Godot ищет
## системный шрифт телефона: на Android это загрузка файла шрифта при первом показе строки, рывок кадра
## (issue #217: «08-power» 700–1400 мс при коде 10 мс и отрисовке 5 мс — подсказка пульта «▲▼ … ◀▶»).
## Проверяем строки в кавычках в коде корабля (scripts/core, scripts/game) без комментариев.

const DIRS := ["res://scripts/core/", "res://scripts/game/"]


## Знаки строк, которых нет в шрифте игры: ["файл:строка знак", …].
static func missing(font: Font) -> PackedStringArray:
	var re := RegEx.new()
	re.compile('"((?:[^"\\\\]|\\\\.)*)"')
	var out := PackedStringArray()
	for dir: String in DIRS:
		for fn in DirAccess.get_files_at(dir):
			if not fn.ends_with(".gd"):
				continue
			var lines := FileAccess.get_file_as_string(dir + fn).split("\n")
			for i in lines.size():
				var code := _code(lines[i])
				for m in re.search_all(code):
					for c in m.get_string(1):
						var u := c.unicode_at(0)
						if u > 127 and not font.has_char(u):
							out.append("%s%s:%d %s" % [dir, fn, i + 1, c])
	return out


## Строка без комментария «#…» вне кавычек.
static func _code(line: String) -> String:
	var quoted := false
	for i in line.length():
		var c := line[i]
		if c == "\"" and (i == 0 or line[i - 1] != "\\"):
			quoted = not quoted
		elif c == "#" and not quoted:
			return line.substr(0, i)
	return line


func test_all_glyphs_in_game_font() -> void:
	var bad := missing(ThemeDB.fallback_font)
	eq(bad.size(), 0, "знаки вне шрифта игры: %s" % ", ".join(bad))


func test_scan_finds_missing_glyph() -> void:   # проверка сама видит знак вне шрифта
	ok(not ThemeDB.fallback_font.has_char("▲".unicode_at(0)), "▲ нет в шрифте игры")
	eq(_code('say("▲ — вверх")  # ▼'), 'say("▲ — вверх")  ', "комментарий отрезан")
	eq(_code('c = Color("#67DDEB")'), 'c = Color("#67DDEB")', "решётка в кавычках — не комментарий")


func test_panel_hints_fit() -> void:   # подсказки словами длиннее стрелок — но влезают в панели
	var f := ThemeDB.fallback_font
	var vis := Vector2(1600, 720)
	ok(f.get_string_size(PowerScreen.CONTROLS, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x < PowerScreen.W - 40.0,
		"пульт: %d px из %d" % [f.get_string_size(PowerScreen.CONTROLS, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x,
		PowerScreen.W - 40.0])
	var vp := VotePanel.new()
	vp.show_vote(0, [])
	var vw := minf(470.0, vis.x * 0.3)   # VotePanel.box
	ok(f.get_string_size(vp.foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x < vw * 0.9,
		"голосование: %d px из %d" % [f.get_string_size(vp.foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, vw * 0.9])
	vp.free()
