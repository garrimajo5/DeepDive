extends TestCase
## Ключи `tools/shot.gd` — таблицей в шапке, строка на ключ (#1379). Повторный ключ молча включал чужую сцену
## (`spusk=` и «глубже», #1368): ключ в таблице один раз, всё, что читает код, — в таблице, и наоборот.

const FILES := ["res://tools/shot.gd", "res://tools/shot_setup.gd"]


## Ключи таблицы по порядку строк «## ключ=пример — что делает».
static func table_keys(text: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("^## ([a-z_0-9]+)=\\S* — ")
	for line in text.split("\n"):
		var m := re.search(line)
		if m:
			out.append(m.get_string(1))
	return out


## Ключи, которые читает код: kv.has("…"), kv.get("…"), kv["…"], "ключ=…" in args.
static func code_keys(text: String) -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("kv(?:\\.has\\(|\\.get\\(|\\[)\"([a-z_0-9]+)\"|\"([a-z_0-9]+)=[^\"]*\" in ")
	for m in re.search_all(text):
		out[m.get_string(1) if m.get_string(1) != "" else m.get_string(2)] = true
	return out


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_table_has_no_duplicates() -> void:
	var keys := table_keys(_read(FILES[0]))
	ok(keys.size() > 50, "таблица ключей найдена: %d" % keys.size())
	var seen := {}
	for k in keys:
		ok(not seen.has(k), "ключ в таблице один раз: " + k)
		seen[k] = true


func test_every_code_key_in_table() -> void:
	var table := {}
	for k in table_keys(_read(FILES[0])):
		table[k] = true
	var used := {}
	for f: String in FILES:
		used.merge(code_keys(_read(f)))
	ok(used.size() > 50, "ключи кода найдены: %d" % used.size())
	for k: String in used:
		ok(table.has(k), "ключ кода описан в шапке shot.gd: " + k)
	for k: String in table:
		ok(used.has(k), "ключ таблицы читает код: " + k)


func test_parsers() -> void:
	eq(table_keys("## a=1 — да\n## b_2=x,y — да\n##   c=1 — нет\n# d=1 — нет\n## e=1 и — нет"), ["a", "b_2"] as Array[String])
	var c := code_keys("if kv.has(\"a\"): kv.get(\"b\", \"0\") + kv[\"c\"]\nx = \"menu=1\" in args")
	eq(c.keys().size(), 4)
	ok(c.has("a") and c.has("b") and c.has("c") and c.has("menu"), "все виды чтения")
