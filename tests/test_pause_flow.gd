extends TestCase
## «Назад», пауза ART-037 и схема корабля ART-042 (#754) — `PauseFlow` (`main.pause_flow`), у `Main` — пересылки
## `back_pressed`, `open_map`, `open_hint_map`.

const DT := 1.0 / 30.0

var main: Main


func after() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_scene_pause_flow() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(main.pause_flow is PauseFlow and main.pause_flow.main == main, "пауза и схема — поле main.pause_flow")
	for f in ["_pause_show", "_pause_step", "_map_back", "_map_step", "_map_show"]:
		ok(not main.has_method(f), "%s больше не в Main" % f)
	main.back_pressed()
	ok(main.pause.open and main.pause_panel != null and main.pause_panel.visible, "«Назад» в забеге — пауза")
	ok(not main.overlay.visible, "крестовина под паузой скрыта")
	main.open_map("pause")
	ok(main.ship_map.open and not main.pause_panel.visible, "схема поверх паузы, кнопки паузы скрыты")
	main.step(DT)
	ok(main.ship_map_panel != null and main.ship_map_panel.visible, "шаг под паузой рисует схему")
	main.back_pressed()
	ok(not main.ship_map.open and main.pause.open and main.pause_panel.visible, "«Назад» схемы — в паузу")
	main.back_pressed()
	ok(not main.pause.open and main.overlay.visible, "второе «Назад» — пауза закрыта, крестовина вернулась")


func test_hint_map_back_to_game() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.open_hint_map()
	ok(main.ship_map.open and main.pause.open, "«Схема» с подсказки — схема поверх паузы")
	main.back_pressed()
	ok(not main.ship_map.open and not main.pause.open, "«Назад» — сразу к подсказке, пауза закрыта")
