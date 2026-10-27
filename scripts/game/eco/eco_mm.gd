class_name EcoMM
## Общие куски видов живого мира (по issue #767): сборка MultiMesh, запись трансформа в буфер,
## ArrayMesh из треугольников. Новые виды бестиария берут их отсюда, а не копируют.

## Длина записи одного экземпляра в буфере MultiMesh.TRANSFORM_3D (матрица 3×4).
const STRIDE := 12
## Рамка на всю отмель: стаи и облака двигаются — границы не пересчитываем.
const SHOAL_AABB := AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))


## MultiMeshInstance3D на слое мира, без тени, ребёнком `parent`. `whole` — рамка `SHOAL_AABB`
## (для подвижного), иначе Godot считает границы по экземплярам.
static func instance(parent: Node, n: String, mesh: Mesh, count: int, colors := false, custom := false,
		whole := true) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = n
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	mi.multimesh = mm
	if whole:
		mi.custom_aabb = SHOAL_AABB
	parent.add_child(mi)
	return mi


## Трансформ в буфер MultiMesh с позиции `i` (порядок строк — как у `MultiMesh.buffer`).
## Тело повторено в put_basis: вызов функции в GDScript дорог, а это — горячий цикл каждого вида.
static func put(buf: PackedFloat32Array, i: int, tr: Transform3D) -> void:
	var b := tr.basis
	var o := tr.origin
	buf[i] = b.x.x; buf[i + 1] = b.y.x; buf[i + 2] = b.z.x; buf[i + 3] = o.x
	buf[i + 4] = b.x.y; buf[i + 5] = b.y.y; buf[i + 6] = b.z.y; buf[i + 7] = o.y
	buf[i + 8] = b.x.z; buf[i + 9] = b.y.z; buf[i + 10] = b.z.z; buf[i + 11] = o.z


static func put_basis(buf: PackedFloat32Array, i: int, b: Basis, o: Vector3) -> void:
	buf[i] = b.x.x; buf[i + 1] = b.y.x; buf[i + 2] = b.z.x; buf[i + 3] = o.x
	buf[i + 4] = b.x.y; buf[i + 5] = b.y.y; buf[i + 6] = b.z.y; buf[i + 7] = o.y
	buf[i + 8] = b.x.z; buf[i + 9] = b.y.z; buf[i + 10] = b.z.z; buf[i + 11] = o.z


## ArrayMesh из треугольников: вершины, нормали, цвета (цвета можно пустые).
static func tris(verts: PackedVector3Array, normals: PackedVector3Array,
		colors := PackedColorArray()) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
