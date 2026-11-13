extends TestCase
## Имя местного вида в строках мира — только после скана (#1784, поправка владельца 13.11, #1709, #1754).
## Строки собираются через EcoWorld.nm / Species.called (описательное имя до скана). Готовый текст с настоящим
## именем вида в коде мира (scripts/core/eco/) — только в ветке «вид изучен» (EcoWorld.scanned): такие строки
## перечислены в ALLOWED; новая строка с именем без проверки скана валит тест.

const DIR := "res://scripts/core/eco/"

## [файл, кусок строки, почему можно]. «scan» — строка в ветке изученного вида: файл обязан читать EcoWorld.scanned.
const ALLOWED := [
	["eel.gd", "красный глаз стеклоуста", "scan"],        # EcoEel.WARN_TEXT, warn_text — при изученном виде
	["coins.gd", "Песчаный глазун схватил", "scan"],
	["coins.gd", "глаза песчаного глазуна", "scan"],
	["skalnik.gd", "Скальник в луче прожектора", "scan"],
	["bladder.gd", " пузырчатки", "scan"],
	["ognevka.gd", "Огнёвки", "scan"],
	["ognevka.gd", "веернике", "scan"],
	["remora.gd", "присоски", "scan"],                    # line(…, scanned)
	["eel.gd", "присосался к корпусу", "глагол"],
	["pred.gd", "присосался к жабрам", "глагол"],
	["organ.gd", "как орган", "сравнение, не имя"],
]


## Основы настоящих имён видов: «серпохво», «стеклоу»… — ловят и падежи, и множественное число.
static func _stems() -> Array[String]:
	var out: Array[String] = []
	for id in Species.ids():
		var n := Species.info(id).name.to_lower()
		var parts := n.split(" ")
		var w := parts[parts.size() - 1] if parts.size() > 1 else n.split("-")[0]
		out.append(w.substr(0, maxi(5, w.length() - 2)))
	return out


## Строковые литералы кода строки (без комментариев «#»/«##»).
static func _literals(line: String) -> Array[String]:
	var out: Array[String] = []
	var inside := false
	var cur := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if inside:
			if c == "\\" and i + 1 < line.length():
				cur += line[i + 1]
				i += 2
				continue
			if c == "\"":
				out.append(cur)
				cur = ""
				inside = false
			else:
				cur += c
		elif c == "#":
			break
		elif c == "\"":
			inside = true
		i += 1
	return out


static func _allowed(file: String, text: String) -> bool:
	for a in ALLOWED:
		if a[0] == file and text.contains(a[1]):
			return true
	return false


func test_no_species_name_without_scan() -> void:
	var stems := _stems()
	ok(stems.has("стеклоу") and stems.has("серпохво") and stems.has("глазу"), "основы имён: %s" % [stems])
	var found := 0
	var bad: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".gd") or f == "species.gd":
			continue
		var src := FileAccess.get_file_as_string(DIR + f)
		var n := 0
		for line in src.split("\n"):
			n += 1
			for s in _literals(line):
				var low := s.to_lower()
				for st in stems:
					if low.contains(st):
						found += 1
						if not _allowed(f, s):
							bad.append("%s:%d «%s»" % [f, n, s])
	eq(bad, [] as Array[String], "строки мира с настоящим именем вида без проверки скана")
	ok(found >= ALLOWED.size(), "проверка не пустая: строк с основами имён %d" % found)


## Каждая строка из ALLOWED ещё есть в коде (иначе список устарел), а «scan» — в файле, который читает scanned.
func test_allowed_lines_live_and_guarded() -> void:
	for a in ALLOWED:
		var src := FileAccess.get_file_as_string(DIR + str(a[0]))
		ok(src.contains(str(a[1])), "%s: «%s» ещё в коде" % [a[0], a[1]])
		if a[2] == "scan":
			ok(src.contains("scanned"), "%s проверяет скан (EcoWorld.scanned)" % a[0])


## Мутация: строка стеклоуста без проверки скана ловится (то, что было до #1784).
func test_catches_old_eel_warning() -> void:
	var old := "В расщелине у трещины — красный глаз стеклоуста."
	eq(_literals("const X := \"%s\"  # прим." % old), [old] as Array[String], "литерал разобран")
	ok(not _allowed("vent.gd", old), "в другом файле строку с именем список не пускает")
	var hit := false
	for st in _stems():
		hit = hit or old.to_lower().contains(st)
	ok(hit, "основа «стеклоу» находит имя в строке")


