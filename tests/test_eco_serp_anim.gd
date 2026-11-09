extends TestCase
## Анимированный серпохвост ANIM-001 (`models/serpohvost-anim.glb`, приёмка PR #654): один скелет на 10 костей,
## три сетки со skin, четыре клипа; плавание зациклено при импорте, укус и удар — разовые; удар серпом вертикальный
## (по уточнению владельца) — кончик хвоста уходит вниз без бокового смещения и возвращается.

const PATH := "res://models/serpohvost-anim.glb"
const BONES := ["Root", "Body", "Tail01", "Tail02", "Tail03", "Jaw",
		"FinFrontL", "FinRearL", "FinFrontR", "FinRearR"]


func _rig() -> Node3D:
	var scene: PackedScene = load(PATH)
	return scene.instantiate()


func _player(n: Node) -> AnimationPlayer:
	return n.find_children("*", "AnimationPlayer", true, false)[0]


func _skeleton(n: Node) -> Skeleton3D:
	return n.find_children("*", "Skeleton3D", true, false)[0]


func test_skeleton_and_meshes() -> void:
	var n := _rig()
	eq(n.find_children("*", "Skeleton3D", true, false).size(), 1, "один скелет")
	var sk := _skeleton(n)
	eq(sk.get_bone_count(), BONES.size(), "10 костей")
	for b in BONES:
		ok(sk.find_bone(b) >= 0, "кость %s" % b)
	eq(sk.get_bone_parent(sk.find_bone("Tail03")), sk.find_bone("Tail02"), "хвост цепочкой")
	var meshes := n.find_children("*", "MeshInstance3D", true, false)
	eq(meshes.size(), 3, "тело, хвост, челюсть")
	var tris := 0
	for m in meshes:
		var mi: MeshInstance3D = m
		ok(mi.skin != null, "%s со skin" % mi.name)
		for k in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_arrays(k)[Mesh.ARRAY_INDEX].size() / 3
	ok(tris <= 6000, "треугольников %d — как у MOD-011" % tris)
	n.free()


func test_clips_and_loops() -> void:
	var n := _rig()
	var ap := _player(n)
	var want := {"Swim": [2.4, Animation.LOOP_LINEAR], "SwimFast": [1.2, Animation.LOOP_LINEAR],
			"Bite": [1.2, Animation.LOOP_NONE], "TailStrike": [0.6, Animation.LOOP_NONE]}
	for name in want:
		if not ok(ap.has_animation(name), "клип %s" % name):
			continue
		var a := ap.get_animation(name)
		near(a.length, want[name][0], 1e-3, "%s: длина" % name)
		eq(a.loop_mode, want[name][1], "%s: цикл" % name)
	n.free()


## Мировая точка кончика хвоста (кость Tail03) в момент t клипа.
func _tip_at(n: Node3D, clip: String, t: float) -> Vector3:
	var ap := _player(n)
	ap.play(clip)
	ap.seek(t, true)
	var sk := _skeleton(n)
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Tail03")).origin


func test_tail_strike_is_vertical() -> void:
	var n := _rig()
	tree.root.add_child(n)
	await frames(1)
	var rest := _tip_at(n, "TailStrike", 0.0)
	var low := rest
	for i in 19:
		var p := _tip_at(n, "TailStrike", 0.6 * i / 18.0)
		if p.y < low.y:
			low = p
		near(p.x, rest.x, 0.02, "удар без бокового смещения (t=%.2f)" % (0.6 * i / 18.0))
	ok(rest.y - low.y > 0.3, "серп уходит вниз на %.2f м" % (rest.y - low.y))
	var back := _tip_at(n, "TailStrike", 0.6)
	ok(back.distance_to(rest) < 0.02, "после удара — исходная поза")
	n.queue_free()
	await frames(1)


func test_swim_wave_is_sideways_and_seamless() -> void:
	var n := _rig()
	tree.root.add_child(n)
	await frames(1)
	var a := _tip_at(n, "Swim", 0.0)
	var side := 0.0
	for i in 12:
		side = maxf(side, absf(_tip_at(n, "Swim", 2.4 * i / 12.0).x - a.x))
	ok(side > 0.1, "плавание — волна хвоста вбок (%.2f м)" % side)
	ok(_tip_at(n, "Swim", 2.4).distance_to(a) < 0.02, "цикл без шва")
	n.queue_free()
	await frames(1)


## По issue #746: прежние модели MOD-011 без скелета не лежат в проекте (иначе ~11 МБ мёртвого груза в APK),
## в сцене серпохвост — только `serpohvost-anim.glb`.
func test_no_old_mod011_models() -> void:
	var models := DirAccess.get_files_at("res://models")
	for f in models:
		if f.begins_with("serpohvost") and not f.begins_with("serpohvost-anim"):
			ok(false, "лишний файл серпохвоста models/%s" % f)
	eq(EcoPredLook.RIG_GLB, PATH, "сцена грузит модель на скелете")
