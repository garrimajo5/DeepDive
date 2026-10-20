class_name SearchlightView
extends Node3D
## Прожектор под носом корабля (Searchlight): свет SpotLight3D на отмель и видимый конус луча в воде.
## Стоит дочерним к кораблю в Searchlight.LAMP, смотрит вперёд (−Z) и вниз на Searchlight.pitch_deg().
## Освещает только отмель (слой 1): мостик изнутри светом прожектора не заливается.

var spot: SpotLight3D
var beam: MeshInstance3D
var on := true


func _ready() -> void:
	position = Searchlight.LAMP
	rotation_degrees.x = -Searchlight.pitch_deg()
	spot = SpotLight3D.new()
	spot.name = "Свет прожектора"
	spot.light_color = Searchlight.COLOR
	spot.light_energy = Searchlight.ENERGY
	spot.spot_angle = Searchlight.spot_angle_deg()
	# затухание по расстоянию слабое, как у луча в браузере: в Godot 1,0 — почти обратный квадрат,
	# и на 20 м до дна прожектор становился невидим (у тестера в pogrujenie — «луча на дне не видно»)
	spot.spot_attenuation = Searchlight.ATTENUATION
	spot.spot_angle_attenuation = Searchlight.SPOT_EDGE
	spot.light_cull_mask = OceanView.LAYER_WORLD
	add_child(spot)
	beam = MeshInstance3D.new()
	beam.name = "Луч прожектора"
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Searchlight.beam_arrays())
	beam.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/beam.gdshader")
	m.set_shader_parameter("beam_color", Searchlight.BEAM_COLOR)
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.layers = OceanView.LAYER_WORLD
	add_child(beam)
	apply(on, 1.0)


## Включён ли и сколько энергии (доля «Прожектор» реактора, 1 — штатно).
## reach — доля длины луча (ил рассеивает свет, Silt.beam_k).
func apply(is_on: bool, k: float, reach: float = 1.0) -> void:
	on = is_on
	var lit := Searchlight.lit(is_on, k)
	spot.visible = lit
	beam.visible = lit
	if lit:
		var s := Searchlight.scale(k)
		spot.spot_range = Searchlight.range_m(k) * reach
		beam.scale = Vector3(s, s, s) * reach
