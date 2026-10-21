class_name DropView
extends MeshInstance3D
## Край отмели в сцене по ART-032: четыре скальных клина вдоль бровки (полка с рваной кромкой, крутая стенка
## уступами-пластами, торцы), шрам оползня — головная стенка светлого скола, ложе по склону от скола к илу,
## диагональная осыпь, три тёмные трещины по площадке. Один меш, один материал, один вызов отрисовки, плоские
## грани (камень). Светится только редкое обрастание #67DDEB — альфа вершинного цвета в том же материале;
## скале — слабая подсветка FILL, чтобы кромка читалась в мути. Без источников света, слой отмели.

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 growth : source_color;
const float FILL = 0.22;
varying float lit;
void vertex() {
	lit = COLOR.a;
}
void fragment() {
	ALBEDO = COLOR.rgb * (1.0 - lit * 0.5);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	EMISSION = growth * lit * 1.4 + COLOR.rgb * (1.0 - lit) * FILL;
}
"""

## Палитра художника (kray-otmeli.md).
const ROCK := Color("294956")
const MID := Color("58717a")
const FRESH := Color("82979c")
const DEEP := Color("0b1c24")
const SILT := Color("6b5945")
const GROWTH := Color("67ddeb")
## Свежий скол и ил на ложе — светлее палитры: в мути отмели ложе должно читаться светлее песка вокруг.
const SCAR := Color("a7b6ba")   # #82979C на 30 % светлее
const SILT_LIT := Color("908374")   # #6B5945 на 25 % светлее
## Сетка клина: шаг вдоль z, рядов полки и стенки; уступ пласта (м внутрь у чётных рядов стенки), дрожь вершин.
const STEP_Z := 1.8
const SHELF_ROWS := 3
const FACE_ROWS := 8
const LEDGE := 0.8
const JITTER := 0.35
## Ложе шрама: столбцов поперёк и рядов вдоль склона; борозды (м).
const SCAR_COLS := 8
const SCAR_ROWS := 12
const FURROW := 0.25
## Обрастания на клин (в верхних рядах стенки), высота кустика.
const TUFTS := 7
const TUFT_H := 0.5
## Ширина трещины.
const CRACK_W := 0.5

var drop: EcoDrop
## Вершины по треугольникам (мир, для тестов), нормали, число треугольников; сколько у клиньев и светится.
var verts := PackedVector3Array()
var normals := PackedVector3Array()
var tris := 0
var wedge_tris := 0
var glowing := 0

var _col := PackedColorArray()


func _init(system: EcoDrop) -> void:
	drop = system
	name = "Край отмели"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for w in EcoDrop.WEDGES.size():
		_wedge(w)
	wedge_tris = verts.size() / 3
	_scar()
	_scree()
	_cracks()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = _col
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	mat.set_shader_parameter("growth", GROWTH)
	m.surface_set_material(0, mat)
	mesh = m
	tris = verts.size() / 3


static func _hash(i: int, j: int) -> float:
	return fposmod(sin(float(i * 57 + j * 13) * 78.233) * 43758.5453, 1.0)


## Ряды профиля: 0 — заход в площадку, 1 — кромка, 1 + SHELF_ROWS — губа, последний — низ стенки.
static func rows() -> int:
	return 2 + SHELF_ROWS + FACE_ROWS


## Точка ряда r профиля клина w при z (с уступами и дрожью; кромка и низ — без дрожи по y).
func _point(w: int, r: int, z: float, iz: int) -> Vector3:
	var pr := drop.profile(w, z)
	var p: Vector2
	if r == 0:
		p = pr[0]
	elif r <= 1 + SHELF_ROWS:
		p = pr[1].lerp(pr[2], float(r - 1) / SHELF_ROWS)
	else:
		var k := r - 1 - SHELF_ROWS
		p = pr[2].lerp(pr[3], float(k) / FACE_ROWS)
		if k > 0 and k < FACE_ROWS and k % 2 == 0:
			p.x -= LEDGE
	var inner := r > 0 and r < rows() - 1
	if inner:
		p.x += (_hash(iz + w * 101, r) - 0.5) * 2.0 * JITTER
		p.y += (_hash(r * 7 + w, iz) - 0.5) * 2.0 * JITTER
	return Vector3(p.x, p.y, z)


func _paint(w: int, r: int, iz: int, y_brow: float, y: float) -> Color:
	var h := _hash(iz + 3, r + w * 17)
	if r <= 1 + SHELF_ROWS:
		return ROCK.lerp(MID, 0.45 + 0.4 * h)
	var deep := clampf((y_brow - y) / EcoDrop.DEPTH, 0.0, 1.0)
	return ROCK.lerp(MID, 0.25 * h).lerp(DEEP, deep * 0.85)


## Клин: сетка по рядам профиля и шагам вдоль z, торцы — веером; у шрама торец — светлый скол.
func _wedge(w: int) -> void:
	var zr := EcoDrop.wedge_z(w)
	var nz := maxi(2, ceili((zr.y - zr.x) / STEP_Z))
	var n := rows()
	var grid: Array[PackedVector3Array] = []
	for i in nz + 1:
		var z := lerpf(zr.x, zr.y, float(i) / nz)
		var col := PackedVector3Array()
		for r in n:
			col.append(_point(w, r, z, i))
		grid.append(col)
	for i in nz:
		var y_brow := grid[i][1].y - EcoDrop.RISE
		for r in n - 1:
			var a := grid[i][r]
			var b := grid[i + 1][r]
			var c := grid[i + 1][r + 1]
			var d := grid[i][r + 1]
			var out := Vector3.UP if r <= SHELF_ROWS else Vector3.RIGHT
			if r == 0:
				out = Vector3(-0.3, 1.0, 0.0)
			_quad(a, b, c, d, out, _paint(w, r, i, y_brow, (a.y + d.y) * 0.5), 0.0)
	# торцы
	for side in 2:
		var col := grid[0] if side == 0 else grid[nz]
		var out := Vector3.FORWARD if side == 0 else Vector3.BACK
		var near_scar := absf(col[1].z - EcoDrop.SCAR_Z) < EcoDrop.SCAR_W * 0.5 + 1.0
		var mid := (col[0] + col[n - 1]) * 0.5
		for r in n - 1:
			var paint := SCAR.lerp(FRESH, _hash(r, side + w) * 0.5) if near_scar else ROCK.lerp(DEEP, 0.3)
			_tri(mid, col[r], col[r + 1], out, paint, 0.0)
	# обрастание в верхних рядах стенки
	for t in TUFTS:
		var i := 1 + int(_hash(t, w + 40) * (nz - 2))
		var r := 2 + SHELF_ROWS + int(_hash(w + 9, t) * 3.0)
		_tuft(grid[i][r] + Vector3(0.15, 0.0, 0.0), Vector3(1.0, 0.4, 0.0).normalized(), t + w * 11)


## Шрам оползня: головная стенка скола и площадка над ней, ложе по склону от скола к илу.
func _scar() -> void:
	var half := EcoDrop.SCAR_W * 0.5
	var nc := SCAR_COLS
	var nr := SCAR_ROWS
	var bed: Array[PackedVector3Array] = []
	for j in nc + 1:
		var u := lerpf(-1.0, 1.0, float(j) / nc)
		var edge := j == 0 or j == nc
		var col := PackedVector3Array()
		# ложе к низу сужается языком и кончается неровно, края рваные
		var run := EcoDrop.SCAR_RUN * (0.7 + 0.3 * cos(u * PI * 0.5)) * (0.9 + 0.2 * _hash(j, 31))
		for i in nr + 1:
			var t := float(i) / nr
			var wk := lerpf(1.0, 0.45, smoothstep(0.35, 1.0, t))
			var z := EcoDrop.SCAR_Z + u * half * wk
			if edge and i > 0:
				z -= signf(u) * _hash(i, j + 7) * 1.6
			var hx := EcoDrop.scar_head_x(z)
			var x := lerpf(hx, EcoDrop.brow_x(z) + run, t)
			var furrow := FURROW * sin((u + 1.0) * PI * 2.5) * (0.5 + _hash(i, j)) * (0.0 if edge else 1.0)
			col.append(Vector3(x, drop.floor_y(x, z) + EcoDrop.FLOOR_UP + furrow, z))
		bed.append(col)
	for j in nc:
		for i in nr:
			var t := float(i) / nr
			var paint := SCAR.lerp(SILT_LIT, smoothstep(0.2, 0.9, t)).lerp(FRESH, 0.25 * _hash(i, j + 5))
			_quad(bed[j][i], bed[j + 1][i], bed[j + 1][i + 1], bed[j][i + 1], Vector3.UP, paint, 0.0)
	# головная стенка: от площадки (кромка на RISE над дном) вниз к ложу, лицом к склону; позади — скат к дну
	for j in nc:
		var a := bed[j][0]
		var b := bed[j + 1][0]
		var ta := Vector3(a.x, drop.floor_y(a.x, a.z) + EcoDrop.RISE, a.z)
		var tb := Vector3(b.x, drop.floor_y(b.x, b.z) + EcoDrop.RISE, b.z)
		_quad(a, b, tb, ta, Vector3.RIGHT, SCAR.lerp(FRESH, 0.3 * _hash(j, 2)), 0.0)
		var ba := Vector3(a.x - 2.5, drop.floor_y(a.x - 2.5, a.z) - 0.3, a.z)
		var bb := Vector3(b.x - 2.5, drop.floor_y(b.x - 2.5, b.z) - 0.3, b.z)
		_quad(ta, tb, bb, ba, Vector3(-0.5, 1.0, 0.0), MID.lerp(ROCK, 0.3), 0.0)


## Осыпь: октаэдры с дрожью, свежие светлее.
func _scree() -> void:
	var rocks := drop.scree()
	for q in rocks.size():
		var s := rocks[q]
		var c := Vector3(s.x, s.y, s.z)
		var r := s.w
		var k := [Vector3(r * (0.9 + _hash(q, 1) * 0.5), 0, 0), Vector3(0, r * (0.55 + _hash(q, 2) * 0.3), 0),
			Vector3(0, 0, r * (0.8 + _hash(q, 3) * 0.5))]
		var paint := SCAR.lerp(ROCK, 0.15 + 0.5 * _hash(q, 4))
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var a: Vector3 = c + k[0] * sx
					var b: Vector3 = c + k[1] * sy
					var d: Vector3 = c + k[2] * sz
					_tri(a, b, d, (a + b + d) / 3.0 - c, paint, 0.0)


## Трещины: тёмные полосы по площадке, к концам сходят на нет.
func _cracks() -> void:
	for k in EcoDrop.CRACKS.size():
		var pts := drop.crack_points(k)
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var d := b - a
			var side := Vector3(-d.z, 0.0, d.x).normalized()
			var wa := CRACK_W * sin(PI * float(i) / (pts.size() - 1)) * 0.5
			var wb := CRACK_W * sin(PI * float(i + 1) / (pts.size() - 1)) * 0.5
			_quad(a - side * wa, b - side * wb, b + side * wb, a + side * wa, Vector3.UP, DEEP, 0.0)


## Кустик обрастания из трёх тонких лопастей, светится (альфа 1).
func _tuft(c: Vector3, n: Vector3, q: int) -> void:
	var t1 := n.cross(Vector3.UP).normalized()
	var t2 := n.cross(t1)
	var h := TUFT_H * (0.6 + 0.8 * _hash(q, 7))
	for k in 3:
		var a := TAU * k / 3.0 + _hash(q, 8) * 2.0
		var side := t1 * cos(a) + t2 * sin(a)
		var tip := c + n * h + side * h * 0.35
		var wv := (t1 * -sin(a) + t2 * cos(a)) * 0.06
		_tri(c - wv, c + wv, tip, side, GROWTH, 1.0)
		_tri(c - wv, c + wv, tip, -side, GROWTH, 1.0)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, paint: Color, glow: float) -> void:
	_tri(a, b, c, out, paint, glow)
	_tri(a, c, d, out, paint, glow)


## Треугольник с плоской нормалью в сторону out. Лицевая сторона — обход по часовой стрелке, если смотреть на неё:
## (b − a) × (c − a) смотрит внутрь (CLAUDE.md); если наоборот — меняем b и c.
func _tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, paint: Color, glow: float) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-12:
		return
	if cr.dot(out) > 0.0:
		var t := b
		b = c
		c = t
		cr = -cr
	var n := -cr.normalized()
	var col := paint.srgb_to_linear()   # вершинный цвет шейдер берёт как есть
	for p in [a, b, c]:
		verts.append(p)
		normals.append(n)
		_col.append(Color(col.r, col.g, col.b, glow))
	if glow > 0.0:
		glowing += 1
