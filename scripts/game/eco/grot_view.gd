class_name GrotView
extends Node3D
## Гротовик в сцене (grotGeo, grotLegsGeo, grotReefGeo, grotUpdate в js/creatures.js): панцирь-купол 4,8 × 2,2 × 6,4 м
## (#5b5a4a) с ободом (#3e3b30) и головой спереди (+Z, #6b6656) — один меш со слабым свечением #0e0c08; шесть ног
## (#4a473a) — свой меш: на ходу шагают треногами (`leg_step`, ниже), прячутся под панцирь (высота 0,35 + 0,65 · lift);
## риф на спине — 11 веток огнецвета (#b35933) и 6 мшистых бугров (#59cc8c), свечение #2a1004; светящиеся кончики
## веток и жёлтые глаза — отдельный меш без освещения. Четыре вызова отрисовки, ≈ 1,6 тыс. треугольников;
## слой отмели (OceanView.LAYER_WORLD); дальше FAR от корабля не виден в мути.
## Муть у дна (EcoGrotDust: облачко у ступни на каждом шаге, панцирь осел — клуб у обода, ноги снова выпущены — у
## ступней) — дочерний MultiMesh «Муть» на общем шейдере мира (+1 вызов).
## «Экономно» (Б6, `set_lite`): панцирь, обод, голова, бугры рифа, кончики веток и глаза — грубее сетка (LITE_*,
## треугольников меньше половины); ноги и ветки те же, мир, муть, вызовы и силуэт те же. Сброс мира уровень не теряет
## (вид не пересоздаётся, EcoView.set_lite).
## «Дыхание» (Б3, `breath`): панцирь с рифом и огоньками набирает воду и выталкивает её — высота ± BREATH_H, ширина
## ± BREATH_W за BREATH_T с, низ панциря стоит (масштаб от узла на теле), длина не меняется — голова и глаза на месте.
## Ноги спрятаны (испуг, `lift` → 0) — затаил дыхание: HELD размаха; доля по `lift` плавная — размах не прыгает.
## По времени мира (у гостя то же), масштаб узлов — даром, и на «Экономно».
## Шаг ног (Б3): ноги ходят вперёд-назад вокруг бедра двумя треногами вразнобой (левая передняя, правая средняя, левая
## задняя — против остальных, как облачка EcoGrotDust.STEP_ORDER) — до LEG_SWING рад, вперёд — со стопой, поднятой до
## LEG_LIFT м; ритм LEG_RATE, размах — по доле шага `stride` (плавной). Раньше все шесть ног качались одним мешем
## в такт — остров «ехал» на ногах. Стопа на дне уходит назад почти со скоростью хода (EcoGrot.SPEED) — не скользит.
## На CPU: меш ног пересобирается из массивов покоя (`legs_rest`/`pose_arrays`), только пока ноги двигаются и корабль
## ближе LEG_FAR; встал — один раз в покой. Шейдеров и вызовов не прибавилось, и на «Экономно».

const SHELL := Color("5b5a4a")
const RIM := Color("3e3b30")
const HEAD := Color("6b6656")
const EYE := Color("ffe08a")
const LEG := Color("4a473a")
const WOOD := Color(0.7, 0.35, 0.2)
const TIP := Color(1.0, 0.75, 0.35)
const MOSS := Color(0.35, 0.8, 0.55)
const BODY_GLOW := Color("0e0c08")
const REEF_GLOW := Color("2a1004")
## Ноги: по три с борта на x = ± LEG_X, z из LEG_Z, верх на LEG_Y, развал наружу LEG_TILT рад.
const LEG_X := 2.1
const LEG_Y := 0.35
const LEG_Z: Array[float] = [-1.8, 0.0, 1.8]
const LEG_TILT := 0.5
## Длина ноги (м), шаг: размах вокруг бедра (рад), подъём стопы (м), ритм (рад/с); дальше LEG_FAR м ноги не шагают.
const LEG_LEN := 1.1
const LEG_SWING := 0.34
const LEG_LIFT := 0.12
const LEG_RATE := 2.2
const LEG_FAR := 60.0
## Меш ног переписывается не чаще LEG_EVERY с (15 раз в секунду — шаг медленный, глаз не заметит), покой — сразу.
const LEG_EVERY := 1.0 / 15.0
## Ветки рифа и мшистые бугры.
const BRANCHES := 11
const BUMPS := 6
const FAR := 160.0
const BREATH_H := 0.04
const BREATH_W := 0.02
const BREATH_T := 6.0
const HELD := 0.3
## Сетка на «Экономно»: панцирь (сегменты × кольца), обод (сегменты × стороны трубки), голова, бугры, огоньки.
const LITE_SHELL := Vector2i(10, 3)
const LITE_RIM := Vector2i(12, 3)
const LITE_HEAD := Vector2i(6, 4)
const LITE_BUMP := Vector2i(5, 3)
const LITE_TIP := Vector2i(4, 2)

