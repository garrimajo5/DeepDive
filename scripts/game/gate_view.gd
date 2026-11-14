class_name GateView
extends Node3D
## Арка террасы врат 07 — модель MOD-023 (`GateArch.MODEL`, встройка #1757) с контактной группой у правой опоры:
## гнёзда под створками `Stvorka0…2` (их читает диагностика, `GateDiag.NESTS`) и табличка `Diagnostika` — перед
## ними карман в склоне жёлоба (`Seabed.Layer.nest_pocket`). Модель стоит pivot-ом на полу жёлоба
## в середине террасы (`EcoGate.CENTER`, `GateArch.floor_y`), подход с +Z — как в файле.
## Слой отмели: её освещает свет сквозь лёд и прожектор; тело арки — `OceanView.LAYER_NOBEAM` (без тени прожектора).
## Материалы модели заменены своим шейдером с её же картами (`shaders/gate_arch.gdshader`): туман — слоями воды
## ART-069 (`OceanView.add_layer_mat`), со штатным туманом арка вдали темнее воды вокруг и видна со старта силуэтом.
## LOD — по расстоянию (`visibility_range_*`, отрезки `GateArch.ranges`), «Экономно» — `set_lite` (без LOD0).
## Створку гнезда поднимает купольник: `set_petal(i, k)` — поворот узла створки вокруг своей оси X
## (`GateArch.PETAL_TURN`), долю ставит `Main` по `EcoLink.petal_lift` и знанию `LayerLore.PETAL07`.
## Створки и табличка — вне LOD модели: дальше `GateArch.DETAIL_END` не рисуются.

const SHADER := preload("res://shaders/gate_arch.gdshader")
const LODS: Array[String] = ["LOD0", "LOD1", "LOD2"]
const PETALS: Array[String] = ["Stvorka0", "Stvorka1", "Stvorka2"]
const PLATE := "Diagnostika"

var model: Node3D
var petals: Array[MeshInstance3D] = []   ## створки гнёзд по номерам `GateDiag.NESTS`
var plate: MeshInstance3D                ## табличка диагностики
var mats: Array[ShaderMaterial] = []
var petal_mat: ShaderMaterial          ## минерал створок — темнее опоры (#1757)
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
	# Тело арки — двусторонняя сетка (glTF doubleSided): в карту теней прожектора не идёт — в луче она затеняла сама
	# себя рваными чёрными треугольниками (#1757, кадр `37`). Тень от света сквозь лёд остаётся; створки и табличка
	# (односторонние, малые) тень прожектора бросают, как раньше.
	for i in LODS.size():
		for mi: MeshInstance3D in lod_meshes(i):
			mi.layers = OceanView.LAYER_NOBEAM
	for n in PETALS:
		petals.append(model.get_node(n) as MeshInstance3D)
	plate = model.get_node(PLATE) as MeshInstance3D
	# Створки — свой материал: тот же минерал, тон темнее опоры (`GateArch.PETAL_TONE…`, #1757).
	petal_mat = (petals[0].get_surface_override_material(0) as ShaderMaterial).duplicate()
	petal_mat.set_shader_parameter("tone", GateArch.PETAL_TONE)
	petal_mat.set_shader_parameter("tone_in", GateArch.PETAL_TONE_IN)
	petal_mat.set_shader_parameter("rough", GateArch.PETAL_ROUGH)
	mats.append(petal_mat)
	for mi in petals:
		mi.set_surface_override_material(0, petal_mat)
	for mi: MeshInstance3D in petals + [plate]:
		mi.visibility_range_end = GateArch.DETAIL_END
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
			mi.visibility_range_begin_margin = 0.0
			mi.visibility_range_end_margin = 0.0


## Створка гнезда i поднята на долю k (0 — закрыта, 1 — открыта).
func set_petal(i: int, k: float) -> void:
	var x := GateArch.PETAL_TURN * clampf(k, 0.0, 1.0)
	if petals[i].rotation.x != x:
		petals[i].rotation.x = x


func petal(i: int) -> float:
	return petals[i].rotation.x / GateArch.PETAL_TURN


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
