class_name PauseFlow
extends RefCounted
## Системная «Назад», пауза ART-037 и схема корабля ART-042 поверх сцены `Main` (#754). «Назад» знает про все
## экраны (схема, настройки, журнал, адрес, сбор, меню, «Экономно», пауза) — порядок проверок важен. Состояние —
## поля `main.pause`, `main.ship_map`, панели — `main.pause_panel`, `main.ship_map_panel`. Живёт полем
## `main.pause_flow`; входы для тестов и `tools/` (`back_pressed`, `open_map`, `open_hint_map`) — тонкие
## пересылки у `Main`.

var main: Main


func _init(m: Main) -> void:
	main = m


## Системная «Назад» (Esc на ПК): в забеге — пауза ART-037, в паузе закрывает сначала подтверждение, потом паузу;
## в главном меню — выход из игры. В сетевом забеге — «Меню забега» (мир идёт); под шторкой «Корпус разрушен» и
## диалогом обрыва связи ART-043 — без паузы.
func back_pressed() -> void:
	if main.warm.active():
		return
	if main.ship_map.open:   # схема корабля — назад туда, откуда открыли (пауза)
		map_back()
		return
	if main.settings.open:   # настройки: сначала подтверждение сброса, потом — назад к меню или паузе
		main.menu_flow.settings_do(main.settings.back())
		main._settings_show()
		return
	if main.main_menu.open and main.logbook.open:
		main.logbook.back()
		if not main.logbook.open:
			main.save.flush(main.samples, main.scanner)
		main._journal_show()
		return
	if main.main_menu.open and main.address.open:   # экран адреса: сначала отмена попытки, потом вход сбора
		main.lobby_flow.address_do(main.address.back())
		if main.address_panel:
			main.address_panel.show_screen(main.address)
		return
	if main.main_menu.open and main.lobby.open:   # комната — ко входу, вход — в меню (ART-028)
		main.lobby_flow.lobby_back()
		return
	if main.main_menu.open:
		main.save.flush(main.samples, main.scanner)
		main.get_tree().quit()
		return
	if main.lite_offer.open:   # «Назад» над предложением «Экономно» — как «Нет»
		main.menu_flow.offer_do(main.lite_offer.back())
		return
	if not main.pause.open:
		if main.wreck.active() or (main.net_client != null and main.drop.blocks()):
			return
		main.pause.set_mode("host" if main.net_host != null else ("guest" if main.net_client != null else "solo"))
		main.pause.enabled["save"] = main.save.enabled()   # тесты и прогон тестера не пишут — кнопка погашена
	main.pause.back()
	pause_show()


func pause_show() -> void:
	if main.pause_panel == null:
		main.pause_panel = PausePanel.new()
		main.add_child(main.pause_panel)
	if not main.pause.open and main.ship_map.open:   # пауза закрылась (шторка, обрыв связи) — схема с ней
		main.ship_map.close()
	main.pause_panel.show_pause(main.pause)
	if main.ship_map.open:
		main.pause_panel.visible = false
	map_show()
	main.overlay.visible = not main.pause.open and not main.wreck.active()
	main.hint.visible = not main.pause.open and not main.wreck.active()   # строки приборов не лезут к заголовку паузы
	main.overlay.router.clear()   # палец, открывший или закрывший паузу, не идёт в игру


## Шаг под паузой: касания кнопок. «Новый забег» — с начала спуска, «Выйти в меню» — главное меню ART-037.
## Меню сетевого забега: хост — новый забег у всех или конец забега (гости теряют хоста), гость — «Покинуть экипаж».
## Шторка «Корпус разрушен», обрыв связи или конец сети закрывают меню забега.
func pause_step() -> void:
	var r := main.overlay.router
	if not main.pause.stops_world() and (main.wreck.active() or (main.net_client != null and main.drop.blocks())
			or (main.net_host == null and main.net_client == null)):
		main.pause.close()
		main.settings.close()
		main._settings_show()
		pause_show()
		return
	if main.ship_map.open:
		map_step(r)
		r.end_frame()
		return
	if main.settings.open:
		main.menu_flow.settings_step(r)
		r.end_frame()
		return
	for p in r.taps:
		var what := main.pause.press(main.pause.hit(p, main.get_viewport().get_visible_rect().size))
		if what != "":
			pause_show()
			match what:
				"new":
					main._leave_posts()
					main._restart()
					if main.net_host:
						main.announce("Хост начал новый забег: Ковчег у начала спуска")
					else:
						main.say("Новый забег: Ковчег у начала спуска")
				"exit":
					if main.net_host:
						main.net_game.stop_host()
					main.menu_flow.to_menu()
				"leave":
					main.net_game.leave_net()
					main.menu_flow.to_menu()
				"settings":
					main.open_settings()
				"map":
					open_map("pause")
				"save":
					main.save_now()
			break
		main.pause_panel.show_pause(main.pause)
	r.end_frame()