var grots: EcoGrot
## Узел гротовика: стоит на теле (низ панциря), повёрнут по курсу.
var group: Node3D
var body: MeshInstance3D
var legs: MeshInstance3D
## Поза ног в последнем меше (по два числа на ногу: угол вокруг бедра, подъём стопы) и массивы покоя (legs_rest).
var leg_pose := PackedFloat32Array()
var _rest: Dictionary = {}
var _leg_t := -1e9
var reef: MeshInstance3D
var glow: MeshInstance3D
var dust := EcoGrotDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()


## На «Экономно» — грубее сетка (set_lite).
var lite := false
## Меши тела, рифа и свечения по уровню (#1798): смена «Экономно» их не пересобирает.
var _variants := {}


func _init(system: EcoGrot, on_lite := false) -> void:
	grots = system
	lite = on_lite
	name = "Гротовик"
	group = Node3D.new()
	group.name = "Гротовик"
	add_child(group)
	body = _mesh("Панцирь", build_body(lite), _lit(BODY_GLOW))
	_rest = legs_rest()
	legs = _mesh("Ноги", _rest["mesh"], _lit(Color.BLACK))
	reef = _mesh("Риф", build_reef(lite), _lit(REEF_GLOW))
	var bright := StandardMaterial3D.new()
	bright.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bright.vertex_color_use_as_albedo = true
	glow = _mesh("Огоньки", build_glow(lite), bright)
	dust_view = GrazerView.build_dust(EcoGrotDust.POOL)
	add_child(dust_view)
	sync(0.0, Vector3.ZERO)


func _mesh(n: String, m: ArrayMesh, mat: Material) -> MeshInstance3D:
	m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.layers = OceanView.LAYER_WORLD
	EcoShadows.cast(mi, n != "Огоньки")
	group.add_child(mi)
	return mi


## «Экономно» — панцирь, риф и огоньки пересобраны грубее (материалы те же).
func set_lite(on: bool) -> void:
	if lite == on:
		return
	_variants[lite] = [body.mesh, reef.mesh, glow.mesh]
	lite = on
	var ms: Array = _variants[on] if _variants.has(on) else _build_variant(on)
	for i in 3:
		[body, reef, glow][i].mesh = ms[i]


## Собрать второй вариант заранее (EcoView.prefetch_lite); вид не меняется. true — собирали.
func prefetch_lite() -> bool:
	if _variants.has(not lite):
		return false
	_variants[not lite] = _build_variant(not lite)
	return true


## Меши тела, рифа и свечения на уровень on — с материалами нынешних (общие у вариантов).
func _build_variant(on: bool) -> Array:
	var out := []
	for pair in [[body, build_body(on)], [reef, build_reef(on)], [glow, build_glow(on)]]:
		var mi: MeshInstance3D = pair[0]
		var m: ArrayMesh = pair[1]
		m.surface_set_material(0, mi.mesh.surface_get_material(0))
		out.append(m)
	return out


