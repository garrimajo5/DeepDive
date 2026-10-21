class_name EchoView
extends Node3D
## Эхоловец в сцене по концепту ART-007 (`docs/concept-art/eholovec.md`): приплюснутое тело около 3 м из двух
## капсул (кожа #344A59, бледные костяные полосы #B5B5A5 по спине — под рисунок рёбер), клин головы с нижней
## челюстью, четыре короткие лапы, короткий хвост — один меш; голосовой мешок под горлом — свой узел, медленно
## дышит; два уха-воронки на стеблях — по узлу на ухо с двумя суставами (поворот и наклон, EcoEcho.Lurker.ears):
## кожа снаружи и слуховые складки внутри со слабым свечением #67DDEB — две поверхности. Раскрытый сонаром — складки
## пульсируют ярче. Шесть вызовов отрисовки, ≈ 1,3 тыс. треугольников; слой отмели (OceanView.LAYER_WORLD);
## дальше FAR от корабля не виден в мути. Материалы как у гротовика — новых шейдеров нет.

const SKIN := Color("344A59")
const SKIN_LIT := Color("667A87")
const STRIPE := Color("B5B5A5")
const SHADE := Color("0B1C24")
const FOLD := Color("67DDEB")
## Складки в тени воронки: цвет FOLD темнее на эту долю — свет даёт только слабое свечение.
const FOLD_DARK := 0.55
## Свечение складок: затаился — FOLD · HUSH, раскрыт — пульс до FOLD · LOUD (3 рад/с, как в браузере).
const HUSH := 0.12
const LOUD := 0.9
## Тело: передняя и задняя капсулы (центр, полуоси), голова, челюсть, мешок (под горлом), лапы, хвост.
const FRONT := [Vector3(0, 0.0, 0.45), Vector3(0.62, 0.38, 0.85)]
const BACK := [Vector3(0, -0.05, -0.6), Vector3(0.55, 0.33, 0.8)]
const HEAD := [Vector3(0, 0.02, 1.35), Vector3(0.4, 0.26, 0.5)]
const JAW := [Vector3(0, -0.2, 1.4), Vector3(0.3, 0.1, 0.42)]
const SAC := Vector3(0, -0.28, 1.0)
const SAC_R := Vector3(0.3, 0.22, 0.32)
const LEGS: Array[Vector3] = [Vector3(0.5, -0.1, 0.8), Vector3(-0.5, -0.1, 0.8), Vector3(0.45, -0.1, -0.75),
	Vector3(-0.45, -0.1, -0.75)]
const TAIL_FROM := Vector3(0, -0.05, -1.3)
const TAIL_LEN := 0.9
## Ухо: стебель до STALK, воронка от STALK до STALK + FUNNEL, раструб от NECK до MOUTH (радиусы, м).
const STALK := 0.45
const FUNNEL := 0.95
const NECK := 0.12
const MOUTH := 0.52
const FOLD_IN := 0.06
const SEG := 12
## Мешок дышит: ± SAC_BREATH за SAC_PERIOD с.
const SAC_BREATH := 0.1
const SAC_PERIOD := 6.0
const FAR := 160.0

var echoes: EcoEcho
## Узел тела: в центре тела, повёрнут по курсу (голова к +Z).
var group: Node3D
var body: MeshInstance3D
var sac: MeshInstance3D
## Суставы ушей: узел в основании стебля, поворот и наклон; в нём — меш уха (кожа и складки).
var ears: Array[Node3D] = []
var fold_mat: StandardMaterial3D
var _glow := HUSH


func _init(system: EcoEcho) -> void:
	echoes = system
	name = "Эхоловец"
	group = Node3D.new()
	group.name = "Эхоловец"
	add_child(group)
	var skin := GrotView._lit(Color.BLACK)
	body = _mesh(group, "Тело", build_body(), skin)
	sac = _mesh(group, "Голосовой мешок", build_sac(), skin)
	sac.position = SAC
	fold_mat = GrotView._lit(FOLD * HUSH)
	var ear_mesh := build_ear()
	ear_mesh.surface_set_material(1, fold_mat)
	for i in 2:
		var joint := Node3D.new()
		joint.name = "Ухо %d" % (i + 1)
		joint.position = EcoEcho.EAR_BASE[i]
		group.add_child(joint)
		_mesh(joint, "Воронка", ear_mesh, skin)
		ears.append(joint)
	sync(0.0, Vector3.ZERO)


static func _mesh(parent: Node3D, n: String, m: ArrayMesh, mat: Material) -> MeshInstance3D:
	m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Поворот сустава уха: (поворот от носа, наклон вверх) → базис, где +Z — ось воронки.
static func ear_basis(e: Vector2) -> Basis:
	return Basis(Vector3.UP, e.x) * Basis(Vector3.RIGHT, -e.y)


