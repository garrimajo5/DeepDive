class_name KelpView
extends Node3D
## Ленточник и шипоежи в сцене (initKelp, setKelp, urchinRender в js/creatures.js): три MultiMesh — ленты (полоса
## 0,45 × 1 м в 7 отрезков, видна с обеих сторон, колышется в шейдере по течению мира — EcoCurrent.sway; цвет экземпляра — от
## голого стебля к зелени по густоте, слабое своё свечение #0b1a10), тела ежей (икосаэдр 0,2 м, #3a1f4a, свечение
## #12061a) и иглы (18 игл по 0,32 м: стержни со светом, голубые кончики светятся сами). Ленты переписываются, только
## когда ёж их объел или они отросли (EcoKelp.dirty). Ленты — общий шейдер растений (EcoShaders.PLANT). Муть у дна
## от ежей (EcoUrchinDust) — дочерний MultiMesh «Муть» в мировых координатах, общий шейдер EcoShaders.MIST (INK).
## Стоит на слое отмели (OceanView.LAYER_WORLD).

const KELP_GLOW := Color("0b1a10")
## Колыхание ленты в течении (EcoCurrent.sway): крен, волна вверх, поперёк — доли высоты ленты.
const BEND := Vector3(0.12, 0.1, 0.06)
const SEGMENTS := 7
const BODY := Color("3a1f4a")
const BODY_GLOW := Color("12061a")
## Иглы ежа (spineGeo(18, 0.32, …, 0.18)): основание и кончик.
const SPINES := 18
const SPINE_LEN := 0.32
const SPINE_R := 0.18
const SPINE_BASE := Color(0.25, 0.12, 0.35)
const SPINE_TIP := Color(0.55, 0.95, 1.0)
## Чисел на экземпляр: transform 3 × 4, у лент ещё цвет (4).
const STRIDE := 12
const STRIDE_C := 16

var kelp: EcoKelp
var stalks: MultiMeshInstance3D
var bodies: MultiMeshInstance3D
var spines: MultiMeshInstance3D
## Последние буферы лент и ежей (для тестов).
var stalk_buffer := PackedFloat32Array()
var urchin_buffer := PackedFloat32Array()
## Сколько раз переписан буфер лент (для тестов: без перемен — не переписывается).
var stalk_writes := 0
## Муть от ежей и её MultiMesh; буфер мути — для тестов.
var dust := EcoUrchinDust.new()
var dust_view: MultiMeshInstance3D
var dust_buffer := PackedFloat32Array()
var _dust_empty := false


func _init(system: EcoKelp) -> void:
	kelp = system
	name = "Ленточник"
	stalks = _instance("Ленты", build_stalk(), kelp.groves.size() * EcoKelp.KELP_N, true)
	bodies = _instance("Шипоежи", build_body(), kelp.urchins.size(), false)
	spines = _instance("Иглы", build_spines(), kelp.urchins.size(), false)
	dust_view = GrazerView.build_dust(EcoUrchinDust.POOL)
	add_child(dust_view)
	kelp.dirty = true
	sync(0.0)


func _instance(n: String, mesh: Mesh, count: int, colors: bool) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = n
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = count
	mi.multimesh = mm
	mi.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	add_child(mi)
	return mi


## Полоса ленты: ширина EcoKelp.WIDTH (экземпляр сужает её по густоте), высота 1 от основания, нормаль +Z.
static func build_stalk() -> ArrayMesh:
	var w := EcoKelp.WIDTH / 2.0
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for k in SEGMENTS + 1:
		var y := float(k) / SEGMENTS
		v.append_array([Vector3(-w, y, 0), Vector3(w, y, 0)])
		nr.append_array([Vector3.BACK, Vector3.BACK])
		uv.append_array([Vector2(0, 1 - y), Vector2(1, 1 - y)])
	for k in SEGMENTS:
		var a := k * 2
		# лицом к +Z: обход по часовой, если смотреть с +Z
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, EcoShaders.plant(EcoShaders.Plant.KELP, {"rough": 0.9,
		"glow": _linear(KELP_GLOW), "bend": BEND, "reach": 1.0}))
	return m


## Цвет из sRGB в линейный (свечение в общем шейдере растений — без source_color).
static func _linear(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)


static func build_body() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.2
	m.height = 0.4
	m.radial_segments = 8
	m.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BODY
	mat.roughness = 0.9
	mat.emission_enabled = true
	mat.emission = BODY_GLOW
	m.material = mat
	return m


