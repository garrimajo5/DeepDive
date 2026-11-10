class_name SearchlightView
extends Node3D
## Прожектор под носом корабля (Searchlight): свет SpotLight3D на отмель и видимый конус луча в воде.
## Стоит дочерним к кораблю в Searchlight.LAMP, смотрит вперёд (−Z) и вниз на Searchlight.pitch_deg().
## Освещает только отмель (слой 1): мостик изнутри светом прожектора не заливается.

var spot: SpotLight3D
var beam: MeshInstance3D
var on := true
var lit := true        ## свет горит: без него у света энергия Searchlight.DARK, но сам SpotLight3D в сцене (issue #159)
var flicker := 1.0     ## мигание вместе с плафонами (set_flicker)


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
	# ART-062: маска пятна отражателя — проектор; в 4.7.2 он работает только с тенями, кастеры — мир (не мостик)
	spot.light_projector = load(Searchlight.MASK)
	spot.shadow_enabled = true
	spot.shadow_caster_mask = OceanView.LAYER_WORLD
	spot.shadow_normal_bias = Searchlight.SHADOW_NORMAL_BIAS   # без полос «акне» на склоне (#489)
	add_child(spot)
	beam = MeshInstance3D.new()
	beam.name = "Луч прожектора"
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Searchlight.beam_arrays())
	beam.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/beam.gdshader")
	m.set_shader_parameter("beam_color", Searchlight.BEAM_COLOR)
	m.set_shader_parameter("field", load(Searchlight.FIELD))
	m.set_shader_parameter("density_base", Searchlight.DENSITY_BASE)
	m.set_shader_parameter("drift", Searchlight.DRIFT)
	m.set_shader_parameter("beam_length", Searchlight.BEAM_LENGTH)
	m.set_shader_parameter("animate", 1.0)
	m.set_shader_parameter("silt_dim", 0.0)
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.layers = OceanView.LAYER_WORLD
	add_child(beam)
	apply(on, 1.0)


## Включён ли и сколько энергии (доля «Прожектор» реактора, 1 — штатно).
## reach — доля длины луча (ил рассеивает свет, Silt.beam_k).
var _k := -1.0      ## сила, по которой записаны дальность и конус (#852)
var _reach := -1.0
var _dim := -1.0


func apply(is_on: bool, k: float, reach: float = 1.0) -> void:
	on = is_on
	lit = Searchlight.lit(is_on, k)
	# Свет не прячем, а гасим энергией: Compatibility собирает шейдер каждого материала отдельно для «есть прожектор»
	# и «нет прожектора» (набор огней на предмете). Спрятанный свет — второй набор: на телефоне сборка шейдеров при
	# гашении прожектора и лишние кадры прогрева на старте (issue #159). С энергией DARK набор огней один.
	spot.visible = true
	beam.visible = lit
	_energy()
	# дальность, размер конуса и плотность — только при изменении (#852): запись дальности обновляет свет,
	# а с ним и его тень, даже когда корабль стоит
	if lit and (not is_equal_approx(k, _k) or not is_equal_approx(reach, _reach)):
		_k = k
		_reach = reach
		var s := Searchlight.scale(k)
		spot.spot_range = Searchlight.range_m(k) * reach
		beam.scale = Vector3(s, s, s) * reach
	var dim := Searchlight.SILT_DIM * Searchlight.silt_k(reach)   # ил укоротил луч — плотность, не длина (ART-062)
	if not is_equal_approx(dim, _dim):
		_dim = dim
		beam_mat().set_shader_parameter("silt_dim", dim)


func beam_mat() -> ShaderMaterial:
	return beam.material_override as ShaderMaterial


## «Экономно» (ART-044): та же маска пятна, луч — поле без дрейфа.
func set_lite(lite: bool) -> void:
	beam_mat().set_shader_parameter("animate", 0.0 if lite else 1.0)


## Прожектор мигает вместе с плафонами (js/ship.js: spot.intensity × fl): свет × k, конус луча не трогаем.
func set_flicker(k: float) -> void:
	flicker = k
	_energy()


func _energy() -> void:
	var e := Searchlight.ENERGY * flicker if lit else Searchlight.DARK
	if not is_equal_approx(e, spot.light_energy):
		spot.light_energy = e
