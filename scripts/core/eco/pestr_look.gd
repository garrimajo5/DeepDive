class_name EcoPestrLook
extends RefCounted
## Как выглядит пестрянка (pestr в js/creatures.js, бестиарий): короткое тело-капля с низким спинным плавником,
## хвостом-веером и двумя грудными плавниками. Плавники живые (Б3, `docs/grafika-plan-eco.md`): хвост машет бегущей
## волной (EcoFishLook.tail_wave), грудные гребут вверх-вниз (EcoFishLook.fin_flap, вес — канал b цвета вершины).
## Рисует тот же шейдер, что светляков (FishView.shader_code) — шейдеров не прибавилось; форма — в осях рыбки
## светляка (x — бок, y — спина, z — нос), в мире её уменьшает SCALE. Тело и плавники светятся цветом пестрянки
## (INSTANCE_CUSTOM.rgb), плавники — слабее и темнее (BODY_COLOR в albedo). Грани тела — обход по часовой снаружи,
## плавники — в обе стороны.

## Во сколько раз форма крупнее пестрянки в мире: тело 7 × 10 × 19 см, с хвостом — 27 см (раньше капля 7 × 10 × 24).
const SCALE := 0.45
## Тело: полуширина, полувысота, нос и корма по z (м формы).
const HALF_WIDTH := 0.08
const HALF_HEIGHT := 0.11
const NOSE := 0.22
const BACK := -0.2
## Кольца тела (без носа и кормы) и грани кольца.
const RINGS := 6
const SEGMENTS := 8
## Хвост-веер: корень у кормы и концы лопастей (z, высота), выемка посередине.
const TAIL_ROOT := Vector2(-0.17, 0.035)
const TAIL_TIP := Vector2(-0.38, 0.12)
const TAIL_NOTCH := -0.33
## Грудной плавник правого борта (левый — зеркально по x): передний и задний корень у бока и кончик, отведённый
## вбок и назад.
const PEC_FRONT := Vector3(0.078, -0.02, 0.08)
const PEC_BACK := Vector3(0.078, -0.035, 0.01)
const PEC_TIP := Vector3(0.18, -0.05, -0.01)
## Краска: тело светится целиком, плавники — доля (smoothstep шейдера FishView от 0,55 до 0,95).
const BODY_PAINT := 1.0
const FIN_PAINT := 0.75
## Тёмная основа плавников (albedo) и доля цвета пестрянки в свечении (раньше — unshaded цвет целиком).
const BODY_COLOR := Color("4a1c0c")
const GLOW := 0.6

## Вершины, нормали, цвет вершин (r — краска, b — вес взмаха грудного плавника) и треугольники.
static var shape := PackedVector3Array()
static var normals := PackedVector3Array()
static var colors := PackedColorArray()
static var tris := PackedInt32Array()
## Кончики грудных плавников (правый, левый), концы хвоста (верх, низ), нос — для тестов.
static var pec_tips: Array[int] = []
static var tail_tips: Array[int] = []
static var nose_vertex := -1


static func _static_init() -> void:
	_build()


static func _add(p: Vector3, n: Vector3, paint: float, flap := 0.0) -> int:
	shape.append(p)
	normals.append(n)
	colors.append(Color(paint, 0.0, flap, 1.0))
	return shape.size() - 1


## Треугольник тела по правилу Godot: (b − a) × (c − a) — к оси тела (внутрь).
static func _tri(a: int, b: int, c: int) -> void:
	var n := (shape[b] - shape[a]).cross(shape[c] - shape[a])
	var m := (shape[a] + shape[b] + shape[c]) / 3.0
	if n.dot(Vector3(m.x, m.y, m.z - _mid())) > 0.0:
		tris.append_array([a, c, b])
	else:
		tris.append_array([a, b, c])


static func _mid() -> float:
	return (NOSE + BACK) * 0.5


## Плоский плавник из точек pts (веер треугольников от первой) с нормалью side — с обеих сторон: свои вершины
## на каждую сторону, чтобы свет ложился верно. flaps — вес взмаха каждой точки.
static func _fin(pts: Array, flaps: Array, side: Vector3) -> Array[int]:
	var first: Array[int] = []
	for s in [1.0, -1.0]:
		var ids: Array[int] = []
		for i in pts.size():
			ids.append(_add(pts[i], side * s, FIN_PAINT, flaps[i]))
		if first.is_empty():
			first = ids
		for i in range(1, pts.size() - 1):
			var a := ids[0]
			var b := ids[i]
			var c := ids[i + 1]
			# лицевая сторона смотрит по side * s: (b − a) × (c − a) — против неё
			if (shape[b] - shape[a]).cross(shape[c] - shape[a]).dot(side * s) > 0.0:
				tris.append_array([a, c, b])
			else:
				tris.append_array([a, b, c])
	return first


