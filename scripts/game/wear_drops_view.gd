class_name WearDropsView
extends MultiMeshInstance3D
## Частицы «корабль устал» ART-074 (`WearDrops`): капли у бортов мостика и машинного, искры у пульта энергии, пар над
## вентилем — один MultiMesh в осях корабля (один материал, один вызов), шейдер пара `shaders/steam.gdshader`,
## атлас `textures/ustalost/atlas.png`. Слой корабля, без теней и огней (`CardSwarm`). Корпус ≥ 62 % — узел скрыт.

var mat: ShaderMaterial
var lite := false   ## «Экономно» (ART-044): 12 карточек
var shown := 0      ## сколько карточек видно (для тестов)
var cards: CardSwarm.Cards   ## буфер карточек (#847)
var _light := -1.0


func _init() -> void:
	name = "Капли износа"
	mat = CardSwarm.material("res://shaders/steam.gdshader", {"atlas": load(WearDrops.ATLAS), "tint": Color.WHITE})
	var mm := CardSwarm.setup(self, mat, WearDrops.COUNT, OceanView.LAYER_SHIP)
	cards = CardSwarm.Cards.new(mm)
	cards.commit(WearDrops.STEAM_AT)
	# от носа мостика до кормы машинного, борт к борту, пол — потолок
	mm.custom_aabb = AABB(Vector3(-4.9, 0.0, -4.9), Vector3(9.8, 3.4, 24.0))
	visible = false


## Каждый кадр: время t, сглаженная потеря прочности (CabinWear.loss), свет плафонов light 0…1.
func apply(t: float, loss: float, light: float) -> void:
	if not WearDrops.shown(loss):
		shown = 0
		visible = false
		return
	cards.begin()
	var n := mini(WearDrops.count(lite), multimesh.instance_count)
	for i in n:
		var c := WearDrops.card(i, t, loss, lite)
		cards.add(Vector3(c.size.x, 0, 0), Vector3(0, c.size.y, 0), c.pos,
				Color(c.age, c.alpha, float(c.first), float(c.span) + c.glow))
	shown = cards.n
	cards.commit(WearDrops.STEAM_AT)
	if not is_equal_approx(light, _light):
		_light = light
		mat.set_shader_parameter("tint", Color(light, light, light, 1.0))
	visible = true
