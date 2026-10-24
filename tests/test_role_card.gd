extends TestCase
## Карточка роли у поста ART-045: первый подход к посту своей роли, «Понятно» → «?», «?» открывает снова, чужая роль —
## плашка на 3 с, скрытие тревогой и подсказками, место карточки, касания не крутят взгляд, запоминание прочитанного.

const SIZE := Vector2(2400, 1080)

var main: Main


func after() -> void:
	Main.hints = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


func _run(c: RoleCard, at: String, mine := true, hidden := false, quiet := false, n := 10) -> void:
	for i in n:
		c.update(0.05, at, mine, hidden, quiet)


func test_table_by_concept() -> void:
	eq(RoleCard.CARDS.size(), 6, "шесть постов: штурвал, энергия, сканер, сонар, разряд, вентиль")
	eq(RoleCard.lines("sonar"), ["Находите контакты", "Действие — импульс", "Свайп — осмотреться"], "сонар по таблице")
	eq(RoleCard.lines("energy")[2], "Вверх-вниз — система, влево-вправо — доля", "у энергии словами, без стрелок")
	eq(RoleCard.letter("helm"), "П", "штурвал — пилот")
	eq(RoleCard.letter("valve"), "И", "вентиль — инженер")
	eq(RoleCard.foreign_title("energy"), "Это пост инженера", "чужая роль")
	eq(RoleCard.cell("valve"), Rect2(256, 128, 128, 128), "значок вентиля — ячейка 2,1 атласа ART-042")
	ok(ResourceLoader.exists(RoleCard.ATLAS), "атлас значков в игре")


func test_own_role() -> void:
	ok(RoleCard.is_own("energy", Crew.Role.PILOT, true), "одиночный забег — все посты свои")
	ok(not RoleCard.is_own("energy", Crew.Role.PILOT, false), "кооп: пилоту энергия чужая")
	ok(RoleCard.is_own("zap", Crew.Role.ENGINEER, false), "инженеру разряд свой")
	ok(not RoleCard.is_own("airlock", Crew.Role.ENGINEER, true), "у шлюза карточки нет")
	eq(RoleCard.post_at(true, false, ""), "helm", "за штурвалом — штурвал")
	eq(RoleCard.post_at(false, true, ""), "energy", "у открытого пульта — энергия")
	eq(RoleCard.post_at(false, false, "route"), "", "у «Маршрута» карточки нет")


func test_first_visit_ok_then_ask() -> void:
	var c := RoleCard.new()
	_run(c, "sonar")
	ok(c.open and c.a == 1.0, "первый подход — карточка")
	ok(not c.ask_shown(), "«?» пока нет")
	var r := RoleCard.card_rect("sonar", SIZE)
	eq(c.tap(RoleCard.button_rect(r, SIZE).get_center(), SIZE, r), "ok", "«Понятно»")
	ok(not c.open and c.read.has("sonar"), "свёрнута и прочитана")
	_run(c, "sonar")
	ok(c.ask_shown() and c.q == 1.0, "у поста — «?»")
	eq(c.tap(RoleCard.ask_rect(SIZE).get_center(), SIZE, Rect2()), "ask", "«?» открывает снова")
	ok(c.open, "открыта")
	_run(c, "")
	_run(c, "sonar")
	ok(not c.open and c.ask_shown(), "второй подход — только «?»")
	eq(c.tap(Vector2(1200, 900), SIZE, r), "", "мимо — ничего")


func test_leaving_counts_as_shown() -> void:
	var c := RoleCard.new()
	_run(c, "helm")
	ok(c.open, "карточка штурвала")
	ok(c.update(0.05, "", false, false), "ушёл не нажав — прочитано (сохранить)")
	_run(c, "helm")
	ok(not c.open, "больше не открывается сама")


func test_hidden_and_quiet() -> void:
	var c := RoleCard.new()
	_run(c, "scanner", true, false, true)
	ok(not c.open and c.a == 0.0, "идут подсказки ART-038 — не показываем")
	ok(not c.read.has("scanner"), "и не считаем прочитанной")
	_run(c, "scanner")
	ok(c.open, "подсказки кончились — карточка")
	_run(c, "scanner", true, true)
	ok(not c.open and c.a == 0.0 and c.q == 0.0, "тревога скрывает и карточку, и «?»")
	_run(c, "scanner")
	ok(not c.open and c.ask_shown(), "после тревоги — только «?»")