## Поставить эхоловца в момент t (время мира); ship — центр корабля (дальше FAR — спрятан).
func sync(t: float, ship: Vector3) -> void:
	var ec := echoes.echo
	visible = ec != null and ec.p.distance_to(ship) < FAR
	if not visible:
		return
	group.transform = ec.xform()
	for i in 2:
		ears[i].basis = ear_basis(ec.ears[i])
	var b := 1.0 + SAC_BREATH * sin(TAU * t / SAC_PERIOD)
	sac.scale = Vector3(b, b, b)
	var k := HUSH
	if ec.is_revealed():
		k = HUSH + (LOUD - HUSH) * (0.5 + 0.5 * sin(t * 3.0))
	if k != _glow:  # затаился — материал не трогаем каждый кадр
		_glow = k
		fold_mat.emission = FOLD * k


## Тело: две капсулы, голова, челюсть, лапы и хвост; бледные полосы поперёк спины.
static func build_body() -> ArrayMesh:
	var st := KrabView._begin()
	_blob(st, FRONT[0], FRONT[1], 14, 7, true)
	_blob(st, BACK[0], BACK[1], 14, 7, true)
	_blob(st, HEAD[0], HEAD[1], 10, 5, false)
	_blob(st, JAW[0], JAW[1], 8, 4, false, SHADE)
	for l in LEGS:
		var out := signf(l.x)
		var tr := Transform3D(Basis(Vector3.BACK, out * 0.6), l)
		GrotView._cone(st, tr, 0.13, 0.17, 0.45, 6, SKIN)
	var tail := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 - 0.15), TAIL_FROM)
	GrotView._cone(st, tail, 0.05, 0.22, TAIL_LEN, 6, SKIN, true)
	return st.commit()


## Голосовой мешок (у начала своего узла — масштаб дыхания от середины).
static func build_sac() -> ArrayMesh:
	var st := KrabView._begin()
	_blob(st, Vector3.ZERO, SAC_R, 10, 5, false, SKIN_LIT)
	return st.commit()


## Ухо вдоль +Z: стебель и воронка снаружи (поверхность 0, кожа), слуховые складки внутри (поверхность 1, свечение).
static func build_ear() -> ArrayMesh:
	var st := KrabView._begin()
	GrotView._cone(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.1, 0.13, STALK, 6, SKIN, true)
	_funnel(st, MOUTH, SKIN, false)
	var m := st.commit()
	st = KrabView._begin()
	_funnel(st, MOUTH - FOLD_IN, FOLD.darkened(FOLD_DARK), true)
	return st.commit(m)


## Воронка от STALK до STALK + FUNNEL, раструб NECK → mouth; inner — лицом к оси (видна изнутри), складки —
## волной по краю.
static func _funnel(st: SurfaceTool, mouth: float, col: Color, inner: bool) -> void:
	var rings := 4
	var pts: Array = []
	for i in rings + 1:
		var u := float(i) / rings
		var r := lerpf(NECK, mouth, u * u)
		var row: Array[Vector3] = []
		for j in SEG:
			var a := TAU * float(j) / SEG
			var fold := 1.0 + (0.08 * sin(a * 5.0) * u if inner else 0.0)
			row.append(Vector3(cos(a) * r * fold, sin(a) * r * fold, STALK + FUNNEL * u))
		pts.append(row)
	for i in rings:
		for j in SEG:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][(j + 1) % SEG]
			var d: Vector3 = pts[i + 1][j]
			var e: Vector3 = pts[i + 1][(j + 1) % SEG]
			var mid := (a + b + d + e) * 0.25
			var axis := Vector3(0, 0, mid.z)
			# снаружи — лицом от оси (середина на оси), внутри — лицом к оси (середина далеко снаружи)
			var inside := axis + (mid - axis) * 4.0 if inner else axis
			KrabView._tri(st, a, b, d, col, inside)
			KrabView._tri(st, b, e, d, col, inside)


## Эллипсоид с центром c и полуосями r; stripes — бледные полосы поперёк спины (по z), col — цвет без полос.
static func _blob(st: SurfaceTool, c: Vector3, r: Vector3, seg: int, rings: int, stripes: bool,
		col: Color = SKIN) -> void:
	var pts: Array = []
	for i in rings + 1:
		var th := PI * float(i) / rings
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
			var mid := (a + b + d + e) * 0.25
			var k := col
			if stripes and mid.y > c.y + r.y * 0.3:
				k = STRIPE if posmod(int(floor(mid.z / 0.32)), 2) == 0 else SKIN_LIT
			elif mid.y < c.y - r.y * 0.4:
				k = col.darkened(0.35)
			KrabView._tri(st, a, b, d, k, c)
			KrabView._tri(st, b, e, d, k, c)
