extends TestCase
## Модель экипажа MOD-012 повторяет позу Crew.Member (CrewRig.pose): рост, ступни на полу, курс, руки на штурвале,
## длины костей модели не меняются, колено вперёд, локоть назад.

var rests := {}


func _rest(look: int) -> CrewRig.Rest:
	if not rests.has(look):
		var root: Node = load(CrewRig.MODELS[look]).instantiate()
		rests[look] = CrewView.rest_of(root.find_children("*", "Skeleton3D", true, false)[0])
		root.free()
	return rests[look]


func _pose(m: Crew.Member, look: int = 0) -> Dictionary:
	var r := _rest(look)
	var g := CrewRig.pose(r, m.joints(), CrewRig.SEAT_BEND if m.seated else 0.0)
	var out := {}
	for i in g.size():
		out[r.names[i]] = g[i]
	return out


func test_standing_matches_model_rest() -> void:
	for look in CrewRig.MODELS.size():
		var m := Crew.Member.new()
		m.follow(0.0, 0.0, 0.0, false, 0.0, 0.1)
		var p := _pose(m, look)
		var r := _rest(look)
		near(p["Head"].origin.y, r.at("Head").y, 0.03, "голова на высоте модели (%s)" % CrewRig.LOOK_NAMES[look])
		for k in ["LeftToeBase", "RightToeBase"]:
			ok(p[k].origin.y > 0.0 and p[k].origin.y < 0.09, "носок у пола: %s %.3f" % [k, p[k].origin.y])
		ok(p["RightHand"].origin.x > 0.2 and p["LeftHand"].origin.x < -0.2, "правая рука — к правому борту")
		ok(p["RightHand"].origin.y > 0.75 and p["RightHand"].origin.y < 1.1, "руки вдоль тела")


func test_bone_lengths_kept() -> void:
	var m := Crew.Member.new()
	m.follow(0.0, 0.0, 0.4, true, 0.6, 0.1)
	var p := _pose(m)
	var r := _rest(0)
	for pair in [["RightArm", "RightForeArm"], ["RightForeArm", "RightHand"], ["LeftUpLeg", "LeftLeg"],
			["LeftLeg", "LeftFoot"], ["Hips", "Spine02"], ["neck", "Head"]]:
		near(p[pair[0]].origin.distance_to(p[pair[1]].origin), r.at(pair[0]).distance_to(r.at(pair[1])), 1e-4,
			"длина %s–%s" % pair)


func test_faces_yaw() -> void:
	var m := Crew.Member.new()
	m.follow(1.0, -2.0, PI / 2.0, false, 0.0, 0.1)  # лицом к левому борту (−X)
	var p := _pose(m)
	var face: Vector3 = p["headfront"].origin - p["Head"].origin
	ok(face.x < -0.04 and absf(face.z) < 0.03, "лицо к левому борту (%s)" % face)
	near(p["LeftUpLeg"].origin.x, 1.0, 0.05, "стоит на месте игрока")
	ok(p["LeftUpLeg"].origin.z > p["RightUpLeg"].origin.z, "левое бедро к корме")


func test_seated_hands_on_wheel() -> void:
	for turn in [0.0, 0.8, -0.8]:
		var m := Crew.Member.new()
		m.follow(0.0, Deck.SEAT_Z, 0.0, true, turn, 0.1)
		var p := _pose(m)
		var grips := Crew.wheel_grips(turn)
		for side in 2:
			var hand: Transform3D = p["LeftHand" if side == 0 else "RightHand"]
			var mid := hand * Vector3(0.0, CrewRig.GRIP, 0.0)
			ok(mid.distance_to(grips[side]) < 0.05, "кисть на ободе, поворот %.1f, рука %d: %.3f м" % [turn, side,
				mid.distance_to(grips[side])])


func test_knees_forward_elbows_back() -> void:
	var m := Crew.Member.new()
	m.follow(0.0, Deck.SEAT_Z, 0.0, true, 0.0, 0.1)
	var p := _pose(m)
	ok(p["LeftLeg"].origin.z < p["LeftUpLeg"].origin.z - 0.25, "сидя колено вперёд")
	ok(p["LeftFoot"].origin.y < p["LeftLeg"].origin.y - 0.25, "голень вниз")
	var s := Crew.Member.new()
	s.weld(Vector3(0.6, 1.2, -1.0), Vector3(-1, 0, 0))
	s.follow(0.0, -1.0, -PI / 2.0, false, 0.0, 0.1)
	p = _pose(s)
	var sh: Vector3 = p["RightArm"].origin
	var wr: Vector3 = p["RightHand"].origin
	var el: Vector3 = p["RightForeArm"].origin
	var d := (wr - sh).normalized()
	var out := el - sh - d * (el - sh).dot(d)
	ok(out.dot(s.joints()["fwd"]) < 0.0, "локоть не вперёд")
	ok(p["RightHand"].origin.distance_to(s.joints()["wrist_r"]) < 0.15, "рука к резаку")


func test_own_mesh_cut() -> void:
	var root: Node = load(CrewRig.MODELS[0]).instantiate()
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = sk.find_children("*", "MeshInstance3D", true, false)[0]
	var full := (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	var own := CrewView.cut_mesh(mi.mesh, mi.skin, sk, CrewRig.HIDE_HEAD + CrewRig.HIDE_CHEST, 0.15)
	var arr := own.surface_get_arrays(0)
	var n := (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	ok(n < full and n > full * 0.5, "без головы: %d из %d" % [n / 3, full / 3])
	var top := 0.0
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for k in (arr[Mesh.ARRAY_INDEX] as PackedInt32Array):
		top = maxf(top, verts[k].y)
	ok(top < 1.62, "выше шеи ничего не осталось (%.2f м)" % top)
	root.free()
