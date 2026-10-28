class_name FanView
extends MultiMeshInstance3D
## Веерники в сцене: все — один MultiMesh из одного прямоугольника 2,6 × 3 м (два треугольника), кружево ветвей
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


## Прямоугольник веера: низ у подножия, плоскость XY, нормаль +Z.
static func build_mesh() -> ArrayMesh:
	var w := EcoFan.WIDTH / 2.0
	var h := EcoFan.HEIGHT
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(w, h, 0), Vector3(-w, h, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	# лицом к +Z по правилу Godot: (b − a) × (c − a) смотрит в −Z
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, EcoShaders.plant(EcoShaders.Plant.FAN, {"paint": RIB, "edge": EDGE, "rough": 0.6,
		"size": Vector2(EcoFan.WIDTH, EcoFan.HEIGHT), "bend": BEND, "reach": EcoFan.HEIGHT}))
	return mesh


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
