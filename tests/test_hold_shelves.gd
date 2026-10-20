extends TestCase
## Полки трюма на 24 образца (HoldShelves, MOD-017): ячейки по tryum.md, порядок заполнения, препятствия, банки в сцене.


func test_cells_match_tryum_md() -> void:
	var cells := HoldShelves.cells()
	eq(cells.size(), HoldShelves.CAPACITY, "24 ячейки")
	var left := HoldShelves.cell_at(0, 0, 0)
	ok(left.is_equal_approx(Vector3(-2.215, 0.55, 20.6)), "левый борт, нижний ярус, к носу: %s" % left)
	var right := HoldShelves.cell_at(1, 2, 0)
	ok(right.is_equal_approx(Vector3(2.215, 2.05, 23.0)), "правый борт повёрнут: z меняет знак — %s" % right)
	var seen := {}
	for c in cells:
		ok(absf(absf(c.x) - 2.215) < 1e-4, "банка у борта: %s" % c)
		ok(HoldShelves.CELL_Y.any(func(y: float) -> bool: return absf(c.y - y) < 1e-4), "на полке: %s" % c)
		seen[c] = true
	eq(seen.size(), HoldShelves.CAPACITY, "ячейки не повторяются")


func test_fill_nearest_to_winch_first() -> void:
	var cells := HoldShelves.cells()
	for i in cells.size() - 1:
		ok(cells[i].distance_to(HoldShelves.FROM) <= cells[i + 1].distance_to(HoldShelves.FROM) + 1e-4, "ближе к захвату — раньше")
	near(cells[0].y, 1.30, 1e-4, "первая — средний ярус, на уровне груди")
	var k := HoldShelves.contents([[2, 5], [0, -1], [3, 1]])
	eq(k.size(), HoldShelves.CAPACITY, "по виду на ячейку")
	eq([k[0], k[1], k[2], k[3]], [2, 0, 3, -1], "груз по порядку, дальше пусто")
	var many: Array = []
	for i in 30:
		many.append([i % 4, -1])
	eq(HoldShelves.contents(many)[HoldShelves.CAPACITY - 1], 3, "сверх 24 не помещается — последняя ячейка занята")


func test_racks_block_walls_not_aisle() -> void:
	var lay := ShipLayout.new()
	ok(not lay.can_stand(-2.0, 21.8), "у левого стеллажа не встать")
	ok(not lay.can_stand(1.9, 22.5), "у правого — тоже")
	ok(lay.can_stand(-1.35, 22.6), "проход у лебёдки (сценарий тестера) свободен")
	ok(lay.can_stand(1.4, 21.0), "проход справа от шлюза свободен")
	ok(lay.can_stand(1.4, 23.5), "у кормы справа свободно")


func test_jars_in_scene_follow_cargo() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(1.0 / 30.0)
	ok(not main.rooms.shelf_jars.visible, "трюм пуст — банок нет")
	main.samples.cargo.append([2, -1])
	main.samples.cargo.append([0, -1])
	main.step(1.0 / 30.0)
	for mm in [main.rooms.shelf_jars, main.rooms.shelf_glass, main.rooms.shelf_samples]:
		eq(mm.multimesh.visible_instance_count, 2, "%s: две банки" % mm.name)
		eq(mm.layers, OceanView.LAYER_SHIP, "слой корабля")
	eq([main.rooms.shown_shelves()[0], main.rooms.shown_shelves()[1]], [2, 0], "виды в ячейках по грузу")
	main.samples.cargo.clear()
	main.step(1.0 / 30.0)
	ok(not main.rooms.shelf_jars.visible, "груз ушёл — полки пусты")
	main.queue_free()
	await frames(1)
