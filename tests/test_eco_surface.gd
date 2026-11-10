extends TestCase
## Матовость и влажность тел живого мира (Б2): шероховатость и блик по тому, из чего тело; только числа —
## шейдеры те же.


func test_kinds_read_as_materials() -> void:
	var k := EcoSurface.KINDS
	for name in k:
		var v: Vector2 = k[name]
		ok(v.x > 0.0 and v.x <= 1.0 and v.y >= 0.0 and v.y <= 1.0, "%s: числа в 0…1" % name)
	ok(k["панцирь"].x < k["камень"].x and k["панцирь"].y > k["камень"].y, "мокрый панцирь блестит ярче камня")
	ok(k["студень"].x > k["кожа"].x and k["студень"].x < k["губка"].x, "студень матово-влажный: между кожей и губкой")
	ok(k["стекло"].x < k["чешуя"].x, "оболочка стеклоуста — глаже всех")
	for who in EcoSurface.TABLE:
		for gi in EcoSurface.TABLE[who]:
			ok(k.has(EcoSurface.TABLE[who][gi]), "%s / %s: поверхность из KINDS" % [who, gi])
	eq(EcoSurface.kind_of("Кольчужник", "Клешни"), "панцирь", "сетка по имени")
	eq(EcoSurface.kind_of("Серпохвосты", "telo"), "кожа", "прочие сетки вида — по «*»")
	eq(EcoSurface.kind_of("Гротовик", "Огоньки"), "", "без строки — не трогаем")
	eq(EcoSurface.kind_of("Кости левиафана", "x"), "", "места держат свои числа")


func test_put_only_numbers() -> void:
	var lit := StandardMaterial3D.new()
	var key := ShaderKey.of(lit)
	ok(EcoSurface.put(lit, Vector2(0.35, 0.6)), "освещаемое тело тронуто")
	near(lit.roughness, 0.35, 1e-6, "шероховатость")
	near(lit.metallic_specular, 0.6, 1e-6, "блик")
	eq(ShaderKey.of(lit), key, "шейдер тот же")
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ok(not EcoSurface.put(glow, Vector2(0.1, 0.9)) and glow.roughness == 1.0, "огонёк без света не тронут")
	var stone := EcoShaders.stone(Color.RED, 0.3, 0.95, 0.15)
	ok(EcoSurface.put(stone, Vector2(0.8, 0.25)), "общий шейдер с rough/spec")
	eq(EcoSurface.read(stone), Vector2(0.8, 0.25), "uniform записаны")
	var own := ShaderMaterial.new()
	own.shader = EcoShaders.shader("shader_type spatial;\nvoid fragment() { ALBEDO = vec3(1.0); }\n")
	ok(not EcoSurface.put(own, Vector2(0.5, 0.5)), "чужой шейдер без uniform не тронут")
	for code in [FishView.SHADER, GrazerView.SHADER, RayView.SHADER]:
		ok(code.contains("uniform float rough") and code.contains("uniform float spec")
				and code.contains("ROUGHNESS = rough;") and code.contains("SPECULAR = spec;"),
				"свои шейдеры светляков, скребунов, ледокрыла берут rough/spec")


func test_scene_species_surfaces() -> void:
	var ev := EcoView.new()
	tree.root.add_child(ev)
	await frames(1)
	_check(ev, "при сборке")
	# дно сменилось — нора, скальник, логова собраны заново, числа вернулись
	ev.ground = func(_x: float, _z: float) -> float: return -40.0
	_check(ev, "после пересборки по дну")
	near(ev.skalnik_view.material.roughness, EcoSurface.KINDS["камень"].x, 1e-6, "скальник — живой камень")
	ev.queue_free()
	await frames(1)


func _check(ev: EcoView, when: String) -> void:
	for who in EcoSurface.TABLE:
		var node := ev.find_child(who, false, false)
		ok(node != null, "%s в мире" % who)
		if node == null:
			continue
		var gis: Array = [node] if node is GeometryInstance3D else []
		gis.append_array(node.find_children("*", "GeometryInstance3D", true, false))
		var seen := {}
		var n := 0
		for gi in gis:
			var kind := EcoSurface.kind_of(who, String(gi.name))
			if kind == "":
				continue
			for m in EcoRim.materials(gi as GeometryInstance3D):
				var v := EcoSurface.read(m)
				if v.x < 0.0 or (m is BaseMaterial3D \
						and (m as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED):
					continue
				ok(v.distance_to(EcoSurface.KINDS[kind]) < 1e-5,
						"%s / %s — %s (%s): %s" % [who, gi.name, kind, when, v])
				seen[String(gi.name)] = true
				n += 1
		ok(n > 0, "%s: тело с числами найдено (%s)" % [who, when])
		for gi_name in EcoSurface.TABLE[who]:
			if gi_name != "*":
				ok(seen.has(gi_name), "%s / %s: сетка есть в мире (%s)" % [who, gi_name, when])
