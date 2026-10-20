extends TestCase
## Табло тревог над носовым окном (ART-025, tablo-trevog.md): пять полей, погашено / горит / мигает.


func test_fields() -> void:
	eq(AlarmBoard.WORDS.size(), 5)
	eq(AlarmBoard.WORDS[0], "ПРОБОИНА")
	eq(AlarmBoard.WORDS[4], "МАЛО ЗАРЯДА")
	var sum := 0.0
	for w in AlarmBoard.WIDTHS:
		sum += w
	near(sum, AlarmBoard.SIZE.x, 1e-5, "поля заполняют табло")
	near(AlarmBoard.field_span(0).x, -3.6, 1e-5, "ПРОБОИНА — у левого борта (−X)")
	near(AlarmBoard.field_span(4).y, 3.6, 1e-5)
	near(AlarmBoard.u_of(-AlarmBoard.face_rect()[1].x * 0.5), 0.0, 1e-5)
	near(AlarmBoard.u_of(AlarmBoard.face_rect()[1].x * 0.5), 1.0, 1e-5)


func test_place() -> void:
	var top := AlarmBoard.CENTER.y + AlarmBoard.SIZE.y * 0.5
	var bottom := AlarmBoard.CENTER.y - AlarmBoard.SIZE.y * 0.5
	var win := BridgePlan.WINDOW_TOP - BridgePlan.WINDOW_BOTTOM
	ok((BridgePlan.WINDOW_TOP - bottom) / win <= 0.10, "окно закрыто не больше 10 %% высоты: %.3f" % [
		(BridgePlan.WINDOW_TOP - bottom) / win])
	# скос потолка над окном: от WINDOW_TOP у носа до CEILING за SLOPE_DEPTH
	var back_z := AlarmBoard.CENTER.z - AlarmBoard.SIZE.z * 0.5
	var roof := BridgePlan.WINDOW_TOP + (BridgePlan.CEILING - BridgePlan.WINDOW_TOP) * (back_z - BridgePlan.NOSE_INNER) \
		/ BridgePlan.SLOPE_DEPTH
	ok(top < roof, "верх табло под скосом потолка: %.3f < %.3f" % [top, roof])
	ok(absf(AlarmBoard.CENTER.x) < 0.01 and AlarmBoard.SIZE.x * 0.5 < BridgePlan.WINDOW_HALF, "по ширине — над окном")
	var tris := 0
	for p in AlarmBoard.boxes():
		tris += 12
		ok(p.center.z - p.size.z * 0.5 > BridgePlan.NOSE_INNER - 0.2, "%s не уходит за носовую стену" % p.name)
	ok(tris + 2 <= 300, "≤ 300 треугольников: %d" % (tris + 2))


func test_levels() -> void:
	var none := AlarmBoard.levels([false, false, false, false, false], 0.2)
	for v in none:
		eq(v, Vector2.ZERO, "погашено")
	var on := AlarmBoard.active("", "СТЕКЛОУСТ", "ПЕРЕГРЕВ 90°", "", true)
	eq(on, [false, true, true, false, true])
	eq(AlarmBoard.main_field(on), AlarmBoard.Field.DRAIN, "главная — первая по порядку Status.alarm")
	var a := AlarmBoard.levels(on, 0.2)
	var b := AlarmBoard.levels(on, 0.7)
	eq(a[1], Vector2(1, 1), "главная: углы горят в первой половине секунды")
	eq(b[1], Vector2(1, 0), "…и гаснут во второй, буквы горят")
	eq(a[2], Vector2(1, 1), "остальные активные горят ровно")
	eq(b[2], Vector2(1, 1))
	eq(b[4], Vector2(1, 1))
	eq(a[0], Vector2.ZERO)
	eq(AlarmBoard.main_field([false, false, false, false, false]), -1)


func test_scene_board() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.step(0.1)
	ok(main.alarm_board != null and main.alarm_board.is_inside_tree(), "табло на мостике")
	eq(main.alarm_board.frame.layers, OceanView.LAYER_SHIP, "слой корабля")
	for v in main.alarm_board.levels:
		eq(v.x, 0.0, "тревог нет — поля погашены")
	main.open_breach(0)
	main.vitals.energy = 5.0
	main.step(0.1)
	var lv := main.alarm_board.levels
	eq(lv[AlarmBoard.Field.BREACH].x, 1.0, "пробоина горит")
	eq(lv[AlarmBoard.Field.CHARGE], Vector2(1, 1), "мало заряда горит ровно — главная пробоина")
	eq(lv[AlarmBoard.Field.HEAT].x, 0.0)
	main.queue_free()
	await frames(1)


