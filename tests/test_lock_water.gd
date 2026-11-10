extends TestCase
## Вода в шахте нижнего шлюза по ART-073 (LockWater): видимость по крышке, сила ряби, события троса по пересечению
## глади, удар, «Экономно»; в игре — одна плоскость под открытым шлюзом, трос лебёдки даёт кольца и всплеск.


func test_shown_by_cover() -> void:
	eq(LockWater.shown(0.0), 0.0, "закрыто — воды нет")
	eq(LockWater.shown(0.02), 0.0, "щель 2 % — ещё нет")
	near(LockWater.shown(0.11), 0.5, 1e-6, "середина открытия S(0,02; 0,20)")
	eq(LockWater.shown(1.0), 1.0, "открыто — целиком")
	near(LockWater.Y, -1.12, 1e-6, "гладь на Airlock.Y + 0,03")
	near(LockWater.CENTER.z, Airlock.Z, 1e-6, "под проёмом")


func test_amplitude() -> void:
	var w := LockWater.new()
	near(w.amplitude(0.0, 100.0), 1.2, 1e-6, "покой — 1,20")
	near(w.amplitude(-5.0, 100.0), 2.0, 1e-6, "полный ход назад тоже +0,80")
	near(w.amplitude(10.0, 0.0), 2.3, 1e-6, "ход ограничен 5 м/с, корпус 0 — +0,30")
	w.on_hit()
	near(w.amplitude(0.0, 100.0), 2.3, 1e-6, "удар +1,10")
	w.update(0.65, 1.0, Samples.REST, false)
	near(w.amplitude(0.0, 100.0), 1.2 + 1.1 * exp(-1.0), 1e-5, "удар гаснет exp(−t/0,65)")
	w.update(10.0, 1.0, Samples.REST, false)
	near(w.amplitude(0.0, 100.0), 1.2, 1e-6, "через несколько секунд — снова покой")
	w.lite = true
	near(w.amplitude(0.0, 100.0), 1.2 * 0.625, 1e-6, "«Экономно» × 0,625")


func test_rope_events() -> void:
	var w := LockWater.new()
	var above := Vector3(0.1, LockWater.Y + 0.5, Airlock.Z - 0.2)
	var below := Vector3(0.1, LockWater.Y - 0.5, Airlock.Z - 0.2)
	w.update(0.1, 1.0, above, false)
	w.update(0.1, 1.0, above, false)
	eq(w.events, 0, "неподвижный трос событий не даёт")
	w.update(0.1, 1.0, below, false)
	eq(w.events, 1, "пересёк гладь вниз — одно событие")
	eq(w.event_kind, LockWater.Kind.ENTER, "вниз — кольца")
	near(w.event_uv().x, 0.5 + 0.1 / 2.2, 1e-5, "кольца там, где трос: U по X")
	near(w.event_uv().y, 0.5 - 0.2 / 2.2, 1e-5, "V по Z")
	w.update(0.1, 1.0, below + Vector3.DOWN, false)
	eq(w.events, 1, "дальше вниз — без новых колец")
	w.update(0.1, 1.0, above, false)
	eq(w.events, 2, "обратно вверх — событие")
	eq(w.event_kind, LockWater.Kind.EXIT, "вверх — всплеск")
	near(w.event_k, LockWater.WEAK_EXIT, 1e-6, "без образца всплеск слабее")
	w.update(0.1, 1.0, below, false)
	w.update(0.1, 1.0, above, true)
	near(w.event_k, 1.0, 1e-6, "с образцом — полный")
	w.update(LockWater.END_S + 0.1, 1.0, above, true)
	ok(w.event_age < 0.0, "через 1,4 с событие кончилось")


func test_closed_lock_no_events() -> void:
	var w := LockWater.new()
	w.update(0.1, 0.0, Vector3(0.0, 0.0, Airlock.Z), false)
	w.update(0.1, 0.0, Vector3(0.0, -3.0, Airlock.Z), false)
	eq(w.events, 0, "шлюз закрыт — воды нет, событий нет")
	w.update(0.1, 1.0, Vector3(3.0, 0.0, Airlock.Z), false)
	w.update(0.1, 1.0, Vector3(3.0, -3.0, Airlock.Z), false)
	eq(w.events, 0, "мимо проёма — не по воде")
	w.reset()
	eq(w.event_age, -1.0, "новый забег — тихо")


func test_lamp_and_color() -> void:
	var l: Array = LockWater.lamp()
	near((l[0] as Vector3).y, 2.98, 1e-6, "полоса плафона на потолке трюма")
	near((l[0] as Vector3).z, 21.75, 1e-6, "по середине трюма")
	var c := LockWater.color(20.0)
	var f := Seabed.Water.fog_color(20.0)
	near(c.b, f.b * 0.65, 1e-6, "цвет — туман × 0,65")


func test_plane_and_winch_in_game() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var view: LockWaterView = main.rooms.lock_water
	ok(view != null, "вода шлюза в отсеках")
	eq(view.layers, OceanView.LAYER_SHIP, "слой корабля")
	eq(view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без теней")
	main.step(1.0 / 60.0)
	ok(not view.visible, "шлюз закрыт — плоскости нет")
	main.park_over_sample(0)
	main.step(1.0 / 60.0)
	ok(view.visible, "шлюз открыт — вода видна")
	near(view.position.distance_to(LockWater.CENTER), 0.0, 1e-6, "плоскость под проёмом")
	var kinds: Array = []
	var seen := 0
	main.debug_winch = true
	for i in 60 * 12:
		main.step(1.0 / 60.0)
		if main.lock_water.events > seen:
			seen = main.lock_water.events
			kinds.append(main.lock_water.event_kind)
		if main.samples.carrying():
			main.debug_winch = false
		if main.samples.cargo.size() > 0:
			break
	eq(main.samples.cargo.size(), 1, "образец поднят")
	eq(kinds, [LockWater.Kind.ENTER, LockWater.Kind.EXIT], "трос вошёл в воду и вышел с образцом")
	near(main.lock_water.event_k, 1.0, 1e-6, "с образцом — полный всплеск")
	main.vitals.hit(5, "")
	ok(main.lock_water.hit_age == 0.0, "удар по корпусу тревожит воду")
	main.queue_free()
	await frames(1)
