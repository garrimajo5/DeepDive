class_name KrabView
extends Node3D
## Кольчужник в сцене (initKelp — нора, crabUpdate, crabSpines в js/creatures.js): нора из пяти приплюснутых камней
## (#4f4a5c, гранёные), тело — панцирь-эллипсоид (#8a4a2e, слабое свечение #1a0804) и шесть ног одним мешем,
## клешни отдельным мешем (поднимаются на 0,9 · raise), иглы ежей на панцире — MultiMesh на 10 игл (стержень со
## светом, кончик светится сам; лишние сжаты в точку), переписывается, только когда игл стало больше (EcoKrab.dirty). Тело в 1,25 раза крупнее, на ходу
## подпрыгивает на 3 см. Муть у дна из-под ног и от клешней (EcoKrabDust) — дочерний MultiMesh «Муть» в мировых
## координатах, общий шейдер EcoShaders.MIST (INK), бурый цвет EcoKrabDust.COLOR/LIT. Шесть вызовов отрисовки (у игл две поверхности); стоит на слое
## отмели (OceanView.LAYER_WORLD).

const ROCK := Color("4f4a5c")
const SHELL := Color("8a4a2e")
const LEG := Color("6a3a26")
const ARM := Color("7a4028")
const PINCER := Color("c06a3a")
const GLOW := Color("1a0804")
const SPINE_BASE := Color(0.3, 0.15, 0.4)
const SPINE_TIP := Color(0.55, 0.95, 1.0)
const SCALE := 1.25
## Камни норы: смещение (нос норы — наружу от рощи, +Z) и размер 0,8…1,1 м, приплюснуты до 0,6 по высоте.
const ROCKS: Array[Vector3] = [Vector3(-1.3, 0.3, -0.4), Vector3(1.3, 0.3, -0.4), Vector3(0, 0.8, -1.1),
	Vector3(-0.6, 1.3, -0.9), Vector3(0.7, 0.2, -1.6)]
const ROCK_SIZES: Array[float] = [0.95, 1.05, 0.85, 0.9, 1.0]
const CLAWS_AT := Vector3(0, 0.35, 0.3)

var krab: EcoKrab
var den: MeshInstance3D
var body: MeshInstance3D
var claws: MeshInstance3D
var spines: MultiMeshInstance3D
## Сколько игл видно (для тестов) и сколько раз переписаны иглы.
var shown_spines := 0
var spine_writes := 0
## Последний буфер игл (KelpView.transform_at с шагом KelpView.STRIDE).
var spine_buffer := PackedFloat32Array()
## Муть от краба и её MultiMesh; буфер мути — для тестов.
var dust := EcoKrabDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()


func _init(system: EcoKrab) -> void:
	krab = system
	name = "Кольчужник"
	var cr := krab.crab
	den = _mesh("Нора", build_den(), self)
	body = _mesh("Тело", build_body(), self)
	claws = _mesh("Клешни", build_claws(), body)
	claws.position = CLAWS_AT
	spines = MultiMeshInstance3D.new()
	spines.name = "Иглы"
	spines.layers = OceanView.LAYER_WORLD
	spines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = build_spine()
	mm.instance_count = EcoKrab.SPINE_MAX
	spines.multimesh = mm
	spines.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	body.add_child(spines)
	body.scale = Vector3.ONE * SCALE
	dust_view = GrazerView.build_dust(EcoKrabDust.POOL)
	add_child(dust_view)
	visible = cr != null
	if cr:
		den.transform = Transform3D(Basis(Vector3.UP, atan2(cr.out.x, cr.out.z)), cr.den)
	krab.dirty = true
	sync(0.0)


