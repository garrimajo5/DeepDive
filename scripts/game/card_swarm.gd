class_name CardSwarm
extends RefCounted
## Общий каркас роёв карточек (#763): квадрат 1×1 с материалом, `MultiMesh` с данными кадра в custom, без тени, слой.
## Собирает пар вентиля ART-071 (`SteamView`), капли износа ART-074 (`WearDropsView`), след винтов ART-063
## (`WakeView`) и частицы пробоины ART-072 (`BreachView`); виды оставляют себе только `apply`.


## Материал карточек: шейдер и его параметры (атлас, оттенок…).
static func material(shader: String, params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(shader)
	for k in params:
		mat.set_shader_parameter(k, params[k])
	return mat


## Узел n — рой до limit карточек: слой layer, без тени, квадрат 1×1 с материалом mat, данные кадра в custom.
## Видимых карточек 0 — поставить пустую можно `park`.
static func setup(n: MultiMeshInstance3D, mat: ShaderMaterial, limit: int, layer: int) -> MultiMesh:
	n.layers = layer
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = limit
	mm.visible_instance_count = 0
	n.multimesh = mm
	return mm


## Одна прозрачная карточка в at (размер size): пока частиц нет, прогрев шейдеров (`Warmup`) покажет её на кадр.
static func park(mm: MultiMesh, at: Vector3, size := Vector3(0.1, 0.1, 1.0)) -> void:
	mm.set_instance_transform(0, Transform3D(Basis.from_scale(size), at))
	mm.set_instance_custom_data(0, Color(0.0, 0.0, 0.0, 0.0))
	mm.visible_instance_count = 1