static func _lit(emission: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
	return mat


## Поставить гротовика в момент t (время мира); ship — центр корабля (дальше FAR — спрятан). info — корабль целиком
## (муть светлее в луче прожектора), flow — течение мира (уносит муть).
func sync(t: float, ship: Vector3, info: EcoLink.ShipState = null, flow := Vector3.ZERO) -> void:
	_sync_dust(t, ship, info, flow)
	var gr := grots.grot
	visible = gr != null and Vector3(gr.p.x, gr.body_y, gr.p.z).distance_to(ship) < FAR
	if not visible:
		return
	group.transform = Transform3D(gr.basis(), Vector3(gr.p.x, gr.body_y, gr.p.z))
	var far := Vector3(gr.p.x, gr.body_y, gr.p.z).distance_to(ship) > LEG_FAR
	_step_legs(t, 0.0 if far else gr.stride)
	legs.scale = Vector3(1.0, 0.35 + 0.65 * gr.lift, 1.0)
	var b := breath(gr.lift, t)
	body.scale = b
	reef.scale = b
	glow.scale = b


## Масштаб панциря с рифом в момент t при выпущенных ногах lift (0 — спрятаны): вдох — выше и шире, длина та же;
## ноги спрятаны — HELD размаха.
static func breath(lift: float, t: float) -> Vector3:
	var k := lerpf(HELD, 1.0, clampf(lift, 0.0, 1.0)) * sin(t * TAU / BREATH_T)
	return Vector3(1.0 + BREATH_W * k, 1.0 + BREATH_H * k, 1.0)


func _sync_dust(t: float, ship: Vector3, info: EcoLink.ShipState, flow: Vector3) -> void:
	dust.update(grots, t, ship)
	_dust.pack(dust.dust, t, flow, info, EcoGrotDust.COLOR, EcoGrotDust.LIT,
			Seabed.mesh_height)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


## Панцирь (верхняя половина эллипсоида), обод по краю и голова спереди.
static func build_body(on_lite := false) -> ArrayMesh:
	var st := KrabView._begin()
	var sh := LITE_SHELL if on_lite else Vector2i(16, 5)
	var rim := LITE_RIM if on_lite else Vector2i(20, 5)
	var hd := LITE_HEAD if on_lite else Vector2i(10, 6)
	EcoMM.ellipsoid(st, Vector3.ZERO, EcoGrot.SHELL, sh.x, sh.y, SHELL, 0.0, 0.5)
	_ring(st, Vector3(EcoGrot.SHELL.x, 1.0, EcoGrot.SHELL.z), 0.12, rim.x, rim.y, RIM)
	EcoMM.ellipsoid(st, Vector3(0, 0.25, 3.4), Vector3(0.55, 0.385, 0.66), hd.x, hd.y, HEAD)
	return st.commit()


## Шесть ног: усечённые конусы 1,1 м (сверху 0,22, снизу 0,3), разведены наружу — в покое.
static func build_legs() -> ArrayMesh:
	return legs_rest()["mesh"]


## Бедро ноги i (0…2 — левый борт x < 0 по LEG_Z, 3…5 — правый).
static func hip(i: int) -> Vector3:
	return Vector3((-1.0 if i < 3 else 1.0) * LEG_X, LEG_Y, LEG_Z[i % 3])


## Ноги в покое: меш, его массивы и номер ноги у каждой вершины (для pose_arrays).
static func legs_rest() -> Dictionary:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var leg := PackedInt32Array()
	for i in 6:
		var sx := -1.0 if i < 3 else 1.0
		var st := KrabView._begin()
		_cone(st, Transform3D(Basis(Vector3.BACK, sx * LEG_TILT), hip(i)), 0.22, 0.3, LEG_LEN, 6, LEG)
		var la := st.commit_to_arrays()
		var lv: PackedVector3Array = la[Mesh.ARRAY_VERTEX]
		v.append_array(lv)
		n.append_array(la[Mesh.ARRAY_NORMAL])
		c.append_array(la[Mesh.ARRAY_COLOR])
		var add := PackedInt32Array()
		add.resize(lv.size())
		add.fill(i)
		leg.append_array(add)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return {"mesh": m, "arrays": arr, "leg": leg}


## Ход ноги i в момент t при доле шага k: x — доля выноса −1…1 (вперёд — к голове +Z), y — подъём стопы 0…1 (только
## на выносе вперёд). Треноги: ноги 0, 2, 4 и 1, 3, 5 — в противофазе. k = 0 — покой.
static func leg_step(i: int, t: float, k: float) -> Vector2:
	k = clampf(k, 0.0, 1.0)
	if k <= 0.0:
		return Vector2.ZERO
	var ph := t * LEG_RATE + PI * float((int(i / 3.0) + i % 3) % 2)
	return Vector2(sin(ph) * k, maxf(0.0, cos(ph)) * k)


## Поставить ноги к моменту t при доле шага k: меш пересобирается, только если поза сдвинулась.
func _step_legs(t: float, k: float) -> void:
	var a := PackedFloat32Array()
	a.resize(12)
	for i in 6:
		var s := leg_step(i, t, k)
		a[i * 2] = -s.x * LEG_SWING
		a[i * 2 + 1] = s.y * LEG_LIFT
	if a == leg_pose:
		return
	if k > 0.0 and absf(t - _leg_t) < LEG_EVERY and not leg_pose.is_empty():
		return
	_leg_t = t
	leg_pose = a
	var m := legs.mesh as ArrayMesh
	var mat := m.surface_get_material(0)
	m.clear_surfaces()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, pose_arrays(_rest, a))
	m.surface_set_material(0, mat)


