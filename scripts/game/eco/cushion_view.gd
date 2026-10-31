class_name CushionView
extends Node3D
## Подушечник в сцене (initCushions в js/creatures.js; ART-004): подушки — один MultiMesh из полусферы 1,1 × 0,75 × 1 м
## с бархатными полипами (цвет по высоте: розовые у дна, светлее к макушке, слабое своё свечение #1a0a14), сжатая
## подушка ниже и уже. Облака чернил — второй MultiMesh из плоских тёмных пятен 2,4 м лицом к камере (смешивание
## по прозрачности, без записи глубины, общий шейдер EcoShaders.MIST): тёмно-синие, тают последние 2 с. Стоит на слое отмели (OceanView.LAYER_WORLD).
## Муть у дна (EcoCushionDust: сжалась — клуб ила кольцом вокруг основания) — дочерний MultiMesh «Муть» на том же
## шейдере MIST, +1 вызов.
## «Экономно» (Б6, `set_lite`): рисуется половина пятен каждого облака чернил (`EcoMM.cloud_slot` — буфер вперемешку
## по подушкам, `visible_instance_count` отрезает вторую половину) — вдвое меньше крупных полупрозрачных пятен у
## камеры. Мир (облако, укрытие, сонар) не меняется.

## Подушка: полусфера радиуса 1 м, сплюснутая по ширине и высоте (g.scale(1.1, 0.75, 1)).
const SHAPE := Vector3(1.1, 0.75, 1.0)
const SEGMENTS := 14
const RINGS := 4
const GLOW := Color("1a0a14")
## Пятно чернил 2,4 м, цвет (0,05, 0,04, 0,12) и непрозрачность 0,85 — как точки в браузере.
const INK_SIZE := 2.4
const INK := Color(0.05, 0.04, 0.12)
const INK_ALPHA := 0.85
## Чисел на экземпляр: transform 3 × 4, у чернил ещё цвет (4).
const STRIDE := 12
const STRIDE_C := 16

var cushions: EcoCushion
var pads: MultiMeshInstance3D
var ink: MultiMeshInstance3D
## Последние буферы подушек и чернил (для тестов).
var pad_buffer := PackedFloat32Array()
var ink_buffer := PackedFloat32Array()
## Подушки, чьё облако в буфере ещё видно: без чернил буфер облака не пишется и не грузится заново (issue #133).
var _ink_shown := PackedByteArray()
## Муть у дна и её последний буфер (для тестов).
var dust := EcoCushionDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()
## «Экономно»: рисуется половина пятен каждого облака.
var lite := false


func _init(system: EcoCushion, on_lite := false) -> void:
	cushions = system
	name = "Подушечник"
	var n := cushions.cushions.size()
	pads = EcoMM.instance(self, "Подушки", build_pad(), n, false)
	ink = EcoMM.instance(self, "Чернила", build_ink(), n * EcoCushion.INK_N, true)
	dust_view = GrazerView.build_dust(EcoCushionDust.POOL)
	add_child(dust_view)
	var pts := PackedVector3Array()
	for c in cushions.cushions:
		pts.append(c.base)
	EcoMM.fit([pads, ink], pts, FRAME_GROW)
	set_lite(on_lite)
	sync(0.0)


## «Экономно» — половина пятен каждого облака чернил; буфер переписывается целиком в следующем sync.
func set_lite(on: bool) -> void:
	lite = on
	ink.multimesh.visible_instance_count = EcoMM.cloud_shown(cushions.cushions.size(), EcoCushion.INK_N, on)
	ink_buffer = PackedFloat32Array()


## Место пятна j подушки cushion в буфере чернил.
func ink_slot(cushion: int, j: int) -> int:
	return EcoMM.cloud_slot(cushion, j, cushions.cushions.size(), EcoCushion.INK_N, lite)


## Сколько пятен чернил рисуется сейчас.
func ink_drawn() -> int:
	var v := ink.multimesh.visible_instance_count
	return ink.multimesh.instance_count if v < 0 else v


## Запас рамки вокруг подушек (#849): облако чернил — 2 м вверх и 5,5 м вширь, его сносит течением.
const FRAME_GROW := 12.0


## Полусфера подушки с цветом вершин по высоте (0,85 − 0,2y, 0,45 + 0,25y, 0,6 + 0,3y; y — высота сферы до сплющивания).
static func build_pad() -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 1.0
	sm.is_hemisphere = true
	sm.radial_segments = SEGMENTS
	sm.rings = RINGS
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var col := PackedColorArray()
	for i in v.size():
		var y := clampf(v[i].y, 0.0, 1.0)
		col.append(Color(0.85 - y * 0.2, 0.45 + y * 0.25, 0.6 + y * 0.3))
		v[i] = v[i] * SHAPE
		nr[i] = (nr[i] / SHAPE).normalized()
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.emission_enabled = true
	mat.emission = GLOW
	m.surface_set_material(0, mat)
	return m


static func build_ink() -> QuadMesh:
	var m := QuadMesh.new()
	m.size = Vector2.ONE * INK_SIZE
	m.material = EcoShaders.mist(EcoShaders.Mist.INK)
	return m


## Расставить подушки и облака в момент t (время мира). ship_pos — корабль (задел ли он подушку, дальние не пылят),
## info — корабль целиком (муть светлее в луче прожектора), flow — течение мира (уносит муть).
func sync(t: float, ship_pos := Vector3.ZERO, info: EcoLink.ShipState = null, flow := Vector3.ZERO) -> void:
	_sync_dust(t, ship_pos, info, flow)
	pad_buffer.resize(pads.multimesh.instance_count * STRIDE)
	var fresh := ink_buffer.size() != ink.multimesh.instance_count * STRIDE_C
	ink_buffer.resize(ink.multimesh.instance_count * STRIDE_C)
	_ink_shown.resize(cushions.cushions.size())
	var ink_changed := fresh
	for cu in cushions.cushions:
		var b := Basis(Vector3.UP, float(cu.index)) * Basis.from_scale(EcoCushion.squash(cu))
		EcoMM.put(pad_buffer, cu.index * STRIDE, Transform3D(b, cu.base))
		var inked := cu.inked()
		if not inked and not fresh and _ink_shown[cu.index] == 0:
			continue
		ink_changed = true
		_ink_shown[cu.index] = 1 if inked else 0
		var c := Color(INK.r, INK.g, INK.b, INK_ALPHA * EcoCushion.ink_fade(cu))
		for j in EcoCushion.INK_N:
			var i := ink_slot(cu.index, j) * STRIDE_C
			if inked:
				EcoMM.put(ink_buffer, i, Transform3D(Basis.IDENTITY, EcoCushion.ink_point(cu, j, t)))
			else:
				EcoMM.put(ink_buffer, i, Transform3D(Basis.from_scale(Vector3.ZERO), cu.ink_c))
			ink_buffer[i + 12] = c.r; ink_buffer[i + 13] = c.g; ink_buffer[i + 14] = c.b; ink_buffer[i + 15] = c.a
	EcoMM.send(pads, pad_buffer)
	if ink_changed:
		ink.multimesh.buffer = ink_buffer


func _sync_dust(t: float, ship: Vector3, info: EcoLink.ShipState, flow: Vector3) -> void:
	dust.update(cushions, t, ship)
	_dust.pack(dust.dust, t, flow, info, EcoCushionDust.COLOR, EcoCushionDust.LIT,
			Seabed.mesh_height)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


## Расстановка экземпляра n из буфера с шагом stride.
static func transform_at(buf: PackedFloat32Array, n: int, stride: int = STRIDE_C) -> Transform3D:
	var i := n * stride
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
