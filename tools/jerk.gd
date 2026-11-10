extends SceneTree
## Рывки в живом мире сцены 00 → 01 (#1400, «Плавность поведения» в `docs/grafika-plan-eco.md`): мир целиком
## (`EcoView` в дереве, дно `Seabed.mesh_height`), корабль стоит в точках ракурсов `scena=` (tools/shot_setup.gd),
## носом к 01, свет включён; шаг 1/30 с. По каждому видимому экземпляру MultiMesh и каждой сетке живого мира —
## ускорение точки и угловое ускорение по трём отсчётам через STRIDE кадров и сдвиг за кадр; печатает худшие по узлам.
## Под xvfb в Compatibility: в headless буфер MultiMesh не читается (видны только сетки):
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 320x240 \
##     -s tools/jerk.gd -- …
## Облачный headless-расчёт, не телефонный. Код игры не меняет.
##   ключи: seed=<n> warm=<с> run=<с> top=<n> stride=<кадров> scena=1,2,3 | place=07,03,06,10
##   place=NN,… — вместо ракурсов сцены: корабль у мест слоя 1 по позе `ShotSetup.place_pose` (как `shot.gd place=`).
##   move=<м/с> — корабль не стоит, а идёт носом к цели с этой скоростью (полный ход — `Helm.Ship.FORWARD` = 3) на
##   FLOOR над видимым дном, с шумом хода как в игре (скорость / 6,7); за MOVE_STOP м до цели встаёт. Так видны
##   реакции живого мира на подход корабля (испуг стай, уход с курса), которых у стоящего нет.
## Порядок экземпляров в буфере у некоторых видов меняется (ближние к кораблю, LOD): скачок «через полкарты» —
## перестановка, а не рывок; такие (сдвиг за кадр больше JUMP) печатаются отдельно числом.

const ShotSetup := preload("res://tools/shot_setup.gd")
const DT := 1.0 / 30.0
const STRIDE := 3                ## отсчёты через 0,1 с — дрожь сетки в кадр не считаем (ключ stride=<кадров>)
## Виды, что шагают через кадр (огнёвки — половинами, EcoOgnevka.moved_half), при нечётном шаге отсчётов ложно
## «дёргаются»: в отрезок попадает то один, то два их шага (у огнёвок ≈ 45 рад/с² и 8 м/с² при любом повороте) —
## для них stride=6.
const FLOOR := 7.0
const JUMP := 5.0                ## сдвиг за кадр больше — перестановка в буфере, не движение
const MOVE_STOP := 15.0         ## move=: ближе к цели корабль встаёт
const NEAR := 120.0              ## дальше от корабля не смотрим — в кадре пилота не различить (ключ near=<м>)
## Дальше EcoFish.MID (50 м) виды переписываются раз в 2–3 кадра (LOD, #133): сдвиг за кадр там — шаг LOD,
## а не рывок; такие строки помечены «LOD». Только ближние — near=50.


var _done := false
var _near := NEAR
var _stride := STRIDE


func _process(_delta: float) -> bool:
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
	var warm := float(kv.get("warm", "10"))
	var run := float(kv.get("run", "20"))
	var top := int(kv.get("top", "12"))
	_near = float(kv.get("near", str(NEAR)))
	_stride = maxi(1, int(kv.get("stride", str(STRIDE))))
	var move := float(kv.get("move", "0"))
	var pts: Array[Vector2] = [Vector2(4.0, 80.0), Vector2(20.0, 22.5), Vector2(33.0, -22.0)]
	var poses: Array = []   # [подпись, корабль (x, z), цель (x, z)]
	if kv.has("place"):
		for id in String(kv["place"]).split(","):
			var pose := ShotSetup.place_pose(id)
			if pose.is_empty():
				push_error("нет места %s" % id)
				continue
			var sp: Vector3 = pose["ship"]
			poses.append(["place=" + id, Vector2(sp.x, sp.z), LayerMap.xz(id if LayerMap.POINTS.has(id) else LayerMap.id_of(id))])
	else:
		for s in String(kv.get("scena", "1,2,3")).split(","):
			poses.append(["scena=" + s, pts[int(s) - 1], LayerMap.xz("01")])
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	root.add_child(ev)
	ev.world.reset(int(kv.get("seed", "20261018")))
	for pz: Array in poses:
		var at: Vector2 = pz[1]
		var goal: Vector2 = pz[2]
		var ship := EcoLink.ShipState.new()
		ship.pos = Vector3(at.x, Seabed.mesh_height(at.x, at.y) + FLOOR, at.y)
		var to := goal - at
		ship.yaw = atan2(-to.x, -to.y)
		ship.light_on = true
		ship.light_range = 60.0
		for i in int(warm / DT):
			_drive(ship, goal, move)
			ev.step(DT, ship)
		var hist := {}    # путь узла → [кадры: PackedVector3Array позиций, Array[Basis]]
		var worst := []
		var swaps := {}
		var nearest := {}   # узел → ближайший к кораблю экземпляр за прогон, м
		var frames := int(run / DT)
		for f in frames:
			_drive(ship, goal, move)
			ev.step(DT, ship)
			_sample(ev, ship.pos, f, hist, worst, swaps, nearest)
		print("\n%s: корабль (%.0f, %.0f, %.0f)%s, мир %.0f с после %.0f с, отсчёты через %d кадров" % [
				pz[0], ship.pos.x, ship.pos.y, ship.pos.z, (" к концу, ход %.1f м/с от (%.0f, %.0f)" % [move, at.x, at.y])
				if move > 0.0 else "", run, warm, _stride])
		print("  до точки места %.0f м" % Vector2(ship.pos.x, ship.pos.z).distance_to(goal))
		if worst.is_empty():
			print(quiet_line(_near, nearest, top))
		else:
			_report(worst, swaps, top)
	ev.free()


