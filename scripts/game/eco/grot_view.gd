class_name GrotView
extends Node3D
## Гротовик в сцене (grotGeo, grotLegsGeo, grotReefGeo, grotUpdate в js/creatures.js): панцирь-купол 4,8 × 2,2 × 6,4 м
## (#5b5a4a) с ободом (#3e3b30) и головой спереди (+Z, #6b6656) — один меш со слабым свечением #0e0c08; шесть ног
## (#4a473a) — свой меш: на ходу качаются (± 0,08 рад, 2,2 рад/с), прячутся под панцирь (высота 0,35 + 0,65 · lift);
## риф на спине — 11 веток огнецвета (#b35933) и 6 мшистых бугров (#59cc8c), свечение #2a1004; светящиеся кончики
## веток и жёлтые глаза — отдельный меш без освещения. Четыре вызова отрисовки, ≈ 1,6 тыс. треугольников;
## слой отмели (OceanView.LAYER_WORLD); дальше FAR от корабля не виден в мути.

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
## Ветки рифа и мшистые бугры.
const BRANCHES := 11
const BUMPS := 6
const FAR := 160.0

var grots: EcoGrot
## Узел гротовика: стоит на теле (низ панциря), повёрнут по курсу.
var group: Node3D
var body: MeshInstance3D
var legs: MeshInstance3D
var reef: MeshInstance3D
var glow: MeshInstance3D


func _init(system: EcoGrot) -> void:
	grots = system
	name = "Гротовик"
	group = Node3D.new()
	group.name = "Гротовик"
	add_child(group)
	body = _mesh("Панцирь", build_body(), _lit(BODY_GLOW))
	legs = _mesh("Ноги", build_legs(), _lit(Color.BLACK))
	reef = _mesh("Риф", build_reef(), _lit(REEF_GLOW))
	var bright := StandardMaterial3D.new()
	bright.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bright.vertex_color_use_as_albedo = true
	glow = _mesh("Огоньки", build_glow(), bright)
	sync(0.0, Vector3.ZERO)


func _mesh(n: String, m: ArrayMesh, mat: Material) -> MeshInstance3D:
	m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	group.add_child(mi)
	return mi


static func _lit(emission: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
	return mat


## Поставить гротовика в момент t (время мира); ship — центр корабля (дальше FAR — спрятан).
func sync(t: float, ship: Vector3) -> void:
	var gr := grots.grot
	visible = gr != null and Vector3(gr.p.x, gr.body_y, gr.p.z).distance_to(ship) < FAR
	if not visible:
		return
	group.transform = Transform3D(Basis(Vector3.UP, gr.yaw), Vector3(gr.p.x, gr.body_y, gr.p.z))
	legs.rotation = Vector3(sin(t * 2.2) * 0.08 if gr.moving() else 0.0, 0.0, 0.0)
	legs.scale = Vector3(1.0, 0.35 + 0.65 * gr.lift, 1.0)


## Панцирь (верхняя половина эллипсоида), обод по краю и голова спереди.
static func build_body() -> ArrayMesh:
	var st := KrabView._begin()
	_dome(st, Vector3.ZERO, EcoGrot.SHELL, 16, 5, SHELL)
	_ring(st, Vector3(EcoGrot.SHELL.x, 1.0, EcoGrot.SHELL.z), 0.12, 20, 5, RIM)
	KrabView._ellipsoid(st, Vector3(0, 0.25, 3.4), Vector3(0.55, 0.385, 0.66), 10, 6, HEAD)
	return st.commit()


## Шесть ног: усечённые конусы 1,1 м (сверху 0,22, снизу 0,3), разведены наружу.
static func build_legs() -> ArrayMesh:
	var st := KrabView._begin()
	for sx in [-1.0, 1.0]:
		for z in LEG_Z:
			var tr := Transform3D(Basis(Vector3.BACK, sx * LEG_TILT), Vector3(sx * LEG_X, LEG_Y, z))
			_cone(st, tr, 0.22, 0.3, 1.1, 6, LEG)
	return st.commit()


## Место ветки k рифа на панцире (золотой угол по куполу, наклон наружу) и её длина.
static func branch(k: int) -> Transform3D:
	var a := k * 2.39996
	var r := sqrt((k + 0.5) / BRANCHES) * 0.85
	var at := Vector3(cos(a) * r * 2.1, sqrt(maxf(0.0, 1.0 - r * r)) * 1.05, sin(a) * r * 2.8)
	return Transform3D(Basis(Vector3(sin(a), 0, -cos(a)), 0.25 + (k % 2) * 0.2), at)


static func branch_len(k: int) -> float:
	return 0.9 + (k % 3) * 0.35


## Риф: ветки огнецвета (конусы 0,14 → 0,06) и приплюснутые мшистые бугры.
static func build_reef() -> ArrayMesh:
	var st := KrabView._begin()
	for k in BRANCHES:
		_cone(st, branch(k), 0.06, 0.14, branch_len(k), 5, WOOD, true)
	for k in BUMPS:
		var a := k * 1.1 + 0.4
		KrabView._ellipsoid(st, Vector3(cos(a) * 1.5, 0.8, sin(a) * 2.1), Vector3(0.45, 0.2, 0.45), 8, 5, MOSS)
	return st.commit()


## Светящиеся кончики веток и глаза.
static func build_glow() -> ArrayMesh:
	var st := KrabView._begin()
	for k in BRANCHES:
		var tip := branch(k) * Vector3(0, branch_len(k), 0)
		KrabView._ellipsoid(st, tip, Vector3.ONE * 0.16, 6, 4, TIP)
	for sx in [-1.0, 1.0]:
		KrabView._ellipsoid(st, Vector3(sx * 0.3, 0.45, 3.85), Vector3.ONE * 0.09, 6, 4, EYE)
	return st.commit()


## Купол: верхняя половина эллипсоида с радиусами r, seg × rings граней, низ открыт.
static func _dome(st: SurfaceTool, c: Vector3, r: Vector3, seg: int, rings: int, col: Color) -> void:
	var pts: Array = []
	for i in rings + 1:
		var th := PI * 0.5 * float(i) / rings
		var row: Array[Vector3] = []
		for j in seg:
			var ph := TAU * float(j) / seg
			row.append(c + Vector3(sin(th) * cos(ph) * r.x, cos(th) * r.y, sin(th) * sin(ph) * r.z))
		pts.append(row)
	for i in rings:
		for j in seg:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][(j + 1) % seg]
			var d: Vector3 = pts[i + 1][j]
			var e: Vector3 = pts[i + 1][(j + 1) % seg]
			KrabView._tri(st, a, b, d, col, c)
			KrabView._tri(st, b, e, d, col, c)


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
			KrabView._tri(st, p00, p10, p01, col, mid)
			KrabView._tri(st, p10, p11, p01, col, mid)


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
		KrabView._tri(st, p0, p1, q0, col, mid)
		KrabView._tri(st, p1, q1, q0, col, mid)
		KrabView._tri(st, p0, p1, tr * Vector3.ZERO, col, mid)
		KrabView._tri(st, q0, q1, tr * Vector3(0, y_end, 0), col, mid)
