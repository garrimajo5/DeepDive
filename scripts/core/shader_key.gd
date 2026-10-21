class_name ShaderKey
extends RefCounted
## Сколько разных шейдеров собирает сцена (issue #159). Рендерер Compatibility на каждый новый шейдер сразу собирает
## четыре программы (цвет и глубина, с инстансингом и без) и ещё по одной на набор огней — разные материалы с одинаковыми
## флагами делят один шейдер, а каждый лишний флаг (отсечение граней, туман, запись глубины, билборд) — это ~5 программ
## и секунды прогрева на телефоне при первом запуске. Ключ материала — его флаги и наличие текстур, без чисел и цветов:
## материалы с одним ключом делят шейдер. Подписи и картинки (Label3D, Sprite3D) — общий материал по своим флагам.
## Свои материалы корабля — по готовым образцам `glass`, `flakes`, чтобы не плодить шейдеры.


## Ключ шейдера материала: одинаковый ключ — один шейдер.
static func of(m: Material) -> String:
	if m == null:
		return ""
	if m is ShaderMaterial:
		var sh: Shader = (m as ShaderMaterial).shader
		return "shader:" + (sh.resource_path if sh and sh.resource_path != "" else str(sh.get_instance_id() if sh else 0))
	var k := m.get_class()
	for p in m.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE == 0 or p.name in ["render_priority", "resource_local_to_scene", "script"]:
			continue
		if p.type == TYPE_BOOL or p.type == TYPE_INT:
			k += "|%s=%s" % [p.name, m.get(p.name)]
		elif p.type == TYPE_OBJECT and p.hint == PROPERTY_HINT_RESOURCE_TYPE:
			k += "|%s=%s" % [p.name, m.get(p.name) != null]
	return k


## Ключ общего материала подписи или картинки (SpriteBase3D и Label3D делят его по этим флагам).
static func of_label(n: GeometryInstance3D) -> String:
	return "2d|sh=%s|ds=%s|nd=%s|fs=%s|ac=%s|bb=%s|tf=%s" % [n.shaded, n.double_sided, n.no_depth_test,
		n.fixed_size, n.alpha_cut, n.billboard, n.texture_filter]


## Все ключи под узлом root, кроме ветки skip: ключ → имена узлов (первые).
static func collect(root: Node, skip: Node = null) -> Dictionary:
	var out := {}
	_walk(root, skip, out)
	return out


static func _add(out: Dictionary, k: String, who: String) -> void:
	if k == "":
		return
	if not out.has(k):
		out[k] = []
	if out[k].size() < 3:
		out[k].append(who)


static func _walk(n: Node, skip: Node, out: Dictionary) -> void:
	if n == skip:
		return
	if n is SpriteBase3D or n is Label3D:
		_add(out, of_label(n), n.name)
	elif n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		_add(out, of(g.material_override), n.name)
		_add(out, of(g.material_overlay), n.name)
		var mesh: Mesh = null
		if n is MeshInstance3D:
			mesh = (n as MeshInstance3D).mesh
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
			mesh = (n as MultiMeshInstance3D).multimesh.mesh
		elif n is CPUParticles3D:
			mesh = (n as CPUParticles3D).mesh
		if mesh and g.material_override == null:
			for s in mesh.get_surface_count():
				var m: Material = mesh.surface_get_material(s)
				if n is MeshInstance3D and (n as MeshInstance3D).get_surface_override_material(s):
					m = (n as MeshInstance3D).get_surface_override_material(s)
				_add(out, of(m), n.name)
				if m and m.next_pass:
					_add(out, of(m.next_pass), n.name)
	for c in n.get_children():
		_walk(c, skip, out)


## Стекло и подложки: прозрачное без света, обе стороны, без записи глубины и тумана. Окно, подложка итога, брызги.
static func glass(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_fog = true
	m.albedo_color = c
	return m


## Хлопья: прозрачный билборд без света, размер частицы сохраняется. Морской снег, ил.
## mask — маска карточки (ил, ART-048: рваные пятна); без неё — круглая точка (морской снег). Текстура есть всегда,
## чтобы снег и ил оставались одним шейдером.
static func flakes(c: Color, mask: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = mask if mask else dot()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = c
	return m


static var _dot: ImageTexture


## Круглая мягкая точка 16×16 для мелких хлопьев.
static func dot() -> ImageTexture:
	if _dot == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var d := Vector2(x + 0.5 - 8.0, y + 0.5 - 8.0).length() / 8.0
				img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - d) * 2.5, 0.0, 1.0)))
		_dot = ImageTexture.create_from_image(img)
	return _dot
