class_name GateView
extends Node3D
## Арка террасы врат 07 — модель MOD-023 (`GateArch.MODEL`, встройка #1757) и три временные чаши гнёзд
## (`GateArch.nests_mesh`, до переноса гнёзд `GateDiag.NESTS` на места модели). Модель стоит pivot-ом на полу жёлоба
## в середине террасы (`EcoGate.CENTER`, `GateArch.floor_y`), подход с +Z — как в файле.
## Слой отмели (`OceanView.LAYER_WORLD`): её освещает свет сквозь лёд и прожектор.
## Материалы модели заменены своим шейдером с её же картами (`shaders/gate_arch.gdshader`): туман — слоями воды
## ART-069 (`OceanView.add_layer_mat`), со штатным туманом арка вдали темнее воды вокруг и видна со старта силуэтом.
## LOD — по расстоянию (`visibility_range_*`, отрезки `GateArch.ranges`), «Экономно» — `set_lite` (без LOD0).
## Створки `Stvorka0…2` и табличка `Diagnostika` скрыты: контактная группа модели у правой опоры (y 0,2…6 м от пола)
## сейчас под восточным склоном жёлоба — вопрос уровням в #1757; покажутся вместе с гнёздами.

const SHADER := preload("res://shaders/gate_arch.gdshader")
const LODS: Array[String] = ["LOD0", "LOD1", "LOD2"]
const HIDDEN: Array[String] = ["Stvorka0", "Stvorka1", "Stvorka2", "Diagnostika"]

var model: Node3D
var nests: MeshInstance3D
var mats: Array[ShaderMaterial] = []
var lite := false
var _by_name := {}   ## имя материала модели → наш материал (один на все LOD)


func _init() -> void:
	name = "Арка врат"
	model = (load(GateArch.MODEL) as PackedScene).instantiate()
	model.name = "Модель"
	model.position = Vector3(EcoGate.CENTER.x, GateArch.floor_y(), EcoGate.CENTER.y)
	add_child(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.layers = OceanView.LAYER_WORLD
		mi.set_surface_override_material(0, _model_mat(mi.mesh.surface_get_material(0) as StandardMaterial3D))
	for n in HIDDEN:
		var h := model.get_node_or_null(n) as Node3D
		if h:
			h.visible = false
	nests = MeshInstance3D.new()
	nests.name = "Чаши гнёзд"
	nests.layers = OceanView.LAYER_WORLD
	nests.mesh = GateArch.nests_mesh()
	var nm := _mat(GateArch.NEST_COLOR, 0.7)
	mats.append(nm)
	nests.set_surface_override_material(0, nm)
	add_child(nests)
	set_lite(false)


## Под OceanView — слои воды и туман от неё (раз; повторный вход в дерево не задваивает).
func _enter_tree() -> void:
	var o := get_parent() as OceanView
	if o:
		for m in mats:
			o.add_layer_mat(m)


## Отрезки LOD по уровню графики: «Экономно» — без LOD0.
func set_lite(on: bool) -> void:
	lite = on
	for i in LODS.size():
		var root := model.get_node_or_null(LODS[i])
		if root == null:
			continue
		var r := GateArch.ranges(i, on)
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			mi.visible = r.x >= 0.0
			mi.visibility_range_begin = maxf(r.x, 0.0)
			mi.visibility_range_end = maxf(r.y, 0.0)
			mi.visibility_range_begin_margin = GateArch.LOD_MARGIN if r.x > 0.0 else 0.0
			mi.visibility_range_end_margin = GateArch.LOD_MARGIN if r.y > 0.0 else 0.0


## Сетки LOD i (0…2).
func lod_meshes(i: int) -> Array:
	return model.get_node(LODS[i]).find_children("*", "MeshInstance3D", true, false)


## Материал модели → свой шейдер с теми же картами; один на имя (LOD и створки делят материал).
func _model_mat(src: StandardMaterial3D) -> ShaderMaterial:
	if src == null:
		return null
	var key := src.resource_name
	if _by_name.has(key):
		return _by_name[key]
	var m := _mat(Color(src.albedo_color.r, src.albedo_color.g, src.albedo_color.b), src.roughness)
	if src.albedo_texture:
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
	if src.normal_enabled and src.normal_texture:
		m.set_shader_parameter("normal_tex", src.normal_texture)
		m.set_shader_parameter("normal_k", src.normal_scale)
	if src.roughness_texture:
		m.set_shader_parameter("orm_tex", src.roughness_texture)
	if src.emission_enabled:
		var e := src.emission * src.emission_energy_multiplier
		m.set_shader_parameter("glow", Color(e.r, e.g, e.b))
		if src.emission_texture:
			m.set_shader_parameter("glow_tex", src.emission_texture)
	_by_name[key] = m
	mats.append(m)
	return m


static func _mat(c: Color, rough: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("rough", rough)
	return m
