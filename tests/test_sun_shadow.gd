extends TestCase
## Тень от света сквозь лёд: отбрасывает только отмель и корпус снаружи (слой 1). Мостик и отсеки изнутри (слой 2)
## тень на дно не кладут — иначе у мелкого дна (площадка 08) под кораблём тёмный прямоугольник оболочки мостика
## (отчёт тестера #945, замечание 2).


func test_sun_skips_ship_inside() -> void:
	var ocean := OceanView.new()
	tree.root.add_child(ocean)
	await frames(1)
	ok(ocean.sun.shadow_enabled, "тени включены")
	eq(ocean.sun.shadow_caster_mask & OceanView.LAYER_SHIP, 0, "корабль изнутри тень не отбрасывает")
	ok(ocean.sun.shadow_caster_mask & OceanView.LAYER_WORLD != 0, "отмель и корпус — отбрасывают")
	ocean.queue_free()
	await frames(1)


func test_scene_bridge_casts_no_sun_shadow() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var mask: int = main.ocean.sun.shadow_caster_mask
	var bridge := 0
	for n: Node in main.get_node("Корабль/Мостик").find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and gi.layers & mask != 0:
			bridge += 1
	eq(bridge, 0, "ни одна деталь мостика не ложится тенью солнца на дно")
	main.queue_free()
	await frames(1)
