class_name FarLifeView
extends Node3D
## Силуэты рыб вдали (EcoFarLife, Б5): один MultiMesh «Силуэты вдали» — один вызов отрисовки, ~1 тыс. треугольников.
## Материал — без света с цветом экземпляра, тот же шейдер, что у глаз глазуна (CoinsView.build_eye): шейдеров не
## прибавилось. Дальше гасит туман воды. «Экономно» — узел скрыт (`set_lite`, из EcoView.set_lite): ноль вызовов.

## Чисел на экземпляр: transform 3 × 4 и цвет (4).
const STRIDE := 16
## Стайка переписывается раз в EVERY кадров, стайки — по очереди: они вдали и плывут 1…2 м/с, сдвиг за три кадра
## на 60 кадр/с — 3…10 см на 40…125 м, глазом не виден, а шаг вида — втрое дешевле.
const EVERY := 3

var mm: MultiMeshInstance3D
## Последний буфер (для тестов).
var buffer := PackedFloat32Array()
var lite := false
## Стайка в прошлом кадре была видна (её силуэты в буфере не сжаты).
var _shown: Array[bool] = []
## Номер кадра (очередь стаек).
var frame := 0


func _init() -> void:
	name = "Жизнь вдали"
	mm = EcoMM.instance(self, "Силуэты вдали", build(), EcoFarLife.count(), true)
	buffer.resize(EcoFarLife.count() * STRIDE)
	_shown.resize(EcoFarLife.schools())
	_shown.fill(false)
	for i in EcoFarLife.schools():
		var c := EcoFarLife.tint(i)
		for j in EcoFarLife.size_of(i):
			var at := (EcoFarLife.first(i) + j) * STRIDE + 12
			buffer[at] = c.r
			buffer[at + 1] = c.g
			buffer[at + 2] = c.b
			buffer[at + 3] = 1.0
	mm.multimesh.buffer = buffer


## «Экономно» (ART-044): силуэтов нет.
func set_lite(on: bool) -> void:
	lite = on
	visible = not on


## Силуэты на время мира t у корабля ship_pos; ground — высота дна (x, z). В кадр — каждая EVERY-я стайка.
func sync(t: float, ship_pos: Vector3, ground: Callable) -> void:
	if lite:
		return
	var dirty := false
	frame += 1
	for i in EcoFarLife.schools():
		if (i + frame) % EVERY != 0:
			continue
		var s := EcoFarLife.school_at(i, t, ship_pos, ground)
		var on := s[4] > 0.0
		if not on and not _shown[i]:
			continue   # невидимая и уже сжатая — буфер не трогаем
		_shown[i] = on
		dirty = true
		for j in EcoFarLife.size_of(i):
			EcoMM.put(buffer, (EcoFarLife.first(i) + j) * STRIDE, EcoFarLife.fish(i, j, t, s))
	if dirty:
		mm.multimesh.buffer = buffer


## Силуэт рыбы длиной 1 м носом в −Z: тело — сплюснутый ромб (высота 0,26, толщина 0,1), хвост — вертикальный
## веер с обеих сторон. Грани наружу (обход по часовой стрелке снаружи).
static func build() -> ArrayMesh:
	var nose := Vector3(0, 0, -0.5)
	var neck := Vector3(0, 0, 0.32)
	var top := Vector3(0, 0.13, -0.08)
	var bot := Vector3(0, -0.1, -0.05)
	var left := Vector3(-0.05, 0.01, -0.1)
	var right := Vector3(0.05, 0.01, -0.1)
	var mid := Vector3(0, 0.01, -0.07)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for tri in [[nose, top, left], [nose, right, top], [nose, left, bot], [nose, bot, right],
			[neck, left, top], [neck, top, right], [neck, bot, left], [neck, right, bot]]:
		_face(verts, normals, tri[0], tri[1], tri[2], mid)
	# хвост: две лопасти, каждая — с обеих сторон
	var t0 := Vector3(0, 0, 0.3)
	for fin in [[Vector3(0, 0.16, 0.52), Vector3(0, 0.02, 0.44)], [Vector3(0, -0.14, 0.5), Vector3(0, 0.0, 0.44)]]:
		_face(verts, normals, t0, fin[0], fin[1], t0 + Vector3(0.1, 0, 0))
		_face(verts, normals, t0, fin[0], fin[1], t0 - Vector3(0.1, 0, 0))
	var m := EcoMM.tris(verts, normals)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	m.surface_set_material(0, mat)
	return m


## Треугольник лицом от точки inner: Godot рисует лицевую сторону при обходе по часовой стрелке, (b − a) × (c − a)
## смотрит внутрь (CLAUDE.md).
static func _face(verts: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3,
		inner: Vector3) -> void:
	var n := (b - a).cross(c - a)
	var out := (a + b + c) / 3.0 - inner
	if n.dot(out) > 0.0:
		var s := b
		b = c
		c = s
		n = -n
	verts.append_array([a, b, c])
	var nn := -n.normalized()
	normals.append_array([nn, nn, nn])
