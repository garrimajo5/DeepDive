class_name SteamView
extends MultiMeshInstance3D
## Пар вентиля по ART-071: частицы `ValveSteam` одним MultiMesh в осях корабля (один материал, один вызов),
## шейдер `shaders/steam.gdshader`, атлас `textures/par/atlas.png`. Слой корабля, без теней и огней (`CardSwarm`).

var mat: ShaderMaterial
var shown := 0   ## сколько карточек видно (для тестов)


func _init() -> void:
	name = "Пар вентиля"
	mat = CardSwarm.material("res://shaders/steam.gdshader", {"atlas": load(ValveSteam.ATLAS), "tint": ValveSteam.COLD})
	var mm := CardSwarm.setup(self, mat, ValveSteam.LIMIT, OceanView.LAYER_SHIP)
	CardSwarm.park(mm, ValveSteam.NOZZLE)
	# весь путь пара: от сопла до +0,3 м по x и +0,6 м вверх, с запасом на карточку
	mm.custom_aabb = AABB(ValveSteam.NOZZLE + Vector3(-0.4, -0.4, -0.4), Vector3(1.2, 1.4, 0.8))
	visible = false


## Каждый кадр: частицы и оттенок (ValveSteam.tint). Пусто — узел скрыт (прогрев покажет пустую карточку на кадр).
func apply(st: ValveSteam, tint: Color) -> void:
	var mm := multimesh
	var n := mini(st.puffs.size(), mm.instance_count)
	for i in n:
		var p: ValveSteam.Puff = st.puffs[i]
		var a := p.age / ValveSteam.LIFE
		var s := ValveSteam.size(a)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s.x, s.y, 1.0)), ValveSteam.pos(p.age, p.angle)))
		mm.set_instance_custom_data(i, Color(a, ValveSteam.alpha(a), 0.0, float(ValveSteam.LAST)))   # кадры 0…15
	shown = n
	if n == 0:
		CardSwarm.park(mm, ValveSteam.NOZZLE)
	mm.visible_instance_count = maxi(n, 1)
	mat.set_shader_parameter("tint", tint)
	visible = n > 0
