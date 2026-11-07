class_name KamenView
extends Node3D
## Каменщики в сцене (EcoKamen, #1337): все трубки всех рядов — один MultiMesh (известковый конус, освещается),
## все венчики — второй (розовая воронка #ff96aa, освещается и слабо светится сама — флаги материала как у
## кольчужника, без нового шейдера). Спрятанный
## венчик сжат и утоплен в устье трубки — ряд гаснет точками с того края, откуда идёт вибрация. Стоит на слое отмели
## (OceanView.LAYER_WORLD). +2 вызова отрисовки, ~6 тыс. треугольников; на «Экономно» то же (дёшево) — set_lite
## ничего не меняет, но есть для единообразия.

const TUBE_COLOR := Color("d8cbb4")
const CROWN_COLOR := Color("ff96aa")
## Свечение венчиков (без света видно розовые точки в темноте).
const GLOW := Color("8a3a4a")
## Венчик: радиус воронки у края и высота (м); спрятанный — CLOSED от размера, ниже устья на SINK.
const CROWN_R := 0.2
const CROWN_H := 0.14
const CLOSED := 0.08
const SINK := 0.1
## Чисел на экземпляр: матрица 3×4 и цвет.
const STRIDE := 16

var kamen: EcoKamen
var tubes: MultiMeshInstance3D
var crowns: MultiMeshInstance3D
## Места венчиков (для тестов — сервер отрисовки без экрана экземпляры не хранит).
var crown_at: Array[Transform3D] = []
var lite := false
var _buf := PackedFloat32Array()


func _init(system: EcoKamen, on_lite := false) -> void:
	kamen = system
	lite = on_lite
	name = "Каменщики"
	var n := maxi(1, count())
	tubes = _mm("Трубки", _tube_mesh(), n)
	crowns = _mm("Венчики", _crown_mesh(), n)
	_fill_tubes()
	sync(true)


func set_lite(on: bool) -> void:
	lite = on


## Трубок (и венчиков) во всех рядах.
func count() -> int:
	return kamen.rows.size() * EcoKamen.PER_ROW * EcoKamen.TUBES


func _mm(title: String, m: Mesh, n: int) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = title
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = m
	mm.instance_count = n
	mi.multimesh = mm
	mi.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	add_child(mi)
	return mi


static func _tube_mesh() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = EcoKamen.TUBE_R
	m.bottom_radius = EcoKamen.TUBE_R * 1.35
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 1
	m.cap_bottom = false
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	m.material = mat
	return m


static func _crown_mesh() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = CROWN_R
	m.bottom_radius = EcoKamen.TUBE_R * 0.6
	m.height = CROWN_H
	m.radial_segments = 8
	m.rings = 1
	m.cap_bottom = false
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.7
	mat.emission_enabled = true   # тело освещается, свечение — своё, слабее (как огоньки кольчужника)
	mat.emission = GLOW
	m.material = mat
	return m


## Цвет трубки номер i (sRGB): светлее-темнее ±10 % (EcoVary).
static func tube_color(i: int) -> Color:
	var k := EcoVary.spread(i, EcoVary.SHADE, 0.1)
	return Color(TUBE_COLOR.r * k, TUBE_COLOR.g * k, TUBE_COLOR.b * k, 1.0)


## Цвет венчика номер i (sRGB): тон от розового к коралловому, яркость ±15 %.
static func crown_color(i: int) -> Color:
	var c := CROWN_COLOR
	c.h = fposmod(c.h + (EcoVary.unit(i, EcoVary.HUE) * 2.0 - 1.0) * 0.03, 1.0)
	var k := EcoVary.spread(i, EcoVary.SHADE, 0.15)
	return Color(minf(1.0, c.r * k), c.g * k, c.b * k, 1.0)


## Венчик трубки: на устье top, раскрыт на open (0…1); спрятанный — мал и утоплен в трубку.
static func crown_xform(top: Vector3, open: float) -> Transform3D:
	var s := lerpf(CLOSED, 1.0, clampf(open, 0.0, 1.0))
	var y := top.y - SINK * (1.0 - open) + CROWN_H * 0.5 * s
	return Transform3D(Basis.from_scale(Vector3(s, s, s)), Vector3(top.x, y, top.z))


func _fill_tubes() -> void:
	var buf := PackedFloat32Array()
	buf.resize(tubes.multimesh.instance_count * STRIDE)
	var i := 0
	for r in kamen.rows:
		for w in r.worms:
			for j in w.tube_base.size():
				var h := w.tube_len[j]
				var x := Transform3D(Basis.from_scale(Vector3(1, h, 1)), w.tube_base[j] + Vector3(0, h * 0.5, 0))
				_put(buf, i, x, tube_color(i).srgb_to_linear())
				i += 1
	tubes.multimesh.buffer = buf


## Переписать венчики, если ряды изменились (all — всё равно).
func sync(all := false) -> void:
	if not all and not kamen.changed:
		return
	var n := crowns.multimesh.instance_count
	if _buf.size() != n * STRIDE:
		_buf.resize(n * STRIDE)
	crown_at.resize(count())
	var i := 0
	for r in kamen.rows:
		for w in r.worms:
			for j in w.tube_base.size():
				var top := w.tube_base[j] + Vector3(0, w.tube_len[j], 0)
				var x := crown_xform(top, w.open)
				crown_at[i] = x
				_put(_buf, i, x, crown_color(i).srgb_to_linear())
				i += 1
	crowns.multimesh.buffer = _buf
	kamen.changed = false


static func _put(buf: PackedFloat32Array, i: int, x: Transform3D, col: Color) -> void:
	var b := x.basis
	var o := i * STRIDE
	buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = x.origin.x
	buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = x.origin.y
	buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = x.origin.z
	buf[o + 12] = col.r; buf[o + 13] = col.g; buf[o + 14] = col.b; buf[o + 15] = col.a
