extends SceneTree
## Рывки серпохвоста по костям (#1753): мир целиком (`EcoView`, дно `Seabed.mesh_height`), корабль стоит со светом.
## По умолчанию хищник 0 ставится сбоку (`EcoPred.stage_near`): замер → бросок → укус → отход → патруль; `free` — без
## постановки, мир сам (свет выключен). Пишет смены режима и по костям — ускорение точки кости в осях тела
## (медиана / 99 % / худшие кадры), у тела — ускорение центра и угловое ускорение, скачки частоты волны.
## Облачный headless-расчёт, не телефонный; код игры не меняет:
##   godot --headless --path . -s tools/pred_jerk.gd -- [free] [lite] x=<м> z=<м> side=<м> run=<с> dt=<с> seed=<n>
##   dump=<с0>:<с1> — построчно скорость, частота волны, смесь, крен.
##   hunts — журнал охот на светляков хищника 0: начало, длина, чем кончилась (`HUNT_WHY`), пауза после прошлой;
##   итог — сколько охот началось быстрее `QUICK` с после конца прошлой (#1753: так видно перескоки
##   «бросил — тут же новая»; с `free` и `run=300` — пять минут мира).
## lite — «Экономно» (`PredView.set_lite`). 12.11: на «Экономно» кончик хвоста в 25–60 м — 99 % ≈ 200 м/с² против
## 13 на «Обычно» (поза раз в 0,1 с) — исправлено в той же PR.

const DT_DEF := 1.0 / 30.0
## Охота началась быстрее этого после конца прошлой — «перескок» (#1753: до паузы `_give_up` — 28 из 56 за 5 мин).
const QUICK := 8.0
## Чем кончилась охота (`hunt_why`).
const HUNT_WHY := {
	"catch": "поймал", "gone": "добычу съел другой", "time": "вышли 12 с", "kelp": "стая в ленточнике",
	"ink": "в чернилах подушечника", "grot": "в рифе гротовика", "truce": "перемирие у станции",
	"ship": "на корабль", "end": "не кончилась к концу расчёта", "other": "другое",
}
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
	var hunts := []   # [начало, конец (−1 — идёт), ключ HUNT_WHY]
	for f in n:
		var was_hunt := pr.mode == EcoPred.Mode.HUNT
		var prey: EcoFish.Fish = pr.prey
		var t_before := pr.agent.timer
		ev.step(dt, ship)
		if not was_hunt and pr.mode == EcoPred.Mode.HUNT:
			hunts.append([(f + 1) * dt, -1.0, "end"])
		elif was_hunt and pr.mode != EcoPred.Mode.HUNT and not hunts.is_empty():
			hunts[hunts.size() - 1][1] = (f + 1) * dt
			hunts[hunts.size() - 1][2] = _why(ev.preds, pr, prey, t_before <= dt)
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
	if kv.has("hunts"):
		print("\nохоты хищника 0 (с): начало, длина, чем кончилась, пауза после прошлой")
		var prev_end := -1.0
		for h in hunts:
			var pause := "—" if prev_end < 0.0 else "%.2f" % (float(h[0]) - prev_end)
			var dur := "идёт" if float(h[1]) < 0.0 else "%.2f" % (float(h[1]) - float(h[0]))
			print("  %7.2f  %6s  %-28s пауза %s" % [h[0], dur, HUNT_WHY[h[2]], pause])
			if float(h[1]) >= 0.0:
				prev_end = h[1]
		var sm := hunt_summary(hunts)
		var why := PackedStringArray()
		for k in sm["why"]:
			why.append("%s %d" % [HUNT_WHY[k], sm["why"][k]])
		print("итог: охот %d, начались быстрее %.0f с после конца прошлой — %d, кратчайшая пауза %s; %s" % [sm["n"], QUICK,
				sm["quick"], "—" if sm["min_pause"] == INF else "%.2f с" % sm["min_pause"], ", ".join(why)])
	ev.free()
	quit()


## Чем кончилась охота, если в шаге мира режим HUNT сменился: prey — добыча до шага, timed — таймер 12 с истекал.
## Порядок — как в `EcoPred` (Mode.HUNT): улов, добыча пропала или вышло время, станция, ленточник, чернила, риф.
static func _why(preds: EcoPred, pr: EcoPred.Pred, prey: EcoFish.Fish, timed: bool) -> String:
	if pr.mode == EcoPred.Mode.EAT:
		return "catch"
	if pr.mode != EcoPred.Mode.PATROL:
		return "ship"
	if prey == null or not prey.agent.alive:
		return "gone"
	if timed:
		return "time"
	if preds.ognevka and preds.leeches and preds.leeches.near_station(prey.agent.p):
		return "truce"
	if preds.kelp and preds.kelp.shelter(prey):
		return "kelp"
	if preds.cushions and preds.cushions.ink_at(prey.agent.p):
		return "ink"
	if preds.grot and preds.grot.shelter(prey):
		return "grot"
	return "other"


## Итог журнала охот [начало, конец (−1 — идёт), ключ]: число охот, сколько началось быстрее QUICK с после конца
## прошлой, кратчайшая такая пауза (INF — пауз нет) и счёт по ключам.
static func hunt_summary(hunts: Array) -> Dictionary:
	var why := {}
	var quick := 0
	var min_pause := INF
	var prev_end := -1.0
	for h in hunts:
		why[h[2]] = int(why.get(h[2], 0)) + 1
		if prev_end >= 0.0:
			var pause := float(h[0]) - prev_end
			min_pause = minf(min_pause, pause)
			if pause < QUICK:
				quick += 1
		if float(h[1]) >= 0.0:
			prev_end = h[1]
	return {"n": hunts.size(), "quick": quick, "min_pause": min_pause, "why": why}

func _omega(a: Basis, b: Basis) -> Vector3:
	var q := (b.get_rotation_quaternion() * a.get_rotation_quaternion().inverse()).normalized()
	if q.w < 0.0:
		q = -q
	var an := 2.0 * acos(clampf(q.w, -1.0, 1.0))
	var s := sqrt(maxf(0.0, 1.0 - q.w * q.w))
	if s < 1e-6:
		return Vector3.ZERO
	return Vector3(q.x, q.y, q.z) / s * an
