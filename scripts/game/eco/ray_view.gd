class_name RayView
extends MultiMeshInstance3D
## Ледокрылы в сцене (rayGeo/initRays в js/creatures.js; концепт icewing.jpg): оба ската — один MultiMesh (один вызов
## отрисовки). Тело — пластина 14 × 9 м (18 × 8 клеток), сужается к хвосту и носу, горб по середине 0,5 м, края
## светлее; хвост-хлыст 9 м назад; на спине два ряда по 7 светящихся пятнышек (#9ffcff). Взмах крыльев — в шейдере
## (как в браузере: sin(1,3 t + i − 0,32 |x|) · (|x| / 7)^1,4 · 1,8, номер ската — в INSTANCE_CUSTOM), крен 0,22 рад.
## Свет сквозь лёд падает на спину; брюхо снизу темнее. Стоит на слое отмели (OceanView.LAYER_WORLD).

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
varying float glow;
void vertex() {
	float ax = abs(VERTEX.x);
	float ph = TIME * 1.3 + INSTANCE_CUSTOM.x - ax * 0.32;
	float k = pow(ax / 7.0, 1.4) * 1.8;
	VERTEX.y += sin(ph) * k;
	// наклон крыла от взмаха: d(y)/d|x|
	float slope = -cos(ph) * 0.32 * k + sin(ph) * 1.8 * 1.4 * pow(ax / 7.0, 0.4) / 7.0;
	NORMAL = normalize(NORMAL - vec3(sign(VERTEX.x) * slope, 0.0, 0.0));
	glow = COLOR.a;
}
void fragment() {
	ALBEDO = COLOR.rgb * (1.0 - glow);
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	EMISSION = vec3(0.07, 0.22, 0.28) * (1.0 - glow) + COLOR.rgb * glow * 1.6;
}
"""

## Пластина: размах и длина (м), клеток поперёк и вдоль.
const SPAN := 14.0
const LENGTH := 9.0
const CELLS_X := 18
const CELLS_Z := 8
## Концы крыльев отогнуты назад на столько (м).
const SWEEP := 2.2
## Хвост: длина, радиус у тела и на конце, середина на 8,5 м позади.
const TAIL_L := 9.0
const TAIL_R := Vector2(0.12, 0.03)
const TAIL_Z := -8.5
## Пятнышки на спине: 14 штук радиусом 0,12 м.
const SPOTS := 14
const SPOT_R := 0.12
const SPOT := Color("9ffcff")
## Цвет тела (#a8cfe0) и крен в повороте (rotateZ(−0,22)).
const BODY := Color("a8cfe0")
const BANK := EcoRay.BANK

var rays: EcoRay
## Вершины и треугольники меша одного ската (для тестов).
var verts := PackedVector3Array()
var tris := 0
## Последние места скатов (для тестов: без видеокарты MultiMesh их не хранит).
var placed: Array[Transform3D] = []

var _nor := PackedVector3Array()
var _col := PackedColorArray()
var _idx := PackedInt32Array()


func _init(system: EcoRay) -> void:
	rays = system
	name = "Ледокрылы"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body()
	_tail()
	for k in SPOTS:
		var sx := 1.0 if k % 2 else -1.0
		_spot(Vector3(sx * (0.8 + (k >> 1) * 0.35), 0.45, 1.0 - (k >> 1) * 0.4))
	var m := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = _nor
	arrays[Mesh.ARRAY_COLOR] = _col
	arrays[Mesh.ARRAY_INDEX] = _idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	m.surface_set_material(0, mat)
	tris = _idx.size() / 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = m
	mm.instance_count = rays.rays.size()
	multimesh = mm
	# скаты огромные и плывут по кругу 110–170 м: границу не считаем, отсечение по камере — по всей отмели
	custom_aabb = AABB(Vector3(-400, -120, -400), Vector3(800, 240, 800))
	sync()


## Поставить скатов по миру.
func sync() -> void:
	placed.resize(rays.rays.size())
	for ry in rays.rays:
		var x := xform(ry)
		placed[ry.index] = x
		multimesh.set_instance_transform(ry.index, x)
		multimesh.set_instance_custom_data(ry.index, Color(float(ry.index), 0, 0, 0))


## Место ската: +Z меша — по курсу, крен BANK.
static func xform(ry: EcoRay.Ray) -> Transform3D:
	return EcoRay.xform(ry)


## Пластина тела (rayGeo): x сужается к носу и хвосту, горб посередине, края светлее, концы крыльев назад (SWEEP).
func _body() -> void:
	var v0 := verts.size()
	for j in CELLS_Z + 1:
		var z := LENGTH * 0.5 - LENGTH * j / CELLS_Z
		var f := maxf(0.05, 1.0 - pow(absf(z + 0.6) / 5.1, 1.6))
		for i in CELLS_X + 1:
			var x := -SPAN * 0.5 + SPAN * i / CELLS_X
			var nx := x * f
			var y := maxf(0.0, 1.0 - absf(nx) / 2.2) * 0.5 * maxf(0.0, 1.0 - absf(z) / 4.5)
			# крылья стреловидные, концы отогнуты назад (концепт icewing.jpg); у браузера — прямые
			verts.append(Vector3(nx, y, z - SWEEP * pow(absf(nx) / (SPAN * 0.5), 1.5)))
			_nor.append(Vector3.UP)
			var c := 0.4 + absf(x) / 7.0 * 0.6
			_col.append(Color(BODY.r * c * 0.75, BODY.g * c, minf(1.0, BODY.b * c * 1.15), 0.0))
	var row := CELLS_X + 1
	for j in CELLS_Z:
		for i in CELLS_X:
			var q := v0 + j * row + i
			_idx.append_array([q, q + 1, q + row, q + 1, q + row + 1, q + row])


## Хвост-хлыст: конус из 5 граней от тела назад.
func _tail() -> void:
	var v0 := verts.size()
	var z0 := TAIL_Z + TAIL_L * 0.5
	var z1 := TAIL_Z - TAIL_L * 0.5
	for i in 6:
		var a := TAU * i / 5.0
		var d := Vector3(cos(a), sin(a), 0)
		verts.append(Vector3(0, 0.1, z0) + d * TAIL_R.x)
		verts.append(Vector3(0, 0.1, z1) + d * TAIL_R.y)
		for k in 2:
			_nor.append(d)
			_col.append(Color(BODY.r * 0.6, BODY.g * 0.6, BODY.b * 0.6, 0.0))
	for i in 5:
		var q := v0 + i * 2
		_idx.append_array([q, q + 1, q + 2, q + 2, q + 1, q + 3])


## Светящееся пятнышко: октаэдр радиуса SPOT_R (альфа 1 — светится в шейдере).
func _spot(c: Vector3) -> void:
	var v0 := verts.size()
	var dirs: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for d in dirs:
		verts.append(c + d * SPOT_R)
		_nor.append(d)
		_col.append(Color(SPOT.r, SPOT.g, SPOT.b, 1.0))
	for t in [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]]:
		_idx.append_array([v0 + t[0], v0 + t[1], v0 + t[2]])
