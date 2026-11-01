class_name LeechView
extends Node3D
## Пиявники в сцене (ART-003: плоская лента 0,2 м у жаберной щели, бурая с тёмными кольцами): один MultiMesh
## по экземпляру на серпохвоста, у здорового — нулевой масштаб. Место — EcoLeech.ON_BODY в осях тела хищника,
## лента слегка изгибается (жабры дышат). Стоит на слое отмели (OceanView.LAYER_WORLD). Разброс (Б4, EcoVary по номеру
## хищника): свой размер ленты, ритм изгиба и оттенок — цвет экземпляра. Облачка слизи на станции чистки
## (EcoLeechDust: огнёвки обирают жабры, паразит снят — клуб) — дочерний MultiMesh «Муть» в мировых координатах на
## общем шейдере EcoShaders.MIST (INK), +1 вызов.
## «Экономно» (set_lite, Б6): лента — капсула 4 грани × 1 кольцо вместо 6 × 2 (`LITE_SIDES`/`LITE_RINGS`), тот же
## материал, размер и место; облачка слизи гасит общий EcoGrazerDust.lite.
## Паразит не возникает и не пропадает за кадр (Б3): заразился — лента вырастает у жабр за LEECH_RISE, огнёвки сняли —
## сжимается за LEECH_FADE (доли leech_k по времени мира, у гостя то же).

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
## Сечение капсулы: полное и на «Экономно».
const SIDES := 6
const RINGS := 2
const LITE_SIDES := 4
const LITE_RINGS := 1
## Заражение — лента вырастает за LEECH_RISE с; чистка — сжимается за LEECH_FADE с. Время назад или скачок дальше
## SNAP_DT (сброс мира, вход гостя) — сразу к цели.
const LEECH_RISE := 2.0
const LEECH_FADE := 0.6
const SNAP_DT := 1.0

var leeches: EcoLeech
var mesh: MultiMeshInstance3D
## «Экономно» — лента грубее (Б6).
var lite := false
## Треугольников в одной ленте (для тестов и замера).
var tris := 0
## Последние места лент (по хищнику; для тестов — сервер отрисовки без экрана экземпляры не хранит).
var placed: Array[Transform3D] = []
## Доля размера ленты по хищнику: 0 — нет, 1 — во весь размер.
var leech_k := PackedFloat32Array()
var _k_t := 0.0
var _k_fresh := true
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


func _init(system: EcoLeech, on_lite := false) -> void:
	leeches = system
	lite = on_lite
	name = "Пиявники"
	mesh = MultiMeshInstance3D.new()
	mesh.name = "Ленты"
	mesh.layers = OceanView.LAYER_WORLD
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = build(lite)
	tris = count_tris(mm.mesh)
	var ps := leeches.preds()
	mm.instance_count = maxi(1, ps.all.size() if ps else 0)
	mesh.multimesh = mm
	mesh.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	add_child(mesh)
	dust_view = GrazerView.build_dust(EcoLeechDust.POOL)
	add_child(dust_view)
	sync(0.0)


## Капсула ленты; on_lite — грубое сечение, mat — материал (на смену уровня — тот же).
static func build(on_lite := false, mat: Material = null) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = RADIUS
	m.height = LENGTH
	m.radial_segments = LITE_SIDES if on_lite else SIDES
	m.rings = LITE_RINGS if on_lite else RINGS
	if mat == null:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = COLOR
		sm.vertex_color_use_as_albedo = true
		sm.roughness = 0.8
		mat = sm
	m.material = mat
	return m


## «Экономно»: лента грубее, материал и места те же.
func set_lite(on: bool) -> void:
	if lite == on:
		return
	lite = on
	var old := mesh.multimesh.mesh as CapsuleMesh
	mesh.multimesh.mesh = build(on, old.material)
	tris = count_tris(mesh.multimesh.mesh)


## Треугольников в меше (первая поверхность).
static func count_tris(m: Mesh) -> int:
	var a := m.surface_get_arrays(0)
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		return (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return idx.size() / 3


## Где и как стоит лента на хищнике в момент t (нулевой масштаб — паразита нет); k — доля размера (leech_k),
## меньше нуля — по pr.leech сразу.
static func place(pr: EcoPred.Pred, t: float, k := -1.0) -> Transform3D:
	if k < 0.0:
		k = 1.0 if pr.leech else 0.0
	if k <= 0.0 or not pr.agent.alive:
		return Transform3D(Basis.from_scale(Vector3.ZERO), pr.agent.p)
	var bend := TILT + sin(t * leech_rate(pr.index) + float(pr.index)) * WIGGLE
	var size_k := smoothstep(0.0, 1.0, k)
	var local := Basis(Vector3.RIGHT, bend) * Basis.from_scale(Vector3(FLAT, 1, 1) * leech_scale(pr.index) * size_k)
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
	grow(t, ps)
	for i in n:
		var x := place(ps.all[i], t, leech_k[i])
		placed[i] = x
		var b := x.basis
		var o := i * STRIDE
		var k := leech_shade(ps.all[i].index)
		_buffer[o + 12] = k; _buffer[o + 13] = k; _buffer[o + 14] = k; _buffer[o + 15] = 1.0
		_buffer[o] = b.x.x; _buffer[o + 1] = b.y.x; _buffer[o + 2] = b.z.x; _buffer[o + 3] = x.origin.x
		_buffer[o + 4] = b.x.y; _buffer[o + 5] = b.y.y; _buffer[o + 6] = b.z.y; _buffer[o + 7] = x.origin.y
		_buffer[o + 8] = b.x.z; _buffer[o + 9] = b.y.z; _buffer[o + 10] = b.z.z; _buffer[o + 11] = x.origin.z
	mm.buffer = _buffer


## Доли размера лент к моменту t: заражённый — растёт за LEECH_RISE, очищенный — сжимается за LEECH_FADE. Первый шаг,
## время назад и скачок дальше SNAP_DT — сразу к цели.
func grow(t: float, ps: EcoPred) -> void:
	var n := ps.all.size()
	if leech_k.size() != n:
		leech_k.resize(n)
		_k_fresh = true
	var dt := t - _k_t
	_k_t = t
	var snap := _k_fresh or dt < 0.0 or dt > SNAP_DT
	_k_fresh = false
	for i in n:
		var pr := ps.all[i]
		var g := leech_k[i]
		if pr.leech:
			leech_k[i] = 1.0 if snap else minf(1.0, g + dt / LEECH_RISE)
		else:
			leech_k[i] = 0.0 if snap else maxf(0.0, g - dt / LEECH_FADE)


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
