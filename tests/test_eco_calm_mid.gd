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


## Секунд стоянки середины, которые куртина прохода видна раскрытой курсом подхода (дальше — выходит из луча и
## через LIT_HOLD + сворачивание закрывается: 3,4–5,7 с на 16 зёрнах; экипаж поворачивает луч сам).
const SEEN := 3.0


## Ход середины, как в `tools/mid_calm.gd` (без тёмной стоянки): свет у выхода из 00, PATH[0] → PATH[1] 5 м/с на
## FLOOR над дном и SEEN с стоянки. Мир — один волнолист. По кусту куртины прохода: {lit, open (раскрыт на
## FEED_OPEN — моллюски под листьями видны), d — до корабля в этот миг, shut — снова свёрнут ниже FEED_OPEN,
## near — ближе всего корабль}; "arrive" — пришёл к стоянке.
func _route_fern_pass(seed_value: int) -> Dictionary:
	var tool := _tool()
	var w := EcoWorld.new()
	w.ground = Seabed.mesh_height
	var fr := w.add(EcoFern.new()) as EcoFern
	w.reset(seed_value)
	var ship := w.ship
	ship.pos = tool.ship_at(tool.PATH[0])
	ship.light_on = true
	ship.light_range = Searchlight.BASE_RANGE
	var dt: float = tool.DT
	var out := {"arrive": -1.0, "ferns": {}}
	for fe in fr.ferns:
		if Vector2(fe.pos.x, fe.pos.z).distance_to(EcoFern.ROUTE_CLUSTER) < EcoFern.SPREAD * 2.0:
			out["ferns"][fe.index] = {"lit": -1.0, "open": -1.0, "d": 0.0, "shut": -1.0, "near": INF}
	var t := 0.0
	var tg: Vector2 = tool.PATH[1]
	while out["arrive"] < 0.0 or t < out["arrive"] + SEEN:
		var d := Vector2(tg.x - ship.pos.x, tg.y - ship.pos.z)
		if d.length() < 0.5:
			ship.speed = 0.0
			if out["arrive"] < 0.0:
				out["arrive"] = t
		else:
			ship.yaw = atan2(-d.x, -d.y)
			ship.speed = tool.SPEED
			var mv := d.normalized() * minf(tool.SPEED * dt, d.length())
			ship.pos = tool.ship_at(Vector2(ship.pos.x + mv.x, ship.pos.z + mv.y))
		w.step(dt)
		t += dt
		for k in out["ferns"]:
			var fe: EcoFern.Fern = fr.ferns[k]
			var r: Dictionary = out["ferns"][k]
			if fe.lit and r["lit"] < 0.0:
				r["lit"] = t
			if fe.open > EcoFern.FEED_OPEN and r["open"] < 0.0:
				r["open"] = t
				r["d"] = ship.pos.distance_to(fe.pos)
			if r["open"] >= 0.0 and r["shut"] < 0.0 and fe.open <= EcoFern.FEED_OPEN:
				r["shut"] = t
			r["near"] = minf(r["near"], ship.pos.distance_to(fe.pos))
	return out


