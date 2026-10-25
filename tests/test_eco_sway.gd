extends TestCase
## Колыхание флоры в течении (план реализма Б3): ленты ленточника, листья волнолиста и веерники ложатся по потоку
## EcoCurrent, по ним бежит волна, соседние кусты — вразнобой. Формула — EcoCurrent.sway, двойник шейдера PLANT.

const BEND := Vector3(0.12, 0.1, 0.06)


## Среднее смещение кончика за минуту.
func _mean(o: Vector3, flow: Vector3, bend: Vector3 = BEND, height: float = 5.0) -> Vector3:
	var sum := Vector3.ZERO
	var n := 600
	for i in n:
		sum += EcoCurrent.sway(o, 1.0, height, i * 0.1, flow, bend)
	return sum / n


func test_root_stays() -> void:
	for t in [0.0, 3.7, 41.0]:
		var off := EcoCurrent.sway(Vector3(10, 0, -4), 0.0, 5.0, t, Vector3(0.3, 0, 0), BEND)
		near(off.length(), 0.0, 1e-6, "подножие не двигается (t = %s)" % t)


func test_leans_downstream() -> void:
	var sea := EcoCurrent.new()
	sea.reset(null)
	for a in EcoCurrent.DIRS:
		sea.angle = a
		var flow := sea.vel()
		var m := _mean(Vector3(3, 0, 7), flow)
		var dir := flow.normalized()
		ok(m.dot(dir) > 0.3, "кончик в среднем ложится по потоку (%.2f м при угле %.1f)" % [m.dot(dir), a])
		var side := Vector3(-dir.z, 0, dir.x)
		ok(absf(m.dot(side)) < 0.1, "поперёк в среднем не уходит")
		ok(m.y < 0.0, "согнутый кончик опускается, стебель не вытягивается")


func test_still_water_no_lean() -> void:
	var m := _mean(Vector3(3, 0, 7), Vector3.ZERO)
	ok(Vector2(m.x, m.z).length() < 0.06, "без течения нет крена: %.3f м" % Vector2(m.x, m.z).length())
	var moved := 0.0
	for i in 50:
		moved = maxf(moved, EcoCurrent.sway(Vector3(3, 0, 7), 1.0, 5.0, i * 0.2, Vector3.ZERO, BEND).length())
	ok(moved > 0.05, "но лёгкое колыхание остаётся: %.2f м" % moved)


func test_grows_to_tip_and_with_height() -> void:
	var flow := Vector3(0, 0, 0.3)
	var t := 2.0
	var o := Vector3(1, 0, 1)
	var half := EcoCurrent.sway(o, 0.5, 5.0, t, flow, BEND).length()
	var tip := EcoCurrent.sway(o, 1.0, 5.0, t, flow, BEND).length()
	ok(tip > half * 2.5, "к кончику сильнее (h²): %.2f и %.2f" % [half, tip])
	var small := EcoCurrent.sway(o, 1.0, 1.4, t, flow, BEND).length()
	ok(small < tip * 0.5, "лист 1,4 м гнётся меньше ленты 5 м")
	ok(tip < 5.0 * 0.35, "крен — доли высоты, не больше трети")


func test_neighbours_out_of_phase() -> void:
	var flow := Vector3(0.2, 0, 0.2)
	var a := EcoCurrent.sway(Vector3(0, 0, 0), 1.0, 5.0, 10.0, flow, BEND)
	var b := EcoCurrent.sway(Vector3(6, 0, 3), 1.0, 5.0, 10.0, flow, BEND)
	ok(a.distance_to(b) > 0.05, "соседние кусты колышутся вразнобой")


## Шейдер растений — двойник EcoCurrent.sway: те же числа фазы, порывов и волны.
func test_shader_twin() -> void:
	var code := EcoShaders.PLANT
	ok(code.contains("uniform vec3 flow") and code.contains("uniform vec3 bend"), "поток и изгиб — в uniform")
	ok(code.contains("o.x * %s + o.z * %s" % [EcoCurrent.PHASE_X, EcoCurrent.PHASE_Z]), "та же фаза")
	ok(code.contains("v / %s" % EcoCurrent.SPEED), "полное течение — EcoCurrent.SPEED")
	ok(code.contains("%s + %s * s" % [EcoCurrent.IDLE, 1.0 - EcoCurrent.IDLE]), "то же колыхание без течения")
	for part in ["TIME * 0.45 + ph", "TIME * 1.6 + ph * 1.3 - h * 2.2", "TIME * 1.1 + ph * 0.7 - h * 1.5"]:
		ok(code.contains(part), "та же волна: " + part)


