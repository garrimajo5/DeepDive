extends TestCase
## Анимированный экипаж ANIM-002 (`models/ekipazh-*.glb`, приёмка PR #697): тот же скелет MOD-012 на 24 кости,
## одна сетка со skin, четыре клипа на месте — Idle, Walk, SitIdle, PostIdle; все зациклены при импорте и бесшовны.
## Walk — 1,3 м пути за цикл (`Crew.STRIDE`), SitIdle — таз 0,67 м, ступни на полу.

const PATHS := ["res://models/ekipazh-muzhchina.glb", "res://models/ekipazh-zhenshchina.glb"]
const CLIPS := {"Idle": 4.0, "Walk": 0.8, "SitIdle": 4.0, "PostIdle": 4.0}
const BONES := ["Hips", "Spine02", "Spine01", "Spine", "neck", "Head",
		"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
		"RightShoulder", "RightArm", "RightForeArm", "RightHand",
		"LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
		"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]


func _rig(path: String) -> Node3D:
	var scene: PackedScene = load(path)
	return scene.instantiate()


func _player(n: Node) -> AnimationPlayer:
	return n.find_children("*", "AnimationPlayer", true, false)[0]


func _skeleton(n: Node) -> Skeleton3D:
	return n.find_children("*", "Skeleton3D", true, false)[0]


## Позиция кости в осях скелета в момент t клипа.
func _at(n: Node, clip: String, t: float, bone: String) -> Vector3:
	var ap := _player(n)
	ap.play(clip)
	ap.seek(t, true)
	var sk := _skeleton(n)
	return sk.get_bone_global_pose(sk.find_bone(bone)).origin


func test_skeleton_and_mesh() -> void:
	for path in PATHS:
		var n := _rig(path)
		eq(n.find_children("*", "Skeleton3D", true, false).size(), 1, "%s: один скелет" % path)
		var sk := _skeleton(n)
		eq(sk.get_bone_count(), 24, "%s: 24 кости" % path)
		for b in BONES:
			ok(sk.find_bone(b) >= 0, "%s: кость %s" % [path, b])
		var meshes := n.find_children("*", "MeshInstance3D", true, false)
		eq(meshes.size(), 1, "%s: одна сетка" % path)
		for m in meshes:
			ok((m as MeshInstance3D).skin != null, "%s: сетка со skin" % path)
		n.free()


func test_clips_and_loops() -> void:
	for path in PATHS:
		var n := _rig(path)
		var ap := _player(n)
		for clip in CLIPS:
			if not ok(ap.has_animation(clip), "%s: клип %s" % [path, clip]):
				continue
			var a := ap.get_animation(clip)
			near(a.length, CLIPS[clip], 1e-3, "%s %s: длина" % [path, clip])
			eq(a.loop_mode, Animation.LOOP_LINEAR, "%s %s: цикл" % [path, clip])
		ok(ap.autoplay == "", "%s: клип сам не играет — позу ставит CrewRig" % path)
		n.free()


func test_loops_are_seamless() -> void:
	for path in PATHS:
		var n := _rig(path)
		tree.root.add_child(n)
		await frames(1)
		for clip in CLIPS:
			var len: float = CLIPS[clip]
			for b in ["Hips", "Head", "LeftFoot", "RightFoot", "LeftHand", "RightHand"]:
				var a := _at(n, clip, 0.0, b)
				var z := _at(n, clip, len - 1e-4, b)
				ok(a.distance_to(z) < 0.005, "%s %s: стык цикла у %s (%.4f м)" % [path, clip, b, a.distance_to(z)])
		n.free()


func test_walk_stride() -> void:
	## Опорная стопа (на полу) едет назад ровно со скоростью хода: 1,3 м за цикл 0,8 с — и не скользит.
	for path in PATHS:
		var n := _rig(path)
		tree.root.add_child(n)
		await frames(1)
		var step := Crew.STRIDE / 24.0
		for f in ["LeftFoot", "RightFoot"]:
			var floor_y := INF
			for i in 24:
				floor_y = minf(floor_y, _at(n, "Walk", 0.8 * i / 24.0, f).y)
			var moved := 0.0
			var slip := 0.0
			var on := 0
			for i in 24:
				var p0 := _at(n, "Walk", 0.8 * i / 24.0, f)
				var p1 := _at(n, "Walk", 0.8 * (i + 1) / 24.0, f)
				if p0.y > floor_y + 0.003 or p1.y > floor_y + 0.003:
					continue
				on += 1
				moved += p1.z - p0.z
				slip += absf(p1.z - p0.z - step)
			ok(on >= 8, "%s %s: опора %d кадров из 24" % [path, f, on])
			near(moved / on * 24.0, Crew.STRIDE, 0.1, "%s %s: путь цикла Walk" % [path, f])
			ok(slip < 0.03, "%s %s: скольжение за опору %.3f м" % [path, f, slip])
		n.free()


func test_sit_pose() -> void:
	for path in PATHS:
		var n := _rig(path)
		tree.root.add_child(n)
		await frames(1)
		var sk := _skeleton(n)
		var foot_rest := sk.get_bone_global_rest(sk.find_bone("LeftFoot")).origin.y
		for i in 9:
			var t := 4.0 * i / 8.0
			near(_at(n, "SitIdle", t, "Hips").y, 0.67, 0.03, "%s: таз в кресле (t=%.1f)" % [path, t])
			for f in ["LeftFoot", "RightFoot"]:
				near(_at(n, "SitIdle", t, f).y, foot_rest, 0.03, "%s: %s на полу (t=%.1f)" % [path, f, t])
			var lk := _at(n, "SitIdle", t, "LeftLeg")
			var rk := _at(n, "SitIdle", t, "RightLeg")
			ok(rk.x - lk.x > 0.15, "%s: колени не сходятся (t=%.1f)" % [path, t])
		n.free()


func test_rest_pose_without_clip() -> void:
	## Без клипа — та же поза покоя: CrewRig и снаряжение MOD-016 садятся как раньше.
	for path in PATHS:
		var n := _rig(path)
		var sk := _skeleton(n)
		for b in sk.get_bone_count():
			ok(sk.get_bone_pose(b).origin.distance_to(sk.get_bone_rest(b).origin) < 1e-4,
					"%s: кость %s в покое" % [path, sk.get_bone_name(b)])
		n.free()
