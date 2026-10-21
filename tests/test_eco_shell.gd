extends TestCase
## Раковина древних (js/world.js, место 3 карты отмели): место с карты, спираль из 70 витков как в браузере стоит
## на дне в пределах препятствия, кольца знаков на лицевой стороне смотрят на старт и загораются по очереди,
## меш — один вызов отрисовки, грани наружу.

const FLAT := -40.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _shell(ground: Callable) -> EcoShell:
	var w := EcoWorld.new()
	w.ground = ground
	return w.add(EcoShell.new()) as EcoShell


func test_place_from_map() -> void:
	var f := FileAccess.open("res://docs/concept-art/karta-otmeli-mesta.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var spot: Dictionary = {}
	for l in data["locations"]:
		if l["name"] == "Раковина древних":
			spot = l
	near(EcoShell.CENTER.x, float(spot["x"]), 1e-6, "x с карты отмели")
	near(EcoShell.CENTER.y, float(spot["z"]), 1e-6, "z с карты отмели")
	eq(EcoShell.ID, "shell", "ключ места как в Run.PLACES")
	eq(Run.PLACES[EcoShell.ID][1], EcoShell.CENTER, "точка маршрута — у раковины")


func test_spiral_like_browser() -> void:
	var sh := _shell(_flat)
	eq(sh.coils.size(), 70, "70 витков")
	eq(sh.ring_c.size(), 5, "5 колец знаков")
	# витки растут наружу: e^(0,085·0,28) на шаг, у последнего — R0·e^(0,085·19,32) × 1,05 × 1,4
	ok(sh.coil_r[69] > sh.coil_r[0] * 5.0, "наружные витки толще: %f / %f" % [sh.coil_r[69], sh.coil_r[0]])
	near(sh.coil_r[69], 0.35 * exp(0.085 * 69 * 0.28) * 1.05 * 1.4, 1e-4, "радиус последнего витка из браузера")
	# локально спираль — в плоскости XY: центр шара i на 2,2 радиуса от оси под углом i·0,28
	for i in [0, 20, 69]:
		var l := sh.to_local(sh.coils[i])
		var r := 0.35 * exp(0.085 * i * 0.28)
		near(l.x, cos(i * 0.28) * r * 2.2, 1e-3, "виток %d по x" % i)
		near(l.y, sin(i * 0.28) * r * 2.2, 1e-3, "виток %d по y" % i)
		ok(absf(l.z) <= 0.05 + 1e-4, "виток %d в плоскости" % i)
	for k in 5:
		near(sh.ring_r[k], (1.2 + k * 1.1) * 1.4, 1e-4, "радиус кольца %d" % k)
		ok(sh.to_local(sh.ring_c[k]).z > 1.1, "кольцо %d впереди витков" % k)


func test_on_ground_within_obstacle() -> void:
	var sh := _shell(Seabed.height)
	var y0 := Seabed.height(EcoShell.CENTER.x, EcoShell.CENTER.y)
	near(sh.base.y, y0, 1e-4, "подножие на дне")
	var top := sh.top().y - y0
	ok(top > 8.0 and top <= EcoShell.OBSTACLE_TOP, "верх витков на %f м — не выше препятствия браузера" % top)
	var lowest := INF
	for i in sh.coils.size():
		lowest = minf(lowest, sh.coils[i].y - sh.coil_r[i])
		var d := Vector2(sh.coils[i].x - sh.base.x, sh.coils[i].z - sh.base.z).length() + sh.coil_r[i]
		ok(d <= EcoShell.OBSTACLE_R, "виток %d в круге препятствия: %f" % [i, d])
	ok(lowest < y0, "нижние витки уходят в дно — раковина не висит")


func test_faces_start() -> void:
	var sh := _shell(_flat)
	var f := sh.face()
	var to := Vector2(EcoShell.FACE.x - sh.base.x, EcoShell.FACE.y - sh.base.z).normalized()
	ok(Vector2(f.x, f.z).normalized().dot(to) > 0.9, "кольца смотрят на старт забега")
	# форма своя — не зависит от зерна мира
	var w := EcoWorld.new(777)
	w.ground = _flat
	var other := w.add(EcoShell.new()) as EcoShell
	eq(other.coils, sh.coils, "форма одна при любом зерне мира")


func test_solid_coils_and_water_around() -> void:
	var sh := _shell(_flat)
	ok(sh.solid(sh.coils[40]), "виток твёрдый")
	ok(not sh.solid(sh.base + Vector3(0, EcoShell.OBSTACLE_TOP + 3.0, 0)), "над раковиной — вода")
	ok(not sh.solid(sh.base + Vector3(EcoShell.OBSTACLE_R + 3.0, 4, 0)), "сбоку за препятствием — вода")
	ok(not sh.solid(sh.ring_c[4] + sh.face() * 3.0), "перед кольцами — вода")


func test_rings_light_in_turn() -> void:
	var lo := 1.0
	var hi := 0.0
	for s in 100:
		var g := EcoShell.glow(0, s * 0.05)
		lo = minf(lo, g)
		hi = maxf(hi, g)
	near(lo, 0.25, 1e-6, "кольцо не гаснет до конца")
	ok(hi > 0.99, "кольцо разгорается полностью: %f" % hi)
	# очередь от середины наружу: внутреннее кольцо на пике, следующее — ещё нет
	var t := (PI * 0.5) / EcoShell.GLOW_RATE
	near(EcoShell.glow(0, t), 1.0, 1e-6, "первое на пике")
	ok(EcoShell.glow(1, t) < EcoShell.glow(0, t), "второе позже")
	ok(EcoShell.glow(1, t + EcoShell.GLOW_WAVE / EcoShell.GLOW_RATE) > 0.999, "второе на пике через 0,53 с")


func test_view_one_mesh_faces_out() -> void:
	var sh := _shell(_flat)
	var v := ShellView.new(sh)
	tree.root.add_child(v)
	await frames(1)
	eq(v.mesh.get_surface_count(), 1, "один вызов отрисовки")
	ok(v.tris > 3000 and v.tris < 12000, "треугольников в бюджете: %d" % v.tris)
	eq(v.layers, OceanView.LAYER_WORLD, "слой отмели")
	# у первых 70·80 треугольников (витки) грань смотрит наружу от центра своего шара
	var per := ShellView.SIDES * (ShellView.ROWS * 2 - 2)
	var outward := 0
	for i in sh.coils.size() * per:
		var a := v.verts[i * 3]
		var c := (a + v.verts[i * 3 + 1] + v.verts[i * 3 + 2]) / 3.0
		var out := c - sh.coils[i / per]
		var cr := (v.verts[i * 3 + 1] - a).cross(v.verts[i * 3 + 2] - a)
		if cr.dot(out) < 0.0 and v.normals[i * 3].dot(out) > 0.0:
			outward += 1
	eq(outward, sh.coils.size() * per, "лицевая сторона витков — снаружи (обход по часовой)")
	v.queue_free()
	await frames(1)


func test_in_eco_view() -> void:
	var ev := EcoView.new()
	ev.ground = _flat
	ok(ev.shell != null and ev.shell_view != null, "раковина в живом мире")
	near(ev.shell.base.y, FLAT, 1e-4, "встала на дно мира")
	ev.free()
