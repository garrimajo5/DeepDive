extends TestCase
## Камера с борта: облёт корабля в начале забега (касание пропускает) и вид при всплытии.

var main: Main


func after() -> void:
	Main.intro = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_start_path_and_end() -> void:
	var f := Flyby.new()
	ok(not f.active(), "сначала облёта нет")
	f.start(Flyby.Kind.START)
	ok(f.active(), "облёт начался")
	var p0 := f.pose()
	ok(p0.origin.is_equal_approx(Flyby.START_PATH[0]), "с первой точки")
	var look := (Flyby.LOOK_AT - p0.origin).normalized()
	near((-p0.basis.z).dot(look), 1.0, 1e-4, "смотрит на корпус")
	var last := -1.0
	for i in 60:
		f.update(Flyby.START_S / 60.0 * 0.999)
		if not f.active():
			break
		var p := f.pose().origin
		ok(not HullPlan.inside(p), "камера снаружи корпуса (%s)" % p)
		ok(p.distance_to(Flyby.LOOK_AT) > 15.0, "весь корпус в кадре — не ближе 15 м")
		ok(f.progress() >= last, "путь только вперёд")
		last = f.progress()
	f.update(0.1)
	ok(not f.active(), "через %.0f с облёт кончился сам" % Flyby.START_S)


func test_surface_holds_then_ends() -> void:
	var f := Flyby.new()
	f.start(Flyby.Kind.SURFACE)
	f.update(Flyby.SURFACE_S + Flyby.SURFACE_HOLD * 0.5)
	ok(f.active(), "вид при всплытии стоит в последней точке")
	ok(f.pose().origin.is_equal_approx(Flyby.SURFACE_PATH[2]), "в последней точке")
	ok(f.pose().origin.y < Flyby.LOOK_AT.y + Flyby.SURFACE_LOOK_UP, "снизу вверх — к свету льда")
	f.update(Flyby.SURFACE_HOLD)
	ok(not f.active(), "вид при всплытии кончился сам (issue #209)")
	ok(Flyby.SURFACE_S + Flyby.SURFACE_HOLD < 9.0, "кончается раньше снимка 22-itog тестера (10 с)")
	f.start(Flyby.Kind.SURFACE)
	f.stop()
	ok(not f.active(), "stop — облёта нет")


func test_scene_intro_skipped_by_touch() -> void:
	Main.intro = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	ok(main.flyby.kind == Flyby.Kind.START, "в начале забега — облёт")
	ok(main.flyby_cam.current, "камера с борта включена")
	eq(main.message.text, Flyby.START_MSG, "подсказка на приборах")
	var start := Vector2(main.walker.x, main.walker.z)
	var r := main.overlay.router
	r.begin(1, r.layout.pad.c + Vector2(0, -r.layout.pad.r * 0.7))   # крестовина вперёд
	main.step(1.0 / 30.0)
	ok(not main.flyby.active(), "касание — облёт пропущен")
	ok(main.camera.current, "глаза на мостике")
	eq(Vector2(main.walker.x, main.walker.z), start, "ввод кадра пропуска не ушёл в ходьбу")
	main.step(1.0 / 30.0)
	ok(Vector2(main.walker.x, main.walker.z) != start, "дальше крестовина ведёт игрока")
	r.end(1)


func test_scene_intro_ends_and_surface_view() -> void:
	Main.intro = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	for i in int(Flyby.START_S * 30.0) + 2:
		main.step(1.0 / 30.0)
	ok(not main.flyby.active() and main.camera.current, "облёт кончился сам — глаза на мостике")
	main.decide("up")
	main.step(1.0 / 30.0)
	ok(main.flyby.kind == Flyby.Kind.SURFACE and main.flyby_cam.current, "наверх — вид с борта при всплытии")
	for i in 30:
		main.step(1.0 / 30.0)
	ok(main.flyby.active(), "сначала — вид с борта")
	for i in int((Flyby.SURFACE_S + Flyby.SURFACE_HOLD) * 30.0):
		main.step(1.0 / 30.0)
	ok(not main.flyby.active() and main.camera.current, "вид с борта кончился сам — глаза на мостике (issue #209)")
	ok(main.run.ended, "забег ещё на итоге")
	main.close_vote()
	main.step(1.0 / 30.0)
	ok(main.flyby.kind == Flyby.Kind.START, "новый забег — снова облёт")


func test_shields_only_start() -> void:
	var f := Flyby.new()
	ok(not f.shields(), "без облёта корпус открыт")
	f.start(Flyby.Kind.START)
	ok(f.shields(), "облёт в начале забега — корпус под защитой")
	f.update(Flyby.START_S + 0.1)
	ok(not f.shields(), "облёт кончился — защиты нет")
	f.start(Flyby.Kind.SURFACE)
	ok(not f.shields(), "вид при всплытии не защищает")


func test_scene_no_breach_during_intro() -> void:   # issue #506
	Main.intro = true
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	ok(main.flyby.kind == Flyby.Kind.START, "в начале забега — облёт")
	var hull := main.vitals.hull
	main.on_eco_event({"type": EcoLink.HIT, "damage": 0.12, "by": "Серпохвост"})
	eq(main.vitals.hull, hull, "удар во время облёта не снял корпус")
	ok(main.breach.active == null, "пробоины нет")
	for i in int(Flyby.START_S * 30.0) + 2:
		main.step(1.0 / 30.0)
	ok(not main.flyby.active(), "облёт кончился")
	main.on_eco_event({"type": EcoLink.HIT, "damage": 0.12, "by": "Серпохвост"})
	ok(main.vitals.hull < hull, "после облёта удар доходит")
	ok(main.breach.active != null, "и пробивает корпус")


func test_scene_surface_skipped_by_action() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.use_post("route")
	main.complete_route()
	main.run.open_vote()   # в слое голосование откроет переход у 10 (#828)
	main.use_post("route")
	main.step(1.0 / 30.0)
	main.decide("up")
	main.step(1.0 / 30.0)
	ok(main.flyby.kind == Flyby.Kind.SURFACE, "наверх — вид с борта")
	var r := main.overlay.router
	r.action_pressed = true
	main.step(1.0 / 30.0)
	ok(not main.flyby.active() and main.camera.current, "кнопка — к итогу на мостике")
	ok(main.run.ended and main.at_vote, "первое нажатие не начинает новый забег")
	main.step(0.3)
	ok(main.sonar_view.vote.board.visible, "итог на голограмме над столом")
