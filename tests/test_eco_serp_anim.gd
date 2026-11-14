extends TestCase
## Анимированный серпохвост ANIM-001 (`models/serpohvost-anim.glb`, приёмка PR #654) с клипами ANIM-005 (#1766,
## приёмка PR #1828): один скелет на 10 костей, три сетки со skin, девять клипов; плавание и замер зациклены при
## импорте, укус, удар, отход и взвод — разовые; удар серпом вертикальный (по уточнению владельца) — кончик хвоста
## уходит вниз без бокового смещения и возвращается. Ключи 60 кадров/с, импорт `animation/fps=60` и без оптимизатора
## у AnimationPlayer — иначе импортёр прореживает ключи и возвращает пики ускорения (CLAUDE.md, «Анимации»).

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
			"Bite": [1.2, Animation.LOOP_NONE], "TailStrike": [0.9, Animation.LOOP_NONE],
			"Recoil": [1.0, Animation.LOOP_NONE], "Hover": [4.0, Animation.LOOP_LINEAR],
			"Coil": [0.5, Animation.LOOP_NONE], "BendL": [1.0 / 30.0, Animation.LOOP_NONE],
			"BendR": [1.0 / 30.0, Animation.LOOP_NONE]}
	eq(ap.get_animation_list().size(), want.size(), "девять клипов")
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


## Конец серпа (точка заказа ANIM-005 в позе покоя, жёстко на Tail03 — как `tools/clip_tip.gd`) в момент t клипа.
func _blade_at(n: Node3D, clip: String, t: float) -> Vector3:
	var ap := _player(n)
	ap.play(clip)
	ap.seek(t, true)
	var sk := _skeleton(n)
	var b := sk.find_bone("Tail03")
	var tool: GDScript = load("res://tools/clip_tip.gd")
	return sk.global_transform * (sk.get_bone_global_pose(b) * sk.get_bone_global_rest(b).affine_inverse()) * tool.POINT


func test_tail_strike_is_vertical() -> void:
	var n := _rig()
	tree.root.add_child(n)
	await frames(1)
	var rest := _blade_at(n, "TailStrike", 0.0)
	var low := rest
	var high := rest
	for i in 28:
		var t := 0.9 * i / 27.0
		var p := _blade_at(n, "TailStrike", t)
		if p.y < low.y:
			low = p
		if p.y > high.y:
			high = p
		near(p.x, rest.x, 0.02, "удар без бокового смещения (t=%.2f)" % t)
	ok(high.y - rest.y >= 0.28, "замах вверх на %.2f м (заказ ≥ 0,3)" % (high.y - rest.y))
	ok(rest.y - low.y >= 0.8, "серп уходит вниз на %.2f м (заказ ≥ 0,8)" % (rest.y - low.y))
	var back := _blade_at(n, "TailStrike", 0.9)
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


## Позы всех костей в момент t клипа (глобальные в скелете).
func _pose_at(n: Node3D, clip: String, t: float) -> Array[Transform3D]:
	var ap := _player(n)
	ap.play(clip)
	ap.seek(t, true)
	var sk := _skeleton(n)
	var out: Array[Transform3D] = []
	for b in sk.get_bone_count():
		out.append(sk.get_bone_global_pose(b))
	return out


## Наибольшее расхождение двух поз: сдвиг кости (м) и угол её поворота (рад, через разность базисов).
func _pose_gap(a: Array[Transform3D], b: Array[Transform3D]) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, a[i].origin.distance_to(b[i].origin))
		for k in 3:
			worst = maxf(worst, (a[i].basis[k] - b[i].basis[k]).length())
	return worst


## ANIM-005: разовые клипы начинаются и кончаются нейтральной позой (Swim на 0 с) — игра смешивает их с плаванием
## 0,12…0,2 с без скачка; взвод кончается позой SwimFast на 0 с — дальше сразу бросок; замер — бесшовный цикл.
func test_new_clips_join_without_jumps() -> void:
	var n := _rig()
	tree.root.add_child(n)
	await frames(1)
	var neutral := _pose_at(n, "Swim", 0.0)
	var lens := {"TailStrike": 0.9, "Recoil": 1.0, "Coil": 0.5}
	for c in ["TailStrike", "Recoil", "Coil"]:
		ok(_pose_gap(_pose_at(n, c, 0.0), neutral) < 0.01, "%s начинается нейтральной позой" % c)
	for c in ["TailStrike", "Recoil"]:
		ok(_pose_gap(_pose_at(n, c, lens[c]), neutral) < 0.01, "%s кончается нейтральной позой" % c)
	ok(_pose_gap(_pose_at(n, "Coil", 0.5), _pose_at(n, "SwimFast", 0.0)) < 0.01, "Coil кончается позой SwimFast")
	ok(_pose_gap(_pose_at(n, "Hover", 0.0), _pose_at(n, "Hover", 4.0)) < 0.01, "Hover — цикл без шва")
	n.queue_free()
	await frames(1)


