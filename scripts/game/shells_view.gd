class_name ShellsView
extends StonesView
## Ракушки на дне (`SeabedShells`): тот же MultiMesh, что у камней `StonesView` (+1 вызов отрисовки, тот же
## материал по цвету вершин — шейдеров не прибавилось), меш — ребристая створка `shell_mesh`. Слой отмели.

const RIBS := 9        ## рёбер на створке
const RIB := 0.07      ## выступ ребра по краю (доля поперечника)


func _init() -> void:
	super()
	name = "Ракушки на дне"
	stones = SeabedShells.new()
	multimesh.mesh = shell_mesh()
	(material_override as StandardMaterial3D).roughness = 0.55   # перламутр чуть блестит в луче


## Створка поперечника 1 м (размер задаёт экземпляр): чаша высотой `SeabedShells.SHELL_HEIGHT`, замок к −z, край —
## волной рёбер; два кольца и макушка, грани плоские. Лицевая сторона — по часовой стрелке снаружи.
static func shell_mesh() -> ArrayMesh:
	var n := RIBS * 2
	var h := SeabedShells.SHELL_HEIGHT
	var top := Vector3(0, h, -0.12)
	var mid: Array[Vector3] = []
	var rim: Array[Vector3] = []
	for i in n:
		# веер: угол от замка, створка шире к краю
		var a := TAU * i / n
		var bump := RIB if i % 2 == 0 else 0.0
		var r := 0.5 * (1.0 + bump)
		var dir := Vector3(sin(a) * 0.5, 0.0, cos(a) * 0.46) * 2.0
		rim.append(Vector3(dir.x * r, bump * 0.4, dir.z * r))
		mid.append(Vector3(dir.x * r * 0.55, h * 0.72 + bump * 0.5, dir.z * r * 0.55 - 0.05))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var j := (i + 1) % n
		_face(st, top, mid[i], mid[j])
		_face(st, mid[i], rim[i], rim[j])
		_face(st, mid[i], rim[j], mid[j])
	return st.commit()


static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var inside := Vector3(0, -0.3, -0.05)   # под чашей
	if (b - a).cross(c - a).dot((a + b + c) / 3.0 - inside) > 0.0:   # (b − a) × (c − a) должно смотреть внутрь
		var tmp := b
		b = c
		c = tmp
	var nrm := (c - a).cross(b - a).normalized()
	for p in [a, b, c]:
		st.set_normal(nrm)
		st.add_vertex(p)
