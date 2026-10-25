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
