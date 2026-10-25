class_name RaduzhView
extends Node3D
## Радужники в сцене (initSwarms/swarmRender в js/creatures.js): все гребневики трёх стай — один MultiMesh из
## вытянутой сферы (0,16 × 0,24 м, сложение цвета, без записи глубины), ореолы вспышки — второй MultiMesh из мягких
## пятен лицом к камере (1,1 м). Без света гребневик — едва заметный голубоватый силуэт, в луче — бегущая радуга;
## ореол виден только у вспыхнувшей стаи (яркость glow² · 0,7). Своя эмиссия; туман для сложения выключен —
## гаснут сами к FADE_FAR. Гребневики не заходят в корпус (EcoRaduzh.member_pos_outside). Слой отмели.
## Разброс особей (Б4, EcoVary по номеру гребневика): свой размер, частота «дыхания» и яркость тёмного силуэта —
## стая не клоны; мир и его случай не меняются, вызовов отрисовки не прибавилось.

const BODY_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform float fade_far = 70.0;
varying vec3 tint;
void vertex() {
	float far = length((VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz);
	tint = COLOR.rgb * clamp(1.0 - far / fade_far, 0.0, 1.0);
}
void fragment() {
	// края прозрачного тела светлее середины — ряды ресничек
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = tint * (0.45 + rim * 0.9);
}
"""

## Тело гребневика — сфера радиуса 1, сплющенная до 0,16 × 0,24 × 0,16 м (7 × 5 сегментов, как в браузере).
const BODY := Vector3(0.16, 0.24, 0.16)
const HALO_SIZE := 1.1
const HALO_K := 0.7
## Дальше этого гребневики и ореолы не видны (м от камеры).
const FADE_FAR := 70.0
## Чисел на экземпляр: transform 3 × 4 и цвет (4).
const STRIDE := 12
const STRIDE_C := 16
## Разброс особей: размер ±15 %, частота дыхания ±20 % (около BREATH_RATE), силуэт без света светлее-темнее ±25 %.
const SIZE_SPREAD := 0.15
const RATE_SPREAD := 0.2
const SHADE_SPREAD := 0.25
const BREATH_RATE := 2.4

var raduzh: EcoRaduzh
var bodies: MultiMeshInstance3D
var halos: MultiMeshInstance3D
## Последние буферы тел и ореолов (для тестов).
var body_buffer := PackedFloat32Array()
var halo_buffer := PackedFloat32Array()
## Разброс по номеру гребневика: размер, частота дыхания, яркость силуэта (хеш — раз, не в каждом кадре).
var _vary := PackedFloat32Array()


func _init(system: EcoRaduzh) -> void:
	raduzh = system
	name = "Радужники"
	var n := raduzh.swarms.size() * EcoRaduzh.PER_SWARM
	bodies = _instance("Гребневики", build_body(), n)
	_vary.resize(n * 3)
	for i in n:
		_vary[i * 3] = member_scale(i)
		_vary[i * 3 + 1] = member_rate(i)
		_vary[i * 3 + 2] = member_shade(i)
	halos = _instance("Ореолы", build_halo(), n)
	sync(0.0, Vector3(1e6, 0, 1e6), 0.0)


func _instance(n: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = n
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mi.multimesh = mm
	# стаи дрейфуют — границы не пересчитываем, рамка на всю отмель
	mi.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	add_child(mi)
	return mi


static func _material(code: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = EcoShaders.shader(code)
	mat.set_shader_parameter("fade_far", FADE_FAR)
	return mat


static func build_body() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 7
	m.rings = 5
	m.material = _material(BODY_SHADER)
	return m


static func build_halo() -> QuadMesh:
	var m := QuadMesh.new()
	m.size = Vector2.ONE * HALO_SIZE
	m.material = _material(EcoShaders.SPOT)
	(m.material as ShaderMaterial).set_shader_parameter("halo", 1.0)
	return m


## Расставить гребневиков в момент t (время мира); корпус корабля — в ship_pos с курсом ship_yaw.
## Стая дальше FAR от корабля без вспышки переписывается раз в FAR_EVERY кадров, дальше MID — через кадр, стаи —
## вразнобой (бюджет кадра, issue #77/#133: дальних в тумане не разглядеть, за 50 м гребневики гаснут к FADE_FAR).
const FAR := EcoFish.FAR
const FAR_EVERY := 3
const MID := EcoFish.MID
const MID_EVERY := 2

var _frame := 0


## all — переписать все стаи сразу.
func sync(t: float, ship_pos: Vector3, ship_yaw: float, all := false) -> void:
	var n := bodies.multimesh.instance_count
	var full := all or body_buffer.size() != n * STRIDE_C
	body_buffer.resize(n * STRIDE_C)
	halo_buffer.resize(n * STRIDE_C)
	_frame += 1
	for sw in raduzh.swarms:
		if not full and not due(sw, ship_pos, _frame):
			continue
		var gg := sw.glow * sw.glow * HALO_K
		for k in EcoRaduzh.PER_SWARM:
			var idx := sw.index * EcoRaduzh.PER_SWARM + k
			var j := idx * STRIDE_C
			var m := sw.members[k]
			var p := EcoRaduzh.member_pos_outside(sw, k, t, ship_pos, ship_yaw)
			var b := Basis.from_euler(Vector3(sin(t * 0.7 + m.phase) * 0.4, m.phase, 0.0))
			b = b.scaled_local(BODY * (_vary[idx * 3] * (1.0 + sin(t * _vary[idx * 3 + 1] + m.phase) * 0.08)))
			# свой силуэт без света; во вспышке радуга одна на всех
			var c := EcoRaduzh.member_color(sw, k, t) * lerpf(_vary[idx * 3 + 2], 1.0, sw.glow)
			_put(body_buffer, j, b, p)
			_color(body_buffer, j + STRIDE, c)
			# без вспышки ореол не нужен — схлопнут в точку, фрагментов не рисует
			_put(halo_buffer, j, Basis.IDENTITY if gg > 0.0 else Basis.from_scale(Vector3.ZERO), p)
			_color(halo_buffer, j + STRIDE, c * gg)
	bodies.multimesh.buffer = body_buffer
	halos.multimesh.buffer = halo_buffer


## Размер гребневика n (номер по всем стаям: стая · PER_SWARM + место) — множитель BODY.
static func member_scale(n: int) -> float:
	return EcoVary.spread(n, EcoVary.SIZE, SIZE_SPREAD)


## Частота «дыхания» гребневика n, рад/с.
static func member_rate(n: int) -> float:
	return BREATH_RATE * EcoVary.spread(n, EcoVary.RATE, RATE_SPREAD)


## Яркость тёмного силуэта гребневика n (без света).
static func member_shade(n: int) -> float:
	return EcoVary.spread(n, EcoVary.SHADE, SHADE_SPREAD)


## Переписать ли стаю в этом кадре: близкая или вспыхнувшая — всегда, средняя — через кадр, дальняя — в свой кадр
## из трёх.
static func due(sw: EcoRaduzh.Swarm, ship_pos: Vector3, frame: int) -> bool:
	if sw.glow > 0.0:
		return true
	var d := sw.c.distance_to(ship_pos)
	if d < MID:
		return true
	return (frame + sw.index) % (MID_EVERY if d < FAR else FAR_EVERY) == 0


static func _put(buf: PackedFloat32Array, i: int, b: Basis, o: Vector3) -> void:
	buf[i] = b.x.x; buf[i + 1] = b.y.x; buf[i + 2] = b.z.x; buf[i + 3] = o.x
	buf[i + 4] = b.x.y; buf[i + 5] = b.y.y; buf[i + 6] = b.z.y; buf[i + 7] = o.y
	buf[i + 8] = b.x.z; buf[i + 9] = b.y.z; buf[i + 10] = b.z.z; buf[i + 11] = o.z


static func _color(buf: PackedFloat32Array, i: int, c: Color) -> void:
	buf[i] = c.r; buf[i + 1] = c.g; buf[i + 2] = c.b; buf[i + 3] = 1.0


## Место экземпляра n из буфера.
static func origin_at(buf: PackedFloat32Array, n: int) -> Vector3:
	var i := n * STRIDE_C
	return Vector3(buf[i + 3], buf[i + 7], buf[i + 11])


## Цвет экземпляра n из буфера.
static func color_at(buf: PackedFloat32Array, n: int) -> Color:
	var i := n * STRIDE_C + STRIDE
	return Color(buf[i], buf[i + 1], buf[i + 2], buf[i + 3])
