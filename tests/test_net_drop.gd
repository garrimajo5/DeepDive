extends TestCase
## Диалог потери хоста у гостя (ART-043): окно ожидания, «Нет ответа», новая попытка, подтверждение соло,
## отказ без повторов, «Связь восстановлена», места кнопок.


func test_wait_counts_down_then_no_answer() -> void:
	var d := NetDrop.new()
	ok(not d.active() and not d.blocks())
	ok(d.open(), "нужна попытка")
	ok(d.blocks(), "управление остановлено")
	eq(d.wait_line(), "Ждём хоста · осталось 10 с")
	ok(not d.update(3.2))
	eq(d.wait_line(), "Ждём хоста · осталось 7 с")
	ok(d.update(7.0), "окно истекло")
	eq(d.phase, NetDrop.Phase.NO_ANSWER)
	eq(d.wait_line(), "Нет ответа")
	ok(not d.update(30.0), "дальше само ничего не делает — соло нет")
	eq(d.phase, NetDrop.Phase.NO_ANSWER)


func test_wait_again_is_new_attempt() -> void:
	var d := NetDrop.new()
	d.open()
	eq(d.press("wait"), "", "пока ждём — «Ждать» не начинает вторую попытку")
	d.update(NetDrop.WINDOW)
	eq(d.press("wait"), "rejoin", "новая попытка")
	eq(d.phase, NetDrop.Phase.WAIT)
	d.update(2.5)
	eq(d.wait_line(), "Подключаемся… 3 из 10 с")


func test_solo_needs_confirm() -> void:
	var d := NetDrop.new()
	d.open()
	eq(d.press("solo"), "")
	eq(d.phase, NetDrop.Phase.CONFIRM_SOLO)
	eq(d.lines()[0], "Продолжить одному?")
	eq(d.lines()[2], "Начать новый одиночный забег?", "перенос забега в соло не сделан")
	var b := d.buttons()
	eq(b.size(), 2)
	eq(b[1][0], "no")
	ok(b[1][2], "по умолчанию выделено «Нет»")
	eq(d.press("no"), "")
	eq(d.phase, NetDrop.Phase.WAIT, "назад к ожиданию")
	d.press("solo")
	eq(d.press("yes"), "solo")
	ok(not d.active())


func test_no_after_window_expired_shows_no_answer() -> void:
	var d := NetDrop.new()
	d.open()
	d.press("solo")
	d.update(NetDrop.WINDOW + 1.0)
	eq(d.phase, NetDrop.Phase.CONFIRM_SOLO, "подтверждение не сбивается")
	d.press("no")
	eq(d.phase, NetDrop.Phase.NO_ANSWER)


func test_menu_off_until_menu_exists() -> void:
	var d := NetDrop.new()
	d.open()
	eq(d.press("menu"), "")
	eq(d.phase, NetDrop.Phase.WAIT, "меню ART-037 нет — «В меню» погашена")
	ok(not d.buttons()[2][3])
	d.menu_ready = true
	d.press("menu")
	eq(d.phase, NetDrop.Phase.CONFIRM_MENU)
	eq(d.press("yes"), "menu")


func test_refused_no_retry() -> void:
	var d := NetDrop.new()
	d.open()
	d.refused("full")
	eq(d.phase, NetDrop.Phase.REFUSED)
	eq(d.wait_line(), "Экипаж полон")
	eq(d.press("wait"), "", "без повторов")
	ok(not d.buttons()[0][3])


func test_restored_banner_two_seconds() -> void:
	var d := NetDrop.new()
	d.open()
	d.update(4.0)
	d.restored()
	eq(d.phase, NetDrop.Phase.BACK)
	ok(not d.blocks(), "управление вернулось")
	eq(d.lines()[1], "Вы снова в экипаже")
	d.update(1.9)
	ok(d.active())
	d.update(0.2)
	ok(not d.active())
	d.restored()
	ok(not d.active(), "кадр без потери — ничего")


func test_layout_scales_from_2400x1080() -> void:
	var d := NetDrop.new()
	d.open()
	var full := NetDrop.to_screen(NetDrop.BUTTONS["wait"], Vector2(2400, 1080))
	eq(full, Rect2(600, 615, 1200, 112))
	var r := NetDrop.to_screen(NetDrop.BUTTONS["solo"], Vector2(1600, 720))
	near(r.size.x, 580.0 * 720.0 / 1080.0, 0.01)
	near(r.position.x, 800.0 - 600.0 * 720.0 / 1080.0, 0.01, "центр по ширине")
	eq(d.hit(r.get_center(), Vector2(1600, 720)), "solo")
	eq(d.hit(Vector2(5, 5), Vector2(1600, 720)), "")
	d.refused("full")
	eq(d.hit(NetDrop.to_screen(NetDrop.BUTTONS["wait"], Vector2(1600, 720)).get_center(), Vector2(1600, 720)), "",
		"после отказа «Ждать» погашена")
