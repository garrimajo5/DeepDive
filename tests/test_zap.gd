extends TestCase
## Разряд по корпусу: стоимость, радиус от доли, откат, живой мир узнаёт о разряде.


func test_fire_rules() -> void:
	var z := Zap.new()
	var v := Vitals.new()
	eq(z.fire(0.0, 0.0, v), "Разряд обесточен", "без доли нет")
	eq(z.fire(0.0, 1.0, v), "Разряд по корпусу", "разряд")
	near(v.energy, 85.0, 1e-6, "−15 единиц")
	near(z.radius, 20.0, 1e-6, "20 м при штатной доле")
	eq(z.fire(1.0, 1.0, v), "Разряд копится", "откат 2 с")
	v.energy = 10.0
	ok(z.fire(5.0, 2.0, v).begins_with("Мало энергии"), "мало заряда")
	v.energy = 50.0
	z.fire(9.0, 2.0, v)
	near(z.radius, 40.0, 1e-6, "доля ×2 — радиус ×2")
	ok(z.flicker > 0.0, "свет мигает")
	z.update(1.0)
	near(z.flicker, 0.0, 1e-9, "и перестаёт через 0,8 с")


class ZapEco:
	extends EcoView
	var zapped := false
	var radius := 0.0

	func step(_dt: float, ship: EcoLink.ShipState) -> Array[Dictionary]:
		if ship.zap:
			zapped = true
			radius = ship.zap_radius
		return []


func test_scene_lever() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var fake := ZapEco.new()
	main.eco.queue_free()
	main.eco = fake
	main.add_child(fake)
	main.walker.x = Zap.POST_AT.x
	main.walker.z = Zap.POST_AT.y
	main.step(0.1)
	eq(main.overlay.action_label, "Разряд", "у рычага — кнопка «Разряд»")
	var r := main.overlay.router
	r.begin(1, r.layout.action.c)
	r.end(1)
	main.step(0.1)
	ok(fake.zapped, "живой мир узнал о разряде")
	near(fake.radius, 20.0, 1e-6, "радиус 20 м")
	ok(not main.eco_ship.zap, "разряд — один шаг")
	near(main.bridge.zap_lever.rotation_degrees.z, Zap.LEVER_DOWN, 1e-3, "рычаг опущен на −25°")
	eq(main.bridge.zap_scale_mat.emission_energy_multiplier, 0.0, "шкала готовности погасла")
	ok(main.zap_light.light_energy > 1.0, "вспышка за бортом")
	near(main.vitals.energy, 100.0 - 15.0, 0.5, "заряд потрачен")
	for i in 10:
		main.step(0.1)
	ok(main.zap_light.light_energy < 0.01, "через секунду вспышки нет")
	ok(main.zap_light.visible and main.zap_light.omni_range > 79.0, "свет вспышки остаётся в сцене на весь радиус (issue #159)")
	var mid := main.bridge.zap_lever.rotation_degrees.z
	ok(mid > Zap.LEVER_DOWN and mid < Zap.LEVER_UP, "рычаг поднимается: %.1f°" % mid)
	eq(main.bridge.zap_scale_mat.emission_energy_multiplier, 0.0, "откат — шкала не горит")
	for i in 10:
		main.step(0.1)
	near(main.bridge.zap_lever.rotation_degrees.z, Zap.LEVER_UP, 1e-3, "через 2 с взведён")
	eq(main.bridge.zap_scale_mat.emission_energy_multiplier, 1.0, "шкала горит — готов")


## Issue #50: без прогрева (тесты) вспышка при старте погашена; прогрев вспышки — test_warmup.
func test_scene_light_off_without_warmup() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	ok(not main.warming(), "в тестах прогрева нет")
	ok(main.zap_light.light_energy < 0.01, "вспышка погашена")
	ok(main.zap_light.light_cull_mask == OceanView.LAYER_WORLD, "светит только за бортом")
	main.queue_free()
	await frames(1)


func test_lever_travel() -> void:
	var z := Zap.new()
	var v := Vitals.new()
	ok(z.ready(0.0), "в начале готов")
	eq(z.lever_deg(0.0), Zap.LEVER_UP, "взведён")
	z.fire(10.0, 1.0, v)
	ok(not z.ready(10.0) and not z.ready(11.9), "откат 2 с")
	ok(z.ready(12.0), "готов снова")
	eq(z.lever_deg(10.0), Zap.LEVER_DOWN, "в момент разряда внизу")
	eq(z.lever_deg(10.7), Zap.LEVER_DOWN, "пока мигает свет — внизу")
	near(z.lever_deg(11.4), 0.0, 1e-3, "на полпути отката — горизонтально")
	eq(z.lever_deg(12.0), Zap.LEVER_UP, "к концу отката взведён")


