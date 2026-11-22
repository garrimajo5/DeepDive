extends TestCase
## Тени живого мира (Б1): «герои» и места-ориентиры отбрасывают тень света сквозь лёд, фон, стаи и прозрачное — нет.


func test_cast_switch() -> void:
	var mi := MeshInstance3D.new()
	EcoShadows.cast(mi, false)
	eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "погашена")
	EcoShadows.cast(mi)
	eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "включена")
	eq(EcoShadows.casters(mi).size(), 1, "узел с тенью найден")
	mi.free()


## Вид или место (прямой ребёнок EcoView), которому принадлежит узел.
func _owner_name(ev: EcoView, n: Node) -> String:
	while n != null and n.get_parent() != ev:
		n = n.get_parent()
	return String(n.name) if n != null else ""


## Прозрачный или без света материал — не должен отбрасывать тень.
func _see_through(m: Material) -> bool:
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
				or b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		var code := (m as ShaderMaterial).shader.code
		return code.contains("unshaded") or code.contains("blend_add") or code.contains("ALPHA")
	return false


func _materials(gi: GeometryInstance3D) -> Array[Material]:
	var out: Array[Material] = []
	if gi.material_override:
		out.append(gi.material_override)
		return out
	var mesh: Mesh = null
	if gi is MeshInstance3D:
		mesh = (gi as MeshInstance3D).mesh
	elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
		mesh = (gi as MultiMeshInstance3D).multimesh.mesh
	if mesh:
		for s in mesh.get_surface_count():
			var m: Material = gi.get_surface_override_material(s) if gi is MeshInstance3D else null
			if m == null:
				m = mesh.surface_get_material(s)
			if m:
				out.append(m)
	return out


## Живой мир без корабля (#1350): тени ставят сами виды, Main для проверки не нужен. Тени света сквозь лёд в
## сцене (`ocean.sun.shadow_enabled`) проверяет test_graphics.
func _world() -> EcoView:
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height   # как в игре (#1386)
	tree.root.add_child(ev)
	await frames(1)
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(0, -30, 0)
	ev.step(0.1, ship)
	return ev


func test_scene_heroes_cast_shadows() -> void:
	var ev: EcoView = await _world()
	var list := EcoShadows.casters(ev)
	var seen := {}
	for gi in list:
		var who := _owner_name(ev, gi)
		ok(who in EcoShadows.HEROES, "тень только у героев и мест: %s (%s)" % [gi.name, who])
		seen[who] = true
		ok(gi.layers & OceanView.LAYER_WORLD, "%s — на слое отмели (свет сквозь лёд)" % gi.name)
		for m in _materials(gi):
			ok(not _see_through(m), "%s / %s: прозрачное и огоньки без тени" % [who, gi.name])
	for who in EcoShadows.HEROES:
		ok(seen.has(who), "%s отбрасывает тень" % who)
	ok(list.size() <= EcoShadows.BUDGET, "узлов с тенью %d ≤ %d" % [list.size(), EcoShadows.BUDGET])
	ok(not ev.grot_view.glow in list, "огоньки гротовика без тени")
	ok(not ev.krab_view.spines in list, "иглы кольчужника без тени")
	ok(not ev.skalnik_view.carry in list, "добыча скальника без тени")
	print("  узлов мира с тенью: %d" % list.size())
	ev.queue_free()
	await frames(1)


## Места-ориентиры из камня (Б1): порода курильщика 02 и Каменный цветок 01 отбрасывают тень, пузыри и марево
## курильщика — нет (прозрачные).
func test_scene_landmarks_cast_shadows() -> void:
	var ev: EcoView = await _world()
	var vent: VentView = ev.find_child("Чёрный курильщик", false, false)
	var flower: FlowerView = ev.find_child("Каменный цветок", false, false)
	ok(vent != null and flower != null, "курильщик и Каменный цветок в сцене")
	if vent and flower:
		var list := EcoShadows.casters(ev)
		ok(vent.rock in list, "порода курильщика отбрасывает тень")
		ok(not vent.bubbles in list, "пузыри курильщика без тени")
		ok(not vent.haze in list, "марево курильщика без тени")
		ok(flower in list, "Каменный цветок отбрасывает тень")
	ev.queue_free()
	await frames(1)


## Флора (Б1): риф (огнецвет), ленты ленточника, листья и моллюски волнолиста отбрасывают тень — «сидят» на дне;
## мелочь (ежи рощ) и муть — без тени. У колодца 05 отбрасывать нечему: трещина и столб света прозрачные, мох
## светится (EcoShaders.MOSS — unshaded).
func test_scene_flora_casts_shadows() -> void:
	var ev: EcoView = await _world()
	var list := EcoShadows.casters(ev)
	var kelp: KelpView = ev.find_child("Ленточник", false, false)
	var fern: FernView = ev.find_child("Волнолист", false, false)
	var coral: CoralView = ev.find_child("Огнецвет", false, false)
	ok(kelp != null and fern != null and coral != null, "ленточник, волнолист и огнецвет в сцене")
	if kelp and fern and coral:
		ok(kelp.stalks in list, "ленты ленточника отбрасывают тень")
		ok(not kelp.bodies in list, "ежи рощ — без тени (мелочь)")
		ok(not kelp.dust_view in list, "муть ленточника без тени")
		ok(fern.leaves in list, "листья волнолиста отбрасывают тень")
		ok(fern.shells in list, "моллюски волнолиста отбрасывают тень")
		ok(not fern.dust_view in list, "муть волнолиста без тени")
		ok(coral in list, "огнецвет рифа отбрасывает тень")
		ok(not coral.dust_view in list, "муть огнецвета без тени")
	ev.queue_free()
	await frames(1)
