class_name EcoRim
## Ободковый (френель) свет живого мира (Б2, `docs/grafika-plan-eco.md`): у «героев» края тела по касательной
## к взгляду ловят свет сквозь лёд и прожектор — силуэт читается в полумраке глубины. Приём — встроенный ободок
## света Godot (`RIM`/`RIM_TINT`): считается от каждого огня, поэтому в темноте ободка нет, а под лучом он вспыхивает.
## Новых шейдеров не прибавляет: флаг стоит у всех освещаемых непрозрачных тел мира (иначе материалы с одними
## флагами раздвоились бы — +3 шейдера), а сила — число: у героев ярче, у прочих слабее. Свои шейдеры героев
## (ледокрыл) берут uniform `rim`/`rim_tint`. «Экономно» — `set_lite(true)`: сила в ноль, шейдер тот же
## (смена флага — пересборка шейдера на телефоне). Проверяет `tests/test_eco_rim.gd`.

## Существа-герои (имена узлов EcoView) — ободок ярче. Места-ориентиры (кости, раковина) — камень, без ободка.
const CREATURES: Array[String] = ["Серпохвосты", "Ледокрылы", "Гротовик", "Скальник", "Кольчужник", "Эхоловец"]
## Сила ободка героя и прочих тел (0…1), доля цвета тела в нём (0 — цвет огня, 1 — цвет тела).
const STRENGTH := 0.4
const SOFT := 0.15
const TINT := 0.35

static var lite := false
## Тронутые материалы: [слабая ссылка, сила без «Экономно»].
static var _mats: Array = []


## Включить ободок под root (EcoView): всем освещаемым непрозрачным телам слабый, героям — сильный (их тела, что
## отбрасывают тень). Повторный вызов (после пересборки норы и скальника) безопасен.
static func apply(root: Node) -> void:
	_walk(root)
	for c in root.get_children():
		if String(c.name) in CREATURES:
			for gi in EcoShadows.casters(c):
				for m in materials(gi):
					rim(m, STRENGTH)


static func _walk(n: Node) -> void:
	if n is GeometryInstance3D:
		for m in materials(n as GeometryInstance3D):
			rim(m, SOFT)
	for c in n.get_children():
		_walk(c)


## Ободок одному материалу силой k: StandardMaterial3D — флаг и числа, свой шейдер — если в нём есть uniform rim.
## Без света, прозрачное и чужие шейдеры не трогает. Возвращает, тронут ли материал.
static func rim(m: Material, k := STRENGTH) -> bool:
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
				or b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
		b.rim_enabled = true
		b.rim_tint = TINT
	elif m is ShaderMaterial and has_uniform(m as ShaderMaterial):
		(m as ShaderMaterial).set_shader_parameter("rim_tint", TINT)
	else:
		return false
	_put(m, 0.0 if lite else k)
	for e in _mats:
		if e[0].get_ref() == m:
			e[1] = k
			return true
	_mats.append([weakref(m), k])
	return true


static func _put(m: Material, k: float) -> void:
	if m is BaseMaterial3D:
		(m as BaseMaterial3D).rim = k
	elif m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("rim", k)


## Есть ли у шейдера материала uniform ободка.
static func has_uniform(m: ShaderMaterial) -> bool:
	return m.shader != null and m.shader.code.contains("uniform float rim")


## «Экономно»: погасить (или вернуть) ободок у всех героев — меняются только числа.
static func set_lite(on: bool) -> void:
	lite = on
	var alive: Array = []
	for e in _mats:
		var m: Material = e[0].get_ref()
		if m == null:
			continue
		alive.append(e)
		_put(m, 0.0 if on else float(e[1]))
	_mats = alive


## Материалы узла: перекрытие или поверхности меша (с перекрытием поверхности).
static func materials(gi: GeometryInstance3D) -> Array[Material]:
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
			var m: Material = (gi as MeshInstance3D).get_surface_override_material(s) if gi is MeshInstance3D else null
			if m == null:
				m = mesh.surface_get_material(s)
			if m:
				out.append(m)
	return out