func test_foreign_role_three_seconds() -> void:
	var c := RoleCard.new()
	_run(c, "energy", false)
	eq(c.foreign, "energy", "чужой пост — плашка")
	ok(not c.open, "карточки нет")
	_run(c, "energy", false, false, false, 60)
	eq(c.foreign, "", "через 3 с убрана")
	_run(c, "")
	_run(c, "energy", false)
	eq(c.foreign, "", "второй раз за забег не говорим")
	c.reset_run()
	_run(c, "energy", false)
	eq(c.foreign, "energy", "новый забег — снова")


func test_place() -> void:
	var l := RoleCard.card_rect("sonar", SIZE)
	eq(l, Rect2(70, 180, 620, 370), "слева по макету")
	var rr := RoleCard.card_rect("energy", SIZE)
	eq(rr.position, Vector2(1040, 180), "у энергии — справа (x W − 1360)")
	eq(RoleCard.card_rect("energy", SIZE, [Rect2(1000, 100, 900, 600)]).position.x, 70.0, "справа занято — слева")
	eq(RoleCard.card_rect("energy", SIZE, [Rect2(0, 0, 2400, 600)]), Rect2(), "обе заняты — места нет")
	eq(RoleCard.card_rect("sonar", SIZE, [], Rect2(0, 0, 2400, 200)).position.y, 212.0, "под строкой приборов")
	var s := RoleCard.card_rect("sonar", Vector2(1920, 1080))
	ok(s.end.x < 1920.0 * 0.5, "16:9 — карточка в левой половине")


func test_router_blocks_look() -> void:
	var r := Touch.Router.new()
	r.layout.compute(Rect2(Vector2.ZERO, SIZE))
	r.blocks = [Rect2(70, 180, 620, 370)]
	r.begin(0, Vector2(300, 400))
	r.moved(0, Vector2(500, 400))
	eq(r.look, Vector2.ZERO, "палец на карточке не крутит взгляд")
	eq(r.taps.size(), 1, "но касание есть")
	r.end(0)
	r.end_frame()
	r.begin(1, Vector2(1200, 300))
	r.moved(1, Vector2(1300, 300))
	ok(r.look.x > 0.0, "мимо карточки — взгляд")


func test_settings_remember() -> void:
	var path := "user://test_kartochki.cfg"
	var s := Settings.new()
	s.path = path
	var c := RoleCard.new()
	c.read = {"valve": true, "helm": true}
	s.cards = c.read_list()
	ok(s.write(), "записано")
	var u := Settings.new()
	u.path = path
	ok(u.read(), "прочитано")
	var d := RoleCard.new()
	d.set_read(u.cards)
	eq(d.read_list(), ["helm", "valve"], "прочитанные карточки помнятся")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _tick(n: int = 1) -> void:
	for i in n:
		main.step(1.0 / 30.0)


func test_scene_card_at_sonar() -> void:
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.tutorial.on = false
	ok(main.role_card.on, "карточки включены")
	main.walker.x = 0.0
	main.walker.z = -2.4
	_tick(10)
	eq(main.role_card.post, "sonar", "у голостола")
	ok(main.role_card_panel.visible, "карточка на экране")
	var size := main.get_viewport().get_visible_rect().size
	var rect := main.role_card_panel.rect
	ok(rect.has_area(), "место есть")
	eq(main.overlay.router.blocks, [rect] as Array[Rect2], "касания карточки не идут во взгляд")
	main.overlay.router.taps.append(RoleCard.button_rect(rect, size).get_center())
	_tick()
	ok(not main.role_card.open, "«Понятно» свернуло")
	eq(main.settings.cards, ["sonar"], "прочитанное — в настройках")
	_tick(10)
	ok(main.role_card.ask_shown(), "«?»")
	main.open_breach(0)
	_tick(5)
	ok(main.role_card.q == 0.0, "пробоина — «?» скрыт")


func test_scene_off_in_tests() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(not main.role_card.on, "тесты и снимки — без карточек")
	main.walker.x = 0.0
	main.walker.z = -2.4
	_tick(10)
	ok(not main.role_card_panel.visible, "не на экране")
	eq(main.overlay.router.blocks.size(), 0, "касания не перехвачены")


func test_ask_below_status() -> void:
	var c := RoleCard.new()
	c.read = {"helm": true}
	c.status = Rect2(0, 0, 1200, 300)
	_run(c, "helm")
	var r := RoleCard.ask_rect(SIZE, c.status)
	ok(r.position.y >= 300.0, "«?» под строкой приборов")
	eq(c.blocks(SIZE, Rect2()), [r] as Array[Rect2], "касания «?» — там же")
	eq(c.tap(r.get_center(), SIZE, Rect2()), "ask", "и нажимается там же")
