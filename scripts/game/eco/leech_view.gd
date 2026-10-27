class_name LeechView
extends Node3D
## Пиявники в сцене (ART-003: плоская лента 0,2 м у жаберной щели, бурая с тёмными кольцами): один MultiMesh
## по экземпляру на серпохвоста, у здорового — нулевой масштаб. Место — EcoLeech.ON_BODY в осях тела хищника,
## лента слегка изгибается (жабры дышат). Стоит на слое отмели (OceanView.LAYER_WORLD). Разброс (Б4, EcoVary по номеру
## хищника): свой размер ленты, ритм изгиба и оттенок — цвет экземпляра. Облачка слизи на станции чистки
## (EcoLeechDust: огнёвки обирают жабры, паразит снят — клуб) — дочерний MultiMesh «Муть» в мировых координатах на
## общем шейдере EcoShaders.MIST (INK), +1 вызов.

## Лента: капсула 0,2 м длиной и 0,06 м шириной, сплющена к боку хищника; наклонена вдоль жаберной щели.
const LENGTH := 0.2
const RADIUS := 0.03
const FLAT := 0.3
const TILT := deg_to_rad(5.0)
## Изгиб: ±0,15 рад с частотой 2 рад/с.
const WIGGLE := 0.15
const WIGGLE_RATE := 2.0
const COLOR := Color("7a4636")
## Разброс: размер ±15 %, ритм изгиба ±25 %, светлее-темнее ±15 %.
const SIZE_SPREAD := 0.15
const RATE_SPREAD := 0.25
const SHADE_SPREAD := 0.15

var leeches: EcoLeech
var mesh: MultiMeshInstance3D
## Последние места лент (по хищнику; для тестов — сервер отрисовки без экрана экземпляры не хранит).
var placed: Array[Transform3D] = []
var _buffer := PackedFloat32Array()
## Облачка на станции чистки и их MultiMesh.
var dust := EcoLeechDust.new()
var dust_view: MultiMeshInstance3D
## Буфер облачков (EcoDustBuffer) — для тестов.
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()
## Чисел на ленту: transform 3 × 4 и цвет экземпляра (4).
const STRIDE := 16


func _init(system: EcoLeech) -> void:
	leeches = system
	name = "Пиявники"
	mesh = MultiMeshInstance3D.new()
	mesh.name = "Ленты"
	mesh.layers = OceanView.LAYER_WORLD
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = build()
	var ps := leeches.preds()
	mm.instance_count = maxi(1, ps.all.size() if ps else 0)
	mesh.multimesh = mm
	mesh.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	add_child(mesh)
	dust_view = GrazerView.build_dust(EcoLeechDust.POOL)
	add_child(dust_view)
	sync(0.0)


static func build() -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = RADIUS
	m.height = LENGTH
	m.radial_segments = 6
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	m.material = mat
	return m


## Где и как стоит лента на хищнике в момент t (нулевой масштаб — паразита нет).
static func place(pr: EcoPred.Pred, t: float) -> Transform3D:
	if not pr.leech or not pr.agent.alive:
		return Transform3D(Basis.from_scale(Vector3.ZERO), pr.agent.p)
	var bend := TILT + sin(t * leech_rate(pr.index) + float(pr.index)) * WIGGLE
	var local := Basis(Vector3.RIGHT, bend) * Basis.from_scale(Vector3(FLAT, 1, 1) * leech_scale(pr.index))
	return Transform3D(EcoPredLook.basis(pr) * local, EcoLeech.position_on(pr))


## Поставить ленты в момент t; state — корабль (облачка: дальность, свет прожектора), flow — течение (уносит их).
func sync(t: float, state: EcoLink.ShipState = null, flow := Vector3.ZERO) -> void:
	var ps := leeches.preds()
	if ps == null:
		return
	_sync_dust(t, state, flow)
	var mm := mesh.multimesh
	var n := mini(ps.all.size(), mm.instance_count)
	placed.resize(n)
	_buffer.resize(mm.instance_count * STRIDE)
	for i in n:
		var x := place(ps.all[i], t)
		placed[i] = x
		var b := x.basis
		var o := i * STRIDE
		var k := leech_shade(ps.all[i].index)
		_buffer[o + 12] = k; _buffer[o + 13] = k; _buffer[o + 14] = k; _buffer[o + 15] = 1.0
		_buffer[o] = b.x.x; _buffer[o + 1] = b.y.x; _buffer[o + 2] = b.z.x; _buffer[o + 3] = x.origin.x
		_buffer[o + 4] = b.x.y; _buffer[o + 5] = b.y.y; _buffer[o + 6] = b.z.y; _buffer[o + 7] = x.origin.y
		_buffer[o + 8] = b.x.z; _buffer[o + 9] = b.y.z; _buffer[o + 10] = b.z.z; _buffer[o + 11] = x.origin.z
	mm.buffer = _buffer


## Размер ленты на хищнике n.
static func leech_scale(n: int) -> float:
	return EcoVary.spread(n, EcoVary.SIZE, SIZE_SPREAD)


## Частота изгиба ленты на хищнике n, рад/с.
static func leech_rate(n: int) -> float:
	return WIGGLE_RATE * EcoVary.spread(n, EcoVary.RATE, RATE_SPREAD)


## Светлее-темнее ленты на хищнике n (множитель цвета экземпляра).
static func leech_shade(n: int) -> float:
	return EcoVary.spread(n, EcoVary.SHADE, SHADE_SPREAD)


## Цвет экземпляра n из буфера (для тестов).
func color_at(n: int) -> Color:
	var o := n * STRIDE + 12
	return Color(_buffer[o], _buffer[o + 1], _buffer[o + 2], _buffer[o + 3])


func _sync_dust(t: float, state: EcoLink.ShipState, flow: Vector3) -> void:
	if state == null:
		return
	dust.update(leeches, t, state.pos)
	_dust.pack(dust.dust, t, flow, state, EcoLeechDust.COLOR, EcoLeechDust.LIT, Seabed.mesh_height)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)
