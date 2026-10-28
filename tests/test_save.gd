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


func test_ship_round_trip() -> void:
	# кампания слоя 1 (#823): место, курс, корпус и заряд корабля — в файле и обратно
	var s := Samples.new(_flat)
	var helm := Helm.Ship.new()
	var v := Vitals.new()
	helm.pos = Vector3(120.456, -61.2, -33.0)
	helm.yaw = 1.25
	helm.speed = 2.0
	v.hull = 47.5
	v.energy = 12.0
	var save := SaveGame.new()
	save.path = TEST_PATH
	save.helm = helm
	save.vitals = v
	ok(save.save(s), "записано")
	var load := SaveGame.new()
	load.path = TEST_PATH
	ok(load.load_into(Samples.new(_flat)), "прочитано")
	ok(not load.ship.is_empty(), "корабль в файле")
	var h2 := Helm.Ship.new()
	var v2 := Vitals.new()
	v2.flash = 1.0
	ok(SaveGame.ship_apply(load.ship, h2, v2), "вернули")
	near(h2.pos.x, 120.46, 0.001, "x до сантиметра")
	near(h2.pos.y, -61.2, 0.001, "глубина")
	near(h2.pos.z, -33.0, 0.001, "z")
	near(h2.yaw, 1.25, 0.0001, "курс")
	eq(h2.speed, 0.0, "после загрузки стоит")
	near(v2.hull, 47.5, 0.001, "корпус")
	near(v2.energy, 12.0, 0.001, "заряд")
	eq(v2.flash, 0.0, "вспышки удара нет")


func test_old_save_without_ship() -> void:
	# старый файл (без "ship") читается, корабль не сохранён — начинаем у старта
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string('{"v":1,"cargo":[{"kind":"moss","i":2}],"got":[2]}')
	f.close()
	var load := SaveGame.new()
	load.path = TEST_PATH
	var s := Samples.new(_flat)
	ok(load.load_into(s), "старое сохранение принято")
	eq(s.cargo, [[Samples.Kind.MOSS, 2]], "груз из него")
	ok(load.ship.is_empty(), "корабля нет")
	var h := Helm.Ship.new()
	ok(not SaveGame.ship_apply(load.ship, h, Vitals.new()), "нечего возвращать")
	eq(h.pos, Helm.Ship.START, "корабль у старта")


func test_ship_read_checks_numbers() -> void:
	for bad in [null, "x", [], {"x": 1}, {"x": 1, "y": -20, "z": 0, "yaw": 0, "hull": "50", "energy": 9},
			{"x": NAN, "y": -20, "z": 0, "yaw": 0, "hull": 50, "energy": 9}]:
		ok(SaveGame.ship_read(bad).is_empty(), "не корабль: %s" % str(bad))
	var d := SaveGame.ship_read({"x": 9000, "y": 40, "z": -9000, "yaw": 7.0, "hull": 0, "energy": 300})
	eq(d["pos"], Vector3(Helm.Ship.EDGE, Helm.Ship.CEILING, -Helm.Ship.EDGE), "место — в пределах хода")
	near(d["yaw"], 7.0 - TAU, 0.0001, "курс свёрнут")
	eq(d["hull"], 1.0, "разрушенный корпус не сохраняется — не ниже 1 %")
	eq(d["energy"], Vitals.MAX, "заряд не больше 100")


func test_ship_kept_without_helm() -> void:
	# сохранение без подключённого корабля (лишь груз) не теряет корабль, прочитанный из файла
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string('{"v":1,"cargo":[],"got":[],"ship":{"x":5,"y":-30,"z":7,"yaw":0.5,"hull":80,"energy":60}}')
	f.close()
	var save := SaveGame.new()
	save.path = TEST_PATH
	var s := Samples.new(_flat)
	ok(save.load_into(s), "прочитано")
	save.save(s)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	eq(float(data["ship"]["z"]), 7.0, "корабль остался в файле")
	save.reset(s)
	ok(save.ship.is_empty(), "сброс — корабля нет")


