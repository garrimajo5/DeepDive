extends TestCase
## Купольник в сцене моделью MOD-022 (#837, `DomeView`): модель в месте и курсе `EcoDome`, низ — в `pos`, перед —
## по курсу; ушёл в нишу — скрыт; импульс фотофоров ярче покоя; слой отмели, тень, один вызов отрисовки.

const DT := 0.1


func _world(ship_at: Vector3) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = ship_at
	return w


func _near() -> Vector3:
	return Vector3(EcoGate.CENTER.x, -35.0, EcoGate.CENTER.y + 60.0)


func test_model_follows_dome() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var v := DomeView.new(d)
	tree.root.add_child(v)
	for i in 80:   # выходит к гнезду: место и курс меняются
		w.time += DT
		d.step(w, DT)
	v.sync()
	ok(v.visible, "на ходу виден")
	near(v.body.global_position.distance_to(d.pos), 0.0, 1e-4, "модель — в месте купольника")
	var nose := -v.body.global_transform.basis.z
	var want := Vector3(-sin(d.yaw), 0.0, -cos(d.yaw))
	near(nose.dot(want), 1.0, 1e-4, "перед модели (−Z) — по курсу")
	var box: AABB = v.mesh.global_transform * v.mesh.mesh.get_aabb()
	near(box.position.y, d.pos.y, 0.02, "низ модели — в pos")
	ok(box.position.y > d.floor_y(d.pos.x, d.pos.z), "модель над дном")
	v.queue_free()
	await frames(1)


func test_hidden_when_gone() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var v := DomeView.new(d)
	d.state = EcoDome.State.GONE
	v.sync()
	ok(not v.visible, "ушёл в нишу — скрыт")
	d.state = EcoDome.State.WAIT
	v.sync()
	ok(v.visible, "ждёт в нише — виден")
	v.free()


func test_pulse_brighter_than_rest() -> void:
	near(DomeView.energy(EcoDome.GLOW_REST, 2.0), 2.0, 1e-5, "покой — как в модели")
	near(DomeView.energy(EcoDome.PULSE, 2.0), 2.0 * DomeView.PULSE_GAIN, 1e-5, "пик импульса")
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var v := DomeView.new(d)
	var peak := 0.0
	for i in 12:
		w.time += DT
		d.step(w, DT)
		v.sync()
		peak = maxf(peak, v.mat.emission_energy_multiplier)
	ok(peak > v.base_energy * 1.5, "импульс команды — фотофоры ярче покоя")
	var own := v.mesh.get_surface_override_material(0)
	ok(own == v.mat and own != v.mesh.mesh.surface_get_material(0), "свой материал, GLB не меняется")
	v.free()


func test_layer_shadow_one_mesh() -> void:
	var d := EcoDome.new()
	d.reset(_world(_near()))
	var v := DomeView.new(d)
	eq(v.find_children("*", "MeshInstance3D", true, false).size(), 1, "одна сетка — один вызов")
	eq(v.mesh.layers, OceanView.LAYER_WORLD, "слой отмели")
	ok(v.mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "отбрасывает тень")
	near(v.mesh.visibility_range_end, DomeView.HIDE_FAR, 1e-5, "вдали не рисуется")
	v.free()


func test_scene_draws_dome() -> void:
	var v := EcoView.new()
	tree.root.add_child(v)
	await frames(1)
	ok(v.dome_view != null and v.dome_view.dome == v.dome, "в сцене — вид купольника")
	eq(v.get_node("Купольник"), v.dome_view, "узел «Купольник»")
	near(v.dome_view.body.position.distance_to(v.dome.pos), 0.0, 1e-4, "на старте — в нише")
	v.queue_free()
	await frames(1)