## Цепочка «прожектор → волнолист → моллюски» на ходу середины (решение гейм-дизайнера 08.11, #1400): куртина у
## прохода попадает в луч на подходе (по `tools/mid_calm.gd` — 6,6–7,5 с после света), раскрывается на FEED_OPEN не
## раньше, чем через FEED_OPEN / OPEN_RATE с в луче, — до стоянки и ещё SEEN с стоянки держится раскрытой;
## моллюски видны после раскрытия, а у стоянки корабль ближе SHELL_BREATH_FAR — моллюски дышат на глазах экипажа.
## 16 зёрен.
func test_route_fern_opens_in_beam_before_stop() -> void:
	var dt: float = _tool().DT
	var need := EcoFern.FEED_OPEN / EcoFern.OPEN_RATE
	var first_lit := INF
	var last_lit := 0.0
	var ferns := 0
	for s in 16:
		var r := _route_fern_pass(20261018 + s * 7919)
		var arrive: float = r["arrive"]
		ok(arrive > 0.0, "зерно %d: корабль пришёл к стоянке" % s)
		eq((r["ferns"] as Dictionary).size(), EcoFern.PER_CLUSTER, "зерно %d: куртина прохода" % s)
		var seed_first := INF
		for k in r["ferns"]:
			var fe: Dictionary = r["ferns"][k]
			ferns += 1
			var tag := "зерно %d, куст %d" % [s, k]
			ok(fe["lit"] > 0.0 and fe["lit"] < arrive, "%s: в луче на подходе (%.2f с, стоянка с %.2f с)" % [tag, fe["lit"], arrive])
			ok(fe["open"] >= fe["lit"] + need - dt * 1.5, "%s: раскрыт не раньше %.2f с в луче: луч %.2f, раскрыт %.2f" % [tag, need, fe["lit"], fe["open"]])
			ok(fe["open"] > 0.0 and fe["open"] < arrive, "%s: раскрыт до стоянки: %.2f с" % [tag, fe["open"]])
			ok(fe["d"] <= EcoWorld.BEAM_R + Searchlight.LAMP.length(), "%s: раскрыт в луче, %.1f м" % [tag, fe["d"]])
			ok(fe["shut"] < 0.0 or fe["shut"] >= arrive + SEEN - dt * 0.5, "%s: раскрыт ещё %.0f с стоянки: свёрнут на %.2f с, стоянка с %.2f с" % [tag, SEEN, fe["shut"], arrive])
			ok(fe["near"] < FernView.SHELL_BREATH_FAR, "%s: моллюски дышат — корабль в %.1f м" % [tag, fe["near"]])
			seed_first = minf(seed_first, fe["lit"])
		first_lit = minf(first_lit, seed_first)
		last_lit = maxf(last_lit, seed_first)
	eq(ferns, 16 * EcoFern.PER_CLUSTER, "все кусты всех зёрен")
	ok(first_lit >= 6.0 and last_lit <= 8.0, "первый куст в луче на 6–8 с после света: %.2f…%.2f" % [first_lit, last_lit])


## Замеры шага мира зова гребневиков: наибольший разогрев стай, шаги хоть одной стаи ярче FLARE_ON, ближайшие
## к кораблю стая и серпохвост.
func _measure_raduzh(out: Dictionary, w: EcoWorld, preds: EcoPred, rz: EcoRaduzh) -> void:
	var lit := false
	for sw in rz.swarms:
		out["glow"] = maxf(out["glow"], sw.glow)
		out["near_swarm"] = minf(out["near_swarm"], sw.c.distance_to(w.ship.pos))
		lit = lit or sw.glow > EcoRaduzh.FLARE_ON
	if lit:
		out["flare_steps"] += 1
	for pr in preds.all:
		out["near_pred"] = minf(out["near_pred"], pr.agent.p.distance_to(w.ship.pos))


## Зов гребневиков на ходу середины: мир — серпохвосты и радужники (порядок систем — как в `EcoView`: хищники
## раньше стай), дно `Seabed`. Ход — как в `tools/mid_calm.gd`: тёмная стоянка у выхода 00 (DARK с — кончается
## пауза хищников после сброса, `EcoPred.reset` — cooldown до 30 с), затем свет, путь PATH[0] → PATH[1] на 5 м/с
## и стоянка STOP с. sweep = false — луч цепочки: в пути по ходу, на стоянке наведён на куртину волнолиста у
## прохода (`EcoFern.ROUTE_CLUSTER`); sweep = true — экипаж оглядывается LOOK курсов. homes — свои дома стай
## (пусто — как в игре). Меряет с момента света до конца стоянки.
func _route_raduzh_pass(seed_value: int, homes: Array[Vector2] = [], sweep := false) -> Dictionary:
	var tool := _tool()
	var w := EcoWorld.new()
	w.ground = Seabed.mesh_height
	var preds := w.add(EcoPred.new()) as EcoPred
	var rz := w.add(EcoRaduzh.new(homes)) as EcoRaduzh
	preds.raduzh = rz
	w.reset(seed_value)
	var ship := w.ship
	ship.pos = tool.ship_at(tool.PATH[0])
	var dt: float = tool.DT
	var out := {"flare_steps": 0, "flare": 0, "betray": 0, "glow": 0.0, "near_swarm": INF, "near_pred": INF}
	for i in int(tool.DARK / dt):
		w.step(dt)
	ship.light_on = true
	ship.light_range = Searchlight.BASE_RANGE
	var tg: Vector2 = tool.PATH[1]
	var travel := 0.0
	while Vector2(tg.x - ship.pos.x, tg.y - ship.pos.z).length() >= 0.5 and travel < 60.0:
		var d := Vector2(tg.x - ship.pos.x, tg.y - ship.pos.z)
		ship.yaw = atan2(-d.x, -d.y)
		ship.speed = tool.SPEED
		var mv := d.normalized() * minf(tool.SPEED * dt, d.length())
		ship.pos = tool.ship_at(Vector2(ship.pos.x + mv.x, ship.pos.z + mv.y))
		w.step(dt)
		_measure_raduzh(out, w, preds, rz)
		travel += dt
	ship.speed = 0.0
	var hold: float = tool.STOP / LOOK if sweep else tool.STOP
	for k in (LOOK if sweep else 1):
		var d := Vector2(EcoFern.ROUTE_CLUSTER.x - ship.pos.x, EcoFern.ROUTE_CLUSTER.y - ship.pos.z)
		ship.yaw = TAU * k / LOOK if sweep else atan2(-d.x, -d.y)
		for i in int(hold / dt):
			w.step(dt)
			_measure_raduzh(out, w, preds, rz)
	for ev in w.bus.pending:
		if ev.species == EcoRaduzh.ID and ev.note == "flare":
			out["flare"] += 1
		elif ev.species == EcoRaduzh.ID and ev.note == "betray":
			out["betray"] += 1
	return out


