class_name GateView
extends MeshInstance3D
## Временная арка террасы врат 07 и три чаши гнёзд (#826, часть 2; геометрия — `GateArch`) до модели MOD-023 (#999).
## Слой отмели (`OceanView.LAYER_WORLD`): её освещает свет сквозь лёд и прожектор. Минерал матовый, без свечения.


func _init() -> void:
	name = "Арка врат"
	layers = OceanView.LAYER_WORLD
	mesh = GateArch.mesh()
	set_surface_override_material(0, _mat(GateArch.MINERAL, 0.85))
	set_surface_override_material(1, _mat(GateArch.NEST_COLOR, 0.7))


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