## Дуги по обшивке ART-068: фронт от носа к корме 50 м/с, ширина 7 м, к 0,8 с жёстко 0, кадр атласа 10 Гц.
func test_arc_numbers() -> void:
	eq(Zap.arc_time(0.0), -1.0, "без мигания дуг нет")
	near(Zap.arc_time(Zap.FLICKER), 0.0, 1e-9, "в момент разряда t = 0")
	near(Zap.arc_time(0.5), 0.3, 1e-6, "мигание 0,5 — t 0,3")
	near(Zap.arc_front(0.0), -7.2, 1e-6, "фронт начинается у носа")
	near(Zap.arc_front(0.3), 7.8, 1e-6, "через 0,3 с — середина корпуса")
	near(Zap.arc_k(-7.2, 0.0), 1.0, 1e-6, "на фронте в начале — полная сила")
	near(Zap.arc_k(7.8, 0.3), 1.0 - 0.3 / 0.8, 1e-6, "на фронте гаснет линейно")
	near(Zap.arc_k(7.8 + 7.0, 0.3), exp(-1.0) * (1.0 - 0.3 / 0.8), 1e-6, "в 7 м от фронта — e⁻¹")
	ok(Zap.arc_k(20.0, 0.0) < 1e-4, "корма в начале тёмная")
	eq(Zap.arc_k(32.8, Zap.FLICKER), 0.0, "в 0,8 с — ровно 0")
	eq(Zap.arc_k(0.0, -1.0), 0.0, "без разряда — 0")
	eq(Zap.arc_frame(0.0), 0, "первый кадр")
	eq(Zap.arc_frame(0.25), 2, "10 Гц")
	eq(Zap.arc_frame(0.79), 7, "последний кадр")
	eq(Zap.arc_frame(5.0), 7, "дальше — держится на последнем")
	eq(Zap.arc_frame(0.55, true), 0, "«Экономно» — один кадр")


## Дуги ART-068 бегут по обшивке тем же материалом (0 новых вызовов) и гаснут к 0,8 с; «Экономно» — один кадр.
func test_scene_arcs_on_hull() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var mat: ShaderMaterial = main.hull.body_material(HullPlan.Paint.METAL)
	ok(mat.get_shader_parameter("arc_tex") is Texture2D, "атлас дуг в материале обшивки")
	eq(float(mat.get_shader_parameter("zap_t")), -1.0, "до разряда дуг нет")
	var calls := main.hull.body.mesh.get_surface_count()
	main.fire_zap()
	main.step(0.0)
	near(float(mat.get_shader_parameter("zap_t")), 0.0, 1e-6, "разряд — дуги с начала")
	for i in 9:
		main.step(1.0 / 30.0)
	near(float(mat.get_shader_parameter("zap_t")), 0.3, 1e-4, "через 0,3 с — t 0,3")
	for i in 20:
		main.step(1.0 / 30.0)
	eq(float(mat.get_shader_parameter("zap_t")), -1.0, "после 0,8 с дуги погасли")
	eq(main.hull.body.mesh.get_surface_count(), calls, "без новых поверхностей")
	main.hull.set_relief(false)
	ok(mat.get_shader_parameter("zap_lite"), "«Экономно» — дуги одним кадром")
	main.queue_free()
	await frames(1)


## ART-068, карточки у окна и у дна: огибающие по времени, двойник шейдера zap_cards.
func test_card_envelopes() -> void:
	near(Zap.card_k(Zap.Card.WINDOW, 0.0), 1.0, 1e-6, "дуга у окна — сразу")
	near(Zap.card_k(Zap.Card.WINDOW, Zap.WINDOW_GONE), 0.0, 1e-6, "и уходит к 0,22 с")
	near(Zap.card_k(Zap.Card.BRANCH, 0.1), 0.0, 1e-6, "ветви к дну — не сразу")
	ok(Zap.card_k(Zap.Card.BRANCH, 0.3) > 0.9, "ветви ярче всего к 0,3 с")
	ok(Zap.card_k(Zap.Card.SPARK, 0.25) > 0.9, "искра касания к 0,25 с")
	for kind in [Zap.Card.WINDOW, Zap.Card.BRANCH, Zap.Card.SPARK]:
		eq(Zap.card_k(kind, -1.0), 0.0, "вне разряда нет (%d)" % kind)
		eq(Zap.card_k(kind, Zap.FLICKER), 0.0, "к 0,8 с нет (%d)" % kind)


