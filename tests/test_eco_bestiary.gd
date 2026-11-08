extends TestCase
## Пометка «[в игре]» в `docs/bestiary.md` совпадает с игрой (эпик #637, `docs/vidy-otbor.md`): у каждого вида реестра
## `Species` и у видов мира без реестра — есть, у прочих — нет. Раньше пометка стояла у 7 видов из 31.

const DOC := "res://docs/bestiary.md"
const MARK := " [в игре]"
## Виды в мире без реестра (сканер их не ловит) — имя в бестиарии и модуль мира, который их держит.
const WORLD_ONLY := {
	"Светящийся мох": "res://scripts/core/eco/moss.gd",
	"Огнецвет": "res://scripts/core/eco/coral.gd",
	"Ленточник": "res://scripts/core/eco/kelp.gd",
	"Ледяная моль": "res://scripts/core/eco/moth.gd",
	"Инеевая бахрома": "res://scripts/core/eco/fringe.gd",
}


## Виды бестиария: имя → есть ли пометка. Строка вида — «- **Имя** (…) [в игре]: …».
static func entries(text: String) -> Dictionary:
	var re := RegEx.create_from_string("(?m)^- \\*\\*([^*]+)\\*\\* \\([^)]*\\)( \\[в игре\\])?")
	var out := {}
	for m in re.search_all(text):
		out[m.get_string(1)] = m.get_string(2) != ""
	return out


func _doc() -> Dictionary:
	return entries(FileAccess.get_file_as_string(DOC))


func test_parse_line() -> void:
	var d := entries("- **Скребун** (фауна, 1,5 м) [в игре]: текст\n- **Блиц** (фауна, 8 см): текст\nпросто строка")
	eq(d.size(), 2, "два вида")
	ok(d["Скребун"], "с пометкой")
	ok(not d["Блиц"], "без пометки")


func test_hundred_species() -> void:
	eq(_doc().size(), 100, "в бестиарии 100 видов")


func test_registry_marked() -> void:
	var d := _doc()
	for id in Species.ids():
		var nm := Species.info(id).name
		ok(d.has(nm), "%s (%s) — в бестиарии" % [nm, id])
		ok(d.get(nm, false), "%s — пометка «в игре»" % nm)


func test_world_only_marked_and_exist() -> void:
	var d := _doc()
	for nm in WORLD_ONLY:
		ok(ResourceLoader.exists(WORLD_ONLY[nm]), "%s — модуль мира есть" % nm)
		ok(d.get(nm, false), "%s — пометка «в игре»" % nm)
		var in_registry := false
		for id in Species.ids():
			in_registry = in_registry or Species.info(id).name == nm
		ok(not in_registry, "%s — не в реестре (иначе убрать из WORLD_ONLY)" % nm)


func test_no_extra_marks() -> void:
	var game := {}
	for id in Species.ids():
		game[Species.info(id).name] = true
	for nm in WORLD_ONLY:
		game[nm] = true
	var d := _doc()
	var marked := 0
	for nm in d:
		if d[nm]:
			marked += 1
			ok(game.has(nm), "%s помечен «в игре», но его нет в игре" % nm)
	eq(marked, Species.count() + WORLD_ONLY.size(), "пометок — сколько видов в игре")
