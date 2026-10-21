extends TestCase
## Новый забег после итога (и после разрушения корпуса) начинается с чистых систем: реактор, доли, шлюз — как на старте (#265).


func _ended_run(main: Main) -> void:
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.use_post("route")
	main.complete_route()
	main.use_post("route")
	main.step(0.3)
	main.decide("up")
	main.flyby.stop()
	main.step(0.3)


func test_new_run_resets_reactor_and_airlock() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var start: Array = main.reactor.share.duplicate()
	main.reactor.hot = true
	main.reactor.heat = 100.0
	main.engine.press(main.reactor)            # щиток «Аварийный сброс»
	main.reactor.share[Reactor.Sys.ENGINES] -= 5
	main.airlock.toggle()
	main.step(0.5)
	ok(main.reactor.scram > 0.0 and main.airlock.open, "до итога: сброс идёт, шлюз открыт")
	_ended_run(main)
	ok(main.run.ended, "забег окончен")
	main.close_vote()                          # «Дальше» — новый забег
	main.step(0.1)
	eq(main.reactor.scram, 0.0, "сброса нет")
	ok(not main.reactor.hot, "реактор не перегрет")
	eq(main.reactor.share, start, "доли — как на старте")
	ok(not main.airlock.open, "шлюз закрыт")
	ok(main.status_parts().all(func(p): return not str(p).contains("СБРОС") and not str(p).contains("шлюз открыт")),
		"в строке приборов нет сброса и шлюза: %s" % [main.status_parts()])
	main.queue_free()
	await frames(1)


func test_destroyed_resets_reactor() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.reactor.hot = true
	main.reactor.heat = 100.0
	main.engine.press(main.reactor)
	main.airlock.toggle()
	main.step(0.5)
	main._on_destroyed()
	main.step(0.1)
	eq(main.reactor.scram, 0.0, "корпус разрушен — подъём с чистым реактором")
	ok(not main.airlock.open, "шлюз закрыт")
	main.queue_free()
	await frames(1)


## #266: на итоге корпус в строке приборов тот же, что «Корпус на финише» на панели — ремонт ждёт нового забега.
func test_summary_hull_matches_status() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.vitals.hull = 74.4
	_ended_run(main)
	for i in 50:
		main.step(0.1)
	var row: Array = main.vote_panel.rows.filter(func(r): return r[0] == "Корпус на финише")[0]
	eq(row[1], "74%", "панель итога")
	ok(main.status_parts().has("корпус 74%"), "строка приборов через 5 с: %s" % [main.status_parts()])
	main.queue_free()
	await frames(1)
