extends TestCase
## Ободковый (френель) свет героев живого мира (Б2): края тел ловят свет — силуэты читаются в полумраке;
## новых шейдеров нет, «Экономно» гасит ободок числом.


func test_rim_material() -> void:
	EcoRim.set_lite(false)
	var lit := StandardMaterial3D.new()
	ok(EcoRim.rim(lit), "освещаемое тело — с ободком")
	ok(lit.rim_enabled, "флаг ободка включён")
	near(lit.rim, EcoRim.STRENGTH, 1e-6, "сила ободка")
	near(lit.rim_tint, EcoRim.TINT, 1e-6, "доля цвета тела")
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ok(not EcoRim.rim(glow) and not glow.rim_enabled, "огонёк без света — без ободка")
	var see := StandardMaterial3D.new()
	see.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ok(not EcoRim.rim(see) and not see.rim_enabled, "прозрачное — без ободка")
	var other := EcoShaders.stone(Color.RED, 0.3, 0.9, 0.2)
	ok(not EcoRim.rim(other), "чужой шейдер без uniform rim не тронут")


func test_lite_keeps_shader() -> void:
	EcoRim.set_lite(false)
	var lit := StandardMaterial3D.new()
	EcoRim.rim(lit)
	var key := ShaderKey.of(lit)
	var own := ShaderMaterial.new()
	own.shader = EcoShaders.shader(RayView.SHADER)
	ok(EcoRim.rim(own), "шейдер ледокрыла берёт ободок")
	EcoRim.set_lite(true)
	near(lit.rim, 0.0, 1e-6, "«Экономно» — ободок погашен")
	near(float(own.get_shader_parameter("rim")), 0.0, 1e-6, "и у своего шейдера")
	eq(ShaderKey.of(lit), key, "шейдер тот же — меняется только число")
	ok(lit.rim_enabled, "флаг не снят (иначе пересборка)")
	EcoRim.set_lite(false)
	near(lit.rim, EcoRim.STRENGTH, 1e-6, "вернулся")
	near(float(own.get_shader_parameter("rim")), EcoRim.STRENGTH, 1e-6, "и у ледокрыла")


func test_scene_heroes_have_rim() -> void:
	EcoRim.set_lite(false)
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(0.1)
	var ev: EcoView = main.eco
	for who in EcoRim.CREATURES:
		var hero := ev.find_child(who, false, false)
		ok(hero != null, "%s в мире" % who)
		var n := 0
		for gi in EcoShadows.casters(hero):
			for m in EcoRim.materials(gi):
				if m is BaseMaterial3D:
					ok((m as BaseMaterial3D).rim_enabled, "%s / %s — ободок" % [who, gi.name])
					n += 1
				elif m is ShaderMaterial and EcoRim.has_uniform(m as ShaderMaterial):
					near(float((m as ShaderMaterial).get_shader_parameter("rim")), EcoRim.STRENGTH, 1e-6,
							"%s / %s — ободок в шейдере" % [who, gi.name])
					n += 1
		ok(n > 0, "%s: тело с ободком найдено" % who)
	# нора и скальник собираются заново вместе с дном — ободок возвращается
	ev.ground = func(_x: float, _z: float) -> float: return -40.0
	var m: BaseMaterial3D = ev.skalnik_view.material
	ok(m.rim_enabled, "скальник после пересборки — с ободком")
	ok(not ev.grot_view.glow.mesh.surface_get_material(0).rim_enabled, "огоньки гротовика без ободка")
	# прочие освещаемые тела — тот же флаг (иначе шейдеры раздвоятся), сила слабее
	var spikes := ev.find_child("Шипоежи", true, false) as GeometryInstance3D
	ok(spikes != null, "шипоежи найдены")
	for mat in EcoRim.materials(spikes):
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
			ok((mat as BaseMaterial3D).rim_enabled, "шипоежи — флаг ободка")
			near((mat as BaseMaterial3D).rim, EcoRim.SOFT, 1e-6, "у не-героя ободок слабее")
	near(m.rim, EcoRim.STRENGTH, 1e-6, "у героя — сильный")
	var plain := 0
	for gi in ev.find_children("*", "GeometryInstance3D", true, false):
		for mat in EcoRim.materials(gi as GeometryInstance3D):
			var b := mat as BaseMaterial3D
			if b and b.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
					and b.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not b.rim_enabled:
				plain += 1
	eq(plain, 0, "все освещаемые непрозрачные тела мира — с флагом ободка")
	ev.set_lite(true)
	near(m.rim, 0.0, 1e-6, "EcoView.set_lite гасит ободок")
	ok(EcoShaders.sway_lite, "и колыхание флоры")
	ev.set_lite(false)
	main.queue_free()
	await frames(1)
