class_name GateView
extends MeshInstance3D
## Временная арка террасы врат 07 и три чаши гнёзд (#826, часть 2; геометрия — `GateArch`) до модели MOD-023 (#999).
## Слой отмели (`OceanView.LAYER_WORLD`): её освещает свет сквозь лёд и прожектор. Минерал матовый, без свечения.
## Туман — слоями воды ART-069 (`shaders/gate_arch.gdshader`, материалы в `OceanView.add_layer_mat`): со штатным
## туманом арка вдали темнее воды вокруг и видна со старта силуэтом.

const SHADER := preload("res://shaders/gate_arch.gdshader")

var mats: Array[ShaderMaterial] = []


func _init() -> void:
	name = "Арка врат"
	layers = OceanView.LAYER_WORLD
	mesh = GateArch.mesh()
	mats = [_mat(GateArch.MINERAL, 0.85), _mat(GateArch.NEST_COLOR, 0.7)]
	for i in mats.size():
		set_surface_override_material(i, mats[i])


## Под OceanView — слои воды и туман от неё (раз; повторный вход в дерево не задваивает).
func _enter_tree() -> void:
	var o := get_parent() as OceanView
	if o:
		for m in mats:
			o.add_layer_mat(m)


static func _mat(c: Color, rough: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("rough", rough)
	return m
