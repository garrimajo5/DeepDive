class_name KelpView
extends Node3D
## Ленточник и шипоежи в сцене (initKelp, setKelp, urchinRender в js/creatures.js): два MultiMesh — ленты (полоса
## 0,45 × 1 м в 7 отрезков, видна с обеих сторон, колышется в шейдере по течению мира — EcoCurrent.sway; цвет экземпляра — от
## голого стебля к зелени по густоте, слабое своё свечение #0b1a10) и ежи целиком одним мешем (#849: было три вызова
## отрисовки — тело, стержни игл, кончики): тело (шар 0,2 м, #3a1f4a, слабое свечение #12061a), 18 игл по 0,32 м
## (стержни со светом, голубые кончики светятся сами). Один материал — общий шейдер растений `Plant.TENTACLE`:
## цвет вершины в альбедо, кончики светятся по альфе вершины (`TIP_A`), тело — общим `glow`. Ленты переписываются, только
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
## Альфа вершины ежа → своё свечение кончика (tip_glow = (0, 1), свет — цвет · альфа²): 1 — кончик светится сам,
## 0 — стержень и тело. Только 0 и 1: промежуточная альфа в Compatibility и Mobile читается по-разному. Слабое
## свечение тела BODY_GLOW — на весь ёж (uniform `glow`): на стержнях оно тонет, кончики и так ярче.
const TIP_A := 1.0
## Чисел на экземпляр: transform 3 × 4, у лент ещё цвет (4).
const STRIDE := 12
const STRIDE_C := 16

var kelp: EcoKelp
var stalks: MultiMeshInstance3D
## Ежи целиком (тело, стержни и кончики игл) — один MultiMesh, один вызов отрисовки (#849).
var bodies: MultiMeshInstance3D
## Последние буферы лент и ежей (для тестов).
var stalk_buffer := PackedFloat32Array()
var urchin_buffer := PackedFloat32Array()
## Сколько раз переписан буфер лент (для тестов: без перемен — не переписывается).
var stalk_writes := 0
## Муть от ежей и её MultiMesh; буфер мути — для тестов.
var dust := EcoUrchinDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()


func _init(system: EcoKelp) -> void:
	kelp = system
	name = "Ленточник"
	stalks = EcoMM.instance(self, "Ленты", build_stalk(), kelp.groves.size() * EcoKelp.KELP_N, true)
	bodies = EcoMM.instance(self, "Шипоежи", build_urchin(), kelp.urchins.size(), false)
	dust_view = GrazerView.build_dust(EcoUrchinDust.POOL)
	add_child(dust_view)
	kelp.dirty = true
	var pts := PackedVector3Array()
	for g in kelp.groves:
		for st in g.stalks:
			pts.append(st.pos)
	EcoMM.fit([stalks], pts, FRAME_GROW)
	sync(0.0)


## Запас рамки вокруг оснований лент (#849): лента до 5,5 м вверх с наклоном и качанием. Ежи ходят между
## рощами — им рамка на всю отмель.
const FRAME_GROW := 7.0


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


## Ёж одним мешем и одной поверхностью: тело — шар 0,2 м (8 × 4, гладкие нормали) цвета BODY в линейном (как
## прежний StandardMaterial), потом 18 четырёхгранных игл по спирали (угол 2,39996), от экватора чуть вниз и вверх
## (spineGeo): стержень от SPINE_BASE к SPINE_TIP, на конце — светящийся ромбик 3 см (альфа вершины TIP_A).
## Цвета вершин — в sRGB, как у прочих мешей мира с цветом вершины; все грани лицом наружу.
static func build_urchin() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	sphere.radial_segments = 8
	sphere.rings = 4
	var arr := sphere.get_mesh_arrays()
	var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var si: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var body := Color(BODY, 0.0)
	for i in range(0, si.size(), 3):
		var a := sv[si[i]]
		var b := sv[si[i + 1]]
		var c := sv[si[i + 2]]
		if (b - a).cross(c - a).length_squared() < 1e-12:
			continue   # у полюсов SphereMesh есть вырожденные
		for j in 3:
			st.set_color(body)
			st.set_normal(sn[si[i + j]])
			st.add_vertex(sv[si[i + j]])
	var tip_c := Color(SPINE_TIP, TIP_A)
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
			_shaft_tri(st, ring[j], ring[(j + 1) % 4], tip, axis)
		# кончик — маленький ромб 3 см
		var e := 0.03
		var c := tip
		var pts: Array[Vector3] = [c + side * e, c + up * e, c - side * e, c - up * e]
		for j in 4:
			EcoMM.tri(st, pts[j], pts[(j + 1) % 4], c + dir * e, tip_c, c)
			EcoMM.tri(st, pts[(j + 1) % 4], pts[j], c - dir * e, tip_c, c)
	var m := st.commit()
	m.surface_set_material(0, EcoShaders.plant(EcoShaders.Plant.TENTACLE, {"rough": 0.35, "spec": 0.6,
		"tip_glow": Vector2(0.0, 1.0), "glow": _linear(BODY_GLOW), "back": Vector3.ZERO}))
	return m


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
		st.set_color(Color(SPINE_TIP if p == top else SPINE_BASE, 0.0))
		st.set_normal(n)
		st.add_vertex(p)


## Расставить ленты (если менялись) и ежей в момент t (время мира); ship — корабль (муть дальше
## EcoGrazerDust.NEAR не поднимается, в луче прожектора светлее), flow — течение мира (уносит муть).
func sync(t: float, ship: EcoLink.ShipState = null, flow: Vector3 = Vector3.ZERO) -> void:
	if kelp.dirty:
		kelp.dirty = false
		stalk_buffer.resize(stalks.multimesh.instance_count * STRIDE_C)
		for gr in kelp.groves:
			if not gr.redraw:   # роща не менялась — её ленты в буфере верны
				continue
			gr.redraw = false
			for k in gr.stalks.size():
				var s := gr.stalks[k]
				s.drawn = s.f
				var i := (gr.index * EcoKelp.KELP_N + k) * STRIDE_C
				EcoMM.put(stalk_buffer, i, Transform3D(EcoKelp.stalk_basis(s), s.pos))
				var c := EcoKelp.stalk_color(s)
				stalk_buffer[i + 12] = c.r; stalk_buffer[i + 13] = c.g; stalk_buffer[i + 14] = c.b; stalk_buffer[i + 15] = 1.0
		stalks.multimesh.buffer = stalk_buffer
		stalk_writes += 1
	urchin_buffer.resize(kelp.urchins.size() * STRIDE)
	for u in kelp.urchins:
		var tr := Transform3D(EcoKelp.urchin_basis(u, t), u.pos) if u.alive \
			else Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -999, 0))
		EcoMM.put(urchin_buffer, u.index * STRIDE, tr)
	bodies.multimesh.buffer = urchin_buffer
	_sync_dust(t, ship, flow)


func _sync_dust(t: float, ship: EcoLink.ShipState, flow: Vector3) -> void:
	dust.update(kelp, t, ship.pos if ship else Vector3.ZERO)
	_dust.pack(dust.dust, t, flow, ship, EcoUrchinDust.COLOR, EcoUrchinDust.LIT,
		Seabed.mesh_height)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


## Расстановка экземпляра n из буфера с шагом stride.
static func transform_at(buf: PackedFloat32Array, n: int, stride: int = STRIDE_C) -> Transform3D:
	var i := n * stride
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