func test_board_below_status_at_start() -> void:   # issue #218: верх табло на старте под плашкой приборов
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.step(0.1)
	await frames(1)
	var cam := main.get_viewport().get_camera_3d()
	var top := cam.global_transform.affine_inverse() * main.ship.to_global(AlarmBoard.CENTER + Vector3(0.0, AlarmBoard.SIZE.y * 0.5, 0.0))
	var h := 720.0   # экран телефона в альбомной: высота вьюпорта 720 (project.godot), fov камеры — по высоте
	var y := h * 0.5 - h * 0.5 * (top.y / -top.z) / tan(deg_to_rad(cam.fov) * 0.5)
	var plate := main.hint.position.y + main.hint.get_line_height() * 4 + Main.HINT_PAD   # четыре строки: сообщение и приборы
	ok(y > plate, "верх табло (%.0f) ниже плашки приборов в четыре строки (%.0f)" % [y, plate])
	main.queue_free()
	await frames(1)


func test_hint_targets() -> void:
	eq(AlarmBoard.hint(-1, null), null, "тревог нет — рамки нет")
	var z := AlarmBoard.hint(AlarmBoard.Field.DRAIN, null)
	near(z.center.z, Zap.PANEL_POS.z, 1e-6, "стеклоуст — щиток разряда")
	ok(z.center.x > Zap.PANEL_POS.x and z.normal == Vector3.RIGHT, "перед щитком, лицом в мостик")
	ok(z.size.x > 0.45 and z.size.y > 0.6, "рамка шире щитка")
	var e := AlarmBoard.hint(AlarmBoard.Field.CHARGE, null)
	near(e.center.z, BridgeProps.ENERGY_POS.z, 1e-6, "мало заряда — пульт энергии")
	var h := AlarmBoard.hint(AlarmBoard.Field.HEAT, null)
	ok(h.normal == Vector3.FORWARD and h.center.z < BridgeProps.HATCH_POS.z, "перегрев — кормовой люк мостика")
	ok(h.center.z > ShipLayout.DOOR_Z[0] - 0.5, "не сквозь борт в машинное")
	var w := AlarmBoard.hint(AlarmBoard.Field.SILT, null)
	near(w.center.z, BridgeProps.WHEEL_Z + 0.2, 1e-6, "ил — штурвал")
	eq(AlarmBoard.hint(AlarmBoard.Field.BREACH, null), null, "вода после заплатки — рамки нет")
	var s: Breach.Spot = Breach.spots()[2]
	var b := AlarmBoard.hint(AlarmBoard.Field.BREACH, s)
	ok(b.center.distance_to(s.p) < 0.05 and b.normal == s.n, "пробоина — место сварки")


func test_hint_glow_and_bars() -> void:
	var none: Array[bool] = [false, false, false, false, false]
	eq(AlarmBoard.hint_glow(none, 0.2), 0.0)
	var on: Array[bool] = [false, true, false, false, true]
	eq(AlarmBoard.hint_glow(on, 0.2), 1.0, "углы главной горят — рамка ярко")
	eq(AlarmBoard.hint_glow(on, 0.7), AlarmBoard.HINT_DIM, "углы погашены — рамка тускло, но видна")
	var bars := AlarmBoard.hint_bars(Vector2(1.0, 2.0))
	eq(bars.size(), 4)
	near(bars[0][0].y + bars[0][1].y * 0.5, 1.0, 1e-6, "внешняя кромка — по размеру")
	near(bars[3][0].x + bars[3][1].x * 0.5, 0.5, 1e-6)


func test_scene_hint() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.step(0.1)
	var hint := main.alarm_board.hint
	ok(not hint.visible, "тревог нет — рамки нет")
	eq(hint.layers, OceanView.LAYER_SHIP, "слой корабля")
	main.open_breach(1)
	main.vitals.energy = 5.0
	main.step(0.1)
	ok(hint.visible, "рамка у пробоины")
	ok(hint.global_position.distance_to(main.ship.to_global(main.breach.active.p)) < 0.1, "у места сварки в коридоре")
	main.breach.active = null
	main.breach.water = 0.0
	main.step(0.1)
	ok(hint.global_position.distance_to(main.ship.to_global(AlarmBoard.hint(AlarmBoard.Field.CHARGE, null).center)) < 0.01,
		"заплата — рамка переходит к пульту энергии")
	ok(hint.global_transform.basis.z.dot(main.ship.global_transform.basis.x) > 0.99, "лицом в мостик")
	main.queue_free()
	await frames(1)
