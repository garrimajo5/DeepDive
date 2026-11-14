extends SceneTree
## Точка кости по клипам модели на скелете (#1753, заказ ANIM-005 #1766): скорость и ускорение точки, жёстко
## сидящей на кости, при выборке hz кадров/с (как игра на телефоне — 30) в осях модели. Ускорение — вторая
## разность положения; по клипу — максимум скорости, медиана и максимум ускорения и когда он. Клипы на месте, тело
## не плывёт — это чистая резкость клипа, без хода мира (ход с миром — `tools/pred_jerk.gd`).
##   godot --headless --path . -s tools/clip_tip.gd -- [glb=res://models/serpohvost-anim.glb] [bone=Tail03]
##     [point=0,-0.19,4.2] [hz=30]
## point — точка в позе покоя модели (м); по умолчанию — конец серпа серпохвоста. 13.11, 30 кадров/с:
## Swim 10,3, SwimFast 38,9, TailStrike 177 м/с² (0,33 с) — по этой таблице заказ ANIM-005. После приёмки ANIM-005
## (14.11, импорт 60 кадров/с без оптимизатора): TailStrike 58,1 / 59,1 м/с² при 30 / 60 кадрах/с, Recoil 15,9, Coil 18,1,
## Hover 0,3.

const GLB := "res://models/serpohvost-anim.glb"
const BONE := "Tail03"
const POINT := Vector3(0.0, -0.19, 4.2)
const HZ := 30.0
var _done := false


func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	var pt := POINT
	if kv.has("point"):
		var c: PackedStringArray = kv["point"].split(",")
		pt = Vector3(float(c[0]), float(c[1]), float(c[2]))
	var hz := float(kv.get("hz", str(HZ)))
	var res := measure(root, kv.get("glb", GLB), kv.get("bone", BONE), pt, hz)
	print("== точка %s на кости %s, %d кадров/с" % [pt, kv.get("bone", BONE), int(hz)])
	for n in res:
		print(line(n, res[n]))
	quit()
	return true


## Строка клипа для лога и заметок.
static func line(clip: String, r: Dictionary) -> String:
	return "%s %.2f с: скорость макс. %.1f м/с, ускорение медиана %.1f, макс. %.1f м/с² (%.2f с)" % [
		clip, r.len, r.vmax, r.amed, r.amax, r.at]


## По клипам модели {имя: {len, vmax, amed, amax, at}}; модель ставится под parent на время замера и уходит.
## Нет файла, скелета, плеера или кости — пустой словарь.
static func measure(parent: Node, glb: String, bone: String, point: Vector3, hz: float) -> Dictionary:
	var out := {}
	var ps := load(glb) as PackedScene
	if ps == null:
		return out
	var sc := ps.instantiate()
	parent.add_child(sc)
	var sks := sc.find_children("*", "Skeleton3D", true, false)
	var aps := sc.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		sc.free()
		return out
	var sk: Skeleton3D = sks[0]
	var ap: AnimationPlayer = aps[0]
	var b := sk.find_bone(bone)
	if b < 0:
		sc.free()
		return out
	var local := sk.get_bone_global_rest(b).affine_inverse() * point
	var h := 1.0 / hz
	var names := Array(ap.get_animation_list())
	names.sort()
	for n in names:
		var anim := ap.get_animation(n)
		var pts: Array[Vector3] = []
		ap.play(n)
		var steps := int(floor(anim.length / h + 1e-4))
		for i in steps + 1:
			ap.seek(minf(i * h, anim.length), true)
			pts.append(sk.get_bone_global_pose(b) * local)
		ap.stop()
		var acc: Array[float] = []
		var vmax := 0.0
		var amax := 0.0
		var at := 0.0
		for i in range(1, pts.size() - 1):
			var a := ((pts[i + 1] - 2.0 * pts[i] + pts[i - 1]) / (h * h)).length()
			acc.append(a)
			if a > amax:
				amax = a
				at = i * h
			vmax = maxf(vmax, ((pts[i + 1] - pts[i - 1]) / (2.0 * h)).length())
		acc.sort()
		out[String(n)] = {"len": anim.length, "vmax": vmax, "amed": acc[acc.size() / 2] if not acc.is_empty() else 0.0,
			"amax": amax, "at": at}
	sc.free()
	return out
