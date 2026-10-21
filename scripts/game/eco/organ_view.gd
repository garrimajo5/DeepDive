class_name OrganView
extends MeshInstance3D
## Трубные органы в сцене (organGeo в js/creatures.js; ART-004): все губки — один меш (один вызов отрисовки).
## Труба — открытый усечённый конус (10 граней, видна с обеих сторон), у устья светлый обод-кольцо. Трубы через одну
## #9a7f6a и #6f5b4c, обод #ffd9a0; губка чуть тлеет тёплым (EcoOrgan.glow — в общем шейдере растений
## EcoShaders.PLANT по TIME).
## Стоит на слое отмели (OceanView.LAYER_WORLD).

const LIGHT := Color("9a7f6a")
const DARK := Color("6f5b4c")
const RIM := Color("ffd9a0")
## Краска гуще: при ярком свете сквозь лёд светлая губка выгорает в белый (как у огнецвета).
const PAINT_K := 0.45
## Тление губки (линейный цвет): GLOW + GLOW_WAVE · sin(TIME · 1,7).
const GLOW := Vector3(0.1, 0.06, 0.03)
const GLOW_WAVE := Vector3(0.05, 0.0, 0.0)
## Граней у трубы, у обода — 10 × 4 (CylinderGeometry(…, 10), TorusGeometry(0,32, 0,05, 4, 10)).
const SIDES := 10
const RIM_TUBE := 0.05
const RIM_SIDES := 4

var organs: EcoOrgan
## Вершины и треугольники всего меша (для тестов).
var verts := PackedVector3Array()
var tris := 0

var _nor := PackedVector3Array()
var _col := PackedColorArray()
var _idx := PackedInt32Array()


func _init(system: EcoOrgan) -> void:
	organs = system
	name = "Трубный орган"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for og in organs.organs:
		for k in EcoOrgan.TUBES:
			var b := og.tube_base[k]
			var top := b + Vector3(0, og.tube_len[k], 0)
			_tube(b, top, LIGHT if k % 2 else DARK)
			_rim(top)
	var m := ArrayMesh.new()
	if not verts.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = _nor
		arrays[Mesh.ARRAY_COLOR] = _col
		arrays[Mesh.ARRAY_INDEX] = _idx
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		m.surface_set_material(0, EcoShaders.plant(EcoShaders.Plant.ORGAN, {"shade": PAINT_K, "rough": 1.0,
			"spec": 0.1, "glow": GLOW, "glow_wave": GLOW_WAVE}))
	mesh = m
	tris = _idx.size() / 3


## Открытый конус от основания b (радиус TUBE_BASE_R) до устья top (TUBE_TOP_R).
func _tube(b: Vector3, top: Vector3, c: Color) -> void:
	var v0 := verts.size()
	var slope := (EcoOrgan.TUBE_BASE_R - EcoOrgan.TUBE_TOP_R) / maxf(0.01, top.y - b.y)
	for i in SIDES + 1:
		var a := TAU * i / SIDES
		var d := Vector3(cos(a), 0, sin(a))
		var n := (d + Vector3(0, slope, 0)).normalized()
		verts.append(b + d * EcoOrgan.TUBE_BASE_R)
		verts.append(top + d * EcoOrgan.TUBE_TOP_R)
		for j in 2:
			_nor.append(n)
			_col.append(c)
	for i in SIDES:
		var q := v0 + i * 2
		# обход не важен: труба видна с обеих сторон (cull_disabled)
		_idx.append_array([q, q + 1, q + 2, q + 2, q + 1, q + 3])


## Обод у устья: тор радиусом TUBE_TOP_R, толщина RIM_TUBE.
func _rim(c: Vector3) -> void:
	var v0 := verts.size()
	for i in SIDES + 1:
		var a := TAU * i / SIDES
		var d := Vector3(cos(a), 0, sin(a))
		for j in RIM_SIDES + 1:
			var b := TAU * j / RIM_SIDES
			var n := d * cos(b) + Vector3(0, sin(b), 0)
			verts.append(c + d * EcoOrgan.TUBE_TOP_R + n * RIM_TUBE)
			_nor.append(n)
			_col.append(RIM)
	var row := RIM_SIDES + 1
	for i in SIDES:
		for j in RIM_SIDES:
			var q := v0 + i * row + j
			_idx.append_array([q, q + row, q + 1, q + 1, q + row, q + row + 1])
