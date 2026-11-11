extends TestCase
## Купольник на скелете ANIM-004 (`models/kupolnik-anim.glb`, приёмка по #1601; геометрия, UV и материал — модели
## MOD-022): один скелет на 20 костей, одна сетка со skin; клипы `Idle` 4 с и `Swim` 3 с —
## циклы без шва, `OpenPetal` 5 с — разовый, начинается и кончается позой `Idle`; в подъёме створки (1,2…3,8 с,
## `EcoDome.LIFT`) подушки среднего захвата поднимаются ≈ 0,6 м, правого — держат обод на месте, левый не участвует.

const PATH := "res://models/kupolnik-anim.glb"
const BONES := ["Root", "Body", "MantleL", "MantleR",
		"GraspLUpper", "GraspLLower", "GraspLPadA", "GraspLPadB",
		"GraspMUpper", "GraspMLower", "GraspMPadA", "GraspMPadB",
		"GraspRUpper", "GraspRLower", "GraspRPadA", "GraspRPadB",
		"SiphonLBase", "SiphonLValve", "SiphonRBase", "SiphonRValve"]


func _rig() -> Node3D:
	var scene: PackedScene = load(PATH)
	return scene.instantiate()


func _player(n: Node) -> AnimationPlayer:
	return n.find_children("*", "AnimationPlayer", true, false)[0]


func _skeleton(n: Node) -> Skeleton3D:
	return n.find_children("*", "Skeleton3D", true, false)[0]


func test_skeleton_and_mesh() -> void:
	var n := _rig()
	eq(n.find_children("*", "Skeleton3D", true, false).size(), 1, "один скелет")
	var sk := _skeleton(n)
	eq(sk.get_bone_count(), BONES.size(), "20 костей")
	for b in BONES:
		ok(sk.find_bone(b) >= 0, "кость %s" % b)
	eq(sk.get_bone_parent(sk.find_bone("GraspMPadA")), sk.find_bone("GraspMLower"), "захват цепочкой")
	eq(sk.get_bone_parent(sk.find_bone("SiphonRValve")), sk.find_bone("SiphonRBase"), "клапан на сифоне")
	var meshes := n.find_children("*", "MeshInstance3D", true, false)
	eq(meshes.size(), 1, "одна сетка")
	var mi: MeshInstance3D = meshes[0]
	ok(mi.skin != null, "сетка со skin")
	eq(mi.mesh.get_surface_count(), 1, "один материал")
	var tris: int = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	ok(tris <= 8000, "треугольников %d — как у MOD-022" % tris)
	var box: AABB = mi.mesh.get_aabb()
	near(box.size.z, 3.0, 0.3, "длина 3 м — размер MOD-022")
	near(box.position.y, 0.0, 0.01, "pivot — низ")
	var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
	ok(mat != null and mat.emission_enabled and mat.emission_texture != null, "фотофоры — маской emissive")
	n.free()


func test_clips_and_loops() -> void:
	var n := _rig()
	var ap := _player(n)
	var want := {"Idle": [4.0, Animation.LOOP_LINEAR], "Swim": [3.0, Animation.LOOP_LINEAR],
			"OpenPetal": [5.0, Animation.LOOP_NONE]}
	for name in want:
		if not ok(ap.has_animation(name), "клип %s" % name):
			continue
		var a := ap.get_animation(name)
		near(a.length, want[name][0], 1e-3, "%s: длина" % name)
		eq(a.loop_mode, want[name][1], "%s: цикл" % name)
	n.free()


## Мировые точки костей в момент t клипа.
func _pose(n: Node3D, clip: String, t: float) -> Dictionary:
	var ap := _player(n)
	ap.play(clip)
	ap.seek(t, true)
	var sk := _skeleton(n)
	var out := {}
	for b in BONES:
		out[b] = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b)).origin
	return out


func _gap(a: Dictionary, b: Dictionary) -> float:
	var worst := 0.0
	for k in a:
		worst = maxf(worst, (a[k] as Vector3).distance_to(b[k]))
	return worst


func test_loops_seamless_and_petal_from_idle() -> void:
	var n := _rig()
	tree.root.add_child(n)
	await frames(1)
	var idle := _pose(n, "Idle", 0.0)
	ok(_gap(_pose(n, "Idle", 4.0), idle) < 0.005, "Idle — цикл без шва")
	ok(_gap(_pose(n, "Swim", 3.0), _pose(n, "Swim", 0.0)) < 0.005, "Swim — цикл без шва")
	ok(_gap(_pose(n, "OpenPetal", 0.0), idle) < 0.005, "OpenPetal начинается позой Idle")
	ok(_gap(_pose(n, "OpenPetal", 5.0), idle) < 0.005, "OpenPetal кончается позой Idle")
	n.queue_free()
	await frames(1)


func test_petal_lift() -> void:
	var n := _rig()
	tree.root.add_child(n)
	await frames(1)
	var a := _pose(n, "OpenPetal", EcoDome.LIFT.x)
	var b := _pose(n, "OpenPetal", EcoDome.LIFT.y)
	var lift: float = (b["GraspMPadA"] as Vector3).y - (a["GraspMPadA"] as Vector3).y
	ok(lift > 0.45 and lift < 0.75, "средний захват поднимает створку на %.2f м" % lift)
	var hold := 0.0
	for i in 11:
		var t := lerpf(EcoDome.LIFT.x, EcoDome.LIFT.y, i / 10.0)
		hold = maxf(hold, (_pose(n, "OpenPetal", t)["GraspRPadA"] as Vector3).distance_to(a["GraspRPadA"]))
	ok(hold < 0.01, "правый держит обод на месте (сдвиг %.3f м)" % hold)
	ok((a["GraspMPadA"] as Vector3).z < (_pose(n, "Idle", 0.0)["Body"] as Vector3).z, "захваты — вперёд (−Z)")
	n.queue_free()
	await frames(1)
