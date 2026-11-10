class_name WakeView
extends MultiMeshInstance3D
## След винтов и выпуски при всплытии по ART-063: частицы `Wake` одним мировым MultiMesh (один вызов отрисовки),
## шейдер `shaders/wake.gdshader`, атлас `textures/sled/atlas.png`. Слой мира (1), без теней (`CardSwarm`).

var mat: ShaderMaterial
var shown := 0   ## сколько карточек видно (для тестов)


var cards: CardSwarm.Cards   ## буфер карточек (#847)


func _init() -> void:
	name = "След винтов"
	top_level = true
	mat = CardSwarm.material("res://shaders/wake.gdshader", {"atlas": load(Wake.ATLAS), "tint": Wake.COLOR})
	cards = CardSwarm.Cards.new(CardSwarm.setup(self, mat, Wake.LIMIT, OceanView.LAYER_WORLD))


func set_lite(on: bool) -> void:
	mat.set_shader_parameter("lite", 1.0 if on else 0.0)


## anchor — где держать пустую карточку, пока пузырей нет (положение корабля): узел скрыт, но прогрев шейдеров
## (`WarmRunner._show`) показывает его на кадр — шейдер собирается под шторкой, а не при первом ходе.
func apply(w: Wake, anchor: Vector3 = Vector3.ZERO) -> void:
	var mm := multimesh
	cards.begin()
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for b: Wake.Bubble in w.bubbles:
		if cards.full():
			break
		cards.add(Vector3(b.size, 0, 0), Vector3(0, b.size, 0), b.pos,
				Color(b.cell / 16.0, Wake.alpha(b.age, b.life, b.pos.y), fposmod(b.angle, TAU) / TAU, 0.0))
		lo = lo.min(b.pos)
		hi = hi.max(b.pos)
	var n := cards.n
	var was := shown
	shown = n
	cards.commit(anchor, Vector3.ONE * 0.5)   # пусто — одна прозрачная карточка у корабля, для прогрева
	if n > 0:   # билборды шире точек: запас на карточку
		mm.custom_aabb = AABB(lo - Vector3.ONE * 1.5, hi - lo + Vector3.ONE * 3.0)
	elif was > 0 or mm.custom_aabb.size == Vector3.ZERO:
		mm.custom_aabb = AABB(anchor - Vector3.ONE * 1.5, Vector3.ONE * 3.0)
	visible = n > 0
