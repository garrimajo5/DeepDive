extends TestCase
## Предложение «Телефон не справляется — включить «Экономно»?» ART-044: замер окнами, когда нельзя, раз за сеанс,
## отказ в настройках, «Да» — уровень «Экономно» в сцене.

var main: Main


func after() -> void:
	Main.offer = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


## Подать секунды кадров с частотой fps.
func _feed(o: LiteOffer, fps: float, secs: float) -> void:
	for i in roundi(fps * secs):
		o.push(1.0 / fps)


func test_low_fps_for_seconds() -> void:
	var o := LiteOffer.new()
	ok(not o.update(Graphics.NORMAL, false, false), "сразу — нет")
	_feed(o, 15.0, 3.0)
	ok(not o.update(Graphics.NORMAL, false, false), "3 с низких — ещё рано")
	_feed(o, 15.0, LiteOffer.HOLD - 3.0 + 0.5)
	ok(o.update(Graphics.NORMAL, false, false), "несколько секунд низких кадр/с — предложить")
	ok(o.open and o.asked, "открыто, предложено в этом сеансе")
	eq(o.press("no"), "no", "«Нет»")
	ok(not o.open, "закрыто")
	_feed(o, 10.0, 20.0)
	ok(not o.update(Graphics.NORMAL, false, false), "раз за сеанс")


func test_fast_frames_and_hitches_do_not_count() -> void:
	var o := LiteOffer.new()
	o.update(Graphics.NORMAL, false, false)
	_feed(o, 58.0, 30.0)
	ok(not o.update(Graphics.NORMAL, false, false), "плавно — молчим")
	for i in 20:   # отдельные рывки 200 мс среди плавных кадров (#519) — не «устойчиво»
		o.push(0.2)
		_feed(o, 58.0, 1.0)
		o.update(Graphics.NORMAL, false, false)
	ok(not o.open, "рывки не предлагают «Экономно»")
	_feed(o, 15.0, 4.0)
	_feed(o, 50.0, 2.0)   # просадка прошла — счёт тает
	_feed(o, 15.0, 2.5)
	ok(not o.update(Graphics.NORMAL, false, false), "просадки с перерывом не складываются целиком")


func test_not_when_blocked() -> void:
	var o := LiteOffer.new()
	o.update(Graphics.ECONOMY, false, false)
	_feed(o, 10.0, 10.0)
	ok(not o.update(Graphics.ECONOMY, false, false), "на «Экономно» не предлагать")
	o.update(Graphics.NORMAL, false, true)
	_feed(o, 10.0, 10.0)
	ok(not o.update(Graphics.NORMAL, false, true), "не во время тревоги, меню, паузы")
	ok(not o.update(Graphics.NORMAL, false, false), "низкие кадры под тревогой не копятся")
	o.update(Graphics.BEAUTY, true, false)
	_feed(o, 10.0, 10.0)
	ok(not o.update(Graphics.BEAUTY, true, false), "отказ запомнен — не предлагать")
	ok(not LiteOffer.allowed(Graphics.NORMAL, false, true, false), "уже предлагали")
	ok(LiteOffer.allowed(Graphics.BEAUTY, false, false, false), "«Красиво» — можно")


func test_layout_and_taps() -> void:
	eq(LiteOffer.screen_rect("box", Vector2(2400, 1080)), Rect2(500, 270, 1400, 540), "диалог 1400×540 по макету")
	eq(LiteOffer.screen_rect("yes", Vector2(2400, 1080)).size, Vector2(520, 112), "кнопки 520×112")
	for size: Vector2 in [Vector2(2400, 1080), Vector2(1600, 720), Vector2(1920, 1080), Vector2(2340, 1080)]:
		var box := LiteOffer.screen_rect("box", size)
		ok(Rect2(Vector2.ZERO, size).encloses(box), "диалог на экране %s" % size)
		var yes := LiteOffer.screen_rect("yes", size)
		var no := LiteOffer.screen_rect("no", size)
		ok(box.encloses(yes) and box.encloses(no) and not yes.intersects(no), "кнопки в окне, не налезают")
	var o := LiteOffer.new()
	var size := Vector2(1600, 720)
	eq(o.hit(LiteOffer.screen_rect("yes", size).get_center(), size), "", "закрыто — касания мимо")
	o.force()
	eq(o.hit(LiteOffer.screen_rect("yes", size).get_center(), size), "yes", "«Да»")
	eq(o.hit(LiteOffer.screen_rect("no", size).get_center(), size), "no", "«Нет»")
	eq(o.hit(LiteOffer.screen_rect("box", size).get_center(), size), "", "середина окна — ничего")
	eq(o.press(""), "", "мимо — окно остаётся")
	ok(o.open, "открыто")
	eq(o.back(), "no", "«Назад» — как «Нет»")


func test_decline_saved() -> void:
	var path := "user://test_ekonomno.cfg"
	var s := Settings.new()
	s.path = path
	s.lite_no = true
	ok(s.write(), "записано")
	var t := Settings.new()
	t.path = path
	ok(t.read(), "прочитано")
	ok(t.lite_no, "отказ запомнен")
	DirAccess.remove_absolute(path)


func test_scene_yes_switches_to_economy() -> void:
	Main.offer = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(1.0 / 30.0)
	_feed(main.lite_offer, 12.0, LiteOffer.HOLD + 1.0)
	main.step(1.0 / 30.0)
	ok(main.lite_offer.open and main.lite_offer_panel.visible, "после низких кадр/с — диалог")
	var x := main.walker.x
	var z := main.walker.z
	var size := main.get_viewport().get_visible_rect().size
	var r := main.overlay.router
	r.begin(1, main.overlay.router.layout.pad.c + Vector2(0, -main.overlay.router.layout.pad.r * 0.7))
	for i in 10:
		main.step(1.0 / 30.0)
	r.end(1)
	ok(is_equal_approx(main.walker.x, x) and is_equal_approx(main.walker.z, z), "под диалогом игрок стоит")
	r.begin(2, LiteOffer.screen_rect("yes", size).get_center())
	main.step(1.0 / 30.0)
	r.end(2)
	main.step(1.0 / 30.0)
	ok(not main.lite_offer.open and not main.lite_offer_panel.visible, "«Да» закрыло диалог")
	eq(main.settings.graphics, Graphics.ECONOMY, "в настройках — «Экономно»")
	eq(main.graphics_level, Graphics.ECONOMY, "и в сцене")


func test_scene_back_declines_and_alarm_blocks() -> void:
	Main.offer = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.vitals.energy = 0.0   # тревога «мало заряда»
	main.step(1.0 / 30.0)
	ok(main.alarms_on().has(true), "тревога")
	_feed(main.lite_offer, 12.0, LiteOffer.HOLD + 1.0)
	main.step(1.0 / 30.0)
	ok(not main.lite_offer.open, "во время тревоги не предлагать")
	main.vitals.energy = Vitals.LOW_ENERGY + 50.0
	main.step(1.0 / 30.0)
	ok(not main.alarms_on().has(true), "тревога снята")
	_feed(main.lite_offer, 12.0, LiteOffer.HOLD + 1.0)
	main.step(1.0 / 30.0)
	ok(main.lite_offer.open, "без тревоги — предложить")
	main.back_pressed()
	ok(not main.lite_offer.open and not main.pause.open, "«Назад» — как «Нет», паузы нет")
	ok(main.settings.lite_no, "отказ запомнен")
	eq(main.graphics_level, Graphics.NORMAL, "уровень прежний")
	Main.offer = false
