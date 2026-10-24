extends TestCase
## История экспедиции для журнала ART-047 (Expedition): места, забеги, рекорд глубины, прочитанные карточки — в
## сохранении ключом "log"; старое сохранение — история неизвестна, испорченный файл — отдельное состояние.

const TEST_PATH := "user://test_expedition.json"


func _flat(_x: float, _z: float) -> float:
	return -40.0


func after() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func test_visit_any_place_once() -> void:
	var e := Expedition.new()
	var n := [0]
	e.changed.connect(func() -> void: n[0] += 1)
	eq(e.visit(0.0, 0.0), "", "у начала спуска мест нет")
	var p := Run.place_xz("geyser")
	eq(e.visit(p.x + 10.0, p.y), "geyser", "в радиусе места — посещено")
	eq(e.visit(p.x, p.y), "", "второй раз не новое")
	var d := Run.place_xz("drop")
	eq(e.visit(d.x, d.y), "drop", "место не из выбранного маршрута — тоже")
	eq(e.places, ["geyser", "drop"] as Array[String], "порядок первого посещения")
	eq(n[0], 2, "изменение — только при новом месте")


func test_depth_record_whole_meters() -> void:
	var e := Expedition.new()
	ok(e.dive_depth(12.7), "первый рекорд")
	eq(e.deepest, 12)
	ok(not e.dive_depth(12.9), "в пределах метра — файл не трогаем")
	ok(not e.dive_depth(5.0), "мельче — не рекорд")
	ok(e.dive_depth(40.2), "глубже — рекорд")
	eq(e.deepest, 40)


func test_new_until_card_opened() -> void:
	var e := Expedition.new()
	ok(e.is_new("fish", ["fish"]), "изучен, карточка не открыта — новое")
	ok(not e.is_new("eel", ["fish"]), "не изучен — не новое")
	e.mark_read("fish")
	e.mark_read("fish")
	ok(not e.is_new("fish", ["fish"]), "открыта — новое снято")
	eq(e.read.size(), 1, "без повторов")


func test_next_place_only_unvisited_and_known_history() -> void:
	var e := Expedition.new()
	eq(e.next_place(), "flower", "первое место первого маршрута")
	for k in ["flower", "bones", "well"]:
		var p := Run.place_xz(k)
		e.visit(p.x, p.y)
	eq(e.next_place(), "geyser", "сад пройден — дальше тёплые трубы")
	e.full = false
	eq(e.next_place(), "", "история неполная — совета нет")


func test_round_trip_in_save() -> void:
	var s := Samples.new(_flat)
	var a := Expedition.new()
	var p := Run.place_xz("shell")
	a.visit(p.x, p.y)
	a.dive_depth(77.0)
	a.end_run()
	a.end_run()
	a.mark_read("fish")
	var raw := JSON.stringify(SaveGame.snapshot(s, null, a))
	var b := Expedition.new()
	ok(SaveGame.apply(JSON.parse_string(raw), Samples.new(_flat), null, b), "принято")
	eq(b.places, ["shell"] as Array[String], "места")
	eq(b.runs, 2, "забеги")
	eq(b.deepest, 77, "рекорд")
	eq(b.read, ["fish"] as Array[String], "прочитанные")
	ok(b.full, "история полная")
	eq(JSON.stringify(SaveGame.snapshot(s)), '{"cargo":[],"got":[],"v":1}', "без журнала формат прежний")


func test_old_save_history_unknown() -> void:
	var e := Expedition.new()
	ok(SaveGame.apply({"v": 1, "cargo": [], "got": []}, Samples.new(_flat), null, e), "старый файл принят")
	ok(not e.full, "истории в файле нет — неизвестна")
	eq(e.runs, 0)
	e.end_run()
	var again := Expedition.new()
	SaveGame.apply(SaveGame.snapshot(Samples.new(_flat), null, e), Samples.new(_flat), null, again)
	ok(not again.full, "дописанная история остаётся неполной")
	var junk := Expedition.new()
	junk.apply({"places": ["nowhere", "well", "well"], "runs": "x", "deepest": -5, "read": 3})
	eq(junk.places, ["well"] as Array[String], "чужие и повторные места отброшены")
	ok(junk.runs == 0 and junk.deepest == 0 and junk.read.is_empty(), "поля без смысла — пусто")


func test_file_states_and_reset() -> void:
	var save := SaveGame.new()
	save.path = TEST_PATH
	save.expedition = Expedition.new()
	var s := Samples.new(_flat)
	ok(not save.load_into(s), "файла нет")
	eq(save.state, SaveGame.Load.NONE, "первый запуск — не испорчен")
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{обрыв")
	f.close()
	ok(not save.load_into(s), "испорчен")
	eq(save.state, SaveGame.Load.BROKEN, "испорченный файл — своё состояние")
	save.expedition.dive_depth(30.0)
	save.expedition.end_run()
	ok(save.save(s), "записано")
	var other := SaveGame.new()
	other.path = TEST_PATH
	other.expedition = Expedition.new()
	ok(other.load_into(Samples.new(_flat)), "прочитано")
	eq(other.state, SaveGame.Load.OK)
	ok(other.expedition.runs == 1 and other.expedition.deepest == 30, "история из файла")
	other.expedition.full = false
	other.reset(Samples.new(_flat))
	ok(other.expedition.runs == 0 and other.expedition.deepest == 0, "сброс — история с нуля")
	ok(other.expedition.full, "после сброса история полная")
	ok(not FileAccess.file_exists(TEST_PATH), "файл стёрт")


func test_scene_records_places_depth_and_runs() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(main.save.expedition == main.expedition, "история — в сохранении")
	var p := Run.place_xz("well")
	main.helm.pos = Vector3(p.x, -60.0, p.y)
	main.step(0.1)
	ok(main.expedition.visited("well"), "корабль у Светового колодца — место в журнале")
	ok(main.expedition.deepest >= floori(main.helm.depth()) and main.expedition.deepest > 0, "рекорд глубины")
	eq(main.expedition.runs, 0, "забег ещё идёт")
	main.vitals.hit(100, "")   # корпус разрушен — забег завершён
	for i in 40:
		main.step(0.1)
	eq(main.expedition.runs, 1, "после «Корпус разрушен» — один забег")
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.use_post("route")
	main.complete_route()
	main.use_post("route")
	main.step(0.3)
	main.decide("up")
	eq(main.expedition.runs, 2, "поднялись наверх — второй")
	main.queue_free()
	await frames(1)
