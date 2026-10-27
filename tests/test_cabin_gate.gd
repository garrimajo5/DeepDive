extends TestCase
## #847: свет кабины, блики, износ и помехи экранов не переписываются каждый кадр, если ничего не сменилось.
## Проверка: «чужое» значение, поставленное между двумя одинаковыми вызовами, остаётся — второй вызов ничего не пишет;
## смена входа — пишет снова.


func test_key_ignores_clock_without_breach() -> void:
	eq(CabinLight.key(-1, 1.0, 0.8), CabinLight.key(-1, 7.5, 0.8), "без аварии часы ритма не важны")
	ok(CabinLight.key(2, 1.0, 0.8) != CabinLight.key(2, 1.1, 0.8), "в аварии ритм идёт — ключ новый")
	ok(CabinLight.key(-1, 0.0, 0.8) != CabinLight.key(-1, 0.0, 0.7), "мигание — ключ новый")


func test_bridge_cabin_and_screens() -> void:
	var v := BridgeView.new()
	tree.root.add_child(v)
	await frames(1)
	v.set_cabin(-1, 0.0, 1.0)
	var e := v.lamps[0].light_energy
	ok(e > 0.0, "огонь горит")
	v.lamps[0].light_energy = 123.0
	v.plafond_mat.emission_energy_multiplier = 77.0
	v.set_cabin(-1, 5.0, 1.0)
	eq(v.lamps[0].light_energy, 123.0, "тот же свет — огонь не переписан")
	eq(v.plafond_mat.emission_energy_multiplier, 77.0, "плафоны не переписаны")
	v.set_cabin(-1, 5.0, 0.5)
	near(v.lamps[0].light_energy, e * 0.5, 1e-4, "мигание — переписан")
	v.set_cabin(0, 1.0, 1.0)
	var a := v.plafond_mat.emission_energy_multiplier
	v.set_cabin(0, 1.0 + CabinLight.PERIOD * 0.25, 1.0)
	ok(v.plafond_mat.emission_energy_multiplier != a, "авария — ритм плафонов идёт каждый кадр")

	v.set_screens(Vector3.ONE, 1.0)
	v.screens_mat.set_shader_parameter("k", Vector3(9, 9, 9))
	v.set_screens(Vector3.ONE, 1.0)
	eq(v.screens_mat.get_shader_parameter("k"), Vector3(9, 9, 9), "экраны без помех — не переписаны")
	v.set_screens(Vector3(0.5, 1, 1), 1.0)
	eq(v.screens_mat.get_shader_parameter("k"), Vector3(0.5, 1, 1), "помеха — переписаны")
	v.queue_free()
	await frames(1)


func test_bridge_glints_and_wear() -> void:
	var v := BridgeView.new()
	tree.root.add_child(v)
	await frames(1)
	var m: ShaderMaterial = v.surface_materials()[0]
	v.set_glints(0.6, Color.WHITE, 1.0)
	near(float(m.get_shader_parameter("glint_k")), 0.6, 1e-5, "сила бликов")
	m.set_shader_parameter("glint_tint", Color.RED)
	v.set_glints(0.6, Color.WHITE, 2.0)
	eq(m.get_shader_parameter("glint_tint"), Color.RED, "тот же оттенок — не переписан")
	near(float(m.get_shader_parameter("glint_time")), 2.0, 1e-5, "часы течения идут, пока блики есть")
	v.set_glints(0.0, Color.WHITE, 3.0)
	near(float(m.get_shader_parameter("glint_k")), 0.0, 1e-5, "блики погасли")
	v.set_glints(0.0, Color.WHITE, 4.0)
	near(float(m.get_shader_parameter("glint_time")), 3.0, 1e-5, "бликов нет — часы не пишем")

	v.set_wear(0.3)
	m.set_shader_parameter("wear_loss", 0.9)
	v.set_wear(0.3)
	near(float(m.get_shader_parameter("wear_loss")), 0.9, 1e-5, "та же потеря — не переписана")
	v.set_wear(0.31)
	near(float(m.get_shader_parameter("wear_loss")), 0.31, 1e-5, "новая потеря — переписана")
	v.queue_free()
	await frames(1)


func test_rooms_cabin_wear_journal() -> void:
	var r := RoomsView.new()
	tree.root.add_child(r)
	await frames(1)
	r.set_cabin(-1, 0.0, 1.0)
	r.lamps[0].light_energy = 55.0
	r.set_cabin(-1, 3.0, 1.0)
	eq(r.lamps[0].light_energy, 55.0, "тот же свет отсеков — не переписан")
	r.set_cabin(-1, 3.0, 0.9)
	ok(r.lamps[0].light_energy != 55.0, "мигание — переписан")

	r.set_journal_k(1.0)
	r.journal_text.modulate = Color.RED
	r.set_journal_k(1.0)
	eq(r.journal_text.modulate, Color.RED, "журнал без помех — не переписан")
	r.set_journal_k(0.5)
	ok(r.journal_text.modulate != Color.RED, "помеха — переписан")

	r.set_wear(0.2)
	var m: ShaderMaterial = null
	for i in r.mesh_instance.mesh.get_surface_count():
		var s := r.mesh_instance.mesh.surface_get_material(i) as ShaderMaterial
		if s:
			m = s
			break
	m.set_shader_parameter("wear_loss", 0.8)
	r.set_wear(0.2)
	near(float(m.get_shader_parameter("wear_loss")), 0.8, 1e-5, "та же потеря — не переписана")
	r.set_wear(0.0)
	near(float(m.get_shader_parameter("wear_loss")), 0.0, 1e-5, "корпус цел — переписана")
	r.queue_free()
	await frames(1)
