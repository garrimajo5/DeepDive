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


## Карточки роя одним буфером (#847): 16 чисел на карточку — базис по строкам со сдвигом (12) и custom (4); весь
## буфер уходит в MultiMesh одним вызовом, а не двумя вызовами на карточку. Пустой рой ставит прозрачную карточку
## один раз (`commit`), а не каждый кадр.
class Cards:
	extends RefCounted
	const STRIDE := 16
	var mm: MultiMesh
	var buf := PackedFloat32Array()
	var n := 0              ## карточек в этом кадре
	var writes := 0         ## сколько раз буфер отправлен (тесты)
	var parked := false     ## пустая карточка уже стоит

	func _init(m: MultiMesh) -> void:
		mm = m
		buf.resize(m.instance_count * STRIDE)

	func begin() -> void:
		n = 0

	func full() -> bool:
		return n >= mm.instance_count

	## Карточка с осями x, y (размер и поворот в них), центром at и данными кадра c. Рой полон — не пишет.
	func add(x: Vector3, y: Vector3, at: Vector3, c: Color) -> void:
		if n >= mm.instance_count:
			return
		var i := n * STRIDE
		buf[i] = x.x; buf[i + 1] = y.x; buf[i + 2] = 0.0; buf[i + 3] = at.x
		buf[i + 4] = x.y; buf[i + 5] = y.y; buf[i + 6] = 0.0; buf[i + 7] = at.y
		buf[i + 8] = x.z; buf[i + 9] = y.z; buf[i + 10] = 1.0; buf[i + 11] = at.z
		buf[i + 12] = c.r; buf[i + 13] = c.g; buf[i + 14] = c.b; buf[i + 15] = c.a
		n += 1

	## Отправить кадр. Пусто — одна прозрачная карточка в park_at (для прогрева шейдеров), но только раз подряд.
	func commit(park_at: Vector3, park_size := Vector3(0.1, 0.1, 1.0)) -> int:
		if n > 0:
			mm.buffer = buf
			mm.visible_instance_count = n
			parked = false
			writes += 1
			return n
		if not parked:
			add(Vector3(park_size.x, 0, 0), Vector3(0, park_size.y, 0), park_at, Color(0, 0, 0, 0))
			buf[10] = park_size.z
			n = 0
			mm.buffer = buf
			mm.visible_instance_count = 1
			parked = true
			writes += 1
		return 0

	## Карточка i из последнего буфера (тесты; в headless движок положения из буфера не отдаёт).
	func card(i: int) -> Transform3D:
		var k := i * STRIDE
		return Transform3D(Basis(Vector3(buf[k], buf[k + 4], buf[k + 8]), Vector3(buf[k + 1], buf[k + 5], buf[k + 9]),
				Vector3(buf[k + 2], buf[k + 6], buf[k + 10])), Vector3(buf[k + 3], buf[k + 7], buf[k + 11]))

	func custom(i: int) -> Color:
		var k := i * STRIDE + 12
		return Color(buf[k], buf[k + 1], buf[k + 2], buf[k + 3])