static func _build() -> void:
	shape.clear()
	normals.clear()
	colors.clear()
	tris.clear()
	var hl := (NOSE - BACK) * 0.5
	var mid := _mid()
	nose_vertex = _add(Vector3(0, 0, NOSE), Vector3(0, 0, 1), BODY_PAINT)
	var ring: Array[int] = []
	for r in RINGS:
		var th := PI * float(r + 1) / float(RINGS + 1)
		var z := mid + hl * cos(th)
		var s := sin(th)
		ring.append(shape.size())
		for j in SEGMENTS:
			var a := TAU * float(j) / float(SEGMENTS)
			var p := Vector3(HALF_WIDTH * s * cos(a), HALF_HEIGHT * s * sin(a), z)
			var n := Vector3(p.x / (HALF_WIDTH * HALF_WIDTH), p.y / (HALF_HEIGHT * HALF_HEIGHT), (z - mid) / (hl * hl))
			_add(p, n.normalized(), BODY_PAINT)
	var back := _add(Vector3(0, 0, BACK), Vector3(0, 0, -1), BODY_PAINT)
	var last := ring[RINGS - 1]
	for j in SEGMENTS:
		var k := (j + 1) % SEGMENTS
		_tri(nose_vertex, ring[0] + j, ring[0] + k)
		_tri(back, last + k, last + j)
	for r in RINGS - 1:
		for j in SEGMENTS:
			var k := (j + 1) % SEGMENTS
			_tri(ring[r] + j, ring[r] + k, ring[r + 1] + k)
			_tri(ring[r] + j, ring[r + 1] + k, ring[r + 1] + j)
	# хвост-веер: корень сверху, лопасть сверху, выемка, лопасть снизу, корень снизу
	var tail := _fin([Vector3(0, TAIL_ROOT.y, TAIL_ROOT.x), Vector3(0, TAIL_TIP.y, TAIL_TIP.x),
		Vector3(0, 0, TAIL_NOTCH), Vector3(0, -TAIL_TIP.y, TAIL_TIP.x), Vector3(0, -TAIL_ROOT.y, TAIL_ROOT.x)],
		[0.0, 0.0, 0.0, 0.0, 0.0], Vector3(1, 0, 0))
	tail_tips = [tail[1], tail[3]]
	# спинной плавник — низкий гребень вдоль спины
	_fin([Vector3(0, HALF_HEIGHT * 0.92, 0.07), Vector3(0, HALF_HEIGHT * 1.5, -0.02),
		Vector3(0, HALF_HEIGHT * 0.85, -0.12)], [0.0, 0.0, 0.0], Vector3(1, 0, 0))
	# грудные плавники — гребут, кончик целиком (вес 1), корень стоит
	pec_tips.clear()
	for sx in [1.0, -1.0]:
		var m := Vector3(sx, 1, 1)
		var pec := _fin([PEC_FRONT * m, PEC_TIP * m, PEC_BACK * m], [0.0, 1.0, 0.0], Vector3(0, 1, 0))
		pec_tips.append(pec[1])


## Смещение вершины i формы в момент t шейдера у пестрянки с фазой a (доля оборота); sway_k — 0 на «Экономно».
## Двойник вершинного шейдера FishView: хвост — вбок, грудные — вверх-вниз.
static func offset(i: int, t: float, a: float, sway_k := 1.0) -> Vector3:
	var p := shape[i]
	return Vector3(EcoFishLook.tail_wave(p.z, t, a, sway_k), EcoFishLook.fin_flap(p.x, colors[i].b, t, a, sway_k), 0.0)


## Фаза плавников пестрянки k у хватня hv (доля оборота 0…1): от фазы хоровода и номера хватня (золотое сечение) —
## соседки и пестрянки разных хватней машут вразнобой.
static func phase(hv: EcoHvaten.Anemone, k: int) -> float:
	return fposmod(hv.pestr[k].phase / TAU + k * 0.21 + hv.index * 0.618034, 1.0)
