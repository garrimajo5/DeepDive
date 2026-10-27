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
	# таблица в репозитории читается и покрывает большую часть файлов (новые весят как средний)
	var t := TestShards.load_times()
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	var known := files.filter(func(f): return t.has(f)).size()
	ok(known >= files.size() * 0.8, "в tests/vremya.txt %d из %d файлов — обновить замером" % [known, files.size()])


func test_ci_runs_every_part() -> void:
	# матрица CI гоняет все части, и итог «Тесты» ждёт их и валится, если хоть одна упала
	var wf := FileAccess.get_file_as_string("res://.github/workflows/godot.yml")
	ok(wf.contains("part: [1, 2, 3]"), "матрица из трёх частей")
	ok(wf.contains("--shard ${{ matrix.part }}/3"), "часть берётся из матрицы, всего 3")
	ok(wf.contains("needs: [changes, test-parts]") and wf.contains("needs.test-parts.result }}\" = \"success\""),
		"итог «Тесты» проверяет результат всех частей")
	ok(wf.contains("if: always() && needs.changes.outputs.code == 'true'"), "итог не пропускается при упавшей части")
