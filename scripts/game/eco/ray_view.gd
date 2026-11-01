class_name RayView
extends MultiMeshInstance3D
## Ледокрылы в сцене (rayGeo/initRays в js/creatures.js; концепт icewing.jpg): оба ската — один MultiMesh (один вызов
## отрисовки). Тело — пластина 14 × 9 м (18 × 8 клеток), сужается к хвосту и носу, горб по середине 0,5 м, края
## светлее; хвост-хлыст 9 м назад; на спине два ряда по 7 светящихся пятнышек (#9ffcff). Взмах крыльев — в шейдере
## (как в браузере: sin(1,3 t + i − 0,32 |x|) · (|x| / 7)^1,4 · 1,8, номер ската — в INSTANCE_CUSTOM), крен 0,22 рад.
## Хвост-хлыст извивается волной от корня к кончику (TAIL_*, доля длины хвоста — в UV.x; двойник на CPU — tail_wave);
## «Экономно» — sway_k = 0 через EcoShaders.follow / set_sway_lite.
## Свет сквозь лёд падает на спину; брюхо снизу темнее; края крыльев — ободок света (EcoRim, uniform rim). Стоит на слое отмели (OceanView.LAYER_WORLD).
## Скат взмывает над кораблём — с кончиков крыльев срываются облачка взвеси (EcoRayDust): дочерний MultiMesh «Муть»
## в мировых координатах (у самого RayView преобразование единичное) на общем шейдере EcoShaders.MIST, +1 вызов.
## «Экономно» (Б6, `set_lite`): пластина 12 × 6 клеток вместо 18 × 8, хвост 6 колец вместо 9 (LITE_*) — 480 → 306
## треугольников на ската; меш пересобирается с тем же материалом (взмах, хлыст, пятнышки, ободок), размах, горб по
## середине и пятнышки те же, муть и вызовы те же. Сброс мира уровень не теряет (EcoView.set_lite).

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
""" + EcoGlow.GLSL + """
uniform float rim = 0.0;
uniform float rim_tint = 0.0;
uniform float sway_k = 1.0;
uniform float rough = 0.8;
uniform float spec = 0.2;
varying float glow;
void vertex() {
	float ax = abs(VERTEX.x);
	float ph = TIME * 1.3 + INSTANCE_CUSTOM.x - ax * 0.32;
	float k = pow(ax / 7.0, 1.4) * 1.8;
	VERTEX.y += sin(ph) * k;
	// наклон крыла от взмаха: d(y)/d|x|
	float slope = -cos(ph) * 0.32 * k + sin(ph) * 1.8 * 1.4 * pow(ax / 7.0, 0.4) / 7.0;
	NORMAL = normalize(NORMAL - vec3(sign(VERTEX.x) * slope, 0.0, 0.0));
	// хвост-хлыст: волна бежит к кончику, размах растёт как квадрат доли длины (UV.x; у тела UV.x = 0)
	VERTEX.x += sin(TIME * 2.4 + INSTANCE_CUSTOM.x * 2.1 - UV.x * 5.0) * 0.8 * UV.x * UV.x * sway_k;
	glow = COLOR.a;
}
void fragment() {
	ALBEDO = COLOR.rgb * (1.0 - glow);
	ROUGHNESS = rough;
	SPECULAR = spec;
	RIM = rim;
	RIM_TINT = rim_tint;
	EMISSION = vec3(0.07, 0.22, 0.28) * (1.0 - glow) + eco_bio(COLOR.rgb * glow * 1.6);
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
## Колец вдоль хвоста (чтобы гнулся) и волна хлыста: размах на кончике (м), частота (рад/с), волн на длину (рад).
const TAIL_RINGS := 9
## То же на «Экономно»: клеток по размаху — чётное (середина спины — ряд вершин, горб не срезан).
const LITE_CELLS_X := 12
const LITE_CELLS_Z := 6
const LITE_TAIL_RINGS := 6
const TAIL_AMP := 0.8
const TAIL_RATE := 2.4
const TAIL_K := 5.0
const TAIL_PHASE := 2.1
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
## Вихри с кончиков крыльев (EcoRayDust); буфер — для тестов.
var dust := EcoRayDust.new()
var dust_view: MultiMeshInstance3D
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()

var _nor := PackedVector3Array()
var _col := PackedColorArray()
## Доля длины хвоста у вершины (у тела и пятнышек — 0).
var _uv := PackedVector2Array()
var _idx := PackedInt32Array()
## На «Экономно» — пластина и хвост грубее (set_lite).
var lite := false
var _mat: ShaderMaterial


func _init(system: EcoRay, on_lite := false) -> void:
	rays = system
	lite = on_lite
	name = "Ледокрылы"
	layers = OceanView.LAYER_WORLD
	EcoShadows.cast(self)
	_mat = ShaderMaterial.new()
	_mat.shader = EcoShaders.shader(SHADER)
	EcoShaders.follow(_mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _build()
	mm.instance_count = rays.rays.size()
	multimesh = mm
	# скаты огромные и плывут по кругу 110–170 м: границу не считаем, отсечение по камере — по всей отмели
	custom_aabb = AABB(Vector3(-400, -120, -400), Vector3(800, 240, 800))
	dust_view = GrazerView.build_dust(EcoRayDust.POOL)
	add_child(dust_view)
	sync()


## «Экономно» — меш ската пересобран грубее (тот же материал); назад — полный. Места и номера скатов в буфере
## MultiMesh не меняются (меняется только меш).
func set_lite(on: bool) -> void:
	if lite == on:
		return
	lite = on
	multimesh.mesh = _build()


## Клеток пластины и колец хвоста по уровню.
func cells_x() -> int:
	return LITE_CELLS_X if lite else CELLS_X


func cells_z() -> int:
	return LITE_CELLS_Z if lite else CELLS_Z


func tail_rings() -> int:
	return LITE_TAIL_RINGS if lite else TAIL_RINGS


func _build() -> ArrayMesh:
	verts.clear()
	_nor.clear()
	_col.clear()
	_uv.clear()
	_idx.clear()
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
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_INDEX] = _idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, _mat)
	tris = _idx.size() / 3
	return m


