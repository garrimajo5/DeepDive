extends TestCase
## Автосохранение кампании слоя 1 (#823): вход в круг мест 00, 07, 09, 10 — запись сразу и «Сохранено: …».

const TEST_PATH := "user://test_autosave.json"

var main: Main


func after() -> void:
	if main:
		main.queue_free()
		main = null
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	await frames(1)


func test_points_on_map() -> void:
	for id: String in Autosave.POINTS:
		ok(LayerMap.POINTS.has(id), "%s — место карты слоя" % id)
	eq(Autosave.spot_at(0.0, 95.0), "00", "старт — место 00")
	eq(Autosave.spot_at(-100.0, -240.0), "07", "терраса врат")
	eq(Autosave.spot_at(40.0, -50.0), "", "Каменный цветок — не стоянка")
	eq(Autosave.message("07"), "Сохранено: Терраса врат")


func test_enter_once_and_rearm() -> void:
	var a := Autosave.new()
	eq(a.update(0.0, 95.0), "", "на старте — не сохранять")
	eq(a.update(0.0, 60.0), "", "отошли недалеко")
	eq(a.update(0.0, 90.0), "", "вернулись, не выйдя за LEAVE — не сохранять")
	eq(a.update(0.0, 40.0), "", "вышли дальше LEAVE")
	eq(a.update(0.0, 70.0), "00", "снова вошли к старту — сохранить")
	eq(a.update(0.0, 80.0), "", "внутри — один раз")
	eq(a.update(-100.0, -200.0), "", "у террасы, но не в круге")
	eq(a.update(-100.0, -225.0), "07", "в круге террасы врат")
	a.reset()
	eq(a.update(-100.0, -240.0), "", "после «Продолжить» на месте — не сохранять")


func test_scene_autosaves_at_spot() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.save.path = TEST_PATH
	tree.root.add_child(main)
	await frames(1)
	main.step(1.0 / 30.0)
	ok(not FileAccess.file_exists(TEST_PATH), "на старте файл не пишется")
	main.helm.pos = Vector3(-80.0, -40.0, 100.0)   # между стартом и заводью
	main.step(1.0 / 30.0)
	main.helm.pos = Vector3(-80.0, -40.0, 150.0)   # Тихая заводь 09
	main.step(1.0 / 30.0)
	ok(FileAccess.file_exists(TEST_PATH), "вход к заводи — запись")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	near(float(data["ship"]["z"]), main.helm.pos.z, 0.5, "в файле — место у заводи")
	eq(main.message.text, Autosave.message("09"), "на приборах «Сохранено: Тихая заводь»")
	main.helm.pos = Vector3(-80.0, -40.0, 155.0)
	var t := FileAccess.get_modified_time(TEST_PATH)
	DirAccess.remove_absolute(TEST_PATH)
	main.step(1.0 / 30.0)
	ok(not FileAccess.file_exists(TEST_PATH), "у заводи — один раз (было %d)" % t)