## Вызовы Species.info(…) в коде мира (кроме species.gd): там настоящее имя вида, минуя EcoWorld.nm (#1784,
## п. 2 (о) фокуса). [файл, кусок строки, почему можно] — имя не уходит на приборы.
const INFO_ALLOWED := [
	["remora.gd", "world.drag(Species.info(ID).name", "ключ тормоза EcoLink.DRAG: Main берёт только k"],
	["remora.gd", "w.nm(ID) == Species.info(ID).name", "сравнение: вид изучен ли"],
]

## Кто называет виновника для приборов: удар, утечка энергии, кража — имя только через nm (Species.cap(world.nm…)).
const BY_CALLS := ["hit_ship(", ".drain(", "EcoLink.steal("]


## Строки кода мира (без комментариев) с вызовом Species.info, не из INFO_ALLOWED.
static func _info_calls(file: String, src: String) -> Array[String]:
	var out: Array[String] = []
	var n := 0
	for line in src.split("\n"):
		n += 1
		var code := line.split("#")[0]
		if not code.contains("Species.info("):
			continue
		var ok_line := false
		for a in INFO_ALLOWED:
			ok_line = ok_line or (a[0] == file and code.contains(a[1]))
		if not ok_line:
			out.append("%s:%d %s" % [file, n, code.strip_edges()])
	return out


## Вызовы удара, утечки и кражи, чьё имя виновника идёт не через nm.
static func _by_calls(file: String, src: String) -> Array[String]:
	var out: Array[String] = []
	var n := 0
	for line in src.split("\n"):
		n += 1
		var code := line.split("#")[0]
		if code.contains("func ") or code.contains("EcoLink.drain(by"):
			continue   # объявления и пересылка уже собранного имени в EcoWorld
		for c in BY_CALLS:
			if code.contains(c) and not code.contains("nm("):
				out.append("%s:%d %s" % [file, n, code.strip_edges()])
	return out


func test_species_info_name_only_off_screen() -> void:
	var bad: Array[String] = []
	var seen := 0
	var by_seen := 0
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".gd") or f == "species.gd":
			continue
		var src := FileAccess.get_file_as_string(DIR + f)
		seen += src.count("Species.info(")
		bad.append_array(_info_calls(f, src))
		bad.append_array(_by_calls(f, src))
		for c in BY_CALLS:
			by_seen += src.count(c)
	print("  Species.info в коде мира: %d, вызовов удара/утечки/кражи: %d" % [seen, by_seen])
	eq(bad, [] as Array[String], "настоящее имя вида мимо EcoWorld.nm")
	ok(seen >= INFO_ALLOWED.size(), "проверка не пустая: Species.info %d" % seen)
	ok(by_seen >= 5, "проверка не пустая: удар/утечка/кража %d" % by_seen)
	for a in INFO_ALLOWED:
		ok(FileAccess.get_file_as_string(DIR + str(a[0])).contains(str(a[1])), "%s: «%s» ещё в коде" % [a[0], a[1]])


## Мутации: имя из Species.info в строке приборов и виновник удара без nm — ловятся.
func test_catches_info_name_and_raw_by() -> void:
	var msg := "\t\tworld.send(EcoLink.message(\"%s рядом\" % Species.info(ID).name))"
	eq(_info_calls("remora.gd", msg).size(), 1, "строка сообщения с Species.info(ID).name")
	eq(_info_calls("remora.gd", "\t\tworld.drag(Species.info(ID).name, on_hull, DRAG)").size(), 0, "ключ тормоза — можно")
	eq(_info_calls("pred.gd", "\tvar x := 1   # Species.info(ID).name в комментарии").size(), 0, "комментарий не код")
	var raw := "\t\t\t\tif world.hit_ship(Species.info(ID).name, BITE_DAMAGE, a.p):"
	eq(_by_calls("pred.gd", raw).size(), 1, "удар с сырым именем")
	eq(_by_calls("pred.gd", "\t\t\t\tif world.hit_ship(\"Серпохвост\", BITE_DAMAGE, a.p):").size(), 1, "удар с готовым именем")
	eq(_by_calls("pred.gd", "\t\t\t\tif world.hit_ship(Species.cap(world.nm(ID)), BITE_DAMAGE, a.p):").size(), 0,
		"удар через nm — можно")