func test_views_bend_and_flow() -> void:
	var kelp := EcoShaders.plant(EcoShaders.Plant.KELP, {"bend": KelpView.BEND, "reach": 1.0})
	var organ := EcoShaders.plant(EcoShaders.Plant.ORGAN)
	EcoShaders.set_flow(Vector3(0.1, 0, -0.2))
	near((kelp.get_shader_parameter("flow") as Vector3).distance_to(Vector3(0.1, 0, -0.2)), 0.0, 1e-6, "поток дошёл")
	eq(organ.get_shader_parameter("bend"), null, "трубы органа не гнутся (bend по умолчанию — ноль)")
	ok(KelpView.BEND.x > FernView.BEND.x and FernView.BEND.x > FanView.BEND.x, "лента гибче листа, лист — веера")
	var fresh := EcoShaders.plant(EcoShaders.Plant.LEAF)
	near((fresh.get_shader_parameter("flow") as Vector3).distance_to(EcoShaders.flow), 0.0, 1e-6,
		"новый материал сразу с текущим потоком")
	EcoShaders.set_sway_lite(true)
	eq(float(kelp.get_shader_parameter("sway_k")), 0.0, "«Экономно» — растения не колышутся")
	eq(float(EcoShaders.plant(EcoShaders.Plant.FAN).get_shader_parameter("sway_k")), 0.0, "и новые тоже")
	EcoShaders.set_sway_lite(false)
	eq(float(kelp.get_shader_parameter("sway_k")), 1.0, "выключатель возвращает колыхание")
	EcoShaders.set_flow(Vector3.ZERO)


func test_eco_view_gives_current() -> void:
	var ev := EcoView.new()
	ev.ground = Seabed.height
	ev.current.angle = 2.4
	ev.step(0.1, EcoLink.ShipState.new())
	var want := ev.current.vel()
	var fan := ev.fan_view.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	var leaf := ev.fern_view.leaves.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	var kelp := ev.kelp_view.stalks.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	for m in [fan, leaf, kelp]:
		near((m.get_shader_parameter("flow") as Vector3).distance_to(want), 0.0, 1e-4, "растения идут по течению мира")
		ok((m.get_shader_parameter("bend") as Vector3).length() > 0.0, "у вида свой изгиб")
	near(float(leaf.get_shader_parameter("reach")), EcoFern.LEAF_LEN, 1e-6, "лист — своя длина")
	near(float(fan.get_shader_parameter("reach")), EcoFan.HEIGHT, 1e-6, "веер — своя высота")
	ev.free()
	EcoShaders.set_flow(Vector3.ZERO)


# ---------- Огнецвет ----------