## Схема корабля ART-042 поверх паузы / меню забега: кнопки паузы скрыты, касания — «Назад».
func open_map(where: String) -> void:
	main.ship_map.open_from(where)
	if main.pause_panel:
		main.pause_panel.visible = false
	map_show()
	main.overlay.router.clear()   # палец с пункта «Схема корабля» не жмёт «Назад»


## Кнопка «Схема» на подсказке первого забега: схема поверх паузы (одиночный забег стоит, в коопе мир идёт —
## «Меню забега»), «Назад» — сразу к подсказке.
func open_hint_map() -> void:
	main.pause.set_mode("host" if main.net_host != null else ("guest" if main.net_client != null else "solo"))
	if not main.pause.open:
		main.pause.back()
	pause_show()
	open_map("hint")


## «Назад» схемы: обратно в паузу; открыли с подсказки — к подсказке, пауза закрывается.
func map_back() -> void:
	if main.ship_map.back() == "hint":
		map_show()
		main.pause.close()
		pause_show()
		return
	map_show()
	if main.pause_panel:
		main.pause_panel.show_pause(main.pause)
	main.overlay.router.clear()


## Шаг открытой схемы: касание «Назад»; в коопе мир идёт — отметки товарищей перерисовываются каждый шаг.
func map_step(r: Touch.Router) -> void:
	for p in r.taps:
		if main.ship_map.hit(p, main.get_viewport().get_visible_rect().size) == "back":
			map_back()
			return
	map_show()


## Данные схемы: отметки экипажа (свой — me), люки, тревога по главному полю табло.
func map_show() -> void:
	if main.ship_map_panel == null:
		if not main.ship_map.open:
			return
		_map_panel()
	var marks: Array = []
	for m: Crew.Member in main.crew:
		marks.append([m.x, m.z, ShipMap.letter(m.role)])
	var doors: Array[bool] = []
	for d in main.layout.doors:
		doors.append(d.passable())
	var a := ShipMap.alarm(AlarmBoard.main_field(main.alarms_on()), main.breach.active)
	main.ship_map_panel.show_map(main.ship_map, marks, main.crew.find(main.me), doors, a)


## Панель схемы: создаётся один раз — при прогреве или при первом открытии.
func _map_panel() -> ShipMapPanel:
	if main.ship_map_panel == null:
		main.ship_map_panel = ShipMapPanel.new()
		main.add_child(main.ship_map_panel)
	return main.ship_map_panel


## Прогрев (WarmRunner; отчёт тестера `29-shema` 295 мс при первом открытии, код 4 мс): панель схемы создаётся
## под шторкой и рисует план с тревогой, закрытым люком и отметками всех ролей — узел, атлас значков и глифы всех
## кеглей в кэше шрифта до первого «Схема корабля». on = false — снова скрыта и пуста.
func warm_map(on: bool) -> void:
	var panel := _map_panel()
	if not on:
		panel.show_map(null, [], -1, [], null)
		return
	var m := ShipMap.new()
	m.open_from("pause")
	var marks: Array = []
	for r in Crew.Role.size():
		marks.append([main.me.x + r * 1.5, main.me.z, ShipMap.letter(r)])
	var doors: Array[bool] = []
	for i in ShipLayout.DOOR_Z.size():
		doors.append(i != 0)   # один люк закрыт — подпись «Люк закрыт»
	panel.show_map(m, marks, 0, doors, ShipMap.alarm(AlarmBoard.Field.HEAT, null))
