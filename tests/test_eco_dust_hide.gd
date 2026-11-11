extends TestCase
## Пустой слой мути не рисуется (issue #849): ≈20 слоёв «Муть» у видов живого мира стоят вызова отрисовки и пустыми —
## EcoDustBuffer.upload прячет слой, пока облачков нет, и показывает, как только облачко поднялось.


func test_upload_hides_empty_layer() -> void:
	var mi := GrazerView.build_dust(8)
	var d := EcoGrazerDust.new(8)
	var buf := EcoDustBuffer.new()
	buf.pack(d, 1.0, Vector3.ZERO)
	buf.upload(mi)
	ok(not mi.visible, "мути нет — слой спрятан")
	d.add(Vector3(1, -40, 1), 1.1, 0.5, 3)
	buf.pack(d, 1.3, Vector3.ZERO)
	buf.upload(mi)
	ok(mi.visible, "облачко поднялось — слой виден")
	eq(mi.multimesh.buffer.size(), buf.data.size(), "буфер загружен")
	buf.pack(d, 1.1 + EcoGrazerDust.LIFE + 0.1, Vector3.ZERO)
	buf.upload(mi)
	ok(not mi.visible, "облачко растаяло — слой снова спрятан")
	mi.free()


## Корабль высоко над отмелью — мути нигде нет: общий слой «Муть» живого мира не виден, своих слоёв у видов нет.
func test_world_without_dust_draws_no_layer() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(0, 2000, 0)
	for i in 10:
		view.step(0.1, ship)
	var layers: Array[Node] = view.find_children("Муть", "MultiMeshInstance3D", true, false)
	eq(layers.size(), 1, "один слой мути на весь живой мир (#849)")
	ok(view.dust_layer.parts.size() >= 15, "в нём муть видов (%d)" % view.dust_layer.parts.size())
	ok(not view.dust_layer.is_visible_in_tree(), "пустой слой мути не рисуется")
	view.queue_free()
	await frames(1)