## Поставить скатов по миру.
func sync() -> void:
	placed.resize(rays.rays.size())
	for ry in rays.rays:
		var x := xform(ry)
		placed[ry.index] = x
		multimesh.set_instance_transform(ry.index, x)
		multimesh.set_instance_custom_data(ry.index, Color(float(ry.index), 0, 0, 0))


## Вихри с кончиков крыльев в момент t (время мира); flow — течение (сносит облачка).
func sync_dust(t: float, ship: EcoLink.ShipState, flow := Vector3.ZERO) -> void:
	dust.update(rays, t, ship.pos if ship != null else Vector3.ZERO)
	_dust.pack(dust.dust, t, flow, ship, EcoRayDust.COLOR, EcoRayDust.LIT)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


## Место ската: +Z меша — по курсу, крен BANK.
static func xform(ry: EcoRay.Ray) -> Transform3D:
	return EcoRay.xform(ry)


## Пластина тела (rayGeo): x сужается к носу и хвосту, горб посередине, края светлее, концы крыльев назад (SWEEP).
func _body() -> void:
	var v0 := verts.size()
	var cx := cells_x()
	var cz := cells_z()
	for j in cz + 1:
		var z := LENGTH * 0.5 - LENGTH * j / cz
		var f := maxf(0.05, 1.0 - pow(absf(z + 0.6) / 5.1, 1.6))
		for i in cx + 1:
			var x := -SPAN * 0.5 + SPAN * i / cx
			var nx := x * f
			var y := maxf(0.0, 1.0 - absf(nx) / 2.2) * 0.5 * maxf(0.0, 1.0 - absf(z) / 4.5)
			# крылья стреловидные, концы отогнуты назад (концепт icewing.jpg); у браузера — прямые
			verts.append(Vector3(nx, y, z - SWEEP * pow(absf(nx) / (SPAN * 0.5), 1.5)))
			_nor.append(Vector3.UP)
			_uv.append(Vector2.ZERO)
			var c := 0.4 + absf(x) / 7.0 * 0.6
			_col.append(Color(BODY.r * c * 0.75, BODY.g * c, minf(1.0, BODY.b * c * 1.15), 0.0))
	var row := cx + 1
	for j in cz:
		for i in cx:
			var q := v0 + j * row + i
			_idx.append_array([q, q + 1, q + row, q + 1, q + row + 1, q + row])


## Хвост-хлыст: конус из 5 граней от тела назад, TAIL_RINGS колец — гнётся волной в шейдере; доля длины — в UV.x.
func _tail() -> void:
	var v0 := verts.size()
	var z0 := TAIL_Z + TAIL_L * 0.5
	var rings := tail_rings()
	for r in rings:
		var s := r / float(rings - 1)
		var rad := lerpf(TAIL_R.x, TAIL_R.y, s)
		for i in 6:
			var a := TAU * i / 5.0
			var d := Vector3(cos(a), sin(a), 0)
			verts.append(Vector3(0, 0.1, z0 - TAIL_L * s) + d * rad)
			_nor.append(d)
			_uv.append(Vector2(s, 0.0))
			_col.append(Color(BODY.r * 0.6, BODY.g * 0.6, BODY.b * 0.6, 0.0))
	for r in rings - 1:
		for i in 5:
			var q := v0 + r * 6 + i
			_idx.append_array([q, q + 6, q + 1, q + 1, q + 6, q + 7])


## Сдвиг вбок (м, по x меша) точки хвоста на доле длины s в момент t у ската номер index — двойник шейдера.
static func tail_wave(s: float, t: float, index: int, sway_k := 1.0) -> float:
	return sin(t * TAIL_RATE + index * TAIL_PHASE - s * TAIL_K) * TAIL_AMP * s * s * sway_k


## Светящееся пятнышко: октаэдр радиуса SPOT_R (альфа 1 — светится в шейдере).
func _spot(c: Vector3) -> void:
	var v0 := verts.size()
	var dirs: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for d in dirs:
		verts.append(c + d * SPOT_R)
		_nor.append(d)
		_uv.append(Vector2.ZERO)
		_col.append(Color(SPOT.r, SPOT.g, SPOT.b, 1.0))
	for t in [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]]:
		_idx.append_array([v0 + t[0], v0 + t[1], v0 + t[2]])