## Иглы ежа одним мешем: 18 четырёхгранных конусов по спирали (угол 2,39996), от экватора чуть вниз и вверх,
## на конце — светящийся кончик (spineGeo). Стержни освещаются (цвет от основания к кончику), кончики светятся
## сами — две поверхности KrabView.spine_mesh; все грани лицом наружу.
static func build_spines() -> ArrayMesh:
	var shaft := SurfaceTool.new()
	shaft.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow := SurfaceTool.new()
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in SPINES:
		var y := 1.0 - (k + 0.5) / SPINES * 1.2
		var rr := sqrt(maxf(0.0, 1.0 - y * y))
		var a := k * 2.39996
		var dir := Vector3(cos(a) * rr, maxf(y, -0.15), sin(a) * rr).normalized()
		var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(dir)
		var base := dir * SPINE_R * 0.8
		var tip := dir * (SPINE_R * 0.8 + SPINE_LEN)
		var ring: Array[Vector3] = []
		for j in 4:
			var t := j * TAU / 4.0
			ring.append(base + (side * cos(t) + up * sin(t)) * 0.02)
		var axis := base + dir * SPINE_LEN / 3.0   # ось на высоте середины грани — грань смотрит от неё
		for j in 4:
			_shaft_tri(shaft, ring[j], ring[(j + 1) % 4], tip, axis)
		# кончик — маленький ромб 3 см
		var e := 0.03
		var c := tip
		var pts: Array[Vector3] = [c + side * e, c + up * e, c - side * e, c - up * e]
		for j in 4:
			KrabView._tri(glow, pts[j], pts[(j + 1) % 4], c + dir * e, SPINE_TIP, c)
			KrabView._tri(glow, pts[(j + 1) % 4], pts[j], c - dir * e, SPINE_TIP, c)
	return KrabView.spine_mesh(shaft, glow)


## Грань стержня иглы: основание a, b цвета SPINE_BASE, кончик c — SPINE_TIP; лицом наружу от точки оси inside.
static func _shaft_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var top := c
	var n := (b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - inside) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = -n.normalized()
	for p in [a, b, c]:
		st.set_color(SPINE_TIP if p == top else SPINE_BASE)
		st.set_normal(n)
		st.add_vertex(p)


## Расставить ленты (если менялись) и ежей в момент t (время мира); ship — корабль (муть дальше
## EcoGrazerDust.NEAR не поднимается, в луче прожектора светлее), flow — течение мира (уносит муть).
func sync(t: float, ship: EcoLink.ShipState = null, flow: Vector3 = Vector3.ZERO) -> void:
	if kelp.dirty:
		kelp.dirty = false
		stalk_buffer.resize(stalks.multimesh.instance_count * STRIDE_C)
		for gr in kelp.groves:
			for k in gr.stalks.size():
				var s := gr.stalks[k]
				s.drawn = s.f
				var i := (gr.index * EcoKelp.KELP_N + k) * STRIDE_C
				_put(stalk_buffer, i, Transform3D(EcoKelp.stalk_basis(s), s.pos))
				var c := EcoKelp.stalk_color(s)
				stalk_buffer[i + 12] = c.r; stalk_buffer[i + 13] = c.g; stalk_buffer[i + 14] = c.b; stalk_buffer[i + 15] = 1.0
		stalks.multimesh.buffer = stalk_buffer
		stalk_writes += 1
	urchin_buffer.resize(kelp.urchins.size() * STRIDE)
	for u in kelp.urchins:
		var tr := Transform3D(EcoKelp.urchin_basis(u, t), u.pos) if u.alive \
			else Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -999, 0))
		_put(urchin_buffer, u.index * STRIDE, tr)
	bodies.multimesh.buffer = urchin_buffer
	spines.multimesh.buffer = urchin_buffer
	_sync_dust(t, ship, flow)


func _sync_dust(t: float, ship: EcoLink.ShipState, flow: Vector3) -> void:
	dust.update(kelp, t, ship.pos if ship else Vector3.ZERO)
	var shown := dust.dust.shown(t)
	if shown == 0 and _dust_empty and dust_buffer.size() == EcoUrchinDust.POOL * GrazerView.DUST_STRIDE:
		return
	dust_buffer = GrazerView.pack_dust(dust.dust, t, flow, ship, EcoUrchinDust.COLOR, EcoUrchinDust.LIT,
		Seabed.mesh_height)
	dust_view.multimesh.buffer = dust_buffer
	_dust_empty = shown == 0


static func _put(buf: PackedFloat32Array, i: int, tr: Transform3D) -> void:
	var b := tr.basis
	var o := tr.origin
	buf[i] = b.x.x; buf[i + 1] = b.y.x; buf[i + 2] = b.z.x; buf[i + 3] = o.x
	buf[i + 4] = b.x.y; buf[i + 5] = b.y.y; buf[i + 6] = b.z.y; buf[i + 7] = o.y
	buf[i + 8] = b.x.z; buf[i + 9] = b.y.z; buf[i + 10] = b.z.z; buf[i + 11] = o.z


## Расстановка экземпляра n из буфера с шагом stride.
static func transform_at(buf: PackedFloat32Array, n: int, stride: int = STRIDE_C) -> Transform3D:
	var i := n * stride
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
