extends TestCase
## Общий каркас роёв карточек (#763): `CardSwarm` и виды пара, износа, следа винтов и пробоины на нём.


func test_setup_builds_swarm() -> void:
	var n := MultiMeshInstance3D.new()
	var mat := CardSwarm.material("res://shaders/steam.gdshader", {"tint": Color(0.5, 0.6, 0.7, 1.0)})
	var mm := CardSwarm.setup(n, mat, 12, OceanView.LAYER_SHIP)
	ok(n.multimesh == mm, "MultiMesh у узла")
	eq(n.layers, OceanView.LAYER_SHIP, "слой")
	eq(n.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	eq(mm.instance_count, 12, "предел карточек")
	eq(mm.visible_instance_count, 0, "сначала пусто")
	ok(mm.use_custom_data, "данные кадра в custom")
	eq(mm.transform_format, MultiMesh.TRANSFORM_3D, "3D")
	var q := mm.mesh as QuadMesh
	ok(q != null and q.size == Vector2.ONE, "квадрат 1×1")
	ok(q.material == mat, "материал на квадрате")
	eq(mat.get_shader_parameter("tint"), Color(0.5, 0.6, 0.7, 1.0), "параметры шейдера")
	n.free()


func test_park_one_clear_card() -> void:
	var n := MultiMeshInstance3D.new()
	var mm := CardSwarm.setup(n, CardSwarm.material("res://shaders/wake.gdshader", {}), 4, OceanView.LAYER_WORLD)
	CardSwarm.park(mm, Vector3(1, 2, 3), Vector3.ONE * 0.5)
	eq(mm.visible_instance_count, 1, "одна карточка для прогрева")
	# место и прозрачность карточки headless-сервер не хранит — их видно на снимках steam=1, vent=2, breach=0
	n.free()


func test_views_share_frame() -> void:
	var views: Array = [SteamView.new(), WearDropsView.new(), WakeView.new()]
	var limits := [ValveSteam.LIMIT, WearDrops.COUNT, Wake.LIMIT]
	var layer := [OceanView.LAYER_SHIP, OceanView.LAYER_SHIP, OceanView.LAYER_WORLD]
	for i in views.size():
		var v: MultiMeshInstance3D = views[i]
		eq(v.multimesh.instance_count, limits[i], "%s: предел" % v.name)
		eq(v.layers, layer[i], "%s: слой" % v.name)
		eq(v.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s: без тени" % v.name)
		ok(v.multimesh.use_custom_data, "%s: custom" % v.name)
		ok((v.multimesh.mesh as QuadMesh).material == v.get("mat"), "%s: свой материал" % v.name)
	ok(not views[0].visible and not views[1].visible, "пар и износ скрыты до частиц")
	eq(views[0].multimesh.visible_instance_count, 1, "пустой пар — одна карточка для прогрева")
	eq(views[1].multimesh.visible_instance_count, 1, "пустой износ — одна карточка")
	eq(views[2].multimesh.visible_instance_count, 0, "след до первого шага пуст")
	(views[2] as WakeView).apply(Wake.new(), Vector3(0, -20, 5))
	eq(views[2].multimesh.visible_instance_count, 1, "пустой след — одна карточка у корабля")
	ok(not views[2].visible, "без пузырей скрыт")
	for v in views:
		v.free()


func test_smooth_matches_smoothstep() -> void:
	# ValveSteam и BreachSpray считают огибающие через HashNoise.smooth (раньше — свои копии smoothstep)
	for e in [[0.0, 0.045], [0.55, 1.0], [0.05, 0.70], [0.85, 1.0]]:
		for x in [-0.1, 0.0, 0.02, 0.3, 0.6, 0.9, 1.0, 1.2]:
			near(HashNoise.smooth(e[0], e[1], x), smoothstep(e[0], e[1], x), 1e-12, "smooth %s при %s" % [e, x])
	ok(not ValveSteam.new().has_method("S"), "у ValveSteam нет своей копии")
	ok(not BreachSpray.new().has_method("S"), "у BreachSpray нет своей копии")
