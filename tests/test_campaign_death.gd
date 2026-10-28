extends TestCase
## Гибель в кампании (#824): «Корпус разрушен» ведёт к последнему сохранению, а не к новому забегу; знания слоя и
## изученные виды не сбрасываются; разрушенный корпус под шторкой в файл не пишется.

const TEST_PATH := "user://test_campaign_death.json"


func _flat(_x: float, _z: float) -> float:
	return -40.0


func after() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func test_subtitle_by_save() -> void:
	eq(Wreck.sub(true), Wreck.SUB_LOAD, "есть сохранение — возврат к нему")
	eq(Wreck.sub(false), Wreck.SUB, "нет — к началу спуска")


## Запись под шторкой (корпус 0) не перетирает прошлое место: иначе гибель вернула бы к месту гибели с 1 % корпуса.
func test_destroyed_hull_not_saved() -> void:
	var s := Samples.new(_flat)
	var ship := Helm.Ship.new()
	var v := Vitals.new()
	var save := SaveGame.new()
	save.path = TEST_PATH
	save.helm = ship
	save.vitals = v
	ship.pos = Vector3(12.0, -50.0, 40.0)
	v.hull = 60.0
	save.save(s)
	ship.pos = Vector3(-80.0, -55.0, -90.0)
	v.hull = 0.0
	save.save(s)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	near(float(data["ship"]["z"]), 40.0, 0.01, "в файле прежнее место")
	near(float(data["ship"]["hull"]), 60.0, 0.01, "и прежний корпус")
	near(save.ship["pos"].z, 40.0, 0.01, "прочитанное в памяти — тоже прежнее")


func test_scene_death_loads_save() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	main.save.path = TEST_PATH
	tree.root.add_child(main)
	await frames(1)
	main.helm.pos = Vector3(30.0, -28.0, 10.0)
	main.helm.yaw = 0.7
	main.vitals.hull = 70.0
	main.vitals.energy = 55.0
	ok(main.save_now(), "сохранено у места")
	main.lore.learn(LayerLore.K2)
	main.scanner.scanned["fish"] = true
	main.helm.pos = Vector3(-60.0, -50.0, -80.0)   # ушли дальше и разбились
	main.save.mark()   # запись ждёт — сработает уже под шторкой
	main.vitals.hit(100, "")
	ok(main.wreck.active(), "корпус разрушен — шторка")
	eq(main.wreck_view.sub.text, Wreck.SUB_LOAD, "подпись — возврат к сохранению")
	for i in 36:
		main.step(0.1)
	ok(main.helm.pos.distance_to(Vector3(30.0, -28.0, 10.0)) < 1.0, "корабль на сохранённом месте: %s" % main.helm.pos)
	near(main.helm.yaw, 0.7, 1e-3, "курс из сохранения")
	near(main.vitals.hull, 70.0, 0.5, "корпус из сохранения, не целый")
	near(main.vitals.energy, 55.0, 0.5, "заряд из сохранения")
	ok(not main.flyby.active(), "без облёта начала забега")
	ok(main.lore.knows(LayerLore.K2), "знания слоя не сброшены")
	ok(main.scanner.scanned.has("fish"), "изученные виды не сброшены")
	main.save.flush(main.samples, main.scanner)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	near(float(data["ship"]["z"]), 10.0, 0.5, "в файле по-прежнему место сохранения")
	for i in 5:
		main.step(0.1)
	ok(not main.wreck.active(), "шторка убрана")
	main.queue_free()
	await frames(1)


## Без сохранения (первый забег, тесты) гибель, как раньше, поднимает корабль к началу спуска.
func test_scene_death_without_save() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.helm.pos = Vector3(30.0, -40.0, -60.0)
	main.vitals.hit(100, "")
	eq(main.wreck_view.sub.text, Wreck.SUB, "подпись — к началу спуска")
	for i in 36:
		main.step(0.1)
	eq(main.vitals.hull, Vitals.MAX, "целый корпус")
	ok(main.helm.pos.distance_to(Helm.Ship.START) < 1.0, "у начала спуска")
	main.queue_free()
	await frames(1)
