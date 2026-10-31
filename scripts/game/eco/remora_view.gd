class_name RemoraView
extends MultiMeshInstance3D
## Присоски в сцене (initRemoras/remorasUpdate в js/creatures.js): все прилипалы — один MultiMesh (один вызов
## отрисовки). Рыба 35 см: серое тело-веретено (#55606a), светлая присоска-диск на темени (#d8e6ea), тёмный хвост
## (#3a444c); слабый свой свет (#0c1418), чтобы не пропадали в темноте. Масштаб 1,6 как в браузере. Нос — +Z меша
## по EcoRemora.Remora.dir; на плаву виляет хвостом (sin(14 t + ph) · 0,3 рад). Слой отмели (OceanView.LAYER_WORLD).
## Разброс (Б4, EcoVary по номеру рыбы): свой размер, частота виляния и оттенок — цвет экземпляра × цвет вершины.
## Слизь присосок (EcoRemoraDust: легла, снялась, сорвана разрядом — облачка) — дочерний MultiMesh «Муть» в мировых
## координатах на общем шейдере EcoShaders.MIST (INK): +1 вызов, шейдеров не прибавилось.
## «Экономно» (Б6, `set_lite`): тело 8 × 4 вместо 8 × 5, присоска — плоский диск 8 × 2 вместо 8 × 4 (LITE_*; по кругу
## восемь граней — нос и края диска на месте) — 120 → 72 треугольника на рыбу, пересобирается с тем же материалом; хвост,
## места, виляние, муть и вызовы те же. Сброс мира уровень не теряет (EcoView.set_lite).

const BODY := Color("55606a")
const DISC := Color("d8e6ea")
const TAIL := Color("3a444c")
const GLOW := Color("0c1418")
## Тело — эллипсоид 0,07 × 0,05 × 0,2; диск 0,05 × 0,015 × 0,09 на 0,045 выше и 0,06 вперёд; хвост — конус
## радиуса 0,05 и длины 0,1 на 0,24 позади.
const BODY_R := Vector3(0.07, 0.05, 0.2)
const DISC_R := Vector3(0.05, 0.015, 0.09)
const DISC_AT := Vector3(0, 0.045, 0.06)
const TAIL_R := 0.05
const TAIL_L := 0.1
const TAIL_Z := -0.24
const SCALE := 1.6
## Граней эллипсоидов (по кругу × по высоте): тело и диск присоски; LITE_* — на «Экономно».
const BODY_SEG := Vector2i(8, 5)
const DISC_SEG := Vector2i(8, 4)
const LITE_BODY_SEG := Vector2i(8, 4)
const LITE_DISC_SEG := Vector2i(8, 2)
const WAG := 0.3
const WAG_RATE := 14.0
## Разброс: размер ±15 %, частота виляния ±20 %, светлее-темнее ±12 %.
const SIZE_SPREAD := 0.15
const RATE_SPREAD := 0.2
const SHADE_SPREAD := 0.12

var remoras: EcoRemora
## Треугольников в меше одной рыбы (для тестов и бюджета).
var tris := 0
## Последние места (для тестов: без видеокарты MultiMesh их не хранит).
var placed: Array[Transform3D] = []
## Центр части меша у каждого треугольника (для теста обхода).
var mids := PackedVector3Array()

## Слизь присосок и её MultiMesh.
var dust := EcoRemoraDust.new()
var dust_view: MultiMeshInstance3D
## Буфер облачков (EcoDustBuffer) — для тестов.
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()

var _st := SurfaceTool.new()
## На «Экономно» — тело и диск грубее (set_lite).
var lite := false
var _mat: StandardMaterial3D


func _init(system: EcoRemora, on_lite := false) -> void:
	remoras = system
	lite = on_lite
	name = "Присоски"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = build()
	mm.instance_count = maxi(1, EcoRemora.PER_RAY * EcoRay.PATHS.size())
	multimesh = mm
	custom_aabb = AABB(Vector3(-400, -120, -400), Vector3(800, 240, 800))
	dust_view = GrazerView.build_dust(EcoRemoraDust.POOL)
	add_child(dust_view)
	sync(0.0)


## «Экономно» — меш рыбы пересобран грубее (тот же материал); назад — полный.
func set_lite(on: bool) -> void:
	if lite == on:
		return
	lite = on
	multimesh.mesh = build()


