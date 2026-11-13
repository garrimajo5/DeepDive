extends TestCase
## Модель Террасы врат MOD-023 (приёмка v21 в PR #1444, заказ #999; концепт ART-079 — `docs/concept-art/terrasa-vrat.md`):
## габарит X 120 × Y 58 × Z 23 м ±5 %, pivot — центр прохода на полу; три LOD по бюджету; свободный проход
## X −24…+24 × Y 0…22 м насквозь вдоль Z пуст на каждом LOD (решение 12.11 по силуэту ансамбля, 48 × 22 м);
## створки `Stvorka0…2` и `Diagnostika` — отдельные узлы у правой опоры вне прохода; светятся только полипы.
## Встройка в сцену (вместо временной `GateArch`) — отдельная задача.

const PATH := "res://models/terrasa-vrat.glb"
const PASS_HALF := 24.0
const PASS_TOP := 22.0
const BUDGET := {"LOD0": 42000, "LOD1": 12000, "LOD2": 5000}
const MOVING := ["Stvorka0", "Stvorka1", "Stvorka2", "Diagnostika"]


func _model() -> Node3D:
	return (load(PATH) as PackedScene).instantiate()


func _tris(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		var a: Array = mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx = a[Mesh.ARRAY_INDEX]
		if idx == null or (idx as PackedInt32Array).is_empty():
			for p in v:
				out.append(mi.transform * p)
		else:
			for k in idx:
				out.append(mi.transform * v[k])
	return out


func _meshes(n: Node) -> Array:
	return n.find_children("*", "MeshInstance3D", true, false)


func test_nodes_and_budget() -> void:
	var n := _model()
	var moving := 0
	for name in MOVING:
		var mi := n.get_node_or_null(name) as MeshInstance3D
		if ok(mi != null, "узел %s" % name):
			moving += _tris(mi).size() / 3
	ok(moving <= 2000, "створки и диагностика: %d ≤ 2000 треуг." % moving)
	for lod in BUDGET:
		var root := n.get_node_or_null(lod)
		if not ok(root != null, "узел %s" % lod):
			continue
		var t := 0
		for mi in _meshes(root):
			t += _tris(mi).size() / 3
		ok(t + moving <= BUDGET[lod], "%s: %d + %d ≤ %d треуг." % [lod, t, moving, BUDGET[lod]])
		eq(_meshes(root).size(), 3, "%s: статика — сетка на материал" % lod)
	n.free()


func test_size_and_pivot() -> void:
	var n := _model()
	var mi := n.get_node("LOD0/LOD0_Mineral") as MeshInstance3D
	var box: AABB = mi.transform * mi.mesh.get_aabb()
	near(box.size.x, 120.0, 6.0, "ширина 120 м")
	near(box.size.y, 58.0, 2.9, "высота 58 м")
	near(box.size.z, 23.0, 1.15, "толщина 23 м")
	near(box.position.y, 0.0, 0.5, "pivot — пол")
	near(box.get_center().x, 0.0, 1.0, "pivot — центр прохода по X")
	near(box.get_center().z, 0.0, 1.0, "pivot — центр прохода по Z")
	n.free()


## Ни один треугольник ни одного LOD не задевает проход: сначала отсев по рамке, затем отрезки вдоль Z сеткой 1 м
## и отрезки поперёк (вдоль X) — ловят и «плёнку», и тонкую перемычку.
func test_passage_empty() -> void:
	var n := _model()
	var pass_box := AABB(Vector3(-PASS_HALF, 0.05, -20.0), Vector3(PASS_HALF * 2.0, PASS_TOP - 0.05, 40.0))
	for mi in _meshes(n):
		var t := _tris(mi)
		var near_tris := PackedVector3Array()
		for i in range(0, t.size(), 3):
			var tb := AABB(t[i], Vector3.ZERO).expand(t[i + 1]).expand(t[i + 2])
			if tb.intersects(pass_box):
				near_tris.append_array([t[i], t[i + 1], t[i + 2]])
		var hits := 0
		for i in range(0, near_tris.size(), 3):
			var a := near_tris[i]
			var b := near_tris[i + 1]
			var c := near_tris[i + 2]
			for x in range(-23, 24):
				for y in range(1, int(PASS_TOP)):
					var o := Vector3(x, y, -20.0)
					if Geometry3D.segment_intersects_triangle(o, o + Vector3(0, 0, 40.0), a, b, c) != null:
						hits += 1
			for z in range(-19, 20):
				for y in range(1, int(PASS_TOP)):
					var o := Vector3(-PASS_HALF + 0.05, y, z)
					if Geometry3D.segment_intersects_triangle(o, o + Vector3(PASS_HALF * 2.0 - 0.1, 0, 0), a, b, c) != null:
						hits += 1
		eq(hits, 0, "%s: проход 48 × 22 м пуст" % mi.name)
	n.free()


## Гнёзда, створки, диагностика и кабели — у правой опоры (+X), вне прохода.
func test_contact_outside_passage() -> void:
	var n := _model()
	for name in MOVING + ["LOD0/LOD0_HumanCable", "LOD0/LOD0_Polyps"]:
		var mi := n.get_node(name) as MeshInstance3D
		var box: AABB = mi.transform * mi.mesh.get_aabb()
		ok(box.position.x > PASS_HALF + 10.0, "%s справа, вне прохода (x от %.1f)" % [name, box.position.x])
	var s0 := n.get_node("Stvorka0") as Node3D
	var s1 := n.get_node("Stvorka1") as Node3D
	near(s0.position.distance_to(s1.position), 4.0, 0.2, "тройка гнёзд — сторона 4 м")
	n.free()


## Гнёзда диагностики стоят на гнёздах модели: середина закрытой створки i — гнездо i (#1757).
func test_nests_behind_petals() -> void:
	var n := _model()
	for i in GateDiag.NESTS.size():
		var mi := n.get_node("Stvorka%d" % i) as MeshInstance3D
		var c: Vector3 = (mi.transform * mi.mesh.get_aabb()).get_center()
		var a: Vector3 = GateDiag.NESTS[i]["at"]
		near(a.x, c.x, 0.05, "гнездо %d: x створки" % i)
		near(a.y, c.y, 0.05, "гнездо %d: высота середины створки" % i)
		near(a.z, c.z, 0.15, "гнездо %d: на лице опоры, под створкой" % i)
	n.free()


func test_only_polyps_glow() -> void:
	var n := _model()
	for mi in _meshes(n):
		var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
		if not ok(mat != null, "%s: StandardMaterial3D" % mi.name):
			continue
		near(mat.metallic, 0.0, 1e-3, "%s: metallic 0" % mi.name)
		eq(mat.emission_enabled, String(mi.name).ends_with("Polyps"), "%s: свечение только у полипов" % mi.name)
	n.free()
