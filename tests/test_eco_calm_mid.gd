extends TestCase
## Спокойная середина 00 → 01 (#1400, решение гейм-дизайнера 08.11 в `docs/urovni/sloj-1.md`): цепочку «прожектор →
## волнолист → моллюски» не совмещать с песчаной засадой, засадчиками и логовом. Путь и стоянка — как в
## `tools/mid_calm.gd` (PATH, FLOOR, STOP): корабль идёт от выхода из 00 к середине (20; 22,5) и стоит там. Засады
## мира стоят на местах из констант, поэтому проверка — геометрией луча, без шагов мира.

const STEP := 0.5   # м между пробами пути
const LOOK := 16    # курсов на стоянке: экипаж оглядывается


func _tool() -> GDScript:
	return load("res://tools/mid_calm.gd")


## Пробы корабля середины: путь PATH[0] → PATH[1] курсом по ходу и стоянка у PATH[1] со всеми курсами.
func _ships() -> Array[EcoLink.ShipState]:
	var tool := _tool()
	var a: Vector2 = tool.PATH[0]
	var b: Vector2 = tool.PATH[1]
	var out: Array[EcoLink.ShipState] = []
	var n := int(a.distance_to(b) / STEP)
	var d := b - a
	for i in n + 1:
		out.append(_ship(tool, a.lerp(b, float(i) / n), atan2(-d.x, -d.y)))
	for k in LOOK:
		out.append(_ship(tool, b, TAU * k / LOOK))
	return out


func _ship(tool: GDScript, xz: Vector2, yaw: float) -> EcoLink.ShipState:
	var s := EcoLink.ShipState.new()
	s.pos = tool.ship_at(xz)
	s.yaw = yaw
	s.light_on = true
	s.light_range = Searchlight.BASE_RANGE
	return s