## Массивы ног в позе a (на ногу: угол вокруг оси X через бедро — минус вперёд, подъём стопы в м): нога поворачивается
## вокруг бедра, подъём растёт к стопе по доле глубины под бедром.
static func pose_arrays(rest: Dictionary, a: PackedFloat32Array) -> Array:
	var arr: Array = (rest["arrays"] as Array).duplicate()
	var v: PackedVector3Array = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var n: PackedVector3Array = (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var leg: PackedInt32Array = rest["leg"]
	var inv_drop := 1.0 / (LEG_LEN * cos(LEG_TILT))
	var hips: Array[Vector3] = []
	var turns: Array[Basis] = []
	for i in 6:
		hips.append(hip(i))
		turns.append(Basis(Vector3.RIGHT, a[i * 2]))
	for j in v.size():
		var i := leg[j]
		var h := hips[i]
		var b := turns[i]
		var d := v[j] - h
		v[j] = h + b * d
		v[j].y += a[i * 2 + 1] * clampf(-d.y * inv_drop, 0.0, 1.0)
		n[j] = b * n[j]
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	return arr


## Стопа ноги i в осях гротовика в позе a (для тестов: куда встала нога).
static func foot(i: int, a: PackedFloat32Array) -> Vector3:
	var sx := -1.0 if i < 3 else 1.0
	var d := Basis(Vector3.BACK, sx * LEG_TILT) * Vector3(0, -LEG_LEN, 0)
	return hip(i) + Basis(Vector3.RIGHT, a[i * 2]) * d + Vector3(0, a[i * 2 + 1], 0)


## Место ветки k рифа на панцире (золотой угол по куполу, наклон наружу) и её длина.
static func branch(k: int) -> Transform3D:
	var a := k * 2.39996
	var r := sqrt((k + 0.5) / BRANCHES) * 0.85
	var at := Vector3(cos(a) * r * 2.1, sqrt(maxf(0.0, 1.0 - r * r)) * 1.05, sin(a) * r * 2.8)
	return Transform3D(Basis(Vector3(sin(a), 0, -cos(a)), 0.25 + (k % 2) * 0.2), at)


static func branch_len(k: int) -> float:
	return 0.9 + (k % 3) * 0.35


## Риф: ветки огнецвета (конусы 0,14 → 0,06) и приплюснутые мшистые бугры.
static func build_reef(on_lite := false) -> ArrayMesh:
	var st := KrabView._begin()
	var bump := LITE_BUMP if on_lite else Vector2i(8, 5)
	for k in BRANCHES:
		_cone(st, branch(k), 0.06, 0.14, branch_len(k), 5, WOOD, true)
	for k in BUMPS:
		var a := k * 1.1 + 0.4
		EcoMM.ellipsoid(st, Vector3(cos(a) * 1.5, 0.8, sin(a) * 2.1), Vector3(0.45, 0.2, 0.45), bump.x, bump.y, MOSS)
	return st.commit()


## Светящиеся кончики веток и глаза.
static func build_glow(on_lite := false) -> ArrayMesh:
	var st := KrabView._begin()
	var tp := LITE_TIP if on_lite else Vector2i(6, 4)
	for k in BRANCHES:
		var tip := branch(k) * Vector3(0, branch_len(k), 0)
		EcoMM.ellipsoid(st, tip, Vector3.ONE * 0.16, tp.x, tp.y, TIP)
	for sx in [-1.0, 1.0]:
		EcoMM.ellipsoid(st, Vector3(sx * 0.3, 0.45, 3.85), Vector3.ONE * 0.09, tp.x, tp.y, EYE)
	return st.commit()



## Обод: тор с трубкой tube вокруг эллипса scale (x, z) в плоскости y = 0.
static func _ring(st: SurfaceTool, scale: Vector3, tube: float, seg: int, sides: int, col: Color) -> void:
	for j in seg:
		var a0 := TAU * float(j) / seg
		var a1 := TAU * float(j + 1) / seg
		var c0 := Vector3(cos(a0) * scale.x, 0, sin(a0) * scale.z)
		var c1 := Vector3(cos(a1) * scale.x, 0, sin(a1) * scale.z)
		var mid := (c0 + c1) * 0.5
		for k in sides:
			var b0 := TAU * float(k) / sides
			var b1 := TAU * float(k + 1) / sides
			var p00 := _tube(a0, b0, scale, tube)
			var p01 := _tube(a0, b1, scale, tube)
			var p10 := _tube(a1, b0, scale, tube)
			var p11 := _tube(a1, b1, scale, tube)
			EcoMM.tri(st, p00, p10, p01, col, mid)
			EcoMM.tri(st, p10, p11, p01, col, mid)


static func _tube(a: float, b: float, scale: Vector3, tube: float) -> Vector3:
	var out := Vector3(cos(a), 0, sin(a))
	return Vector3(cos(a) * scale.x, 0, sin(a) * scale.z) + out * cos(b) * tube + Vector3.UP * sin(b) * tube


## Усечённый конус длиной len в системе tr: от начала (радиус r_top) вниз до −len (r_bottom); up — вверх до +len
## (тогда r_top — на конце, r_bottom — у основания).
static func _cone(st: SurfaceTool, tr: Transform3D, r_top: float, r_bottom: float, length: float, seg: int,
		col: Color, up: bool = false) -> void:
	var y_end := length if up else -length
	var r0 := r_bottom if up else r_top
	var r1 := r_top if up else r_bottom
	var mid := tr * Vector3(0, y_end * 0.5, 0)
	for j in seg:
		var a0 := TAU * float(j) / seg
		var a1 := TAU * float(j + 1) / seg
		var p0 := tr * Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p1 := tr * Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var q0 := tr * Vector3(cos(a0) * r1, y_end, sin(a0) * r1)
		var q1 := tr * Vector3(cos(a1) * r1, y_end, sin(a1) * r1)
		EcoMM.tri(st, p0, p1, q0, col, mid)
		EcoMM.tri(st, p1, q1, q0, col, mid)
		EcoMM.tri(st, p0, p1, tr * Vector3.ZERO, col, mid)
		EcoMM.tri(st, q0, q1, tr * Vector3(0, y_end, 0), col, mid)
