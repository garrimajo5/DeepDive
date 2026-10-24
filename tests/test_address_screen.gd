extends TestCase
## Экран гостя «Войти по адресу» ART-039 (`AddressScreen`, `AddressPanel`): раскладка по макету, клавиши, подписи,
## «Войти» / «Отмена», ошибки NetLink, последний удачный адрес в своём файле; в сцене — «Экипаж» в меню, «Назад»,
## вход к хосту по loopback.

const PORT := 24740
const DT := 1.0 / 30.0
var main: Main
var host: NetLink.Host


func after() -> void:
	Main.menu = false
	if main:
		if main.net_client:
			main.net_client.stop()
		main.queue_free()
		main = null
	if host:
		host.stop()
		host = null
	await frames(1)


func test_layout_fits_phones() -> void:
	for size: Vector2 in [Vector2(2400, 1080), Vector2(1600, 720), Vector2(1920, 1080), Vector2(2340, 1080)]:
		var screen := Rect2(Vector2.ZERO, size)
		var rects := []
		for id in ["back", "field", "last", "join"]:
			var r := AddressScreen.screen_rect(id, size)
			ok(screen.encloses(r), "%s на экране %s" % [id, size])
			rects.append(r)
		for row in AddressPad.KEYS.size():
			for c in AddressPad.KEYS[row].size():
				var k := AddressPad.key_rect(c, row, size)
				ok(screen.encloses(k), "клавиша на экране %s" % size)
				for r: Rect2 in rects:
					ok(not r.intersects(k), "клавиши не налезают на кнопки (%s)" % size)
				near(k.position.x, Splash.rect_to_screen(Rect2(AddressPad.KEY_ORIGIN + AddressPad.KEY_STEP * Vector2(c, row),
					AddressPad.KEY_SIZE), size).position.x, 0.5, "клавиатура и кнопки — одна обрезка фона")
		for i in range(1, 4):
			ok(not (rects[i - 1] as Rect2).intersects(rects[i]), "кнопки не налезают друг на друга")
	near(AddressScreen.screen_rect("field", Vector2(1600, 720)).size.y, 126.0 * 720.0 / 1080.0, 0.01, "масштаб H/1080")


func test_keys_hint_and_join() -> void:
	var a := AddressScreen.new()
	var size := Vector2(1600, 720)
	var key := func(k: String) -> Vector2:
		for row in AddressPad.KEYS.size():
			var c: int = AddressPad.KEYS[row].find(k)
			if c >= 0:
				return AddressPad.key_rect(c, row, size).get_center()
		return Vector2.ZERO
	eq(a.hit(key.call("1"), size), "", "закрытый экран касаний не берёт")
	a.show()
	eq(a.hint(), AddressScreen.EMPTY_TEXT, "пусто — «Введите адрес хоста»")
	eq(a.hit(AddressScreen.screen_rect("join", size).get_center(), size), "", "«Войти» погашена без адреса")
	eq(a.hit(AddressScreen.screen_rect("last", size).get_center(), size), "", "последнего адреса нет — кнопки нет")
	for k in "192.168.43.999":
		a.press(a.hit(key.call(k), size))
	eq(a.field.text, "192.168.43.999")
	eq(a.hint(), "Проверьте адрес")
	a.press(a.hit(key.call("del"), size))
	a.press(a.hit(key.call("del"), size))
	eq(a.hint(), AddressScreen.GOOD_TEXT, "годный адрес — «В одной сети с хостом»")
	var join := AddressScreen.screen_rect("join", size).get_center()
	eq(a.press(a.hit(join, size)), "join", "«Войти» — подключаться")
	eq(a.hint(), AddressScreen.CONNECTING_TEXT)
	eq(a.field.join_text(), "Отмена")
	eq(a.hit(key.call("5"), size), "", "во время подключения клавиши неактивны")
	ok(not a.result(NetLink.State.CONNECTING, ""), "ещё ждём")
	ok(not a.result(NetLink.State.REFUSED, "timeout"), "тишина — отказ")
	eq(a.hint(), "Нет ответа", "тишина хоста — «Нет ответа», как на листе ART-039")
	eq(a.field.text, "192.168.43.9", "адрес остаётся")
	eq(a.field.last, "", "неудачный адрес не запоминается")
	a.press("join")
	a.result(NetLink.State.REFUSED, "full")
	eq(a.hint(), "Экипаж полон")
	a.press("join")
	a.result(NetLink.State.REFUSED, "version")
	eq(a.hint(), "Другая версия игры")
	a.press("0")
	eq(a.hint(), AddressScreen.GOOD_TEXT, "нажатие клавиши снимает ошибку")
	eq(a.press("join"), "join")
	eq(a.press(a.hit(join, size)), "cancel", "«Отмена» бросает попытку")
	ok(a.open and not a.field.connecting, "экран открыт, клавиши снова работают")
	a.press("join")
	eq(a.back(), "cancel", "«Назад» во время подключения — отмена, экран открыт")
	ok(a.open)
	a.press("join")
	ok(a.result(NetLink.State.JOINED, ""), "на борту")
	ok(not a.open, "экран закрыт")
	eq(a.field.last, "192.168.43.90", "удачный адрес — последний")
	a.show()
	a.field.text = ""
	eq(a.press(a.hit(AddressScreen.screen_rect("last", size).get_center(), size)), "", "последний не подключает")
	eq(a.field.text, "192.168.43.90", "последний заполняет поле")
	eq(a.back(), "back", "«Назад» — в меню")
	ok(not a.open)


