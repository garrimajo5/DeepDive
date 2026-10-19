class_name SonarView
extends MeshInstance3D
## Голограмма сонара над голостолом: круг Ø 2,04 м на столе (шейдер shaders/sonar_holo.gdshader),
## карта рельефа — Sonar.bathymetry() один раз при запуске.

const TOP_Y := 0.93   ## над краем корпуса голостола (0,9 м)

var mat: ShaderMaterial
static var _map: ImageTexture


func _ready() -> void:
	name = "Голограмма сонара"
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.04, 2.04)
	mesh = pm
	position = Vector3(0, TOP_Y, BridgeProps.TABLE_Z)
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/sonar_holo.gdshader")
	if _map == null:   # карта одна на все запуски сцены: считать её ~1 с
		_map = ImageTexture.create_from_image(Sonar.bathymetry())
	mat.set_shader_parameter("map_tex", _map)
	mat.set_shader_parameter("map_size", Sonar.MAP_SIZE)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = OceanView.LAYER_SHIP


## Каждый кадр: где корабль, сколько прошло с импульса, отметки.
func show_state(s: Sonar, ship_pos: Vector3, yaw: float, t: float, powered: bool) -> void:
	mat.set_shader_parameter("ship_xz", Vector2(ship_pos.x, ship_pos.z))
	mat.set_shader_parameter("ship_yaw", yaw)
	mat.set_shader_parameter("range_m", s.range_m)
	mat.set_shader_parameter("ping_age", t - s.ping_time)
	mat.set_shader_parameter("brightness", 1.0 if powered else 0.25)
	var a := s.blip_alpha(t)
	var data := PackedVector4Array()
	var cols := PackedVector3Array()
	for b in s.blips:
		var p: Vector3 = b["pos"]
		var c: Color = b["color"]
		data.append(Vector4(p.x, p.z, 0.035, a))
		cols.append(Vector3(c.r, c.g, c.b))
	data.resize(Sonar.MAX_BLIPS)
	cols.resize(Sonar.MAX_BLIPS)
	mat.set_shader_parameter("blip_count", s.blips.size())
	mat.set_shader_parameter("blips", data)
	mat.set_shader_parameter("blip_cols", cols)
