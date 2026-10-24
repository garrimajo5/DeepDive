extends TestCase
## Указатель на пост подсказки первого забега ART-038 (`HintPointer`, `HintPointerView`): ячейки атласа, размер
## 96…160 px, покачивание, стрелка у края экрана для поста вне кадра, цель по шагу, указатель в сцене.

var main: Main


func after() -> void:
	Main.hints = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_cells_and_atlas() -> void:
	eq(HintPointer.cell(false), Rect2(0, 0, 256, 256), "пост виден — кольцо с шевроном")
	eq(HintPointer.cell(true), Rect2(0, 256, 256, 256), "рядом — кольцо с точкой")
	var img := (load(HintPointer.PATH) as Texture2D).get_image()
	eq(img.get_size(), Vector2i(512, 512), "атлас 512²")
	ok(img.get_pixel(128, 101).a < 0.1 and img.get_pixel(128, 55).a > 0.5, "кольцо в ячейке (0,0)")
	ok(img.get_pixel(384, 384).a < 0.05, "ячейка (256,256) пуста")


func test_size_on_screen() -> void:
	eq(HintPointer.px(1.0), HintPointer.PX_MAX, "вблизи не больше 160 px")
	eq(HintPointer.px(8.0), HintPointer.PX_MIN, "вдали не меньше 96 px")
	ok(HintPointer.px(2.0) < 160.0 and HintPointer.px(2.0) > 96.0, "между — по расстоянию")
	# высота символа на экране 1080 px при fov 70°: обратно из мировой высоты ячейки
	for d: float in [1.0, 2.0, 5.0]:
		var h := HintPointer.cell_height(d, d, 70.0)
		var px := h * HintPointer.SYMBOL_H / (2.0 * d * tan(deg_to_rad(35.0))) * 1080.0
		near(px, HintPointer.px(d), 1e-3, "символ %.0f м — %.0f px" % [d, px])
		ok(px >= 96.0 - 1e-3, "не меньше 96 px (ART-038)")
	near(HintPointer.bob(0.5), HintPointer.BOB, 1e-4, "покачивание ±4 px")
	near(HintPointer.bob(2.0), 0.0, 1e-4, "период 2 с")


func test_edge_arrow() -> void:
	var size := Vector2(2400, 1080)
	var left: Array = HintPointer.edge(Vector3(-3.0, 0.0, 1.0), Vector2.ZERO, size)   # слева за спиной
	ok(not left[1], "слева — без зеркала")
	var r: Rect2 = left[0]
	var sym_left := r.position.x + HintPointer.ARROW_X * r.size.x - HintPointer.ARROW_W * r.size.x * 0.5
	near(sym_left, HintPointer.EDGE, 1e-3, "символ в 60 px от края")
	near(r.size.y * HintPointer.ARROW_H, HintPointer.ARROW, 1e-3, "символ стрелки 128 px")
	near(r.get_center().y, 410.0, 1e-3, "за спиной — середина 260…560")
	var right: Array = HintPointer.edge(Vector3(2.0, 0.0, -5.0), Vector2(2600, 1000), size)
	ok(right[1], "справа — зеркально")
	var rr: Rect2 = right[0]
	var sym_right := rr.position.x + (1.0 - HintPointer.ARROW_X) * rr.size.x + HintPointer.ARROW_W * rr.size.x * 0.5
	near(sym_right, size.x - HintPointer.EDGE, 1e-3, "символ в 60 px от правого края")
	near(rr.get_center().y, 560.0, 1e-3, "в нижний угол не заходит")
	var hi: Array = HintPointer.edge(Vector3(-2.0, 0.0, -5.0), Vector2(-100, 20), size)
	near((hi[0] as Rect2).get_center().y, 260.0, 1e-3, "и в верхний (строка приборов) тоже")
	# половина экрана: масштаб H/1080
	var half: Array = HintPointer.edge(Vector3(-3.0, 0.0, 1.0), Vector2.ZERO, size * 0.5)
	near((half[0] as Rect2).size.y, r.size.y * 0.5, 1e-3, "масштаб по высоте экрана")