## Огнецвет колышется тем же куском SWAY: подножие стоит, вершина со станцией огнёвок — не дальше 0,3 м,
## коралл твёрже веерника, соседние кусты вразнобой.
func test_coral_sways_gently() -> void:
	var ev := EcoView.new()
	ev.ground = Seabed.height
	ev.step(0.1, EcoLink.ShipState.new())
	var cv := ev.coral_view
	var mat := cv.material()
	ok(mat.shader.code.contains("eco_sway(foot[i], UV2.x, tall[i], bend)"), "кусты гнутся общим куском SWAY")
	eq(cv.heights.size(), cv.verts.size(), "доля высоты у каждой вершины")
	eq(cv.feet.size(), ev.coral.bushes.size(), "подножие каждого куста")
	near((mat.get_shader_parameter("flow") as Vector3).distance_to(ev.current.vel()), 0.0, 1e-4,
		"огнецвет идёт по течению мира")
	ok(CoralView.BEND.x < FanView.BEND.x, "коралл твёрже веерника")
	var flow := Vector3(0, 0, EcoCurrent.SPEED)
	var top_i := 0
	var low_i := 0
	for i in EcoCoralLook.verts.size():
		if cv.heights[i] > cv.heights[top_i]:
			top_i = i
		if cv.heights[i] < cv.heights[low_i]:
			low_i = i
	var most := 0.0
	for k in 300:
		var t := k * 0.2
		near(cv.offset(low_i, t, flow).length(), 0.0, 1e-6, "подножие стоит")
		most = maxf(most, cv.offset(top_i, t, flow).length())
	ok(most > 0.05, "вершина заметно колышется: %.2f м" % most)
	ok(most < 0.3, "но станция огнёвок на месте: %.2f м" % most)
	var n := EcoCoralLook.verts.size()
	ok(cv.offset(top_i, 10.0, flow).distance_to(cv.offset(n + top_i, 10.0, flow)) > 0.01, "кусты вразнобой")
	EcoShaders.set_sway_lite(true)
	eq(float(mat.get_shader_parameter("sway_k")), 0.0, "«Экономно» — огнецвет стоит")
	EcoShaders.set_sway_lite(false)
	ev.free()
	EcoShaders.set_flow(Vector3.ZERO)


# ---------- Щупальца хватней ----------

## Щупальца хватней (Б1 + Б3): тело со светом, к кончику светится само, колышутся общим шейдером растений —
## нового шейдера нет; у диска стоят, кончик ходит заметно, но не дальше трети длины, соседние — вразнобой.
func test_hvaten_tentacles_writhe() -> void:
	var m := HvatenView.build_tentacle()
	var mat := m.surface_get_material(0) as ShaderMaterial
	ok(mat != null and mat.shader.code == EcoShaders.PLANT, "щупальца — общий шейдер растений")
	eq(int(mat.get_shader_parameter("mode")), int(EcoShaders.Plant.TENTACLE), "режим щупалец")
	ok(not mat.shader.code.contains("unshaded"), "тело ловит свет")
	var glow: Vector2 = mat.get_shader_parameter("tip_glow")
	ok(glow.y > glow.x * 3.0 and glow.x > 0.0, "к кончику светится ярче, у диска — чуть")
	var col: PackedColorArray = m.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in v.size():
		near(col[i].a, clampf(v[i].y, 0.0, 1.0), 0.01, "в альфе — доля длины")
	ok(EcoShaders.PLANT.contains("po.x += atan(ay.z, ay.x) * phase_axis"), "фаза вдоль оси — и в шейдере")
	var ev := EcoView.new()
	ev.ground = Seabed.height
	ev.step(0.1, EcoLink.ShipState.new())
	var hv := ev.hvaten_view
	var tm := hv.tents.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	near((tm.get_shader_parameter("flow") as Vector3).distance_to(ev.current.vel()), 0.0, 1e-4,
		"щупальца идут по течению мира")
	var flow := Vector3(0, 0, EcoCurrent.SPEED)
	var a := HvatenView.transform_at(hv.tent_buffer, 0)
	var b := HvatenView.transform_at(hv.tent_buffer, 1)
	var most := 0.0
	var apart := 0.0
	for k in 300:
		var t := k * 0.2
		near(HvatenView.tentacle_offset(a, Vector3.ZERO, t, flow).length(), 0.0, 1e-6, "у диска стоит")
		var ta := HvatenView.tentacle_offset(a, Vector3.UP, t, flow)
		most = maxf(most, ta.length())
		apart = maxf(apart, ta.distance_to(HvatenView.tentacle_offset(b, Vector3.UP, t, flow)))
	var length := a.basis.y.length()
	ok(most > 0.08, "кончик заметно извивается: %.2f м" % most)
	ok(most < length / 3.0, "но не дальше трети длины: %.2f из %.2f м" % [most, length])
	ok(apart > 0.05, "соседние щупальца одного диска — вразнобой: %.2f м" % apart)
	EcoShaders.set_sway_lite(true)
	eq(float(tm.get_shader_parameter("sway_k")), 0.0, "«Экономно» — щупальца не извиваются в шейдере")
	EcoShaders.set_sway_lite(false)
	ev.free()
	EcoShaders.set_flow(Vector3.ZERO)
