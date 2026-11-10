extends TestCase
## Экипаж на постах (#757): товарищи, их кнопка действия, удержания и руки — `CrewFlow` (`main.crew_flow`),
## у `Main` — только пересылка `add_mate`. Своему игроку и товарищу одна поза рук на посту удержания (`CrewFlow.grip`).

const DT := 1.0 / 30.0

var main: Main


func after() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_grip_same_for_own_and_mate() -> void:
	var m := Crew.Member.new(Crew.Role.ENGINEER)
	m.walker.x = -0.6
	m.walker.z = 22.2
	eq(CrewFlow.grip(m, "valve"), CrewHands.valve(), "вентиль")
	eq(CrewFlow.grip(m, "winch"), CrewHands.winch(-0.6, 22.2), "лебёдка — от места члена экипажа")
	eq(CrewFlow.grip(m, "scanner"), CrewHands.scanner(), "сканер")
	eq(CrewFlow.grip(m, ""), CrewHands.none(), "не держит — руки свободны")
	eq(CrewFlow.grip(m, "breach"), CrewHands.none(), "у пробоины руки — резак (weld), не поза поста")


func test_scene_crew_flow() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(main.crew_flow is CrewFlow and main.crew_flow.main == main, "экипаж на постах — поле main.crew_flow")
	for f in ["_hands", "_mate_posts", "_mate_holds", "_mate_hands", "_drive_mates", "_mark_presses", "mate_action",
			"stand_for"]:
		ok(not main.has_method(f), "%s больше не в Main" % f)
	var mate := main.add_mate(0.0, Deck.SEAT_Z + 0.6, 0.0, Crew.Role.PILOT, 0)
	ok(main.crew.has(mate) and main.crew.size() == 2, "add_mate — пересылка, товарищ на палубе")
	ok(mate.walker.stand.call(mate.walker.x, mate.walker.z), "товарищ стоит на полу и не в другой фигуре")
	mate.pad.action = true
	main.step(DT)
	ok(mate.seated, "кнопка товарища у штурвала — сел (CrewFlow.drive → mate_action)")
	ok(not mate.pad.action, "нажатие съедено")
	mate.pad.move = Vector2(0.0, 1.0)
	main.step(DT)
	eq(main.helm.in_thrust, 1.0, "товарищ за штурвалом даёт ход (CrewFlow.posts)")
	mate.pad.action = true
	main.step(DT)
	ok(not mate.seated, "второе нажатие — встал")