## Сетка дна: в вершинах — Seabed.height, между — по треугольникам клетки, как в build_arrays.
func test_mesh_height() -> void:
	var step := Seabed.SIZE / Seabed.SEGMENTS
	near(Seabed.mesh_height(10.0, -20.0), Seabed.height(10.0, -20.0), 1e-4, "в вершине — высота")
	var mid := Seabed.mesh_height(10.0 + step / 2.0, -20.0 + step / 2.0)
	near(mid, (Seabed.height(10.0 + step, -20.0) + Seabed.height(10.0, -20.0 + step)) / 2.0, 1e-4,
		"середина клетки — на диагонали (x0 + шаг, z0)…(x0, z0 + шаг)")
	var arr := Seabed.build_arrays(4, 20.0)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	eq(pos[idx[1]], Vector3(-5.0, Seabed.height(-5.0, -10.0), -10.0), "у сетки та же диагональ: вершина (x0 + шаг, z0)")
	eq(pos[idx[2]], Vector3(-10.0, Seabed.height(-10.0, -5.0), -5.0), "и (x0, z0 + шаг)")


## Ветви к дну — только если от киля до сетки дна не больше GROUND_GAP; точка касания чуть над дном, в осях корабля.
func test_ground_contact() -> void:
	var x := 10.0
	var z := 30.0
	var floor_y := Seabed.mesh_height(x, z + Zap.KEEL.z)
	var near_xf := Transform3D(Basis(), Vector3(x, floor_y - Zap.KEEL.y + 1.4, z))
	var c := Zap.ground_contact(near_xf)
	ok(c != Vector3.INF, "киль в 1,4 м от дна — касание")
	near(c.y, Zap.KEEL.y - 1.4 + Zap.GROUND_LIFT, 1e-3, "точка над дном на GROUND_LIFT")
	near(c.z, Zap.KEEL.z, 1e-4, "под килем")
	var far_xf := Transform3D(Basis(), Vector3(x, floor_y - Zap.KEEL.y + Zap.GROUND_GAP + 0.5, z))
	eq(Zap.ground_contact(far_xf), Vector3.INF, "дальше 3 м — ветвей нет")
	eq(Zap.card_strips(Vector3.INF).size(), 1, "без дна — только дуга у окна")
	var strips := Zap.card_strips(c)
	eq(strips.size(), 5, "окно, три ветви, искра")
	var arr := Zap.card_arrays(strips)
	eq((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 30, "по два треугольника на полосу")
	near((arr[Mesh.ARRAY_COLOR] as PackedColorArray)[29].r, float(Zap.Card.SPARK), 1e-6, "вид — в COLOR.r")


## Карточки в сцене: скрыты до разряда, видны 0,8 с, на «Экономно» нет; у дна — ветви.
func test_scene_cards() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(0.05)
	ok(not main.hull.zap_cards.visible, "до разряда карточек нет")
	main.fire_zap()
	main.step(0.1)
	ok(main.hull.zap_cards.visible, "в разряде видны")
	var mat := main.hull.zap_cards.material_override as ShaderMaterial
	near(float(mat.get_shader_parameter("zap_t")), 0.1, 0.02, "время разряда в шейдере")
	var verts: int = (main.hull.zap_cards.mesh as ArrayMesh).surface_get_array_len(0)
	var gap := main.ship.global_transform * Zap.KEEL
	var touching := gap.y - Seabed.mesh_height(gap.x, gap.z) <= Zap.GROUND_GAP
	eq(verts, 30 if touching else 6, "ветви — по зазору до дна")
	for i in 9:
		main.step(0.1)
	ok(not main.hull.zap_cards.visible, "через секунду скрыты")
	main.hull.set_relief(false)
	main.zap.last = -99.0
	main.fire_zap()
	main.step(0.1)
	ok(not main.hull.zap_cards.visible, "«Экономно» — без карточек")
	main.queue_free()
	await frames(1)
