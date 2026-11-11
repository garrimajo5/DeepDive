extends TestCase
## Части прогона тестов для CI (#845): TestShards.


func _files(names: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(names)
	return out


func test_parse() -> void:
	eq(TestShards.parse("2/3"), [2, 3])
	eq(TestShards.parse("1/1"), [1, 1])
	eq(TestShards.parse("0/3"), [], "части с 1")
	eq(TestShards.parse("4/3"), [], "часть больше числа частей")
	eq(TestShards.parse("2"), [])
	eq(TestShards.parse("a/b"), [])


func test_times_round_trip() -> void:
	var t := {"test_b.gd": 2.5, "test_a.gd": 10.0}
	var text := TestShards.write_times(t)
	ok(text.find("test_a.gd") < text.find("test_b.gd"), "по имени")
	eq(TestShards.read_times(text), t)
	eq(TestShards.read_times("# только заголовок\n\nплохая строка\n"), {})


func test_every_file_in_one_part() -> void:
	var files := _files(["test_a.gd", "test_b.gd", "test_c.gd", "test_d.gd", "test_e.gd", "test_f.gd", "test_g.gd"])
	var t := {"test_a.gd": 30.0, "test_b.gd": 5.0, "test_c.gd": 20.0, "test_d.gd": 1.0, "test_e.gd": 12.0}
	var seen: Array[String] = []
	for i in range(1, 4):
		seen.append_array(TestShards.pick(files, t, i, 3))
	seen.sort()
	eq(seen, files, "каждый файл ровно в одной части")


func test_balanced_by_time() -> void:
	# один долгий файл и много коротких: долгий — один в части, короткие делят остальные
	var files := _files(["test_big.gd"])
	var t := {"test_big.gd": 60.0}
	for k in 12:
		var f := "test_s%02d.gd" % k
		files.append(f)
		t[f] = 10.0
	var parts := TestShards.split(files, t, 3)
	var sums: Array[float] = []
	for p in parts:
		var s := 0.0
		for f in p:
			s += t[f]
		sums.append(s)
	eq(parts[0], ["test_big.gd"], "самый долгий — первым в свою часть")
	ok(sums.max() - sums.min() <= 10.0, "части ровные по времени: %s" % [sums])


func test_unknown_file_weighs_average() -> void:
	var t := {"test_a.gd": 4.0, "test_b.gd": 8.0}
	near(TestShards.weight("test_new.gd", t), 6.0, 0.001)
	near(TestShards.weight("test_a.gd", t), 4.0, 0.001)
	near(TestShards.weight("test_x.gd", {}), 1.0, 0.001)


func test_same_split_everywhere() -> void:
	# равные веса — порядок по имени, от порядка входа не зависит
	var a := _files(["test_c.gd", "test_a.gd", "test_d.gd", "test_b.gd"])
	var b := _files(["test_b.gd", "test_d.gd", "test_a.gd", "test_c.gd"])
	eq(TestShards.split(a, {}, 2), TestShards.split(b, {}, 2))
	eq(TestShards.split(a, {}, 2), [["test_a.gd", "test_c.gd"], ["test_b.gd", "test_d.gd"]])


func test_table_in_repo() -> void:
	# таблица в репозитории читается и покрывает 9 из 10 файлов (новые весят как средний — раскладка плывёт)
	var t := TestShards.load_times()
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	var known := files.filter(func(f): return t.has(f)).size()
	ok(known >= files.size() * 0.9, "в tests/vremya.txt %d из %d файлов — обновить замером" % [known, files.size()])


func test_table_has_no_gone_files() -> void:
	# в таблице нет строк удалённых файлов: их время не ушло бы ни в одну часть, а среднее для новых — съехало
	var t := TestShards.load_times()
	ok(not t.is_empty(), "таблица читается")
	for f in t:
		ok(FileAccess.file_exists("res://tests/" + f), "%s есть в tests/ — иначе убрать из tests/vremya.txt" % f)


func test_ci_runs_every_part() -> void:
	# матрица CI гоняет все части, и итог «Тесты» ждёт их и валится, если хоть одна упала
	var wf := FileAccess.get_file_as_string("res://.github/workflows/godot.yml")
	ok(wf.contains("part: [1, 2, 3]"), "матрица из трёх частей")
	ok(wf.contains("--shard ${{ matrix.part }}/3"), "часть берётся из матрицы, всего 3")
	ok(wf.contains("--shard ${{ matrix.part }}/3 --slow 15"), "каждая часть печатает 15 самых долгих тестов")
	ok(wf.contains("needs: [changes, test-parts, ps1]") and wf.contains("needs.test-parts.result }}\" = \"success\""),
		"итог «Тесты» проверяет результат всех частей")
	ok(wf.contains("if: always() && needs.changes.outputs.code == 'true'"), "итог не пропускается при упавшей части")


func test_slowest_tests() -> void:
	var t := {"test_a.test_x": 3.0, "test_a.test_y": 12.5, "test_b.test_z": 3.0, "test_c.test_w": 0.2}
	eq(TestShards.slowest(t, 2), [["test_a.test_y", 12.5], ["test_a.test_x", 3.0]], "долгие первыми, равные — по имени")
	eq(TestShards.slowest(t, 10).size(), 4, "N больше числа тестов — все")
	eq(TestShards.slowest(t, 0), [])
	eq(TestShards.slowest({}, 5), [])
	var text := TestShards.slow_text(t, 2)
	ok(text.begins_with("Самые долгие тесты (2):"), text)
	ok(text.find("test_a.test_y") < text.find("test_a.test_x"), "по убыванию: " + text)
	ok(text.contains("  12.5 с  test_a.test_y"), text)
	eq(TestShards.slow_text({}, 3), "")


func test_runner_has_slow_key() -> void:
	# ключ разбирает сам раннер: без него --slow ушёл бы в фильтры и прогон стал бы пустым
	var src := FileAccess.get_file_as_string("res://tests/run.gd")
	ok(src.contains("\"--slow\""), "run.gd разбирает --slow")
	ok(src.contains("TestShards.slow_text(test_s, slow_n)"), "run.gd печатает самые долгие тесты")


func test_load_fail_reason() -> void:
	# файл не загрузился — раннер пишет причину из ошибок движка и команду --check-only (#1350)
	var errs := ["Parse Error: Identifier \"nope\" not declared (test_a.gd:4 GDScript::reload)",
		"Failed to load script \"res://tests/test_a.gd\" with error \"Parse error\". (gdscript_resource_format.cpp:46 load)",
		"Parse Error: Identifier \"nope\" not declared (test_a.gd:4 GDScript::reload)"]
	var lines := TestShards.load_fail("test_a.gd", errs)
	eq(lines[0], "ПАДЕНИЕ  test_a.gd: скрипт не загрузился")
	eq(lines.size(), 3, "повтор и «Failed to load» — не причины: %s" % [lines])
	ok(lines[1].contains("причина: Parse Error: Identifier \"nope\""), lines[1])
	eq(lines[2], "         - подробно: godot --headless --path . --check-only -s tests/test_a.gd")
	eq(TestShards.load_fail("test_b.gd", []).size(), 2, "движок причину не дал — только подсказка")
	var many: Array = []
	for i in 9:
		many.append("ошибка %d" % i)
	eq(TestShards.load_fail("test_c.gd", many).size(), 7, "не больше пяти причин")
	var src := FileAccess.get_file_as_string("res://tests/run.gd")
	ok(src.contains("TestShards.load_fail(f, trap.take())"), "run.gd печатает причину незагрузившегося файла")
