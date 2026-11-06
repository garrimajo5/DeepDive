class_name TuftsView
extends StonesView
## Кочки водорослей-щёток на дне (`SeabedTufts`): тот же MultiMesh, что у камней `StonesView` (+1 вызов отрисовки,
## тот же материал по цвету вершин — шейдеров не прибавилось), меш — пучок лопастей `tuft_mesh`. Слой отмели.

const BLADES := 7          ## лопастей в пучке
const BLADE_R := 0.07      ## полуширина основания лопасти (доля поперечника)
const SPREAD := 0.42       ## насколько верхушки разошлись от середины (доля поперечника)


func _init() -> void:
	super()
	name = "Кочки на дне"
	stones = SeabedTufts.new()
	multimesh.mesh = tuft_mesh()
	(material_override as StandardMaterial3D).roughness = 0.85   # мокрые лопасти чуть ловят луч


## Пучок поперечника 1 м и высоты 1 (размер задаёт экземпляр): BLADES трёхгранных лопастей от середины веером —
## основание у грунта, верхушка отклонена наружу, высоты разные; одна в середине стоит прямо. Грани плоские,
## 3 треугольника на лопасть. Лицевая сторона — по часовой стрелке снаружи.
static func tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in BLADES:
		var a := TAU * i / (BLADES - 1)
		var mid := i == BLADES - 1
		var root := Vector3.ZERO if mid else Vector3(sin(a), 0.0, cos(a)) * 0.12
		var lean := 0.0 if mid else SPREAD * lerpf(0.75, 1.15, HashNoise.hash2(i * 5 + 2, 9))
		var tall := lerpf(0.7, 1.0, HashNoise.hash2(i * 3 + 1, 17))
		var tip := Vector3(sin(a) * lean, tall, cos(a) * lean)
		var base: Array[Vector3] = []
		for j in 3:
			var b := a + TAU * j / 3.0
			base.append(root + Vector3(sin(b), 0.0, cos(b)) * BLADE_R)
		var axis := (root + tip) * 0.5   # середина лопасти — грани смотрят от неё
		for j in 3:
			_face(st, base[j], base[(j + 1) % 3], tip, axis)
	return st.commit()


static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	if (b - a).cross(c - a).dot((a + b + c) / 3.0 - inside) > 0.0:   # (b − a) × (c − a) должно смотреть внутрь
		var tmp := b
		b = c
		c = tmp
	var nrm := (c - a).cross(b - a).normalized()
	for p in [a, b, c]:
		st.set_normal(nrm)
		st.add_vertex(p)
