class_name WearDropsView
extends MultiMeshInstance3D
## Частицы «корабль устал» ART-074 (`WearDrops`): капли у бортов мостика и машинного, искры у пульта энергии, пар над
## вентилем — один MultiMesh в осях корабля (один материал, один вызов), шейдер пара `shaders/steam.gdshader`,
## атлас `textures/ustalost/atlas.png`. Слой корабля, без теней и огней. Корпус ≥ 62 % — узел скрыт.

var mat: ShaderMaterial
var lite := false   ## «Экономно» (ART-044): 12 карточек
var shown := 0      ## сколько карточек видно (для тестов)


func _init() -> void:
	name = "Капли износа"
	layers = OceanView.LAYER_SHIP
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/steam.gdshader")
	mat.set_shader_parameter("atlas", load(WearDrops.ATLAS))
	mat.set_shader_parameter("tint", Color.WHITE)
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = WearDrops.COUNT
	mm.visible_instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3(0.1, 0.1, 1.0)), WearDrops.STEAM_AT))
	mm.set_instance_custom_data(0, Color(0.0, 0.0, 0.0, 0.0))
	multimesh = mm
	# от носа мостика до кормы машинного, борт к борту, пол — потолок
	mm.custom_aabb = AABB(Vector3(-4.9, 0.0, -4.9), Vector3(9.8, 3.4, 24.0))
	visible = false


## Каждый кадр: время t, сглаженная потеря прочности (CabinWear.loss), свет плафонов light 0…1.
func apply(t: float, loss: float, light: float) -> void:
	if not WearDrops.shown(loss):
		shown = 0
		visible = false
		return
	var mm := multimesh
	var n := WearDrops.count(lite)
	for i in n:
		var c := WearDrops.card(i, t, loss, lite)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(c.size.x, c.size.y, 1.0)), c.pos))
		mm.set_instance_custom_data(i, Color(c.age, c.alpha, float(c.first), float(c.span) + c.glow))
	mm.visible_instance_count = n
	shown = n
	mat.set_shader_parameter("tint", Color(light, light, light, 1.0))
	visible = true
