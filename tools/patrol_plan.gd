extends SceneTree
## Запуск: godot --headless --path . -s tools/patrol_plan.gd -- plan.json; рисунок: python3 tools/patrol_plan.py plan.json plan.png
## План патруля серпохвоста для #1400: где бывают хищники (корабль далеко) и что они делают с кораблём на штатном
## проходе 00 → 01 со светом (стоянка в середине).

const SEEDS := 8
const PATROL_T := 400.0
const DT := 0.15
const SCENA: Array[Vector2] = [Vector2(4.0, 80.0), Vector2(20.0, 22.5), Vector2(33.0, -22.0)]
var out_path := ""


func _initialize() -> void:
	out_path = OS.get_cmdline_user_args()[0]
	_go.call_deferred()


func _ship_y(x: float, z: float) -> float:
	return Seabed.mesh_height(x, z) + 7.0


func _go() -> void:
	var eco := EcoView.new()
	root.add_child(eco)
	eco.ground = Seabed.mesh_height
	var w: EcoWorld = eco.world
	var preds: EcoPred = eco.preds
	var data := {"starts": [], "patrol": [], "routes": [], "reef": [], "scena": []}
	for s in EcoPred.STARTS:
		data["starts"].append([s.x, s.y])
	for s in SCENA:
		data["scena"].append([s.x, s.y])
	# 1) патруль: корабль далеко, тихо
	var near := [0, 0, 0]
	var near24 := [0, 0, 0]
	var samples := 0
	for sd in SEEDS:
		w.ship.pos = Vector3(900, -30, 900)
		w.ship.light_on = false
		w.ship.speed = 0.0
		w.ship.shielded = true
		w.reset(1000 + sd)
		if sd == 0:
			var r := preds.reef_axis()
			data["reef"] = [r.x, r.z]
		var tr := []
		var t := 0.0
		var next := 0.0
		while t < PATROL_T:
			w.step(DT)
			t += DT
			if t >= next:
				next += 1.0
				samples += 1
				for pr in preds.all:
					var p := pr.agent.p
					tr.append([snappedf(p.x, 0.1), snappedf(p.z, 0.1), pr.index, int(pr.mode)])
				for i in 3:
					var m := INF
					for pr in preds.all:
						var p := pr.agent.p
						m = minf(m, Vector2(p.x - SCENA[i].x, p.z - SCENA[i].y).length())
					if m < 32.0: near[i] += 1
					if m < 24.0: near24[i] += 1
		data["patrol"].append(tr)
	print("патруль: %d с на зерно × %d зёрен" % [int(PATROL_T), SEEDS])
	for i in 3:
		print("  scena=%d: хищник ближе 32 м — %.0f %% времени, ближе 24 м — %.0f %%" % [i + 1,
			100.0 * near[i] / samples, 100.0 * near24[i] / samples])
	# 2) проход: 00 → середина (стоянка 25 с со светом) → подход к 01, 5 м/с, свет включён
	var path: Array[Vector2] = [LayerMap.xz("00"), SCENA[0], SCENA[1], SCENA[2], LayerMap.xz("01")]
	var bites := 0
	var charges := 0
	for sd in SEEDS:
		w.reset(1000 + sd)
		w.ship.shielded = false
		w.ship.light_on = true
		var tr := []
		var ev := []
		var t := 0.0
		var leg := 0
		var at := path[0]
		var hold := 0.0
		var prev := {}
		var next := 0.0
		var dead_end := 200.0
		while t < dead_end and leg < path.size() - 1:
			var spd := 5.0
			if leg == 2 and hold < 25.0 and at.distance_to(SCENA[1]) < 0.5:
				hold += DT
				spd = 0.0
			var to := path[leg + 1]
			var d := to - at
			if spd > 0.0:
				if d.length() <= spd * DT:
					at = to
					leg += 1
				else:
					at += d.normalized() * spd * DT
			w.ship.pos = Vector3(at.x, _ship_y(at.x, at.y), at.y)
			w.ship.speed = spd
			w.ship.yaw = atan2(-d.x, -d.y)
			w.step(DT)
			t += DT
			for pr in preds.all:
				if prev.get(pr.index, -1) != int(pr.mode):
					if pr.mode == EcoPred.Mode.CHARGE:
						charges += 1
						ev.append(["charge", snappedf(t, 0.1), pr.index, snappedf(pr.agent.p.x, 0.1), snappedf(pr.agent.p.z, 0.1), snappedf(at.x, 0.1), snappedf(at.y, 0.1)])
					prev[pr.index] = int(pr.mode)
			for e in w.bus.pending:
				if e.species == "pred" and e.note == "bite":
					bites += 1
					ev.append(["bite", snappedf(t, 0.1), -1, snappedf(e.pos.x, 0.1), snappedf(e.pos.z, 0.1), snappedf(at.x, 0.1), snappedf(at.y, 0.1)])
			w.bus.pending.clear()
			if t >= next:
				next += 1.0
				var row := [snappedf(at.x, 0.1), snappedf(at.y, 0.1)]
				for pr in preds.all:
					row.append_array([snappedf(pr.agent.p.x, 0.1), snappedf(pr.agent.p.z, 0.1), int(pr.mode)])
				tr.append(row)
		data["routes"].append({"track": tr, "events": ev, "t": t})
		var s := ", ".join(ev.map(func(e): return "%s %.0f с (корабль %.0f; %.0f)" % [e[0], e[1], e[5], e[6]]))
		print("  зерно %d: %s" % [sd, s if s != "" else "без бросков"])
	print("проход: бросков %d, укусов %d на %d проходов" % [charges, bites, SEEDS])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	quit(0)
