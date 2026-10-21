extends TestCase
## Вход по адресу ART-039 (`AddressPad`): клавиатура, проверка адреса, последний удачный адрес, адрес хоста.


func test_check() -> void:
	eq(AddressPad.check(""), AddressPad.Check.EMPTY)
	eq(AddressPad.check("192.168.1.7"), AddressPad.Check.OK)
	eq(AddressPad.check("0.0.0.0"), AddressPad.Check.OK)
	eq(AddressPad.check("255.255.255.255"), AddressPad.Check.OK)
	for t in ["1", "192.", "192.168", "192.168.1.", "10.0.0"]:
		eq(AddressPad.check(t), AddressPad.Check.PARTIAL, t + " — можно дописать")
	for t in [".", ".1", "1..2", "256.1.1.1", "1.2.3.4.5", "1.2.3.4.", "1234.1.1.1", "1.2.3.999"]:
		eq(AddressPad.check(t), AddressPad.Check.BAD, t + " — неверный")


func test_field_keys() -> void:
	var f := AddressPad.Field.new()
	for k in "192.168.1.7":
		ok(f.press(k))
	eq(f.text, "192.168.1.7")
	ok(f.can_join(), "годный адрес — «Войти» активна")
	ok(f.press("del"))
	eq(f.text, "192.168.1.")
	ok(not f.can_join(), "неполный не отправляется")
	eq(f.hint(), "", "неполный — без «Проверьте адрес»")
	ok(not f.press("x"), "только цифры и точка")
	var e := AddressPad.Field.new()
	ok(not e.press("del"), "пустое не стирается")


func test_field_max_len() -> void:
	var f := AddressPad.Field.new()
	for k in "111.111.111.1111":
		f.press(k)
	eq(f.text.length(), AddressPad.MAX_LEN, "до 15 знаков")
	f.text = "300.1.1.1"
	eq(f.hint(), AddressPad.BAD_TEXT)
	ok(not f.can_join())


func test_connecting() -> void:
	var f := AddressPad.Field.new()
	f.text = "10.0.0.2"
	ok(f.begin())
	eq(f.join_text(), "Отмена")
	ok(not f.press("1"), "во время подключения клавиши неактивны")
	ok(not f.begin(), "второе подключение не начинается")
	f.finish(false)
	eq(f.text, "10.0.0.2", "неудача — адрес в поле остаётся")
	eq(f.last, "", "неудачный адрес не запоминается")
	eq(f.join_text(), "Войти")
	f.begin()
	f.cancel()
	ok(not f.connecting, "«Отмена» прерывает подключение")
	f.begin()
	f.finish(true)
	eq(f.last, "10.0.0.2", "удачный — последний")
	f.text = ""
	ok(f.recall())
	eq(f.text, "10.0.0.2", "кнопка заполняет поле")
	ok(not f.connecting, "но не подключает")
	ok(not AddressPad.Field.new().recall(), "последнего ещё нет")


func test_key_rects() -> void:
	var full := Vector2(2400, 1080)
	eq(AddressPad.key_rect(0, 0, full), Rect2(1260, 270, 224, 128), "клавиша «1» по заметке")
	eq(AddressPad.key_rect(2, 3, full), Rect2(1756, 726, 224, 128), "«Стереть»")
	eq(AddressPad.key_rect(0, 0, Vector2(2340, 1080)).position.x, 1230.0, "19,5:9 — на 30 px левее")
	eq(AddressPad.key_rect(0, 0, Vector2(1920, 1080)).position.x, 1020.0, "16:9 — на 240 px левее")
	var half := AddressPad.key_rect(1, 1, Vector2(1200, 540))
	eq(half, Rect2(754, 211, 112, 64), "масштаб по высоте")
	eq(AddressPad.key_at(Vector2(1300, 300), full), "1")
	eq(AddressPad.key_at(Vector2(1800, 760), full), "del")
	eq(AddressPad.key_at(Vector2(1495, 300), full), "", "зазор между клавишами")
	eq(AddressPad.key_text("del"), "Стереть")
	eq(AddressPad.key_text("7"), "7")


func test_host_address() -> void:
	eq(AddressPad.host_address(PackedStringArray(["127.0.0.1", "fe80::1", "10.1.2.3", "192.168.0.5"])), "192.168.0.5",
		"домашняя сеть раньше прочих")
	eq(AddressPad.host_address(PackedStringArray(["127.0.0.1", "172.20.0.4", "10.0.0.9"])), "10.0.0.9")
	eq(AddressPad.host_address(PackedStringArray(["172.20.0.4", "169.254.3.3"])), "172.20.0.4")
	eq(AddressPad.host_address(PackedStringArray(["127.0.0.1", "169.254.1.1", "::1"])), "", "нет сети — пусто")
