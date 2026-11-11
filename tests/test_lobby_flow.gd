extends TestCase
## Сбор экипажа ART-028 и вход по адресу ART-039 (#755) — `LobbyFlow` (`main.lobby_flow`), у `Main` — пересылки
## `open_lobby`, `open_address`.

const DT := 1.0 / 30.0
const FIND_PORT := 24790

var main: Main


func after() -> void:
	Main.menu = false
	if main:
		main.finder.stop()
		main.queue_free()
		main = null
	await frames(1)


func test_scene_lobby_flow() -> void:
	Main.menu = true
	main = load("res://scenes/main.tscn").instantiate()
	main.finder.port = FIND_PORT
	tree.root.add_child(main)
	await frames(2)
	ok(main.lobby_flow is LobbyFlow and main.lobby_flow.main == main, "сбор экипажа — поле main.lobby_flow")
	for f in ["_lobby_show", "_lobby_step", "_lobby_runs", "_lobby_join_start", "_lobby_join_step", "_lobby_join_end",
			"_lobby_create", "_lobby_back", "_lobby_start_host", "_lobby_start_guest", "_address_step", "_address_do"]:
		ok(not main.has_method(f), "%s больше не в Main" % f)
	ok(main.main_menu.open, "меню открыто")
	main.open_lobby()
	ok(main.lobby.open and main.lobby.entry, "«Экипаж» — вход сбора")
	ok(main.lobby_panel != null and main.lobby_panel.visible and not main.menu_panel.visible, "панель сбора поверх меню")
	main.step(DT)
	main.open_address()
	ok(main.address.open and main.address_panel.visible and not main.lobby_panel.visible, "«По адресу» поверх входа")
	main.step(DT)
	main.back_pressed()
	ok(not main.address.open and main.lobby.open and main.lobby_panel.visible, "«Назад» адреса — ко входу сбора")
	main.back_pressed()
	ok(not main.lobby.open and main.menu_panel.visible, "«Назад» со входа — в меню")