func test_mode() -> void:
	var size := Vector2(2400, 1080)
	eq(HintPointer.mode(Vector3(0, 0, -3), Vector2(1200, 540), size), "world", "в кадре — над постом")
	eq(HintPointer.mode(Vector3(0, 0, 3), Vector2(1200, 540), size), "edge", "за спиной — стрелка")
	eq(HintPointer.mode(Vector3(5, 0, -3), Vector2(2500, 540), size), "edge", "сбоку за кадром — стрелка")
	eq(HintPointer.mode(Vector3(0, 0, -3), Vector2(1200, 30), size), "edge", "символ не влез бы сверху — стрелка")
	eq(HintPointer.mode(Vector3(0, 0, -0.1), Vector2(1200, 540), size), "", "вплотную — ничего")


func test_target_by_step() -> void:
	var t := Tutorial.new()
	eq(t.pointer_target(false), "helm", "шаг 1 — штурвал")
	eq(t.pointer_target(true), "", "сидит за штурвалом — над своим креслом не показываем")
	t.note(Tutorial.Ev.SAT)
	eq(t.pointer_target(false), "", "в «Выполнено» — нет")
	t.update(Tutorial.DONE_TIME + 0.01, false)
	eq(t.pointer_target(false), "helm", "шаг хода не сидя — к штурвалу")
	t.step = 3
	eq(t.pointer_target(true), "energy", "шаг энергии из кресла — на пульт")
	t.step = 4
	eq(t.pointer_target(false), "sonar", "сонар")
	t.step = 5
	eq(t.pointer_target(false), "route", "маршрут")
	t.on = false
	eq(t.pointer_target(false), "", "выключено — нет")
	for id: String in ["helm", "energy", "sonar", "route"]:
		ok(HintPointer.ANCHORS.has(id), "место указателя для %s" % id)


func _tick(n: int = 1) -> void:
	for i in n:
		main.step(1.0 / 30.0)


func test_scene_world_and_edge() -> void:
	Main.hints = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var spr := main.hint_pointer.sprite
	main.walker.x = 0.0
	main.walker.z = 1.0
	main.walker.yaw = 0.0
	main.walker.pitch = 0.0
	_tick(10)
	ok(spr.visible, "штурвал впереди — указатель над креслом")
	eq(spr.region_rect, HintPointer.SEEN, "кольцо с шевроном")
	eq(main.tutorial_panel.arrow, [], "стрелки нет")
	var p := main.camera.unproject_position(spr.global_position)
	var vp := main.get_viewport().get_visible_rect().size
	ok(Rect2(Vector2.ZERO, vp).has_point(p), "указатель в кадре")
	var tip := main.ship.to_global(HintPointer.ANCHORS["helm"])
	ok(spr.global_position.y > tip.y, "символ над остриём")
	main.walker.yaw = PI   # спиной к носу: штурвал за спиной
	_tick(2)
	ok(not spr.visible, "пост за спиной — мировой скрыт")
	eq(main.tutorial_panel.arrow.size(), 2, "стрелка у края")
	# шаг энергии: стоим справа на палубе, пульт у левой стены
	main.tutorial.step = 3
	main.walker.x = 2.0
	main.walker.z = -2.0
	main.walker.yaw = 0.0
	_tick(2)
	eq(main.tutorial_panel.arrow.size(), 2, "пульт сбоку — стрелка")
	ok(not main.tutorial_panel.arrow[1], "пульт слева — стрелка у левого края")
	main.walker.yaw = PI
	_tick(2)
	ok(main.tutorial_panel.arrow[1], "развернулись — пульт справа")
	main.walker.yaw = PI * 0.5   # лицом к левому борту
	_tick(2)
	ok(spr.visible, "пульт перед глазами — указатель над ним")
	main.walker.x = -3.9
	main.walker.yaw = PI * 0.5
	main.walker.pitch = 0.3
	_tick(2)
	ok(spr.visible, "у пульта, взгляд вверх — указатель виден")
	eq(spr.region_rect, HintPointer.NEAR, "в радиусе пульта — кольцо с точкой")
	main.open_breach(0)
	_tick(10)
	ok(not main.tutorial_panel.visible, "тревога — плашка и стрелка скрыты")
	ok(not spr.visible, "мировой скрыт под тревогой")
