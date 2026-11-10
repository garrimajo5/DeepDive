extends TestCase
## Фигура отключившегося гостя у хоста (ART-043, MateGhost): полупрозрачная на последнем месте с «Нет связи» 10 с,
## тает за 0,3 с, поста не держит и в экипаже её нет; гость вернулся — прежняя фигура уходит сразу.

const DT := 1.0 / 30.0


func _ghost(name := "Игорь") -> MateGhost:
	var m := Crew.Member.new(Crew.Role.ENGINEER)
	m.name = name
	return MateGhost.new(m)


func test_alpha_holds_then_melts() -> void:
	var g := _ghost()
	ok(g.member.lost, "табличка — «Нет связи»")
	near(g.alpha(), 0.35, 1e-6, "альфа 0,35")
	g.update(9.9)
	near(g.alpha(), 0.35, 1e-6, "стоит 10 с")
	g.update(0.25)
	ok(g.alpha() > 0.0 and g.alpha() < 0.35, "тает: %.3f" % g.alpha())
	ok(not g.done())
	g.update(0.2)
	near(g.alpha(), 0.0, 1e-6)
	ok(g.done(), "растаяла за 0,3 с")


func test_step_and_forget() -> void:
	var list: Array[MateGhost] = [_ghost("Игорь"), _ghost("Ира")]
	list[0].t = 5.0
	ok(not MateGhost.step(list, 1.0), "все стоят — список тот же")
	ok(MateGhost.step(list, 4.4), "Игорь растаял")
	eq(list.size(), 1)
	eq(list[0].member.name, "Ира")
	ok(not MateGhost.forget(list, "Игорь"))
	ok(MateGhost.forget(list, "Ира"), "Ира вернулась — фигура ушла")
	eq(list.size(), 0)


func test_scene_ghost_stays_then_goes() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var m := main.add_mate(-3.5, -2.0, PI / 2.0, Crew.Role.ENGINEER, 0)
	m.name = "Игорь"
	m.pad.action = true
	main.step(DT)
	m.pad.clear()
	ok(m.at_power, "инженер у пульта")
	main.mate_gone(m)
	main.step(DT)
	ok(not main.crew.has(m), "в экипаже его нет")
	ok(Crew.holder(main.crew, main.me, "energy") == null, "пост свободен")
	eq(main.ghosts.size(), 1, "фигура осталась")
	var fig: Node3D = main.ghost_view.figures[0]
	ok(fig.visible, "видна на последнем месте")
	var mi: MeshInstance3D = main.ghost_view.meshes[0]
	var mat: BaseMaterial3D = mi.get_active_material(0)
	near(mat.albedo_color.a, 0.35, 1e-3, "полупрозрачная 0,35")
	eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	ok(main.crew_view.meshes[0].get_active_material(0) != mat, "у своих фигур материал прежний")
	near(main.ghost_view.shown[0]["hip"].x, -3.5, 0.6, "там, где стоял")
	for i in int(9.5 / DT):
		main.step(DT)
	ok(fig.visible, "через 9,5 с ещё стоит")
	for i in int(1.0 / DT):
		main.step(DT)
	eq(main.ghosts.size(), 0, "через 10,3 с растаяла")
	ok(not fig.visible, "фигуры нет")
	main.queue_free()
	await frames(1)
