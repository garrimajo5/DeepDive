extends TestCase
## #847: OceanView пишет воду, туман, лёд, лучи и взвесь только при изменении глубины, ила и положения корабля.


func _ocean() -> OceanView:
	var o := OceanView.new()
	tree.root.add_child(o)
	return o


func test_water_written_only_on_change() -> void:
	var o := _ocean()
	await frames(1)
	var env := Environment.new()
	o.apply_water(env, 20.0, Vector3.ZERO)
	var n := o.water_writes
	var d20 := env.fog_density
	o.apply_water(env, 20.0, Vector3(1, 0, 0))
	o.apply_water(env, 20.002, Vector3(2, 0, 0))
	eq(o.water_writes, n, "глубина та же — вода не переписана")
	eq(o.snow.position, Vector3(2, 0, 0), "взвесь всё равно идёт за кораблём")
	o.apply_water(env, 40.0, Vector3.ZERO)
	eq(o.water_writes, n + 1, "глубже — записано")
	ok(not is_equal_approx(env.fog_density, d20), "туман по новой глубине")
	o.apply_water(env, 40.0, Vector3.ZERO, 0.5)
	eq(o.water_writes, n + 2, "ил — записано")
	o.set_relief(false)
	o.apply_water(env, 40.0, Vector3.ZERO, 0.5)
	eq(o.water_writes, n + 3, "смена рельефа — записано заново")
	near(float(o.ice_mat.get_shader_parameter("relief")), 0.0, 1e-6, "«Экономно» — лёд без рельефа")
	o.set_relief(true)
	o.apply_water(env, 40.0, Vector3.ZERO, 0.5)
	near(float(o.ice_mat.get_shader_parameter("relief")), IceSheet.relief(40.0), 1e-6, "рельеф вернулся без смены глубины")
	o.queue_free()
	await frames(1)


func test_ship_matrix_written_only_on_move() -> void:
	var o := _ocean()
	await frames(1)
	o.set_ship(Vector3(1, -20, 3), 0.4)
	o.shafts_mat.set_shader_parameter("ship_inv", Projection.IDENTITY)
	o.set_ship(Vector3(1, -20, 3), 0.4)
	eq(o.shafts_mat.get_shader_parameter("ship_inv"), Projection.IDENTITY, "корабль стоит — матрица не переписана")
	o.set_ship(Vector3(2, -20, 3), 0.4)
	ok(o.shafts_mat.get_shader_parameter("ship_inv") != Projection.IDENTITY, "сдвинулся — записана")
	o.queue_free()
	await frames(1)
