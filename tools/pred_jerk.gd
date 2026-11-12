extends SceneTree
## Рывки серпохвоста по костям (#1753): мир целиком (`EcoView`, дно `Seabed.mesh_height`), корабль стоит со светом.
## По умолчанию хищник 0 ставится сбоку (`EcoPred.stage_near`): замер → бросок → укус → отход → патруль; `free` — без
## постановки, мир сам (свет выключен). Пишет смены режима и по костям — ускорение точки кости в осях тела
## (медиана / 99 % / худшие кадры), у тела — ускорение центра и угловое ускорение, скачки частоты волны.
## Облачный headless-расчёт, не телефонный; код игры не меняет:
##   godot --headless --path . -s tools/pred_jerk.gd -- [free] [lite] x=<м> z=<м> side=<м> run=<с> dt=<с> seed=<n>
##   dump=<с0>:<с1> — построчно скорость, частота волны, смесь, крен.
## lite — «Экономно» (`PredView.set_lite`). 12.11: на «Экономно» кончик хвоста в 25–60 м — 99 % ≈ 200 м/с² против
## 13 на «Обычно» (поза раз в 0,1 с) — исправлено в той же PR.

const DT_DEF := 1.0 / 30.0
var _done := false

func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	var dt := float(kv.get("dt", str(DT_DEF)))
	var run := float(kv.get("run", "45"))
	var side := float(kv.get("side", "26"))
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	root.add_child(ev)
	ev.world.reset(int(kv.get("seed", "20261018")))
	var ship := EcoLink.ShipState.new()
	var sx := float(kv.get("x", "20"))
	var sz := float(kv.get("z", "22.5"))
	ship.pos = Vector3(sx, Seabed.mesh_height(sx, sz) + 7.0, sz)
	ship.yaw = 0.0
	ship.light_on = true
	ship.light_range = 60.0
	for i in 30:
		ev.step(dt, ship)
	if not kv.has("free"):
		ev.preds.stage_near(0, ship.pos + Vector3(side, 0, 0), ship.pos)
	else:
		ship.light_on = false
	var pv := ev.pred_view
	if kv.has("lite"):
		pv.set_lite(true)
	var body: Node3D = pv.bodies[0]
	var sk: Skeleton3D = body.find_child("Skeleton3D", true, false)
	var bones := ["Tail03", "Tail02", "Jaw", "FinFrontL", "Body"]
	var ids := []
	for b in bones:
		ids.append(sk.find_bone(b))
	var pr: EcoPred.Pred = ev.preds.all[0]
	var hist := []   # кадр → {local: [Vector3], origin, basis, mode, v, rate, mix}
	var n := int(run / dt)
	var last_mode := -1
	for f in n:
		ev.step(dt, ship)
		var loc := []
		for id in ids:
			loc.append(sk.get_bone_global_pose(id).origin)
		var rec := {"loc": loc, "o": body.global_transform.origin, "b": body.global_transform.basis.orthonormalized(),
				"mode": pr.mode, "v": pr.agent.v.length(), "rate": EcoPredLook.swim_rate(pr), "mix": EcoPredLook.swim_mix(pr),
				"d": pr.agent.p.distance_to(ship.pos), "bank": pr.bank}
		hist.append(rec)
		if pr.mode != last_mode:
			print("%6.2f с  режим %s  v %.2f  до корабля %.1f" % [f * dt, EcoPred.Mode.keys()[pr.mode], rec["v"], rec["d"]])
			last_mode = pr.mode
	# всплески: вторая разность локальной позы кости за кадр (м/с²), курс тела — угловое ускорение
	print("\nкость: медиана / 99 % / максимум ускорения в осях тела (м/с²), где максимум")
	for bi in bones.size():
		var acc := []
		for f in range(1, n - 1):
			var a: Vector3 = hist[f - 1]["loc"][bi]
			var b: Vector3 = hist[f]["loc"][bi]
			var c: Vector3 = hist[f + 1]["loc"][bi]
			acc.append([(a - 2.0 * b + c).length() / (dt * dt), f])
		acc.sort_custom(func(x, y): return x[0] < y[0])
		var top: Array = acc[acc.size() - 1]
		var fr: int = top[1]
		print("  %-9s %6.1f  %6.1f  %7.1f  @%.2f с %s v %.2f rate %.3f mix %.2f" % [bones[bi], acc[acc.size() / 2][0],
				acc[int(acc.size() * 0.99)][0], top[0], fr * dt, EcoPred.Mode.keys()[hist[fr]["mode"]], hist[fr]["v"],
				hist[fr]["rate"], hist[fr]["mix"]])
		# десять худших с временем
		var line := PackedStringArray()
		for k in range(acc.size() - 1, maxi(acc.size() - 9, 0), -1):
			line.append("%.2f:%.0f" % [acc[k][1] * dt, acc[k][0]])
		print("     ", ", ".join(line))
	# тело: ускорение центра и угловое ускорение
	var lin := []
	var ang := []
	for f in range(1, n - 1):
		var a: Vector3 = hist[f - 1]["o"]
		var b: Vector3 = hist[f]["o"]
		var c: Vector3 = hist[f + 1]["o"]
		lin.append([(a - 2.0 * b + c).length() / (dt * dt), f])
		var w1 := _omega(hist[f - 1]["b"], hist[f]["b"]) / dt
		var w2 := _omega(hist[f]["b"], hist[f + 1]["b"]) / dt
		ang.append([(w2 - w1).length() / dt, f, w2.length()])
	for pair in [["центр тела м/с²", lin], ["поворот тела рад/с²", ang]]:
		var arr: Array = pair[1]
		arr.sort_custom(func(x, y): return x[0] < y[0])
		var line := PackedStringArray()
		for k in range(arr.size() - 1, maxi(arr.size() - 9, 0), -1):
			var fr: int = arr[k][1]
			line.append("%.2f:%.1f(%s)" % [fr * dt, arr[k][0], EcoPred.Mode.keys()[hist[fr]["mode"]]])
		print("%s: медиана %.2f, 99%% %.2f; худшие %s" % [pair[0], arr[arr.size() / 2][0], arr[int(arr.size() * 0.99)][0], ", ".join(line)])
	# скачки частоты волны
	var dr := []
	for f in range(1, n):
		dr.append([absf(hist[f]["rate"] - hist[f - 1]["rate"]) / dt, f])
	dr.sort_custom(func(x, y): return x[0] < y[0])
	var l2 := PackedStringArray()
	for k in range(dr.size() - 1, maxi(dr.size() - 7, 0), -1):
		var fr: int = dr[k][1]
		l2.append("%.2f:%.2f→%.2f" % [fr * dt, hist[fr - 1]["rate"], hist[fr]["rate"]])
	print("частота волны, худшие изменения (Гц/с): ", ", ".join(l2))
	if kv.has("dump"):
		var a0 := float(kv["dump"].split(":")[0])
		var a1 := float(kv["dump"].split(":")[1])
		for f in range(int(a0 / dt), mini(int(a1 / dt), n)):
			var h: Dictionary = hist[f]
			print("%6.2f %s v %.2f rate %.3f mix %.2f bank %.3f tail %s" % [f * dt, EcoPred.Mode.keys()[h["mode"]], h["v"], h["rate"], h["mix"], h["bank"], str(h["loc"][0])])
	ev.free()
	quit()

func _omega(a: Basis, b: Basis) -> Vector3:
	var q := (b.get_rotation_quaternion() * a.get_rotation_quaternion().inverse()).normalized()
	if q.w < 0.0:
		q = -q
	var an := 2.0 * acos(clampf(q.w, -1.0, 1.0))
	var s := sqrt(maxf(0.0, 1.0 - q.w * q.w))
	if s < 1e-6:
		return Vector3.ZERO
	return Vector3(q.x, q.y, q.z) / s * an