## move=: шаг корабля носом к цели на FLOOR над видимым дном; ближе MOVE_STOP — стоит.
static func _drive(ship: EcoLink.ShipState, goal: Vector2, move: float) -> void:
	if move <= 0.0:
		return
	var to := goal - Vector2(ship.pos.x, ship.pos.z)
	if to.length() < MOVE_STOP:
		ship.speed = 0.0
		ship.hull_noise = 0.0
		return
	ship.speed = move
	ship.hull_noise = clampf(move / 6.7, 0.0, 1.0)
	var d := to.normalized() * move * DT
	var x := ship.pos.x + d.x
	var z := ship.pos.z + d.y
	ship.pos = Vector3(x, Seabed.mesh_height(x, z) + FLOOR, z)
	ship.yaw = atan2(-to.x, -to.y)


## Позиции и базисы экземпляров кадра f; узел — путь от EcoView.
func _sample(ev: Node, ship: Vector3, f: int, hist: Dictionary, worst: Array, swaps: Dictionary, nearest: Dictionary) -> void:
	for node in ev.find_children("*", "", true, false):
		var gi := node as GeometryInstance3D
		if gi == null or not gi.is_visible_in_tree():
			continue
		var items: Array = []    # [Transform3D]
		if gi is MultiMeshInstance3D:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm == null:
				continue
			var cnt := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
			for i in cnt:
				items.append(gi.global_transform * mm.get_instance_transform(i))
		elif gi is MeshInstance3D:
			items.append(gi.global_transform)
		else:
			continue
		var key := String(ev.get_path_to(gi))
		for t: Transform3D in items:
			if t.basis.get_scale().length() < 1e-3:
				continue
			var d := t.origin.distance_to(ship)
			if d < float(nearest.get(key, INF)):
				nearest[key] = d
		var h: Array = hist.get(key, [])
		h.append(items)
		if h.size() > 2 * _stride + 1:
			h.pop_front()
		hist[key] = h
		if h.size() < 2 * _stride + 1:
			continue
		var a0: Array = h[0]
		var a1: Array = h[_stride]
		var a2: Array = h[2 * _stride]
		var prev: Array = h[2 * _stride - 1]
		var cnt2 := mini(mini(a0.size(), a1.size()), mini(a2.size(), prev.size()))
		for i in cnt2:
			var t0: Transform3D = a0[i]
			var t1: Transform3D = a1[i]
			var t2: Transform3D = a2[i]
			if t2.origin.distance_to(ship) > _near or t2.basis.get_scale().length() < 1e-3 or t0.basis.get_scale().length() < 1e-3 \
					or t1.basis.get_scale().length() < 1e-3:
				continue
			var hop := t2.origin.distance_to((prev[i] as Transform3D).origin)
			if hop > JUMP:
				swaps[key] = int(swaps.get(key, 0)) + 1
				continue
			var k := _stride * DT
			var acc := (t0.origin - 2.0 * t1.origin + t2.origin).length() / (k * k)
			var w1 := _omega(t0.basis, t1.basis) / k
			var w2 := _omega(t1.basis, t2.basis) / k
			var alpha := (w2 - w1).length() / k
			worst.append([key, i, f, acc, alpha, t2.origin, hop, t2.origin.distance_to(ship)])


## Строка вместо пустого списка худших: ближе near никого не было — кто ближайший за прогон (узел → м), чтобы
## отличить «мир у точки не заселён» от «точка съёмки далеко от жизни» (#1400).
static func quiet_line(near: float, nearest: Dictionary, top: int) -> String:
	var keys := nearest.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return nearest[a] < nearest[b])
	var parts: PackedStringArray = []
	for k: String in keys.slice(0, top):
		parts.append("%s %.0f м" % [k, nearest[k]])
	return "  ближе %.0f м никого; ближайшие за прогон: %s" % [near, ", ".join(parts) if parts.size() > 0 else "нет ни одного"]


## Поворот от a к b — вектор оси × угол, рад.
func _omega(a: Basis, b: Basis) -> Vector3:
	var q := (b.orthonormalized().get_rotation_quaternion() * a.orthonormalized().get_rotation_quaternion().inverse()).normalized()
	if q.w < 0.0:
		q = -q
	var ang := 2.0 * acos(clampf(q.w, -1.0, 1.0))
	var s := sqrt(maxf(0.0, 1.0 - q.w * q.w))
	if s < 1e-6:
		return Vector3.ZERO
	return Vector3(q.x, q.y, q.z) / s * ang


func _report(worst: Array, swaps: Dictionary, top: int) -> void:
	for col in [3, 4, 6]:
		var best := {}   # узел → худшая строка
		for r in worst:
			var b: Array = best.get(r[0], [])
			if b.is_empty() or r[col] > b[col]:
				best[r[0]] = r
		var rows := best.values()
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[col] > b[col])
		print("  худшие по %s:" % {3: "ускорению точки, м/с²", 4: "угловому ускорению, рад/с²", 6: "сдвигу за кадр, м"}[col])
		for r in rows.slice(0, top):
			var p: Vector3 = r[5]
			print("    %8.2f  %s #%d, кадр %d, у (%.0f, %.0f, %.0f), %.0f м от корабля%s" % [r[col], r[0], r[1], r[2],
					p.x, p.y, p.z, r[7], " — LOD" if r[7] > EcoFish.MID else ""])
	if not swaps.is_empty():
		print("  перестановки в буфере (сдвиг > %.0f м за кадр): %s" % [JUMP, str(swaps)])
