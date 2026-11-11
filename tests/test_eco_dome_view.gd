extends TestCase
## Купольник в сцене моделью MOD-022 (#837, `DomeView`): модель в месте и курсе `EcoDome`, низ — в `pos`, перед —
## по курсу; ушёл в нишу — скрыт; импульс фотофоров ярче покоя; слой отмели, тень, один вызов отрисовки.
## Клипы ANIM-004 по состоянию: Idle в нише, Swim на ходу, OpenPetal у гнезда — по времени состояния, вдали стоят.

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


## Шаг мира и вида; клип считается — вид меряет от самого купольника (камера рядом).
func _run(w: EcoWorld, d: EcoDome, v: DomeView, n: int) -> void:
	for i in n:
		w.time += DT
		d.step(w, DT)
		v.sync(w.time, d.pos)


func test_clip_by_state() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var v := DomeView.new(d)
	tree.root.add_child(v)
	w.ship.pos = Vector3(d.pos.x, d.pos.y + 30.0, d.pos.z + 200.0)   # далеко от террасы: ждёт
	_run(w, d, v, 3)
	eq(v.playing, "Idle", "в нише — Idle")
	w.ship.pos = _near()
	var swam := false
	for i in 3000:
		_run(w, d, v, 1)
		if d.state == EcoDome.State.GO and d.speed > 0.3:
			swam = swam or v.playing == "Swim"
		if d.state == EcoDome.State.OPEN:
			break
	ok(swam, "на ходу к гнезду — Swim")
	eq(d.state, EcoDome.State.OPEN, "дошёл до гнезда")
	_run(w, d, v, 20)
	eq(v.playing, "OpenPetal", "у гнезда — OpenPetal")
	near(v.player.current_animation_position, d.t, DomeView.DRIFT + 1e-3, "клип — по времени состояния")
	_run(w, d, v, 40)
	ok(d.state == EcoDome.State.BACK, "открыл и уходит")
	_run(w, d, v, 30)
	eq(v.playing, "Swim" if d.speed > 0.05 else "Idle", "обратно — Swim")
	v.queue_free()
	await frames(1)


func test_petal_lift_with_world() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var v := DomeView.new(d)
	tree.root.add_child(v)
	await frames(1)
	d.pos = d.stand()
	d.state = EcoDome.State.OPEN
	d.t = 0.0
	var sk: Skeleton3D = v.body.find_children("*", "Skeleton3D", true, false)[0]
	var pad := sk.find_bone("GraspMPadA")
	var y0 := 0.0
	var y1 := 0.0
	while d.state == EcoDome.State.OPEN:
		w.time += DT
		d.step(w, DT)
		v.sync(w.time, d.pos)
		if absf(d.t - EcoDome.LIFT.x) < DT * 0.5:
			y0 = sk.get_bone_global_pose(pad).origin.y
		if absf(d.t - EcoDome.LIFT.y) < DT * 0.5:
			y1 = sk.get_bone_global_pose(pad).origin.y
			ok(d.petal > 0.99, "в мире створка поднята к концу подъёма")
	ok(y1 - y0 > 0.4, "захват поднимает створку вместе с миром (%.2f м)" % (y1 - y0))
	v.queue_free()
	await frames(1)


func test_far_clip_stands() -> void:
	var w := _world(_near())
	var d := EcoDome.new()
	d.reset(w)
	var v := DomeView.new(d)
	tree.root.add_child(v)
	_run(w, d, v, 2)
	var far := d.pos + Vector3(0.0, 0.0, DomeView.HIDE_FAR + 5.0)
	var at := v.player.current_animation_position
	for i in 10:
		w.time += DT
		v.sync(w.time, far)
	eq(v.playing, "Idle", "клип выбран")
	near(v.player.current_animation_position, at, 1e-5, "дальше HIDE_FAR — поза не считается")
	v.sync(w.time + DT, d.pos)
	ok(v.player.current_animation_position > at, "рядом — снова идёт")
	v.queue_free()
	await frames(1)


func test_swim_rate() -> void:
	near(DomeView.swim_rate(EcoDome.SWIM), 1.0, 1e-5, "полный ход к гнезду — темп клипа 1")
	near(DomeView.swim_rate(0.0), DomeView.RATE_MIN, 1e-5, "трогается — не стоит на месте")
	ok(DomeView.swim_rate(EcoDome.LEAVE) > 1.0, "уходит быстрее — сифоны чаще")