## Меш одной рыбы: три части одним мешем с цветом вершин.
func build() -> ArrayMesh:
	mids.clear()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := LITE_BODY_SEG if lite else BODY_SEG
	var d := LITE_DISC_SEG if lite else DISC_SEG
	_ellipsoid(Vector3.ZERO, BODY_R, b.x, b.y, BODY)
	_ellipsoid(DISC_AT, DISC_R, d.x, d.y, DISC)
	_cone(TAIL)
	_st.generate_normals()
	var m := _st.commit()
	tris = m.surface_get_array_len(0) / 3
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 0.7
		_mat.emission_enabled = true
		_mat.emission = GLOW
	m.surface_set_material(0, _mat)
	return m


## Поставить прилипал по миру; state — корабль (null — без слизи), flow — течение мира.
func sync(t: float, state: EcoLink.ShipState = null, flow: Vector3 = Vector3.ZERO) -> void:
	_sync_dust(t, state, flow)
	var n := multimesh.instance_count
	placed.resize(n)
	for i in n:
		var x := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
		var c := Color.WHITE
		if i < remoras.remoras.size():
			var rm := remoras.remoras[i]
			x = place(rm, t)
			var k := remora_shade(rm.index)
			c = Color(k, k, k)
		placed[i] = x
		multimesh.set_instance_transform(i, x)
		multimesh.set_instance_color(i, c)


func _sync_dust(t: float, state: EcoLink.ShipState, flow: Vector3) -> void:
	if state == null:
		return
	dust.update(remoras, t, state.pos)
	_dust.pack(dust.dust, t, flow, state, EcoRemoraDust.COLOR, EcoRemoraDust.LIT, Seabed.mesh_height)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


## Место рыбы: нос (+Z) — по dir, на плаву виляет.
static func place(rm: EcoRemora.Remora, t: float) -> Transform3D:
	var fwd := rm.dir if rm.dir.length_squared() > 1e-6 else Vector3.BACK
	var up := Vector3.UP if absf(fwd.normalized().y) < 0.99 else Vector3.BACK
	var b := Basis.looking_at(-fwd, up)  # looking_at смотрит в −Z: меш смотрит носом в +Z
	if rm.mode == EcoRemora.Mode.SWIM:
		b = b * Basis(Vector3.UP, sin(t * remora_rate(rm.index) + rm.ph) * WAG)
	return Transform3D(b.scaled_local(Vector3.ONE * SCALE * remora_scale(rm.index)), rm.p)


## Размер рыбы n (множитель к SCALE).
static func remora_scale(n: int) -> float:
	return EcoVary.spread(n, EcoVary.SIZE, SIZE_SPREAD)


## Частота виляния рыбы n, рад/с.
static func remora_rate(n: int) -> float:
	return WAG_RATE * EcoVary.spread(n, EcoVary.RATE, RATE_SPREAD)


## Светлее-темнее рыбы n (множитель цвета экземпляра).
static func remora_shade(n: int) -> float:
	return EcoVary.spread(n, EcoVary.SHADE, SHADE_SPREAD)


## Эллипсоид: кольца по широте, обход — лицом наружу (по часовой, если смотреть снаружи).
func _ellipsoid(c: Vector3, r: Vector3, seg: int, rings: int, col: Color) -> void:
	var pts: Array[Vector3] = []
	for j in rings + 1:
		var th := PI * j / rings
		for i in seg + 1:
			var ph := TAU * i / seg
			pts.append(c + Vector3(sin(th) * cos(ph) * r.x, cos(th) * r.y, sin(th) * sin(ph) * r.z))
	var row := seg + 1
	for j in rings:
		for i in seg:
			var a := j * row + i
			_tri(pts[a], pts[a + 1], pts[a + row], col, c)
			_tri(pts[a + 1], pts[a + row + 1], pts[a + row], col, c)


## Хвост — конус из 4 граней назад, донце к телу.
func _cone(col: Color) -> void:
	var tip := Vector3(0, 0, TAIL_Z - TAIL_L * 0.5)
	var base := TAIL_Z + TAIL_L * 0.5
	var ring: Array[Vector3] = []
	for i in 5:
		var a := TAU * i / 4.0
		ring.append(Vector3(cos(a) * TAIL_R, sin(a) * TAIL_R, base))
	var mid := Vector3(0, 0, TAIL_Z)
	for i in 4:
		_tri(ring[i], tip, ring[i + 1], col, mid)
		_tri(ring[i + 1], Vector3(0, 0, base), ring[i], col, mid)


## Треугольник лицом наружу от центра фигуры mid: у лицевой (b − a) × (c − a) смотрит внутрь (правило проекта).
func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color, mid: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	if n.dot((a + b + c) / 3.0 - mid) > 0.0:
		var t := b
		b = c
		c = t
	mids.append(mid)
	_st.set_color(col)
	_st.add_vertex(a)
	_st.set_color(col)
	_st.add_vertex(b)
	_st.set_color(col)
	_st.add_vertex(c)
