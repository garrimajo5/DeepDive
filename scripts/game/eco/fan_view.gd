class_name FanView
extends MultiMeshInstance3D
## Веерники в сцене: все — один MultiMesh из одного многоугольника по контуру кружева в прямоугольнике 2,6 × 3 м
## (build_mesh, Б6), кружево ветвей
## рисует общий шейдер растений (EcoShaders.PLANT, как fanTex в js/creatures.js: ствол, 13 лучей веером и дуги
## между ними; остальное отброшено).
## Своего света нет: светлые края — отражённый свет (ART-004, #68E6DC). Плоскость повёрнута навстречу потоку
## (EcoFan.basis), видна с обеих сторон. Стоит на слое отмели (OceanView.LAYER_WORLD). Разброс (Б4, EcoVary по номеру
## веера): свой размер и оттенок кружева — цвет экземпляра, мир не меняется.

const RIB := Color("1f8796")
const EDGE := Color("68E6DC")
## Веер жёсткий — в течении лишь чуть выгибается парусом (EcoCurrent.sway, в шейдере): доли высоты.
const BEND := Vector3(0.04, 0.02, 0.015)
## Чисел на веер в буфере: transform 3 × 4 по строкам и цвет экземпляра (4).
const STRIDE := 16
## Разброс веерников: размер ±15 %, светлее-темнее ±15 %, зеленее-синее на 8 %.
const SIZE_SPREAD := 0.15
const SHADE_SPREAD := 0.15
const HUE_SPREAD := 0.08

var fans: EcoFan
## Последний буфер MultiMesh (для тестов).
var buffer := PackedFloat32Array()


func _init(system: EcoFan) -> void:
	fans = system
	name = "Веерники"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = build_mesh()
	mm.instance_count = fans.fans.size()
	multimesh = mm
	sync(0.0)


## Лучи кружева расходятся из HUB (м над подножием) в пределах ±SPREAD рад от вертикали, кружево кончается на эллипсе
## el = EDGE_EL с полуосями AXES (el = |(dx / AXES.x, dy / AXES.y)|) — как в шейдере (EcoShaders.PLANT, режим FAN).
const HUB := 0.35
const SPREAD := 1.3
const AXES := Vector2(0.55, 0.95)
const EDGE_EL := 2.6
## Ствол: полуширина и высота.
const TRUNK := Vector2(0.09, 0.4)
## Дуг описанного многоугольника по краю веера.
const ARCS := 8


## Меш веера (Б6): не прямоугольник 2,6 × 3 м, а многоугольник по контуру кружева — веер из HUB, описанный вокруг
## эллипса края (вершины на радиусе EDGE_EL / cos(половины шага) в осях эллипса — хорды не срезают кружево), обрезан
## шириной прямоугольника; и ствол. Пустые углы прямоугольника больше не считаются и не отбрасываются шейдером
## (фрагментов на треть меньше: 5,0 м² вместо 7,8), а промежуточные вершины гнут веер парусом плавно, а не одной прямой. UV — как у
## прямоугольника (x поперёк, y от верха), кружево рисует тот же шейдер. Плоскость XY, нормаль +Z.
static func build_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var tri := outline_tris()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	for p in tri:
		verts.append(Vector3(p.x, p.y, 0.0))
		uvs.append(Vector2(p.x / EcoFan.WIDTH + 0.5, 1.0 - p.y / EcoFan.HEIGHT))
		norms.append(Vector3.BACK)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, EcoShaders.plant(EcoShaders.Plant.FAN, {"paint": RIB, "edge": EDGE, "rough": 0.6,
		"size": Vector2(EcoFan.WIDTH, EcoFan.HEIGHT), "bend": BEND, "reach": EcoFan.HEIGHT}))
	return mesh


