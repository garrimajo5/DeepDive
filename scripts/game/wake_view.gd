class_name WakeView
extends MultiMeshInstance3D
## След винтов и выпуски при всплытии по ART-063: частицы `Wake` одним мировым MultiMesh (один вызов отрисовки),
## шейдер `shaders/wake.gdshader`, атлас `textures/sled/atlas.png`. Слой мира (1), без теней.

var mat: ShaderMaterial
var shown := 0   ## сколько карточек видно (для тестов)


func _init() -> void:
	name = "След винтов"
	top_level = true
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/wake.gdshader")
	mat.set_shader_parameter("atlas", load(Wake.ATLAS))
	mat.set_shader_parameter("tint", Wake.COLOR)
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = Wake.LIMIT
	mm.visible_instance_count = 0
	multimesh = mm


func set_lite(on: bool) -> void:
	mat.set_shader_parameter("lite", 1.0 if on else 0.0)


## anchor — где держать пустую карточку, пока пузырей нет (положение корабля): узел скрыт, но прогрев шейдеров
## (`Main._warm_show`) показывает его на кадр — шейдер собирается под шторкой, а не при первом ходе.
func apply(w: Wake, anchor: Vector3 = Vector3.ZERO) -> void:
	var mm := multimesh
	var n := mini(w.bubbles.size(), mm.instance_count)
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for i in n:
		var b: Wake.Bubble = w.bubbles[i]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * b.size), b.pos))
		mm.set_instance_custom_data(i, Color(b.cell / 16.0, Wake.alpha(b.age, b.life, b.pos.y),
				fposmod(b.angle, TAU) / TAU, 0.0))
		lo = lo.min(b.pos)
		hi = hi.max(b.pos)
	shown = n
	if n == 0:   # одна прозрачная карточка у корабля — для прогрева
		mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * 0.5), anchor))
		mm.set_instance_custom_data(0, Color(0.0, 0.0, 0.0, 0.0))
		lo = anchor
		hi = anchor
	mm.visible_instance_count = maxi(n, 1)
	# билборды шире точек: запас на карточку
	mm.custom_aabb = AABB(lo - Vector3.ONE * 1.5, hi - lo + Vector3.ONE * 3.0)
	visible = n > 0