## Зов гребневиков не в середине (#1400, решение гейм-дизайнера 08.11 — «стая не вспыхивает в том же луче, что и
## волнолист у прохода, и не зовёт хищника», код — `EcoRaduzh.HOMES`; расчёт `tools/mid_calm.gd`; статика домов —
## `test_eco_raduzh.test_no_swarm_home_on_calm_middle`): на ходу середины 00 → 01 с лучом по ходу и за стоянку с
## лучом на куртине волнолиста ни одна стая радужников не вспыхивает (наблюдений «flare» нет, разогрев ниже
## FLARE_ON с учётом дрейфа ±10 м) и вспышка не зовёт серпохвоста («betray» нет). 16 зёрен. Проверка не пустая:
## с прежним домом стаи 1 (45, 0) — в 5 м от волнолиста у прохода — вспышка в середине есть (в расчёте звала
## хищника в 7 из 16 проходов).
func test_raduzh_call_not_on_calm_middle() -> void:
	var glow := 0.0
	var near_swarm := INF
	var near_pred := INF
	for s in 16:
		var r := _route_raduzh_pass(20261018 + s * 7919)
		var tag := "зерно %d" % s
		eq(r["flare"], 0, "%s: наблюдений «flare» нет" % tag)
		eq(r["flare_steps"], 0, "%s: стая не вспыхивает (шагов ярче FLARE_ON)" % tag)
		eq(r["betray"], 0, "%s: вспышка не зовёт серпохвоста" % tag)
		glow = maxf(glow, r["glow"])
		near_swarm = minf(near_swarm, r["near_swarm"])
		near_pred = minf(near_pred, r["near_pred"])
	print("  середина 00 → 01, луч цепочки, 16 зёрен: разогрев стай до %.2f (вспышка с %.1f), стая ближе всего %.0f м, серпохвост %.0f м" \
		% [glow, EcoRaduzh.FLARE_ON, near_swarm, near_pred])
	ok(glow < EcoRaduzh.FLARE_ON, "ни одна стая не разогрелась до вспышки: %.2f" % glow)
	# Проверка не пустая: прежний дом стаи 1 — в 5 м от волнолиста у прохода.
	var moved: Array[Vector2] = EcoRaduzh.HOMES.duplicate()
	moved[1] = Vector2(45, 0)
	var flare := 0
	var betray := 0
	for s in 4:
		var rp := _route_raduzh_pass(20261018 + s * 7919, moved)
		flare += rp["flare"]
		betray += rp["betray"]
	print("  прежний дом (45; 0): наблюдений «flare» %d, «betray» %d за 4 зерна" % [flare, betray])
	ok(flare > 0, "с прежним домом стая 1 вспыхивает в середине — тест её ловит")