## Треугольники меша в плоскости веера (x поперёк, y от подножия), по три точки; лицом к +Z по правилу Godot —
## (b − a) × (c − a) смотрит в −Z.
static func outline_tris() -> PackedVector2Array:
	var hub := Vector2(0.0, HUB)
	# края сектора в осях эллипса: прямая из HUB под углом SPREAD остаётся прямой
	var side := Vector2(sin(SPREAD) / AXES.x, cos(SPREAD) / AXES.y).angle()   # от оси +x
	var from := PI - side
	var step := (from - side) / ARCS
	var r := EDGE_EL / cos(step * 0.5)
	var poly := PackedVector2Array([hub])
	for i in ARCS + 1:
		var a := from - step * i   # слева направо
		poly.append(hub + Vector2(cos(a) * AXES.x, sin(a) * AXES.y) * r)
	var w := EcoFan.WIDTH * 0.5
	poly = _clip_x(poly, -w, 1.0)
	poly = _clip_x(poly, w, -1.0)
	var out := PackedVector2Array()
	for i in range(1, poly.size() - 1):
		out.append_array([poly[0], poly[i], poly[i + 1]])
	# ствол: от подножия до TRUNK.y
	var t := TRUNK
	out.append_array([Vector2(-t.x, 0), Vector2(-t.x, t.y), Vector2(t.x, t.y),
		Vector2(-t.x, 0), Vector2(t.x, t.y), Vector2(t.x, 0)])
	return out


## Обрезать выпуклый многоугольник полуплоскостью sign · (x − at) ≥ 0 (Сазерленд — Ходжман).
static func _clip_x(poly: PackedVector2Array, at: float, sign: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var da := sign * (a.x - at)
		var db := sign * (b.x - at)
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


## Двойник маски кружева шейдера (EcoShaders.PLANT, режим FAN): рисуется ли точка p плоскости веера (м).
static func lace(p: Vector2) -> bool:
	var d := p - Vector2(0.0, HUB)
	var r := d.length()
	var a := atan2(d.x, maxf(d.y, 1e-4))
	var w := p.y < TRUNK.y and absf(p.x) <= TRUNK.x
	var el := Vector2(d.x / AXES.x, d.y / AXES.y).length()
	if d.y > 0.0 and absf(a) < SPREAD:
		var k := (a + 1.25) / 2.5 * 12.0
		var ray := absf(k - roundf(k)) * 2.5 / 12.0 * r
		var ring := absf(fposmod(el / 0.22, 1.0) - 0.5) * 0.22
		w = w or ray <= 0.05 - r * 0.008 or (ring <= 0.024 and el >= 0.3)
		w = w and el <= EDGE_EL
	return w


## Расставить веера в момент t (время мира).
func sync(t: float) -> void:
	buffer.resize(fans.fans.size() * STRIDE)
	for f in fans.fans:
		var b := EcoFan.basis(f, t) * fan_scale(f.index)
		var o := f.pos
		var c := fan_tint(f.index)
		var i := f.index * STRIDE
		var row := [b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z, c.r, c.g, c.b, 1.0]
		for k in STRIDE:
			buffer[i + k] = row[k]
	EcoMM.send(self, buffer)


## Размер веера n (множитель прямоугольника; колыхание в шейдере считает высоту по осям — веер выше гнётся дальше).
static func fan_scale(n: int) -> float:
	return EcoVary.spread(n, EcoVary.SIZE, SIZE_SPREAD)


## Множитель красок веера n — цвет экземпляра: светлее или темнее, зеленее или синее.
static func fan_tint(n: int) -> Color:
	var k := EcoVary.spread(n, EcoVary.SHADE, SHADE_SPREAD)
	var h := (EcoVary.unit(n, EcoVary.HUE) * 2.0 - 1.0) * HUE_SPREAD
	return Color(k, k * (1.0 + h), k * (1.0 - h))


## Расстановка веера n из буфера.
static func transform_at(buf: PackedFloat32Array, n: int) -> Transform3D:
	var i := n * STRIDE
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