## Где могут быть глаза глазуна у пятна стайки p: на круге GZ_OFFSET (угол — от зерна), над видимым дном.
func _glazun_eyes(p: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in 12:
		var a := TAU * k / 12.0
		var x := p.x + cos(a) * EcoCoins.GZ_OFFSET
		var z := p.z + sin(a) * EcoCoins.GZ_OFFSET
		out.append(Vector3(x, Seabed.mesh_height(x, z) + EcoCoins.EYE.y, z))
	return out


func test_glazun_eyes_never_in_beam() -> void:
	var ships := _ships()
	var eyes: Array[Vector3] = []
	for p in EcoCoins.default_spots():
		eyes.append_array(_glazun_eyes(p))
	eq(eyes.size(), EcoCoins.SCHOOLS * 12, "все глазуны")
	var nearest := INF
	var lit: Array[String] = []
	for s in ships:
		for e in eyes:
			if EcoWorld.beam_hits(s, e):
				lit.append("%s из %s" % [e, s.pos])
			nearest = minf(nearest, Vector2(e.x - s.pos.x, e.z - s.pos.z).length())
	eq(lit.size(), 0, "глаза глазуна не в луче середины: %s" % ", ".join(lit.slice(0, 3)))
	ok(nearest > EcoWorld.BEAM_R * 0.5, "глазун не у пути середины: %.1f м" % nearest)
	# Проверка не пустая: глаз прямо по курсу середины луч видит.
	var hits := 0
	for s in ships:
		var fwd := Basis(Vector3.UP, s.yaw) * Vector3(0, 0, -20)
		var p := s.pos + fwd
		p.y = Seabed.mesh_height(p.x, p.z) + EcoCoins.EYE.y
		if EcoWorld.beam_hits(s, p):
			hits += 1
	ok(hits > ships.size() / 2, "глаз в 20 м по курсу — в луче: %d из %d" % [hits, ships.size()])


func test_eel_lair_beyond_warning() -> void:
	var nearest := INF
	for s in _ships():
		for l in EcoEel.LAIRS:
			nearest = minf(nearest, Vector2(s.pos.x, s.pos.z).distance_to(l))
	ok(nearest > EcoEel.WARN_R, "логово стеклоуста дальше знака WARN_R: %.1f м" % nearest)


func test_echo_does_not_listen() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.mesh_height
	var bones := w.add(EcoBones.new()) as EcoBones
	var echo := w.add(EcoEcho.new(bones, null)) as EcoEcho
	w.reset(1)
	var at := echo.echo.p
	var nearest := INF
	for s in _ships():
		nearest = minf(nearest, Vector2(s.pos.x, s.pos.z).distance_to(Vector2(at.x, at.z)))
	ok(nearest > EcoEcho.LISTEN_R, "эхоловец не слушает корабль середины: %.1f м" % nearest)
	ok(nearest > EcoEcho.STRIKE_R, "и не бьёт на импульс")



## Места появления из starts, которые ближе sense к пробам середины.
func _near_starts(starts: Array[Vector2], sense: float) -> Array[String]:
	var out: Array[String] = []
	for st in starts:
		for s in _ships():
			var d := Vector2(s.pos.x, s.pos.z).distance_to(st)
			if d <= sense:
				out.append("%s у %s: %.1f м" % [st, s.pos, d])
				break
	return out


## «Не создавать новую точку спавна непосредственно перед кораблём» (`docs/urovni/sloj-1.md`, 08.11): серпохвосты
## появляются (STARTS, и пробная дуга ARC[0]) дальше, чем видят свет и слышат сонар (REACH) и двигатели
## (HEAR_RADIUS), от всего пути середины и стоянки. Тихий круг пробы — вокруг той же стоянки, что у инструмента.
func test_pred_starts_beyond_senses() -> void:
	var tool := _tool()
	eq(EcoPred.QUIET, tool.PATH[1], "тихий круг пробы — вокруг стоянки середины")
	var starts: Array[Vector2] = EcoPred.STARTS.duplicate()
	starts.append(EcoPred.ARC[0])
	var sense := maxf(EcoPred.REACH, EcoPred.HEAR_RADIUS)
	var near := _near_starts(starts, sense)
	eq(near.size(), 0, "хищник не появляется у пути середины: %s" % ", ".join(near))
	var nearest := INF
	for st in starts:
		for s in _ships():
			nearest = minf(nearest, Vector2(s.pos.x, s.pos.z).distance_to(st))
	ok(nearest > sense, "ближайшее место появления — %.1f м, чутьё %.0f м" % [nearest, sense])
	# Проверка не пустая: место появления у середины пути (сбоку на полчутья) она ловит.
	var mid: Vector2 = (tool.PATH[0] + tool.PATH[1]) * 0.5 + Vector2(sense * 0.5, 0.0)
	var bad: Array[Vector2] = [mid]
	eq(_near_starts(bad, sense).size(), 1, "место у пути — поймано")


## `tools/mid_calm.gd start0=` (#1400, 12.11): серпохвост №0 со своего старта стоит там же, где его ставит
## `EcoPred.reset`; с пробного — в той же высоте над дном.
func test_tool_moves_pred_like_reset() -> void:
	var tool := _tool()
	var w := EcoWorld.new()
	w.ground = Seabed.mesh_height
	var preds := w.add(EcoPred.new(null)) as EcoPred
	w.reset(7)
	var pr: EcoPred.Pred = preds.all[0]
	var was := pr.agent.p
	tool.move_pred(pr, EcoPred.STARTS[0])
	near(pr.agent.p.distance_to(was), 0.0, 1e-4, "свой старт — то же место")
	tool.move_pred(pr, Vector2(-60, -20))
	near(Vector2(pr.agent.p.x, pr.agent.p.z).distance_to(Vector2(-60, -20)), 0.0, 1e-4, "пробный старт")
	eq(pr.start, pr.agent.p, "старт патруля — там же")
	ok(pr.agent.p.y <= EcoPred.GOAL_CEILING + 1e-4, "не выше потолка")


## Наблюдение закончено: моллюски видны раньше первого «замера» или «замера» нет.
func test_tool_chain_done() -> void:
	var tool := _tool()
	ok(tool.chain_done({"mollusk_t": 8.5, "alert_t": -1.0}), "без замера")
	ok(tool.chain_done({"mollusk_t": 8.5, "alert_t": 12.0}), "замер позже")
	ok(not tool.chain_done({"mollusk_t": 8.8, "alert_t": 7.9}), "замер раньше")
	ok(not tool.chain_done({"mollusk_t": -1.0, "alert_t": -1.0}), "моллюски не показались")
