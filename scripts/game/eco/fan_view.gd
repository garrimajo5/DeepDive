class_name FanView
extends MultiMeshInstance3D
## Веерники в сцене: все — один MultiMesh из одного прямоугольника 2,6 × 3 м (два треугольника), кружево ветвей
## рисует общий шейдер растений (EcoShaders.PLANT, как fanTex в js/creatures.js: ствол, 13 лучей веером и дуги
## между ними; остальное отброшено).
## Своего света нет: светлые края — отражённый свет (ART-004, #68E6DC). Плоскость повёрнута навстречу потоку
## (EcoFan.basis), видна с обеих сторон. Стоит на слое отмели (OceanView.LAYER_WORLD).

const RIB := Color("1f8796")
const EDGE := Color("68E6DC")
## Чисел на веер в буфере: transform 3 × 4 по строкам.
const STRIDE := 12

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
		"size": Vector2(EcoFan.WIDTH, EcoFan.HEIGHT)}))
	return mesh


## Расставить веера в момент t (время мира).
func sync(t: float) -> void:
	buffer.resize(fans.fans.size() * STRIDE)
	for f in fans.fans:
		var b := EcoFan.basis(f, t)
		var o := f.pos
		var i := f.index * STRIDE
		var row := [b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z]
		for k in STRIDE:
			buffer[i + k] = row[k]
	multimesh.buffer = buffer


## Расстановка веера n из буфера.
static func transform_at(buf: PackedFloat32Array, n: int) -> Transform3D:
	var i := n * STRIDE
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
