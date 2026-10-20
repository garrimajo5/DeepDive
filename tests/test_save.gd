extends TestCase
## Сохранение экспедиции (SaveGame, js/save.js): груз трюма и поднятые образцы переживают перезапуск игры.

const TEST_PATH := "user://test_save.json"


func _flat(_x: float, _z: float) -> float:
	return -40.0


func after() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func test_tests_do_not_touch_player_save() -> void:
	eq(SaveGame.default_path, "", "раннер выключил сохранение игрока")
	ok(not SaveGame.new().enabled(), "новое сохранение в тестах выключено")
	eq(SaveGame.PATH, "user://save.json", "в игре — user://save.json")


func test_snapshot_like_browser() -> void:
	var s := Samples.new(_flat)
	s.restore([3, 8], [[Samples.Kind.SHELL, 8], [Samples.Kind.CORAL, -1]])
	var d := SaveGame.snapshot(s)
	eq(JSON.stringify(d), '{"cargo":[{"i":8,"kind":"shell"},{"i":null,"kind":"coral"}],"got":[3,8],"v":1}',
		"формат как в js/save.js")


func test_round_trip_through_json() -> void:
	var a := Samples.new(_flat)
	a.restore([1, 5], [[Samples.Kind.MOSS, 5], [Samples.Kind.SPINE, -1]])
	var b := Samples.new(_flat)
	ok(SaveGame.apply(JSON.parse_string(JSON.stringify(SaveGame.snapshot(a))), b), "принято")
	eq(b.cargo, [[Samples.Kind.MOSS, 5], [Samples.Kind.SPINE, -1]], "груз тот же")
	ok(b.all[1].taken and b.all[5].taken and not b.all[0].taken, "поднятые убраны со дна")
	eq(b.got.size(), 2, "поднятые: 1 и 5")


func test_browser_save_accepted() -> void:
	# файл браузерной версии: лишние поля (виды, места, улучшения) не мешают
	var raw := '{"v":1,"species":{},"pois":[],"cargo":[{"kind":"coral","i":10},{"kind":"moss","i":null},{"kind":"???","i":2}],"got":[10,4],"ups":[]}'
	var s := Samples.new(_flat)
	ok(SaveGame.apply(JSON.parse_string(raw), s), "принято")
	eq(s.cargo, [[Samples.Kind.CORAL, 10], [Samples.Kind.MOSS, -1]], "неизвестный вид пропущен")
	ok(s.all[4].taken and s.all[10].taken, "поднятые 4 и 10")


func test_bad_data_changes_nothing() -> void:
	var s := Samples.new(_flat)
	s.restore([2], [[Samples.Kind.MOSS, 2]])
	for bad in [null, [], {"v": 2, "cargo": []}, {"cargo": []}, "x"]:
		ok(not SaveGame.apply(bad, s), "не наш формат: %s" % str(bad))
	eq(s.cargo, [[Samples.Kind.MOSS, 2]], "груз не тронут")
	ok(SaveGame.apply({"v": 1, "cargo": "x", "got": 5}, s), "версия наша — поля без смысла дают пустой трюм")
	ok(s.cargo.is_empty() and not s.all[2].taken, "пустой трюм")


func test_write_after_delay_and_load() -> void:
	var s := Samples.new(_flat)
	var save := SaveGame.new()
	save.path = TEST_PATH
	s.changed.connect(save.mark)
	s.restore([], [])
	s.cargo.append([Samples.Kind.SHELL, 9])
	s.got[9] = true
	s.changed.emit()
	ok(save.dirty, "изменение отмечено")
	save.tick(0.5, s)
	ok(not FileAccess.file_exists(TEST_PATH), "за 0,5 с ещё не пишет")
	save.tick(0.6, s)
	ok(FileAccess.file_exists(TEST_PATH) and not save.dirty, "через секунду записано")
	var t := Samples.new(_flat)
	var load := SaveGame.new()
	load.path = TEST_PATH
	ok(load.load_into(t), "прочитано")
	eq(t.cargo, [[Samples.Kind.SHELL, 9]], "груз из файла")
	ok(t.all[9].taken, "образец 9 со дна убран")
	load.wipe()
	ok(not FileAccess.file_exists(TEST_PATH), "стёрто")
	ok(not load.load_into(Samples.new(_flat)), "файла нет — false")


func test_broken_file_ignored() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{не json")
	f.close()
	var save := SaveGame.new()
	save.path = TEST_PATH
	var s := Samples.new(_flat)
	ok(not save.load_into(s), "испорченный файл — false")
	ok(s.cargo.is_empty(), "трюм пуст")


func test_flush_only_when_dirty() -> void:
	var s := Samples.new(_flat)
	var save := SaveGame.new()
	save.path = TEST_PATH
	save.flush(s)
	ok(not FileAccess.file_exists(TEST_PATH), "нечего писать — файла нет")
	save.mark()
	save.flush(s)
	ok(FileAccess.file_exists(TEST_PATH), "свернули игру — записано сразу")


func test_scene_restores_and_saves() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string('{"v":1,"cargo":[{"kind":"coral","i":11}],"got":[11]}')
	f.close()
	var main: Main = load("res://scenes/main.tscn").instantiate()
	main.save.path = TEST_PATH
	tree.root.add_child(main)
	await frames(1)
	eq(main.samples.cargo, [[Samples.Kind.CORAL, 11]], "после перезапуска груз в трюме")
	ok(main.samples.all[11].taken, "поднятый образец не лежит снова на дне")
	main.park_over_sample(8)
	main.airlock.open = true
	main.debug_winch = true
	for i in 16:
		main.step(0.1)
	main.debug_winch = false
	for i in 25:
		main.step(0.1)
	eq(main.samples.cargo.size(), 2, "поднят ещё один")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	eq(str(data["got"]), "[8.0, 11.0]", "в файле оба поднятых")
	main.queue_free()
	await frames(1)
