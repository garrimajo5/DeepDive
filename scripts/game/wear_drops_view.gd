class_name WearDropsView
extends MultiMeshInstance3D
## Частицы «корабль устал» ART-074 (`WearDrops`): капли у бортов мостика и машинного, искры у пульта энергии, пар над
## вентилем — один MultiMesh в осях корабля (один материал, один вызов), шейдер пара `shaders/steam.gdshader`,
## атлас `textures/ustalost/atlas.png`. Слой корабля, без теней и огней (`CardSwarm`). Корпус ≥ 62 % — узел скрыт.

var mat: ShaderMaterial
var lite := false   ## «Экономно» (ART-044): 12 карточек
var shown := 0      ## сколько карточек видно (для тестов)


func _init() -> void:
	name = "Капли износа"
	mat = CardSwarm.material("res://shaders/steam.gdshader", {"atlas": load(WearDrops.ATLAS), "tint": Color.WHITE})
	var mm := CardSwarm.setup(self, mat, WearDrops.COUNT, OceanView.LAYER_SHIP)
	CardSwarm.park(mm, WearDrops.STEAM_AT)
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
