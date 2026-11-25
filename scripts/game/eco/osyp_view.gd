class_name OsypView
extends Node3D
## Каменная крошка, осыпи и валуны у дна (EcoOsyp, #2108): один MultiMesh «Осыпи» — один вызов отрисовки,
## 320 экземпляров камня (меш — икосаэдр с плоскими гранями, 20 треугольников). Камни освещаются:
## StandardMaterial3D с числами «камень» из EcoSurface, цвет — из экземпляра; шейдеров не прибавилось.
## Камни неподвижны: пятно переписывается только когда его ближайшая к кораблю копия плитки сменилась
## (а это бывает дальше TILE/2, где камень уже погашен), — в кадре почти всегда ноль записей в буфер.
## «Экономно» — узел скрыт (set_lite): ноль вызовов.

## Чисел на экземпляр: transform 3 × 4 и цвет (4).
const STRIDE := 16

var mm: MultiMeshInstance3D
## Последний буфер (для тестов).
var buffer := PackedFloat32Array()
var lite := false
## Копия плитки, которой пятно заполнено в буфере (INF — не заполнено).
var _copies: Array[Vector2] = []
## Пятно в буфере видимо (иначе его камни уже сжаты в точку).
var _shown: Array[bool] = []


func _init() -> void:
	name = "Осыпи"
	mm = EcoMM.instance(self, "Осыпи", build(), EcoOsyp.count(), true)
	buffer.resize(EcoOsyp.count() * STRIDE)
	_copies.resize(EcoOsyp.PATCHES)
	_copies.fill(Vector2(INF, INF))
	_shown.resize(EcoOsyp.PATCHES)
	_shown.fill(false)
	for i in EcoOsyp.PATCHES:
		for j in EcoOsyp.PER:
			var c := EcoOsyp.tint(i * EcoOsyp.PER + j)
			var at := (i * EcoOsyp.PER + j) * STRIDE + 12
			buffer[at] = c.r
			buffer[at + 1] = c.g
			buffer[at + 2] = c.b
			buffer[at + 3] = 1.0
	mm.multimesh.buffer = buffer


## «Экономно» (ART-044): осыпей нет.
func set_lite(on: bool) -> void:
	lite = on
	visible = not on


## Камни у корабля ship_pos; ground — высота дна (x, z). Без времени: камни стоят в мире.
func sync(ship_pos: Vector3, ground: Callable) -> void:
	if lite:
		return
	var ship := Vector2(ship_pos.x, ship_pos.z)
	var dirty := false
	for i in EcoOsyp.PATCHES:
		var copy := EcoOsyp.near_copy(EcoOsyp.base(i), ship)
		if copy == _copies[i]:
			continue   # пятно уже заполнено этой копией
		var s := EcoOsyp.patch_at(i, ship_pos, ground)
		var on := s[2] > 0.0
		if not on and not _shown[i]:
			_copies[i] = copy
			continue   # невидимое и уже сжатое — буфер не трогаем
		_copies[i] = copy
		_shown[i] = on
		dirty = true
		for j in EcoOsyp.PER:
			EcoMM.put(buffer, (i * EcoOsyp.PER + j) * STRIDE, EcoOsyp.stone(i, j, s, ground))
	if dirty:
		mm.multimesh.buffer = buffer


## Камень-икосаэдр радиуса 1 с плоскими гранями (20 треугольников), приплюснут по вертикали.
static func build() -> ArrayMesh:
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var verts := PackedVector3Array()
	for v in [Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
			Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
			Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1)]:
		verts.append((v.normalized() * Vector3(1.0, 0.72, 1.0)))
	var tris_v := PackedVector3Array()
	var tris_n := PackedVector3Array()
	for f in [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
			[11, 10, 2], [7, 1, 8], [10, 7, 6], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
			[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]:
		_face(verts, tris_v, tris_n, f[0], f[1], f[2])
	var m := EcoMM.tris(tris_v, tris_n)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE   # цвет дают экземпляры MultiMesh
	mat.roughness = EcoSurface.KINDS["камень"].x
	mat.metallic_specular = EcoSurface.KINDS["камень"].y
	m.surface_set_material(0, mat)
	return m


## Грань икосаэдра: обход — по часовой снаружи (как `FarLifeView._face`), нормаль — плоская наружу.
static func _face(verts: PackedVector3Array, out_v: PackedVector3Array, out_n: PackedVector3Array,
		a: int, b: int, c: int) -> void:
	var va := verts[a]
	var vb := verts[b]
	var vc := verts[c]
	var n := (vb - va).cross(vc - va)
	# (b − a) × (c − a) у лицевой грани смотрит внутрь; вышел наружу — переставь обход
	if n.dot((va + vb + vc) / 3.0) > 0.0:
		var t := vb
		vb = vc
		vc = t
		n = -n
	var flat := -n.normalized()
	out_v.append_array([va, vb, vc])
	out_n.append_array([flat, flat, flat])
