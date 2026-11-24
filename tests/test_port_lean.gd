extends TestCase
## Режим «у порта» (#2095, спецификация UX из #2067): дожим за упором взгляда сдвигает глаз пилота на 0,5 м к окну.

var main: Main


func before() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)


## Свайп обзора на points «точек» экрана: down — палец вниз (взгляд вниз). Кусок за шаг игры — 20 px.
func _look_swipe(points: float, down: bool) -> void:
	var r := main.overlay.router
	var k: float = maxf(main.overlay.points_per_px * main.overlay.swipe, 0.01)
	var left_px := points / k
	var p := Vector2(800, 300)
	r.begin(7, p)
	while left_px > 0.0:
		var d: float = minf(left_px, 20.0)
		p += Vector2(0.0, d if down else -d)
		r.moved(7, p)
		main.step(0.05)
		left_px -= d
	r.end(7)
	main.step(0.05)


## Точек взгляда от посадки (SEAT_PITCH) до нижнего упора (Walker.MAX_PITCH).
func _to_clamp() -> float:
	return (Deck.Walker.MAX_PITCH - absf(Deck.SEAT_PITCH)) / Deck.Walker.LOOK_SENS


## Войти в режим «у порта» со штурвала: свайп вниз до упора и дожим (запас 100 точек против квантования кусков).
func _enter_port() -> void:
	_look_swipe(_to_clamp() + 100.0, true)


func test_entry_only_with_push() -> void:
	main.sit_at_helm()
	main.step(0.05)
	_look_swipe(_to_clamp() + 5.0, true)   # до упора и чуть дальше — без полного дожима режима нет
	near(main.walker.pitch, -Deck.Walker.MAX_PITCH, 1e-3, "взгляд на нижнем упоре")
	ok(not main.pilot.port_on, "без дожима — обычный осмотр")
	_look_swipe(80.0, true)   # дожим в ту же сторону за упором
	ok(main.pilot.port_on, "дожим включил режим")
	eq(main.message.text, Main.PORT_MSG, "сообщение при входе")
	var z0: float = main.pilot.eye(main.walker).z
	ok(z0 < Deck.SEAT_Z and z0 > Deck.SEAT_PORT_Z, "глаз в переходе: %0.3f" % z0)
	for i in 10:   # 0,5 с — переход доиграл до конца (Deck.SEAT_PORT_T)
		main.step(0.05)
	near(main.pilot.port, 1.0, 1e-6, "переход дошёл")
	near(main.pilot.eye(main.walker).z, Deck.SEAT_PORT_Z, 1e-6, "глаз у порта")


func test_smooth_exit_by_push_up() -> void:
	main.sit_at_helm()
	main.step(0.05)
	_enter_port()
	for i in 12:
		main.step(0.05)
	near(main.pilot.port, 1.0, 1e-6, "режим доиграл")
	var up_to_stop := (Deck.Walker.MAX_PITCH - absf(Deck.SEAT_PORT_PITCH_UP)) / Deck.Walker.LOOK_SENS
	_look_swipe(up_to_stop + 100.0, false)   # вверх до упора зоны (−35°) и дожим
	ok(not main.pilot.port_on, "режим снят дожимом вверх")
	var p0 := main.pilot.port
	ok(p0 > 0.0 and p0 < 1.0, "выход плавный: глаз ещё в переходе (%0.2f)" % p0)
	for i in 12:
		main.step(0.05)
	near(main.pilot.port, 0.0, 1e-6, "глаз вернулся штатно")
	near(main.pilot.eye(main.walker).z, Deck.SEAT_Z, 1e-6, "глаз над креслом")


func test_cross_exits_with_command_same_frame() -> void:
	main.sit_at_helm()
	main.step(0.05)
	_enter_port()
	main.step(0.2)
	ok(main.pilot.port > 0.0, "глаз уже поехал к окну")
	var r := main.overlay.router
	r.begin(1, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.7))   # крестовина вперёд
	main.step(0.05)
	ok(not main.pilot.port_on, "режим снят крестовиной")
	eq(main.pilot.port, 0.0, "глаз штатный сразу")
	near(main.pilot.eye(main.walker).z, Deck.SEAT_Z, 1e-6, "глаз над креслом")
	eq(main.helm.in_thrust, 1.0, "та же тяга — ход в том же кадре")
	r.end(1)


func test_back_exits_without_pause() -> void:
	main.sit_at_helm()
	main.step(0.05)
	_enter_port()
	main.back_pressed()
	ok(not main.pilot.port_on, "«Назад» сняла режим")
	eq(main.pilot.port, 0.0, "мгновенно")
	ok(not main.pause.open, "пауза не открылась")
	main.back_pressed()
	ok(main.pause.open, "повторная «Назад» — пауза")
	main.back_pressed()
	ok(not main.pause.open, "и закрылась обратно")


func test_status_row_marks_port() -> void:
	main.sit_at_helm()
	main.step(0.05)
	eq(str(main.status_rows()[0][0]), "За штурвалом", "штатный ряд 1")
	_enter_port()
	main.step(0.05)
	eq(str(main.status_rows()[0][0]), "У порта", "ряд 1 в режиме")
	main.port_lean_off(true)
	main.step(0.05)
	eq(str(main.status_rows()[0][0]), "За штурвалом", "после выхода — как было")


func test_stand_and_sit_reset_mode() -> void:
	main.sit_at_helm()
	main.step(0.05)
	_enter_port()
	var r := main.overlay.router
	r.begin(2, r.layout.action.c)   # «Встать»
	r.end(2)
	main.step(0.05)
	ok(not main.pilot.seated, "встали")
	ok(not main.pilot.port_on and main.pilot.port == 0.0, "режим сброшен вставанием")
	main.walker.x = 0.0
	main.walker.z = Deck.STAND_Z
	r.begin(2, r.layout.action.c)   # снова «Сесть за штурвал»
	r.end(2)
	main.step(0.05)
	ok(main.pilot.seated, "сели")
	ok(not main.pilot.port_on and main.pilot.port == 0.0, "посадка без режима")
	near(main.walker.pitch, Deck.SEAT_PITCH, 1e-6, "взгляд посадки")
