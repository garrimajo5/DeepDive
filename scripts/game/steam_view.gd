class_name SteamView
extends MultiMeshInstance3D
## Пар вентиля по ART-071: частицы `ValveSteam` одним MultiMesh в осях корабля (один материал, один вызов),
## шейдер `shaders/steam.gdshader`, атлас `textures/par/atlas.png`. Слой корабля, без теней и огней (`CardSwarm`).

var mat: ShaderMaterial
var shown := 0   ## сколько карточек видно (для тестов)
var cards: CardSwarm.Cards   ## буфер карточек (#847)
var _tint := Color(-1, -1, -1)


func _init() -> void:
	name = "Пар вентиля"
	mat = CardSwarm.material("res://shaders/steam.gdshader", {"atlas": load(ValveSteam.ATLAS), "tint": ValveSteam.COLD})
	var mm := CardSwarm.setup(self, mat, ValveSteam.LIMIT, OceanView.LAYER_SHIP)
	cards = CardSwarm.Cards.new(mm)
	cards.commit(ValveSteam.NOZZLE)
	# весь путь пара: от сопла до +0,3 м по x и +0,6 м вверх, с запасом на карточку
	mm.custom_aabb = AABB(ValveSteam.NOZZLE + Vector3(-0.4, -0.4, -0.4), Vector3(1.2, 1.4, 0.8))
	visible = false


## Каждый кадр: частицы и оттенок (ValveSteam.tint). Пусто — узел скрыт (прогрев покажет пустую карточку на кадр).
func apply(st: ValveSteam, tint: Color) -> void:
	cards.begin()
	for p: ValveSteam.Puff in st.puffs:
		if cards.full():
			break
		var a := p.age / ValveSteam.LIFE
		var s := ValveSteam.size(a)
		cards.add(Vector3(s.x, 0, 0), Vector3(0, s.y, 0), ValveSteam.pos(p.age, p.angle),
				Color(a, ValveSteam.alpha(a), 0.0, float(ValveSteam.LAST)))   # кадры 0…15
	shown = cards.n
	cards.commit(ValveSteam.NOZZLE)
	if shown > 0 and tint != _tint:
		_tint = tint
		mat.set_shader_parameter("tint", tint)
	visible = shown > 0
