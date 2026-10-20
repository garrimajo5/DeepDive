extends TestCase
## Тестовый режим noclip: игрок летит сквозь корпус смотреть живой мир (кнопка noclip в правом верхнем углу).
## Крестовина ведёт по взгляду (вперёд с наклоном — вверх/вниз), стены не держат; выход возвращает на пол.


func test_fly_ignores_walls_and_flies_3d() -> void:
	var w := Deck.Walker.new()
	w.stand = func(_x: float, _z: float, _r: float = 0.0) -> bool: return false   # стоять нельзя нигде
	w.x = 0.0
	w.z = 0.0
	# без noclip стена держит — шага нет
	w.walk(Vector2(0, 1), 1.0)
	near(w.z, 0.0, 1e-6, "без noclip сквозь стену не идём")

	w.noclip = true
	w.yaw = 0.0   # лицом к носу (−Z)
	w.pitch = 0.0
	w.walk(Vector2(0, 1), 1.0)
	near(w.z, -Deck.Walker.FLY_SPEED, 1e-5, "вперёд — по −Z на FLY_SPEED, сквозь стену")
	near(w.x, 0.0, 1e-5, "вбок не снесло")
	near(w.y, Deck.Walker.EYE, 1e-5, "без наклона высота не меняется")

	# взгляд вверх + вперёд — набор высоты
	w.pitch = PI / 2.0
	w.walk(Vector2(0, 1), 1.0)
	near(w.y, Deck.Walker.EYE + Deck.Walker.FLY_SPEED, 1e-4, "взгляд вверх — летим вверх")

	# строго вбок (m.x) — по горизонтали, без набора высоты даже при наклоне
	var y0 := w.y
	w.walk(Vector2(1, 0), 1.0)
	near(w.y, y0, 1e-5, "вбок высоту не меняет")
	near(w.x, Deck.Walker.FLY_SPEED, 1e-5, "вбок — на правый борт (+X) при yaw 0")


func test_forward3_unit() -> void:
	var w := Deck.Walker.new()
	for p in [-1.0, -0.3, 0.0, 0.8, 1.4]:
		w.yaw = 0.7
		w.pitch = p
		near(w.forward3().length(), 1.0, 1e-6, "взгляд — единичный вектор")


func test_eye_follows_noclip() -> void:
	var p := Deck.Pilot.new()
	var w := Deck.Walker.new()
	w.x = 3.0
	w.z = -20.0
	eq(p.eye(w), Vector3(w.x, Deck.Walker.EYE, w.z), "на ногах — глаз на EYE")
	w.noclip = true
	w.y = 9.0
	eq(p.eye(w), Vector3(3.0, 9.0, -20.0), "в noclip — глаз в (x, y, z)")


func test_scene_noclip_button() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var r := main.overlay.router

	# нажать кнопку noclip
	r.begin(1, r.layout.noclip.c)
	r.end(1)
	main.step(0.1)
	ok(main.walker.noclip, "кнопка включила noclip")
	ok(main.overlay.noclip_on, "кнопка подсвечена")

	# лететь вперёд с наклоном вниз — выйти за пределы мостика сквозь стену и уйти ниже пола
	main.walker.yaw = 0.0
	main.walker.pitch = -0.5
	r.move = Vector2i(0, 1)
	for i in 40:
		main.step(0.1)
	ok(main.walker.z < Deck.BRIDGE_MIN.y - 5.0, "улетели за носовую стену: z=%.1f" % main.walker.z)
	ok(not Deck.can_stand(main.walker.x, main.walker.z), "там стоять нельзя — прошли сквозь корпус")
	ok(main.walker.y < Deck.Walker.EYE, "наклон вниз — опустились ниже глаз на полу")

	# выключить noclip — вернуться на пол, где включали
	r.move = Vector2i.ZERO
	r.begin(2, r.layout.noclip.c)
	r.end(2)
	main.step(0.1)
	ok(not main.walker.noclip, "кнопка выключила noclip")
	ok(Deck.can_stand(main.walker.x, main.walker.z), "вернулись туда, где можно стоять")
	near(main.walker.y, Deck.Walker.EYE, 1e-6, "высота глаза вернулась на EYE")

	main.queue_free()
