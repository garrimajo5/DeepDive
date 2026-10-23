class_name LockWaterView
extends MeshInstance3D
## Вода в шахте нижнего шлюза по ART-073: одна плоскость 2,2 × 2,2 м (`LockWater`, шейдер `shaders/lock_water.gdshader`,
## карты `textures/shlyuz/`). Узел в осях корабля (ребёнок `RoomsView`), слой корабля, без теней, +1 вызов, пока шлюз
## открыт; закрыт — узел скрыт.

var mat: ShaderMaterial


func _init() -> void:
	name = "Вода шлюза"
	layers = OceanView.LAYER_SHIP
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(LockWater.SIZE, LockWater.SIZE)
	mesh = plane
	position = LockWater.CENTER
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/lock_water.gdshader")
	mat.set_shader_parameter("ripple", load(LockWater.RIPPLE))
	mat.set_shader_parameter("rings", load(LockWater.RINGS))
	var l: Array = LockWater.lamp()
	mat.set_shader_parameter("lamp_pos", (l[0] as Vector3) - LockWater.CENTER)
	mat.set_shader_parameter("lamp_extent", l[1])
	mat.set_shader_parameter("lamp_color", LockWater.LAMP_COLOR)
	material_override = mat
	visible = false


## Каждый кадр: lock_t — открытие крышки, depth — глубина корабля, speed — ход, hull — прочность, lamp_k — мигание.
func apply(w: LockWater, lock_t: float, depth: float, speed: float, hull: float, time: float, lamp_k: float) -> void:
	var k := LockWater.shown(lock_t)
	visible = k > 0.0
	if not visible:
		return
	mat.set_shader_parameter("shown", k)
	mat.set_shader_parameter("water_color", LockWater.color(depth))
	mat.set_shader_parameter("ambient", Seabed.Water.ambient(depth))
	mat.set_shader_parameter("deepness", Seabed.Water.k(depth))
	mat.set_shader_parameter("clock", time)
	mat.set_shader_parameter("amplitude", w.amplitude(speed, hull))
	mat.set_shader_parameter("lamp_k", lamp_k)
	mat.set_shader_parameter("event_age", w.event_age)
	mat.set_shader_parameter("event_kind", float(w.event_kind))
	mat.set_shader_parameter("event_k", w.event_k)
	mat.set_shader_parameter("rope_uv", w.event_uv())