## Оглядка со стоянки середины — замер к решению уровней (#1400): свободный поворот луча на стоянке (LOOK курсов)
## на части зёрен задевает стаю 1 в дрейфе (дом (80, 5) в ~62 м от стоянки, дрейф до 14 м к кораблю, члены стаи ещё
## 4 м, лампа выносит луч на ~7 м вперёд) — стая вспыхивает и зовёт серпохвоста (зерно 20261018+14×7919: курс
## 4,71 рад, 54 м, glow 0,8, «betray» ×2). Луч цепочки (на куртину) не задевает ни одно зерно — см. тест выше.
func test_raduzh_call_on_calm_middle_sweep_measure() -> void:
	var flared := 0
	var betray := 0
	var glow := 0.0
	var near_swarm := INF
	for s in 16:
		var r := _route_raduzh_pass(20261018 + s * 7919, [], true)
		if r["flare"] > 0:
			flared += 1
		betray += r["betray"]
		glow = maxf(glow, r["glow"])
		near_swarm = minf(near_swarm, r["near_swarm"])
	print("  ЗАМЕР (#1400): оглядка со стоянки середины — вспышки стай в %d/16 зёрен, «betray» %d, разогрев до %.2f, стая ближе всего %.0f м" \
		% [flared, betray, glow, near_swarm])
	ok(true, "замер без порога — решение за уровнями и гейм-дизайнером")


## Проба целей патруля №0 (#1400, уровни и гейм-дизайнер 12.11, вариант 1): `band0=` — прямоугольник x0…x1, z0…z1;
## цель «у дома» — та же доля сдвига от дома по каждой оси внутри прямоугольника, углы — в углах.
func test_tool_band_and_goal() -> void:
	var tool := _tool()
	var r: Rect2 = tool.parse_band("-75,-45,20,76")
	eq(r, Rect2(-75, 20, 30, 56), "полоса уровней")
	eq(EcoPred.band_goal(r, -25.0, -25.0), Vector2(-75, 20), "угол x0, z0")
	eq(EcoPred.band_goal(r, 25.0, 25.0), Vector2(-45, 76), "угол x1, z1")
	eq(EcoPred.band_goal(r, 0.0, 0.0), Vector2(-60, 48), "середина")
	near(tool.to_mid_path(Vector2(-45, 80), Vector2(-45, 20)), 49.0, 1e-3, "полоса западнее пути середины на 49 м")
	near(tool.to_mid_path(Vector2(-45, 50), Vector2(60, 50)), 0.0, 1e-3, "отрезок через путь")


## Цели патруля серпохвоста в маленьком квадрате в углу карты (туда случайная цель почти не попадает): за 400 с
## мира — у кого из хищников сколько.
func _band_goals(band: Dictionary) -> Array:
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float: return -40.0
	w.ship.pos = Vector3(400, -30, 400)
	var fish := w.add(EcoFish.new()) as EcoFish
	var preds := w.add(EcoPred.new(fish)) as EcoPred
	preds.alert = EcoPred.ALERT_ON  # «замер» как в игре; корабль далеко — здесь только выбор цели
	preds.home_band = band
	w.reset(11)
	var corner := Rect2(-160, -160, 1, 1)
	var got := [0, 0, 0]
	var was: Array[Vector3] = []
	for pr in preds.all:
		was.append(pr.agent.goal)
	for i in 400 * 10:
		w.step(0.1)
		for pr in preds.all:
			var g := pr.agent.goal
			if g.distance_to(was[pr.index]) > 0.01 and corner.grow(0.01).has_point(Vector2(g.x, g.z)):
				got[pr.index] += 1
			was[pr.index] = g
	return got


## `EcoPred.home_band` берёт цели «у дома» только у своего хищника и только у своих стай; пусто — как в игре.
func test_home_band_only_own_pred() -> void:
	var off := _band_goals({})
	eq(off, [0, 0, 0], "как в игре — в угол не ходит никто")
	var on := _band_goals({0: {"homes": [0, 1, 2, 3, 4, 5], "rect": Rect2(-160, -160, 1, 1)}})
	ok(on[0] >= 3, "№0 берёт цели у домов в полосе: %s" % str(on))
	eq(on[1], 0, "№1 — как в игре")
	eq(on[2], 0, "№2 — как в игре")
