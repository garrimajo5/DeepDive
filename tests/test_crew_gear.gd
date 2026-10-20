extends TestCase
## По issue #157: снаряжение MOD-016 сидит на теле — фартук и туника не отстают от торса, лямки не висят дугами над
## плечами, поднятый щиток лежит на макушке, а не парит над головой. Тело — меш модели в позе стоя (скиннинг на CPU),
## деталь — её вершины по CrewView; зазор — расстояние до ближайшей вершины тела, знак — по нормали тела.

var cv: CrewView


func before() -> void:
	cv = CrewView.new()
	tree.root.add_child(cv)
	var ms := []
	for look in 2:
		for role in [Crew.Role.ENGINEER, Crew.Role.BIOLOGIST]:
			var m := Crew.Member.new(role)
			m.look = look
			ms.append(m)
	cv.set_members(ms, null)
	cv.apply()
	await frames(1)


func after() -> void:
	cv.queue_free()
	await frames(1)


## Тело фигуры i в осях скелета: [точки, нормали].
func _body(i: int) -> Array:
	var sk: Skeleton3D = cv.skeletons[i]
	var mi: MeshInstance3D = cv.meshes[i]
	var skin: Skin = mi.skin
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var bones = arr[Mesh.ARRAY_BONES]
	var weights = arr[Mesh.ARRAY_WEIGHTS]
	var nb: int = bones.size() / v.size()
	var xf: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = sk.find_bone(skin.get_bind_name(b))
		xf.append(sk.get_bone_global_pose(bone) * skin.get_bind_pose(b))
	var pts := PackedVector3Array()
	var ns := PackedVector3Array()
	for k in v.size():
		var p := Vector3.ZERO
		var n := Vector3.ZERO
		for j in nb:
			var w: float = weights[k * nb + j]
			if w > 0.0:
				var t: Transform3D = xf[bones[k * nb + j]]
				p += w * (t * v[k])
				n += w * (t.basis * nrm[k])
		pts.append(p)
		ns.append(n.normalized())
	return [pts, ns]


## Зазоры вершин детали gn фигуры i до тела (каждая step-я вершина), м; < 0 — внутри тела.
func _gaps(i: int, gn: String, body: Array, step: int) -> PackedFloat32Array:
	var sk: Skeleton3D = cv.skeletons[i]
	var node: Node3D = cv.gear[i][gn]
	var g := sk.get_bone_global_pose(sk.find_bone(CrewRig.GEAR[gn][0])) * node.transform
	var mesh: MeshInstance3D = node.find_children("*", "MeshInstance3D", true, false)[0]
	var gv: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var pts: PackedVector3Array = body[0]
	var ns: PackedVector3Array = body[1]
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var at := PackedVector3Array()
	for k in range(0, gv.size(), step):
		var q := g * gv[k]
		at.append(q)
		lo = lo.min(q)
		hi = hi.max(q)
	var box := AABB(lo, hi - lo).grow(0.2)
	var near_pts := PackedInt32Array()
	for k in pts.size():
		if box.has_point(pts[k]):
			near_pts.append(k)
	var out := PackedFloat32Array()
	for q in at:
		var best := INF
		var bk := -1
		for k in near_pts:
			var d := q.distance_squared_to(pts[k])
			if d < best:
				best = d
				bk = k
		out.append((q - pts[bk]).dot(ns[bk]))
	return out


func _check(i: int, gn: String, body: Array, step: int) -> void:
	var gaps := _gaps(i, gn, body, step)
	var sum := 0.0
	var far := 0
	var inside := 0
	for d in gaps:
		sum += absf(d)
		if d > 0.06:
			far += 1
		if d < -0.015:
			inside += 1
	var m: Crew.Member = cv.members[i]
	var who := "%s, внешность %d" % [gn, m.look]
	var mean := sum / gaps.size()
	ok(mean < 0.04, "%s: средний зазор %.3f м (< 4 см)" % [who, mean])
	ok(far < gaps.size() * 0.12, "%s: дальше 6 см — %d из %d" % [who, far, gaps.size()])
	ok(inside < gaps.size() * 0.12, "%s: в теле глубже 1,5 см — %d из %d" % [who, inside, gaps.size()])


func test_apron_and_tunic_fit_torso() -> void:
	for i in cv.members.size():
		var body := _body(i)
		for gn in ["gear-fartuk", "gear-tunika"]:
			if cv.gear[i].has(gn):
				_check(i, gn, body, 1)


func test_raised_visor_on_head() -> void:
	for i in cv.members.size():
		if cv.gear[i].has("gear-shchitok"):
			_check(i, "gear-shchitok", _body(i), 3)
