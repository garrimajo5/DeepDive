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


## Рамка вокруг точек `pts`, раздутая на `grow` м (#849): неподвижным видам — по местам их экземпляров, чтобы
## Godot отсекал вид за спиной и вдали и не пересчитывал границы при каждой записи буфера. Пусто — нулевая рамка.
static func frame(pts: PackedVector3Array, grow: float) -> AABB:
	if pts.is_empty():
		return AABB()
	var box := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box = box.expand(p)
	return box.grow(grow)


## Поставить всем `mis` одну рамку по точкам `pts` с запасом `grow` (см. frame).
static func fit(mis: Array, pts: PackedVector3Array, grow: float) -> void:
	var box := frame(pts, grow)
	for mi: MultiMeshInstance3D in mis:
		mi.custom_aabb = box


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


## Треугольник в SurfaceTool лицом от точки `inside` (обход переставит сам), с плоской нормалью и цветом.
## Вырожденный пропускает.
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	if n.dot((a + b + c) / 3.0 - inside) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = -n.normalized()
	for p in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)


## Точки эллипсоида с центром c и полуосями r: rings + 1 рядов по широте (от верхнего полюса) по seg точек.
## turn — поворот сетки вокруг y; top — доля от полюса до полюса (0,5 — купол, низ открыт).
static func ellipsoid_rows(c: Vector3, r: Vector3, seg: int, rings: int, turn := 0.0, top := 1.0) -> Array:
	var pts: Array = []
	for i in rings + 1:
		var th := PI * top * float(i) / rings
		var row: Array[Vector3] = []
		for j in seg:
			var ph := TAU * float(j) / seg + turn
			row.append(c + Vector3(sin(th) * cos(ph) * r.x, cos(th) * r.y, sin(th) * sin(ph) * r.z))
		pts.append(row)
	return pts


## Эллипсоид (или купол при top = 0,5) из seg × rings граней одного цвета, лицом наружу.
static func ellipsoid(st: SurfaceTool, c: Vector3, r: Vector3, seg: int, rings: int, col: Color,
		turn := 0.0, top := 1.0) -> void:
	var pts := ellipsoid_rows(c, r, seg, rings, turn, top)
	for i in rings:
		for j in seg:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][(j + 1) % seg]
			var d: Vector3 = pts[i + 1][j]
			var e: Vector3 = pts[i + 1][(j + 1) % seg]
			tri(st, a, b, d, col, c)
			tri(st, b, e, d, col, c)