func test_last_address_file() -> void:
	var path := "user://test_adres.cfg"
	DirAccess.remove_absolute(path)
	var a := AddressScreen.new()
	a.path = path
	a.load_last()
	eq(a.field.last, "", "файла нет — последнего нет")
	a.show()
	a.field.text = "10.0.0.7"
	a.press("join")
	a.result(NetLink.State.JOINED, "")
	var b := AddressScreen.new()
	b.path = path
	b.load_last()
	eq(b.field.last, "10.0.0.7", "последний удачный адрес — из файла")
	ok(not FileAccess.file_exists(SaveGame.PATH) or SaveGame.PATH != path, "отдельно от сохранения забега")
	DirAccess.remove_absolute(path)
	var off := AddressScreen.new()
	eq(off.path, "", "раннер выключил файл адреса")


func test_scene_menu_crew_join() -> void:
	host = NetLink.Host.new()
	eq(host.start(PORT), OK, "хост открыт")
	Main.menu = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var r := main.overlay.router
	var size := main.get_viewport().get_visible_rect().size
	ok(main.main_menu.open)
	_tap(r, MainMenu.screen_rect("crew", size).get_center())
	ok(main.address.open, "«Экипаж» — экран «Войти по адресу»")
	ok(main.address_panel.visible and not main.menu_panel.visible, "экран адреса вместо меню")
	ok(main.main_menu.open, "игра всё ещё под меню")
	main.back_pressed()
	ok(not main.address.open and main.menu_panel.visible, "«Назад» — снова меню")
	ok(main.main_menu.open)
	_tap(r, MainMenu.screen_rect("crew", size).get_center())
	main.address.field.text = "127.0.0.1"
	var c := main.address_client
	ok(c == null)
	# порт хоста — тестовый: попытку ставим вручную тем же путём, что «Войти»
	ok(main.address.field.begin())
	main.address_client = NetLink.Client.new()
	eq(main.address_client.join("127.0.0.1", PORT), OK)
	var joined := false
	for i in 120:
		host.poll(DT)
		main.step(DT)
		await frames(1)
		if main.net_client != null:
			joined = true
			break
	ok(joined, "хост ответил — клиент на борту")
	ok(not main.main_menu.open and not main.address.open, "меню и экран адреса закрыты")
	ok(not main.address_panel.visible, "экран скрыт")
	eq(main.address.field.last, "127.0.0.1", "адрес запомнен")


func test_scene_no_answer() -> void:
	Main.menu = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var r := main.overlay.router
	var size := main.get_viewport().get_visible_rect().size
	_tap(r, MainMenu.screen_rect("crew", size).get_center())
	main.address.field.text = "127.0.0.1"   # порт по умолчанию — хоста нет
	_tap(r, AddressScreen.screen_rect("join", size).get_center())
	ok(main.address_client != null and main.address.field.connecting, "«Войти» — попытка идёт")
	for i in int((NetLink.TIMEOUT + 1.0) / DT):
		main.step(DT)
		if not main.address.field.connecting:
			break
	ok(not main.address.field.connecting, "попытка кончилась")
	eq(main.address.hint(), "Нет ответа")
	ok(main.address.open and main.main_menu.open, "остаёмся на экране адреса")
	ok(main.net_client == null, "в игру не вошли")


func _tap(r: Touch.Router, p: Vector2) -> void:
	r.begin(7, p)
	main.step(DT)
	r.end(7)
	main.step(DT)
