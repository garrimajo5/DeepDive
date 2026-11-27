extends SceneTree
## Разбор строки tools/jerk.gd по составляющим базиса рыбки (#2106) —
## нос (look), виляние (wag), крен (bank). Тот же мир, что tools/jerk.gd scena=1: корабль стоит в точке
## ракурса 1 (4, 80) носом к 01, свет включён, шаг 1/30, warm 6 с; зерно ключом.
## Разница с jerk.gd: базис считается на CPU по EcoFishLook.basis с временным занулением bank/wag
## (состояние мира не меняется — поля восстанавливаются сразу после расчёта кадра).
## Ускорение — как в jerk.gd: окна по 3 отсчёта через STRIDE=3 кадра (k = 0,1 с), alpha = |w2-w1|/k.
##   ключи: idx=<номер рыбки в EcoFish.all> from=<кадр> to=<кадр> seed=<n>
##   (умолчания — строка «Светляки #13, кадр 118» из #2106: idx=13 from=100 to=124 seed=20261018)
## Запуск и на main (поля ветки вроде look_rate читаются через get — на main печатается −1).

const DT := 1.0 / 30.0
const STRIDE := 3
const FLOOR := 7.0

var _hist := []            # кадры: [pos, basis_full, basis_nose, basis_nosewag, basis_nosebank, |v|, look_rate, bank, bank_v, alive]


func _process(_delta: float) -> bool:
	_run()
	return true


static func _omega(a: Basis, b: Basis) -> Vector3:
	var q := (b.orthonormalized().get_rotation_quaternion() * a.orthonormalized().get_rotation_quaternion().inverse()).normalized()
	if q.w < 0.0:
		q = -q
	var ang := 2.0 * acos(clampf(q.w, -1.0, 1.0))
	var s := sqrt(maxf(0.0, 1.0 - q.w * q.w))
	if s < 1e-6:
		return Vector3.ZERO
	return Vector3(q.x, q.y, q.z) / s * ang


## Базисы рыбки в момент t: полный, только нос (bank = wag = 0), нос+виляние, нос+крен. Поля f восстановлены.
func _basis_variants(f: EcoFish.Fish, t: float) -> Array:
	var full := EcoFishLook.basis(f, t)
	var bank0: float = f.bank
	var wag0: float = f.wag
	f.bank = 0.0
	var nosewag := EcoFishLook.basis(f, t)   # нос + виляние, без крена
	f.wag = 0.0
	var nose := EcoFishLook.basis(f, t)      # только нос
	f.bank = bank0
	var nosebank := EcoFishLook.basis(f, t)  # нос + крен, без виляния
	f.wag = wag0
	return [full, nose, nosewag, nosebank]


func _run() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	var idx := int(kv.get("idx", "13"))
	var from := int(kv.get("from", "100"))
	var upto := int(kv.get("to", "124"))
	var seed := int(kv.get("seed", "20261018"))
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	root.add_child(ev)
	ev.world.reset(seed)
	var at := Vector2(4.0, 80.0)
	var goal: Vector2 = LayerMap.xz("01")
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(at.x, Seabed.mesh_height(at.x, at.y) + FLOOR, at.y)
	var to := goal - at
	ship.yaw = atan2(-to.x, -to.y)
	ship.light_on = true
	ship.light_range = 60.0
	for i in int(6.0 / DT):
		ev.step(DT, ship)
	var fish: EcoFish = ev.fish
	print("jerk_parts: зерно %d, рыбок всего %d, смотрим all[%d], кадры %d..%d" % [seed, fish.all.size(), idx, from, upto])
	for fr in upto + 1:
		ev.step(DT, ship)
		var t: float = ev.world.time
		var f: EcoFish.Fish = fish.all[idx]
		var bb := _basis_variants(f, t)
		var lr = f.get("look_rate")   # есть только в ветке #2106; на main — null
		_hist.append([f.agent.p, bb[0], bb[1], bb[2], bb[3],
				f.agent.v.length(), float(lr) if lr != null else -1.0, f.bank, f.bank_v, f.agent.alive])
	var k := STRIDE * DT
	print("кадр | alpha полный | только нос | нос+виляние | нос+крен | |v| | look_rate | bank | bank_v | до корабля")
	for end in range(from, upto + 1):
		if end < 2 * STRIDE or end >= _hist.size():
			continue
		var h0: Array = _hist[end - 2 * STRIDE]
		var h1: Array = _hist[end - STRIDE]
		var h2: Array = _hist[end]
		if not h0[9] or not h1[9] or not h2[9]:
			continue
		var cells := [str(end)]
		for v in [1, 2, 3, 4]:   # full, nose, nosewag, nosebank
			var w1 := _omega(h0[v], h1[v]) / k
			var w2 := _omega(h1[v], h2[v]) / k
			var alpha := (w2 - w1).length() / k
			cells.append("%.2f" % alpha)
		cells.append("%.2f" % h2[5])
		cells.append("%.2f" % h2[6])
		cells.append("%.3f" % h2[7])
		cells.append("%.3f" % h2[8])
		cells.append("%.1f" % (h2[0] as Vector3).distance_to(ship.pos))
		print(" | ".join(cells))
	print("\nпо кадрам: fr | look_rate | bank | bank_v | |v|")
	for fr in range(from, upto + 1):
		if fr < _hist.size():
			var h: Array = _hist[fr]
			print("%d | %.2f | %.3f | %.3f | %.2f" % [fr, h[6], h[7], h[8], h[5]])
	ev.free()