## Изгиб в развороте: BendL — хвост дугой влево (к −X), BendR — зеркально; замер почти неподвижен (хвост медленнее
## и уже, чем в плавании).
func test_bends_mirror_and_hover_is_calm() -> void:
	var n := _rig()
	tree.root.add_child(n)
	await frames(1)
	var rest := _tip_at(n, "Swim", 0.0)
	var l := _tip_at(n, "BendL", 0.0)
	var r := _tip_at(n, "BendR", 0.0)
	ok(l.x < rest.x - 0.3, "BendL: серп влево на %.2f м" % (rest.x - l.x))
	ok(r.x > rest.x + 0.3, "BendR: серп вправо на %.2f м" % (r.x - rest.x))
	near(l.x, -r.x, 0.05, "изгибы зеркальны (относительно оси тела)")
	var hover := 0.0
	var swim := 0.0
	var h0 := _tip_at(n, "Hover", 0.0)
	for i in 16:
		hover = maxf(hover, _tip_at(n, "Hover", 4.0 * i / 16.0).distance_to(h0))
		swim = maxf(swim, absf(_tip_at(n, "Swim", 2.4 * i / 16.0).x - rest.x))
	ok(hover < swim / 3.0, "замер: размах %.2f м — меньше трети плавания (%.2f м)" % [hover, swim])
	n.queue_free()
	await frames(1)


## Пределы заказа ANIM-005 по концу серпа (`tools/clip_tip.gd`) — и при 30, и при 60 кадрах/с: импорт
## не прореживает ключи (отношение пиков 60/30 ≤ 1,25, решение владельца по #1804).
func test_clip_limits_at_30_and_60() -> void:
	var tool: GDScript = load("res://tools/clip_tip.gd")
	var root := Node3D.new()
	tree.root.add_child(root)
	var r30: Dictionary = tool.measure(root, PATH, tool.BONE, tool.POINT, 30.0)
	var r60: Dictionary = tool.measure(root, PATH, tool.BONE, tool.POINT, 60.0)
	root.free()
	var limit := {"TailStrike": 60.0, "Recoil": 40.0, "Hover": 8.0, "Coil": 60.0}
	for c in limit:
		if not ok(r30.has(c) and r60.has(c), "замер %s" % c):
			continue
		ok(float(r30[c].amax) <= limit[c], "%s при 30: %.1f м/с² ≤ %.0f" % [c, r30[c].amax, limit[c]])
		ok(float(r60[c].amax) <= limit[c], "%s при 60: %.1f м/с² ≤ %.0f" % [c, r60[c].amax, limit[c]])
		ok(float(r60[c].amax) <= 1.25 * float(r30[c].amax), "%s: 60/30 = %.2f" % [c,
				float(r60[c].amax) / maxf(float(r30[c].amax), 1e-6)])
	ok(float(r30["TailStrike"].vmax) >= 7.0, "удар читается: %.1f м/с" % r30["TailStrike"].vmax)


## Импорт: 60 кадров/с и оптимизатор AnimationPlayer выключен — без этого пики удара возвращаются (116 м/с²).
func test_import_keeps_60_fps() -> void:
	var f := FileAccess.get_file_as_string(PATH + ".import")
	ok(f.contains("animation/fps=60"), "animation/fps=60")
	ok(f.contains("\"PATH:AnimationPlayer\": {\n\"optimizer/enabled\": false"), "оптимизатор выключен")


## Удар после укуса виден ровно столько, сколько длится клип.
func test_strike_time_is_clip_length() -> void:
	var n := _rig()
	near(EcoPredLook.STRIKE_TIME, _player(n).get_animation(EcoPredLook.STRIKE).length, 1e-3, "STRIKE_TIME = TailStrike")
	n.free()