func test_scene_saves_ship() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	main.save.path = TEST_PATH
	tree.root.add_child(main)
	await frames(1)
	main.helm.pos = Vector3(30.0, -40.0, 10.0)
	main.vitals.hull = 66.0
	main.save.mark()
	main.save.flush(main.samples, main.scanner)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	eq(float(data["ship"]["x"]), 30.0, "место корабля в файле")
	eq(float(data["ship"]["hull"]), 66.0, "корпус в файле")
	main.queue_free()
	await frames(1)


## Под главным меню (`live = false`) корабль у начала спуска не перетирает сохранённое место (#823).
func test_menu_keeps_saved_ship() -> void:
	var s := Samples.new(_flat)
	var ship := Helm.Ship.new()
	var v := Vitals.new()
	var save := SaveGame.new()
	save.path = TEST_PATH
	save.helm = ship
	save.vitals = v
	ship.pos = Vector3(12.0, -50.0, 40.0)
	save.save(s)
	ship.reset()   # выход в меню: корабль у начала спуска
	save.live = false
	save.save(s)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	eq(float(data["ship"]["z"]), 40.0, "под меню в файле прежнее место")
	save.live = true
	save.save(s)
	data = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	near(float(data["ship"]["z"]), ship.pos.z, 0.01, "в забеге — место корабля в игре")


## «Продолжить» в меню — забег с сохранённого места; «Сохранить» в паузе пишет сразу; выход в меню место не трогает.
func test_scene_continue_and_pause_save() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": 1, "cargo": [], "got": [],
		"ship": {"x": 20.0, "y": -45.0, "z": -30.0, "yaw": 0.5, "hull": 70.0, "energy": 55.0}}))
	f.close()
	Main.menu = true
	Main.intro = true
	var main: Main = load("res://scenes/main.tscn").instantiate()
	main.save.path = TEST_PATH
	tree.root.add_child(main)
	await frames(1)
	main.settings.intro = true
	ok(main.main_menu.open and main.main_menu.can_continue, "в меню есть «Продолжить»")
	eq(main.main_menu.main_item(), "continue", "«Продолжить» — главная кнопка")
	var r := main.overlay.router
	var size := main.get_viewport().get_visible_rect().size
	r.begin(1, main.main_menu.rect("continue", size).get_center())
	main.step(1.0 / 30.0)
	r.end(1)
	ok(not main.main_menu.open, "меню закрыто")
	ok(main.helm.pos.is_equal_approx(Vector3(20.0, -45.0, -30.0)), "корабль на сохранённом месте")
	near(main.helm.yaw, 0.5, 1e-4, "курс из файла")
	near(main.vitals.hull, 70.0, 0.01, "корпус из файла")
	near(main.vitals.energy, 55.0, 0.01, "заряд из файла")
	ok(not main.flyby.active(), "без облёта: продолжаем, а не начинаем")
	main.helm.pos = Vector3(25.0, -45.0, -35.0)
	main.back_pressed()
	ok(main.pause.open and main.pause.enabled["save"], "пауза, «Сохранить» работает")
	r.begin(2, main.pause.rect("save", size).get_center())
	main.step(1.0 / 30.0)
	r.end(2)
	ok(main.pause.open and main.pause.saved, "пауза открыта, на кнопке «Сохранено»")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	eq(float(data["ship"]["z"]), -35.0, "«Сохранить» записал место сразу")
	main.pause.press("exit")
	main.pause.press("yes")
	main.menu_flow.to_menu()
	main.save.mark()
	main.save.flush(main.samples, main.scanner)
	data = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	eq(float(data["ship"]["z"]), -35.0, "выход в меню сохранённое место не перетёр")
	ok(main.main_menu.open and main.main_menu.can_continue, "в меню снова «Продолжить»")
	main.queue_free()
	Main.menu = false
	Main.intro = false
	await frames(1)