func _mesh(n: String, m: Mesh, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.layers = OceanView.LAYER_WORLD
	EcoShadows.cast(mi)
	parent.add_child(mi)
	return mi


## Расставить краба в момент t (время мира). ship — корабль (дальше EcoGrazerDust.NEAR муть не поднимается, в луче
## прожектора светлее), flow — течение мира (уносит муть).
func sync(t: float, ship: EcoLink.ShipState = null, flow: Vector3 = Vector3.ZERO) -> void:
	var cr := krab.crab
	if cr == null:
		return
	_sync_dust(t, ship, flow)
	var p := cr.pos
	if cr.moving:
		p.y += absf(sin(t * 8.0)) * 0.03
	body.transform = Transform3D(Basis(Vector3.UP, atan2(cr.dir.x, cr.dir.z)).scaled(Vector3.ONE * SCALE), p)
	claws.rotation = Vector3(-cr.raise * 0.9, 0, 0)
	if krab.dirty:
		krab.dirty = false
		spine_buffer.resize(EcoKrab.SPINE_MAX * KelpView.STRIDE)
		for k in EcoKrab.SPINE_MAX:
			var tr := spine_transform(k) if k < cr.spines else Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
			EcoMM.put(spine_buffer, k * KelpView.STRIDE, tr)
		spines.multimesh.buffer = spine_buffer
		shown_spines = cr.spines
		spine_writes += 1


func _sync_dust(t: float, ship: EcoLink.ShipState, flow: Vector3) -> void:
	dust.update(krab, t, ship.pos if ship else Vector3.ZERO)
	_dust.pack(dust.dust, t, flow, ship, EcoKrabDust.COLOR, EcoKrabDust.LIT,
			Seabed.mesh_height)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


## Место иглы k на панцире: по кругу, наклонена наружу (crab spineM).
static func spine_transform(k: int) -> Transform3D:
	var a := float(k) / EcoKrab.SPINE_MAX * TAU + 0.3
	var b := Basis(Vector3.RIGHT, sin(a) * 0.9) * Basis(Vector3.BACK, -cos(a) * 0.9)
	return Transform3D(b, Vector3(cos(a) * 0.38, 0.45, sin(a) * 0.3))


## Нора: пять гранёных камней, приплюснутых по высоте.
static func build_den() -> ArrayMesh:
	var st := _begin()
	for i in ROCKS.size():
		var s := ROCK_SIZES[i]
		EcoMM.ellipsoid(st, ROCKS[i], Vector3(s, s * 0.6, s), 5, 3, ROCK, 0.17 * i)
	return _commit(st, false)


## Панцирь и шесть ног (по три с борта, разведены веером и опущены к дну).
static func build_body() -> ArrayMesh:
	var st := _begin()
	EcoMM.ellipsoid(st, Vector3(0, 0.35, 0), Vector3(0.55, 0.22, 0.42), 10, 6, SHELL)
	for sx in [-1.0, 1.0]:
		for z in [-0.25, 0.0, 0.25]:
			var yaw: float = -z * 1.5 if sx > 0 else PI + z * 1.5
			var b := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, -0.5)
			var tr := Transform3D(b, Vector3(sx * 0.4, 0.33, z))
			_box(st, tr, Vector3(0.27, 0, 0), Vector3(0.55, 0.05, 0.06), LEG)
	return _commit(st, true)


## Клешни: две руки вперёд и щипцы на концах.
static func build_claws() -> ArrayMesh:
	var st := _begin()
	for sx in [-1.0, 1.0]:
		_box(st, Transform3D.IDENTITY, Vector3(sx * 0.22, 0, 0.2), Vector3(0.08, 0.08, 0.4), ARM)
		EcoMM.ellipsoid(st, Vector3(sx * 0.24, 0, 0.5), Vector3(0.11, 0.08, 0.2), 8, 5, PINCER)
	return _commit(st, true)


## Игла ежа: четырёхгранный конус 0,3 м и светящийся кончик-ромб. Стержень освещается (ловит свет сквозь лёд,
## прожектор и тени), сам светится только кончик — две поверхности, см. spine_mesh.
static func build_spine() -> ArrayMesh:
	var shaft := _begin()
	var glow := _begin()
	var tip := Vector3(0, 0.3, 0)
	var ring: Array[Vector3] = []
	for j in 4:
		var t := j * TAU / 4.0
		ring.append(Vector3(cos(t), 0, sin(t)) * 0.025)
	var mid := Vector3(0, 0.1, 0)
	for j in 4:
		EcoMM.tri(shaft, ring[j], ring[(j + 1) % 4], tip, SPINE_BASE, mid)
		EcoMM.tri(shaft, ring[(j + 1) % 4], ring[j], Vector3.ZERO, SPINE_BASE, mid)
	var e := 0.03
	var pts: Array[Vector3] = [tip + Vector3(e, 0, 0), tip + Vector3(0, 0, e), tip - Vector3(e, 0, 0), tip - Vector3(0, 0, e)]
	for j in 4:
		EcoMM.tri(glow, pts[j], pts[(j + 1) % 4], tip + Vector3(0, e, 0), SPINE_TIP, tip)
		EcoMM.tri(glow, pts[j], pts[(j + 1) % 4], tip - Vector3(0, e, 0), SPINE_TIP, tip)
	return spine_mesh(shaft, glow)


## Игла из двух поверхностей: 0 — стержень со светом (цвет вершин, матовый — тот же шейдер, что у норы), 1 — кончик
## без освещения (светится сам). Новых шейдеров нет; у MultiMesh игл — два вызова отрисовки.
static func spine_mesh(shaft: SurfaceTool, glow: SurfaceTool) -> ArrayMesh:
	var m := shaft.commit()
	var lit := StandardMaterial3D.new()
	lit.vertex_color_use_as_albedo = true
	lit.roughness = 0.6
	m.surface_set_material(0, lit)
	glow.commit(m)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	m.surface_set_material(1, mat)
	return m


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _commit(st: SurfaceTool, glow: bool) -> ArrayMesh:
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	if glow:
		mat.emission_enabled = true
		mat.emission = GLOW
	m.surface_set_material(0, mat)
	return m




## Брусок размером size с серединой at в системе tr.
static func _box(st: SurfaceTool, tr: Transform3D, at: Vector3, size: Vector3, col: Color) -> void:
	var h := size / 2.0
	var v: Array[Vector3] = []
	for k in 8:
		v.append(tr * (at + Vector3(h.x if k & 1 else -h.x, h.y if k & 2 else -h.y, h.z if k & 4 else -h.z)))
	var mid := tr * at
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		EcoMM.tri(st, v[f[0]], v[f[1]], v[f[2]], col, mid)
		EcoMM.tri(st, v[f[0]], v[f[2]], v[f[3]], col, mid)
