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


func test_scene_heroes_cast_shadows() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(0.1)
	var ev: EcoView = main.eco
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
	ok(main.ocean.sun.shadow_enabled, "свет сквозь лёд даёт тени")
	print("  узлов мира с тенью: %d" % list.size())
	main.queue_free()
	await frames(1)
