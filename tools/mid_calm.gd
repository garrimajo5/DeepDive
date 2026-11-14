extends SceneTree
## Спокойная середина 00 → 01 (#1400): что ещё зажигает луч, пока экипаж смотрит цепочку «прожектор → волнолист →
## моллюски». Гейм-дизайнер (08.11): в середине не накладывать зов хищника гребневиками. Мир целиком (`EcoView`, дно
## `Seabed.mesh_height`), headless, без узлов сцены; облачный расчёт, не телефонный.
##   godot --headless --path . -s tools/mid_calm.gd [-- seeds=16 raduzh=1:80,5 lim=<с> dark=<с> probe=1 answer=1 delay=<с> hold=<с>
##   start0=<x>,<z> band0=<x0>,<x1>,<z0>,<z1> fish=<номер>:<x>,<z> watch=<номера через ,> sites=1
##   grot=<x>,<z>;<x>,<z>;… path=1 repeat=1]
## repeat=1 — настоящий повтор 00→01→00→01 (уровни и ГД 14.11, #1400): после 01 стоянка STOP с, обратный ход к 00 через
## середину, стоянка STOP с у 00 и второй проход к 01 со стоянкой у середины, свет не гаснет (кроме ответа экипажа).
## Участки: mid, 01 — первый проход; back — 01→00 и стоянка у 00; mid2, 012 — второй проход. По участку — угрозы,
## первый «замер» и моллюски от его начала; засады глазуна в слышимости — где, когда, где корабль, кто из серпохвостов
## ближе и в каком режиме, сколько монетников в стайке; «СТРОКА» — засада дошла до приборов текстом (`line_shown`, как
## `EcoWorld.repeat`), итогом — во скольких зёрнах строка вернулась во втором проходе и самая долгая тишина между
## засадами (#1400, п. 2 (ш)). Предел прохода по умолчанию — LIMIT_REPEAT.
## Предел `lim=` — ход без ответов: каждый ответ экипажа (`answer=1`) продлевает его на `hold=` с стоянки без света
## (`pass_limit`), иначе повтор с ответом молча обрывался до 012 (#1350, 14.11 01:08). Строки печатаются сразу —
## и зерно, как только посчитано (`live`), а не всё в конце.
## grot= — круг гротовика на пробу (`EcoGrot.route`; уровни и ГД 13.11, #1400: стая 5 едет на нём). С sites=1 — среда
## каждой точки круга; path=1 — весь путь (`grot_path`): гротовик один, корабль далеко, круг целиком — время круга,
## дно и наклон, остановки и поворот на точках, задевает ли панцирь или риф твёрдое других систем и кто ближе всего.
## watch=1,5 — чьи разброс и погони печатать (по умолчанию стая 0; уровни и ГД 13.11 — совместная проба домов стай 1
## и 5): по каждой стае разброс, а по зерну — погони на неё (кто, когда, откуда и куда, ближе всего к выходу 00 и к пути
## середины), итогом — сколько погонь и в скольких зёрнах они ближе EXIT_NEAR м к выходу или к пути середины.
## sites=1 — среда (`site_line`) у домов стай watch и у существующих рифов `EcoCoral.BASES` — кандидатов расстановки.
## fish=<номер>:<x>,<z> — дом стаи рифа (светляки, `EcoFish.home_at`; дом на HOME_LIFT над `Seabed.height`) на пробу в
## другом месте (#1400, гейм-дизайнер и уровни 12.11: стая 0 (15; 76) → (100; 90)); несколько — через «;». Печатает
## разброс стаи WATCH_SHOAL (рыбы дальше всего от дома, ближе всего к выходу 00 и к пути середины) и погони всех
## серпохвостов (HUNT): ближе всего к выходу 00 и к пути середины, на какие стаи.
## band0= — проба целей патруля №0 (#1400, уровни и гейм-дизайнер 12.11, вариант 1): цели «у дома» стай светляков 0 и 1
## — в прямоугольнике x0…x1, z0…z1 (`EcoPred.home_band`); печатает цели №0 и отрезки между ними против пути середины.
## start0= — старт серпохвоста №0 на пробу в другом месте (как `EcoPred.STARTS[0]`: та же высота над дном, #1400, 12.11).
## raduzh=<номер>:<x>,<z> — дом стаи радужников с этим номером на пробу в другом месте (`EcoRaduzh._homes` до сброса
## мира; несколько — через «;»). Проход как `late` в tools/patrol.gd: 30 с без света у 00 (пауза хищников после сброса
## кончилась), затем свет и ход 5 м/с по оси PATH на 7 м над дном, стоянка STOP с у середины, дальше к 01.
## Печатает по зерну и итогом: когда раскрылся волнолист у прохода, вспыхнула ли в середине стая радужников (какая,
## на каком расстоянии от корабля), «betray» — серпохвост заметил вспышку и плывёт к кораблю. Угрозы — события шины
## THREATS в слышимости экипажа (`EcoBus.HEARING`), удары и присоски (HIT, DRAIN), серпохвост в «замере» или броске
## (ALERT, CHARGE) и ближе всего к кораблю — раздельно для середины и подхода к 01.
## «Середина» — от выхода из 00 до конца стоянки; дальше подход к 01 (там своя цепочка угрозы).

## Угрозы кораблю в ленте экипажа: вид → заметки событий шины (песчаная засада, охота серпохвоста, стеклоуст,
## эхоловец).
const THREATS := {
	"glazun": ["ambush", "eyes"],
	"pred": ["alert", "ship", "ping", "hear", "bite"],
	"eel": ["latch", "zap"],
	"echo": ["lure", "strike", "reveal"],
}
const PATH: Array[Vector2] = [Vector2(4.0, 80.0), Vector2(20.0, 22.5), Vector2(33.0, -22.0)]
const FLOOR := 7.0
const SPEED := 5.0
const DT := 1.0 / 30.0
const DARK := 30.0
const STOP := 25.0
## Предел прохода после тёмной стоянки без ответов экипажа, с (каждый ответ добавляет hold — `pass_limit`).
const LIMIT := 120.0
static var limit := LIMIT
const LIMIT_REPEAT := 420.0
## Повтор 00→01→00→01 (`repeat=1`).
static var repeat := false
const SEGS: Array[String] = ["mid", "01", "back", "mid2", "012"]
## Тёмная стоянка этого прогона, с (`dark=`, по умолчанию DARK; короче 20 с — пауза хищников не кончилась, только для
## проверки инструмента).
static var dark := DARK
## Переносы домов радужников этого прогона: номер → (x, z).
static var moves := {}
## Проба тихого круга серпохвоста #1400 (`EcoPred.probe`, `probe=1`).
static var probe := false
## Ответ экипажа (`answer=1`, как `answer=alert` в tools/patrol.gd): услышав «замер» серпохвоста, через `delay=` с
## (по умолчанию DELAY — реакция людей) гасит свет и стоит без хода `hold=` с (HOLD), затем свет и путь дальше.
const DELAY := 1.5
const HOLD := 25.0
static var answer := false
static var delay := DELAY
static var hold := HOLD
## Старт серпохвоста №0 этого прогона (`start0=`), не задан — INF: как в игре.
static var start0 := Vector2.INF
## Полоса целей патруля №0 у домов стай BAND_HOMES (`band0=`), пустая — как в игре.
const BAND_HOMES := [0, 1]
static var band0 := Rect2()
## Порядок событий середины (гейм-дизайнер, #1400, 12.11): свет → раскрытие волнолиста → видимая реакция моллюсков
## (раскрыт на `EcoFern.FEED_OPEN` — моллюски под листьями видны; «рыбы приплыли» — `EcoFern` "mollusk" у куртины
## прохода) → первый «замер» серпохвоста. Путь №0 — старт, затем точки раз в TRACK_EVERY с первые TRACK_FOR с после света.
## Стая, разброс которой печатает расчёт (`fish=`), и подъём дома над дном (как `tools/quiet_map.gd`).
const WATCH_SHOAL := 0
## Стаи, чьи разброс и погони печатает расчёт (`watch=`), по умолчанию [WATCH_SHOAL].
static var watch: Array[int] = [WATCH_SHOAL]
## Среда у домов watch и у рифов (`sites=1`).
static var sites := false
const HOME_LIFT := 3.5
## Переносы домов стай рифа этого прогона: номер → (x, z).
static var fish_moves := {}
## Печатать строки отчёта сразу, как появились (`_init`; тесты собирают их молча).
static var live := false
const TRACK_EVERY := 5.0
const TRACK_FOR := 60.0


func _init() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	var seeds := int(kv.get("seeds", "16"))
	repeat = kv.get("repeat", "0") == "1"
	limit = float(kv.get("lim", str(LIMIT_REPEAT if repeat else LIMIT)))
	dark = float(kv.get("dark", str(DARK)))
	probe = kv.get("probe", "0") == "1"
	answer = kv.get("answer", "0") == "1"
	delay = float(kv.get("delay", str(DELAY)))
	hold = float(kv.get("hold", str(HOLD)))
	if kv.has("start0"):
		var xz: PackedStringArray = kv["start0"].split(",")
		start0 = Vector2(float(xz[0]), float(xz[1]))
	if kv.has("band0"):
		band0 = parse_band(kv["band0"])
	if kv.has("raduzh"):
		moves = parse_moves(kv["raduzh"])
	if kv.has("fish"):
		fish_moves = parse_moves(kv["fish"])
	if kv.has("watch"):
		watch = parse_watch(kv["watch"])
	sites = kv.get("sites", "0") == "1"
	if kv.has("grot"):
		EcoGrot.route = parse_route(kv["grot"])
	if kv.get("path", "0") == "1":
		for line in grot_path():
			print(line)
		if seeds <= 0:
			quit()
			return
	live = true
	report(seeds)
	quit()


## Предел прохода после тёмной стоянки, с: ход `limit` и стоянки без света по ответам экипажа (каждая `hold`).
static func pass_limit(answers: int) -> float:
	return limit + answers * hold


## Строка в отчёт; при `live` — сразу в лог.
static func put(lines: Array[String], line: String) -> void:
	lines.append(line)
	if live:
		print(line)


## "43,75;55,65" → [(43, 75), (55, 65)].
static func parse_route(s: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for part in s.split(";", false):
		var xz := part.split(",")
		out.append(Vector2(float(xz[0]), float(xz[1])))
	return out


## Весь круг гротовика (`EcoGrot.route`) на мире зерна 20261018: гротовик идёт один (корабль за 2 км), шаг PATH_DT,
## пока не пройдёт все точки и не вернётся к первой (не дольше PATH_MAX с). Печатает время круга, дно (мин…макс),
## наклон панциря (наибольший и доля времени у предела `EcoGrot.TILT_MAX`), остановки на точках (сколько секунд шаг
## ниже 0,2 и наибольший поворот, рад/с), касания панцирем и рифом (`body_points`) твёрдого других систем (`solid`) и
## кто из живого ближе PATH_NEAR м к центру тела в пути (система.поле — наименьшее расстояние).
const PATH_DT := 0.1
const PATH_MAX := 1500.0
const PATH_NEAR := 8.0
static func grot_path() -> Array[String]:
	var lines: Array[String] = []
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	ev.world.reset(20261018)
	ev.world.ship.pos = Vector3(0.0, 0.0, -2000.0)
	var g: EcoGrot = ev.grot
	var route := EcoGrot.route
	var perim := 0.0
	for i in route.size():
		perim += route[i].distance_to(route[(i + 1) % route.size()])
	var solids: Array[EcoSystem] = []
	for sys in ev.world.systems:
		if sys != g and sys.has_method("solid"):
			solids.append(sys)
	var objs: Array = []   # [ключ, (x, z)]
	for sys in ev.world.systems:
		if sys == g or sys is EcoFish:
			continue
		for prop in sys.get_property_list():
			if prop["type"] != TYPE_ARRAY:
				continue
			var arr = sys.get(prop["name"])
			if not (arr is Array):
				continue
			for it in arr:
				if not (it is Object) or not ("pos" in it):
					continue
				var pv = it.get("pos")
				if pv is Vector3:
					objs.append(["%s.%s" % [sys.get_script().get_global_name(), prop["name"]], Vector2(pv.x, pv.z)])
				elif pv is Vector2:
					objs.append(["%s.%s" % [sys.get_script().get_global_name(), prop["name"]], pv])
	for b in EcoCoral.BASES:
		objs.append(["огнецвет (EcoCoral.BASES)", b])
	var near := {}
	var hits := {}
	var lo := INF
	var hi := -INF
	var tilt_max := 0.0
	var capped := 0.0
	var slow := 0.0
	var turn_max := 0.0
	var visited := 0
	var last_wp := g.grot.wp
	var t := 0.0
	var yaw0 := g.grot.yaw
	while t < PATH_MAX:
		g.step(ev.world, PATH_DT)
		t += PATH_DT
		var gr := g.grot
		var rate := absf(wrapf(gr.yaw - yaw0, -PI, PI)) / PATH_DT
		yaw0 = gr.yaw
		if t > 5.0:
			turn_max = maxf(turn_max, rate)
		lo = minf(lo, gr.p.y)
		hi = maxf(hi, gr.p.y)
		var tl := maxf(absf(gr.tilt_want.x), absf(gr.tilt_want.y))
		tilt_max = maxf(tilt_max, tl)
		if tl >= EcoGrot.TILT_MAX - 1e-4:
			capped += PATH_DT
		if gr.stride < 0.2 and t > 5.0:
			slow += PATH_DT
		var xz := Vector2(gr.p.x, gr.p.z)
		for o in objs:
			var d: float = (o[1] as Vector2).distance_to(xz)
			if d < PATH_NEAR and d < near.get(o[0], INF):
				near[o[0]] = d
		var base := Vector3(gr.p.x, gr.body_y, gr.p.z)
		var bs := gr.basis()
		for sys in solids:
			for q in EcoGrot.body_points():
				if sys.solid(base + bs * q):
					var key: String = sys.get_script().get_global_name()
					if not hits.has(key):
						hits[key] = "в (%.0f; %.0f) на %.0f с" % [xz.x, xz.y, t]
					break
		if gr.wp != last_wp:
			last_wp = gr.wp
			visited += 1
			if visited > route.size():
				break
	ev.free()
	lines.append("== круг гротовика %s: длина %.0f м, круг за %.0f с (%.0f с хода на %.2f м/с без поворотов)%s" % [str(route), perim, t, perim / EcoGrot.SPEED, EcoGrot.SPEED, "" if visited > route.size() else " — круг НЕ замкнулся"])
	lines.append("   дно %.1f…%.1f м; наклон панциря до %.2f рад (предел %.2f — %.0f с у предела); шаг ниже 0,2 — %.0f с за круг, поворот до %.2f рад/с" % [lo, hi, tilt_max, EcoGrot.TILT_MAX, capped, slow, turn_max])
	var hl: Array[String] = []
	for k in hits:
		hl.append("%s %s" % [k, hits[k]])
	lines.append("   панцирь и риф задевают твёрдое: %s" % (", ".join(hl) if not hl.is_empty() else "нет"))
	var nl: Array[String] = []
	for k in near:
		nl.append("%s %.1f м" % [k, near[k]])
	nl.sort()
	lines.append("   ближе %.0f м к телу в пути: %s" % [PATH_NEAR, ", ".join(nl) if not nl.is_empty() else "никого"])
	return lines


## "1:80,5;2:-70,-60" → {1: (80, 5), 2: (−70, −60)}.
static func parse_moves(s: String) -> Dictionary:
	var out := {}
	for part in s.split(";", false):
		var kz := part.split(":")
		var xz := kz[1].split(",")
		out[int(kz[0])] = Vector2(float(xz[0]), float(xz[1]))
	return out


## "1,5" → [1, 5].
static func parse_watch(s: String) -> Array[int]:
	var out: Array[int] = []
	for part in s.split(",", false):
		out.append(int(part))
	return out


## "-75,-45,20,76" → Rect2 x −75…−45, z 20…76.
static func parse_band(s: String) -> Rect2:
	var v := s.split(",")
	var x0 := float(v[0])
	var z0 := float(v[2])
	return Rect2(x0, z0, float(v[1]) - x0, float(v[3]) - z0)


## Ближе всего отрезок a–b (x, z) к пути середины PATH[0] → PATH[1], м.
static func to_mid_path(a: Vector2, b: Vector2) -> float:
	var c := Geometry2D.get_closest_points_between_segments(a, b, PATH[0], PATH[1])
	return c[0].distance_to(c[1])


static func ship_at(xz: Vector2) -> Vector3:
	return Vector3(xz.x, Seabed.mesh_height(xz.x, xz.y) + FLOOR, xz.y)


static func make(seed_value: int) -> EcoView:
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	if not moves.is_empty():
		var homes: Array[Vector2] = EcoRaduzh.HOMES.duplicate()
		for k in moves:
			homes[k] = moves[k]
		ev.raduzh._homes = homes
	for k in fish_moves:
		var xz: Vector2 = fish_moves[k]
		ev.fish.home_at[k] = Vector3(xz.x, Seabed.height(xz.x, xz.y) + HOME_LIFT, xz.y)
	ev.preds.probe = probe
	if band0.has_area():
		ev.preds.home_band = {0: {"homes": BAND_HOMES, "rect": band0}}
	ev.world.reset(seed_value)
	if start0.is_finite():
		move_pred(ev.preds.all[0], start0)
	return ev


## Серпохвост pr — со старта xz, как если бы он стоял там в `EcoPred.STARTS` (высота — как в `EcoPred.reset`).
static func move_pred(pr: EcoPred.Pred, xz: Vector2) -> void:
	var p := Vector3(xz.x, minf(Seabed.mesh_height(xz.x, xz.y) + 8.0, EcoPred.GOAL_CEILING), xz.y)
	pr.agent.p = p
	pr.start = p


## Событие шины — угроза в слышимости экипажа: «вид:заметка», иначе "".
static func threat_key(e: EcoBus.Event, ship: Vector3) -> String:
	if e.note in (THREATS.get(e.species, []) as Array) and e.pos.distance_to(ship) <= EcoBus.HEARING:
		return "%s:%s" % [e.species, e.note]
	return ""


## Один проход: {fern_t, flare (стая → {t, d}), betray_mid, betray_01, threat_mid/threat_01 («вид:заметка» → раз),
## pred_mid (ближе всего серпохвост к кораблю в середине, м)}.
static func run(seed_value: int) -> Dictionary:
	var ev := make(seed_value)
	var w := ev.world
	var ship := EcoLink.ShipState.new()
	ship.pos = ship_at(PATH[0])
	ship.light_on = false
	ship.speed = 0.0
	var born: Vector3 = ev.preds.all[0].agent.p
	var t := 0.0
	var goals: Array = []   # цели патруля №0 (x, z) по порядку, с первой после сброса мира
	var path0 := {"near": INF, "hunt": 0.0}  # №0 ближе всего к пути середины (x, z) и секунд охоты на рыб, пока корабль в середине
	var was := {"mode": ev.preds.all[0].mode, "goal": ev.preds.all[0].agent.goal}
	# Цель выбрана патрулем — сменилась, когда №0 и до шага, и после шага в PATROL (цель охоты или «замера»,
	# оставшаяся при возврате в патруль, — не выбор цели).
	var track := func() -> void:
		var pr: EcoPred.Pred = ev.preds.all[0]
		if pr.mode == EcoPred.Mode.PATROL and was["mode"] == EcoPred.Mode.PATROL \
				and (was["goal"] as Vector3).distance_to(pr.agent.goal) > 0.01:
			goals.append(Vector2(pr.agent.goal.x, pr.agent.goal.z))
		was["mode"] = pr.mode
		was["goal"] = pr.agent.goal
	# Стаи watch и погони (`fish=`, `watch=`): весь проход, и в тёмные секунды у 00.
	var spread := {"shoals": {}, "hunt_exit": INF, "hunt_path": INF, "prey": {}, "chases": []}
	var flocks := {}
	for k in watch:
		spread["shoals"][k] = {"far": 0.0, "exit": INF, "path": INF}
		flocks[k] = []
	for f in ev.fish.all:
		if flocks.has(f.shoal.index):
			flocks[f.shoal.index].append(f)
	var open := {}   # серпохвост → идущая погоня на стаю из watch
	var watch_step := func(now: float) -> void:
		for k in flocks:
			var hw: Vector3 = ev.fish.shoals[k].home
			var sd: Dictionary = spread["shoals"][k]
			for f in flocks[k]:
				var q := Vector2(f.agent.p.x, f.agent.p.z)
				sd["far"] = maxf(sd["far"], q.distance_to(Vector2(hw.x, hw.z)))
				sd["exit"] = minf(sd["exit"], q.distance_to(PATH[0]))
				sd["path"] = minf(sd["path"], to_mid_path(q, q))
		for pr in ev.preds.all:
			var q := Vector2(pr.agent.p.x, pr.agent.p.z)
			var on := pr.mode == EcoPred.Mode.HUNT and pr.prey != null and flocks.has(pr.prey.shoal.index)
			var c: Dictionary = open.get(pr.index, {})
			if not c.is_empty() and (not on or c["shoal"] != pr.prey.shoal.index):
				c["t1"] = now
				c["to"] = q
				spread["chases"].append(c)
				open.erase(pr.index)
				c = {}
			if on:
				if c.is_empty():
					c = {"who": pr.index, "shoal": pr.prey.shoal.index, "t0": now, "from": q, "exit": INF, "path": INF}
					open[pr.index] = c
				c["exit"] = minf(c["exit"], q.distance_to(PATH[0]))
				c["path"] = minf(c["path"], to_mid_path(q, q))
			if pr.mode != EcoPred.Mode.HUNT:
				continue
			spread["hunt_exit"] = minf(spread["hunt_exit"], q.distance_to(PATH[0]))
			spread["hunt_path"] = minf(spread["hunt_path"], to_mid_path(q, q))
			if pr.prey != null:
				var who: Dictionary = spread["prey"]
				var key := "№%d→%d" % [pr.index, pr.prey.shoal.index]
				who[key] = who.get(key, 0) + 1
	while t < dark:
		w.ship = ship
		w.step(DT)
		w.take_link()
		t += DT
		track.call()
		watch_step.call(t)
		if ev.preds.all[0].mode == EcoPred.Mode.HUNT:
			path0["hunt"] += DT
		var q := Vector2(ev.preds.all[0].agent.p.x, ev.preds.all[0].agent.p.z)
		path0["near"] = minf(path0["near"], to_mid_path(q, q))
	ship.light_on = true
	ship.light_range = Searchlight.BASE_RANGE
	var mode_lit: String = EcoPred.Mode.keys()[ev.preds.all[0].mode]
	var r := {"mode0_lit": mode_lit, "fern_t": -1.0, "flare": {}, "betray_mid": 0, "betray_01": 0, "threat_mid": {}, "threat_01": {},
		"pred_mid": INF, "answers": 0, "mollusk_t": -1.0, "alert_t": -1.0, "alert_who": -1, "alert_d": 0.0,
		"track0": [], "near0": INF, "near0_t": 0.0, "lit_t": -1.0, "born0": Vector2(born.x, born.z),
		"fish_t": -1.0, "seg_t0": {}, "seg_alert": {}, "seg_open": {}, "seg_moll": {}, "seg_pred": {}, "ambush": [], "gz_last": -INF, "gz_quiet": 0.0}
	for sg in SEGS:
		r["threat_" + sg] = r.get("threat_" + sg, {})
		r["betray_" + sg] = r.get("betray_" + sg, 0)
	var at := {"seg": "mid"}   # участок, на котором сейчас корабль
	r["seg_t0"]["mid"] = 0.0
	var heard: Array = []   # [«вид:заметка», расстояние до корабля] за шаг
	var listen := func(e: EcoBus.Event) -> void:
		if e.species == EcoFern.ID and e.note == "mollusk" and r["fish_t"] < 0.0 \
				and Vector2(e.pos.x, e.pos.z).distance_to(EcoFern.ROUTE_CLUSTER) < 6.0:
			r["fish_t"] = w.time - dark
		if e.species == EcoFern.ID and e.note == "mollusk" and not r["seg_moll"].has(at["seg"]) \
				and Vector2(e.pos.x, e.pos.z).distance_to(EcoFern.ROUTE_CLUSTER) < 6.0:
			r["seg_moll"][at["seg"]] = w.time - dark - r["seg_t0"][at["seg"]]
		var k := threat_key(e, w.ship.pos)
		if k == "glazun:ambush":
			var an := ambush_note(ev, e, at["seg"], w.time - dark - r["seg_t0"][at["seg"]])
			an["line"] = line_shown(r, w.time)
			r["ambush"].append(an)
		if k != "":
			heard.append([k, e.pos.distance_to(w.ship.pos)])
	w.bus.emitted.connect(listen)
	# Ноги прохода: куда, сколько стоять там, участок. Без repeat — как раньше: стоянка у середины, затем к 01.
	var legs: Array = [[PATH[1], STOP, "mid"], [PATH[2], 0.0, "01"]]
	if repeat:
		legs = [[PATH[1], STOP, "mid"], [PATH[2], STOP, "01"], [PATH[1], 0.0, "back"], [PATH[0], STOP, "back"],
			[PATH[1], STOP, "mid2"], [PATH[2], 0.0, "012"]]
	var leg := 0
	var stop: float = legs[0][1]
	var cue := -1.0     # когда экипаж услышал «замер» (ответ через delay)
	var hushed := -1.0  # с какого времени стоит без света и хода
	var mid := true
	var lit := {}
	while leg < legs.size() and t < dark + pass_limit(r["answers"]):
		var tg: Vector2 = legs[leg][0]
		if legs[leg][2] != at["seg"]:
			at["seg"] = legs[leg][2]
			r["seg_t0"][at["seg"]] = t - dark
		mid = at["seg"] == "mid"
		var d := Vector2(tg.x - ship.pos.x, tg.y - ship.pos.z)
		if cue >= 0.0 and t - cue >= delay - DT * 0.5:
			cue = -1.0
			hushed = t
			r["answers"] += 1
		if hushed >= 0.0 and t - hushed >= hold:
			hushed = -1.0
		ship.light_on = hushed < 0.0
		if hushed >= 0.0:
			ship.speed = 0.0
		elif d.length() < 0.5 and stop > 0.0:
			stop -= DT
			ship.speed = 0.0
		elif d.length() < 0.5:
			leg += 1
			if leg < legs.size():
				stop = legs[leg][1]
			continue
		else:
			ship.yaw = atan2(-d.x, -d.y)
			ship.speed = SPEED
			var mv := d.normalized() * minf(SPEED * DT, d.length())
			ship.pos = ship_at(Vector2(ship.pos.x + mv.x, ship.pos.z + mv.y))
		w.ship = ship
		heard.clear()
		w.step(DT)
		t += DT
		var sg: String = at["seg"]
		var got: Dictionary = r["threat_" + sg]
		for e in w.take_link():
			if e["type"] == EcoLink.OBSERVE and e.get("species", "") == EcoRaduzh.ID and e.get("note", "") == "betray":
				r["betray_" + sg] += 1
			elif e["type"] == EcoLink.HIT or e["type"] == EcoLink.DRAIN:
				heard.append(["%s:%s" % [e["by"], e["type"]], 0.0])
		track.call()
		watch_step.call(t)
		var p0: EcoPred.Pred = ev.preds.all[0]
		var d0 := p0.agent.p.distance_to(ship.pos)
		if mid:
			if p0.mode == EcoPred.Mode.HUNT:
				path0["hunt"] += DT
			var q0 := Vector2(p0.agent.p.x, p0.agent.p.z)
			path0["near"] = minf(path0["near"], to_mid_path(q0, q0))
		if d0 < r["near0"]:
			r["near0"] = d0
			r["near0_t"] = t - dark
		if t - dark <= TRACK_FOR + DT * 0.5 and (r["track0"] as Array).size() < int((t - dark) / TRACK_EVERY + 1e-4) + 1:
			(r["track0"] as Array).append([Vector2(p0.agent.p.x, p0.agent.p.z), d0])
		for pr in ev.preds.all:
			var dp := pr.agent.p.distance_to(ship.pos)
			if pr.mode == EcoPred.Mode.ALERT and r["alert_t"] < 0.0:
				r["alert_t"] = t - dark
				r["alert_who"] = pr.index
				r["alert_d"] = dp
			if pr.mode == EcoPred.Mode.ALERT and not r["seg_alert"].has(sg):
				r["seg_alert"][sg] = t - dark - r["seg_t0"][sg]
			r["seg_pred"][sg] = minf(r["seg_pred"].get(sg, INF), dp)
			if pr.mode == EcoPred.Mode.ALERT or pr.mode == EcoPred.Mode.CHARGE:
				heard.append(["pred%d:%s" % [pr.index, EcoPred.Mode.keys()[pr.mode].to_lower()], dp])
			if mid:
				r["pred_mid"] = minf(r["pred_mid"], dp)
		for h in heard:
			if answer and h[0] == "pred:alert" and cue < 0.0 and hushed < 0.0:
				cue = t
			if not got.has(h[0]):
				got[h[0]] = {"n": 0, "t": t - dark, "d": h[1]}
			got[h[0]]["n"] += 1
		if not r["seg_open"].has(sg):
			for fe in ev.ferns.ferns:
				if fe.open > EcoFern.FEED_OPEN and Vector2(fe.pos.x, fe.pos.z).distance_to(EcoFern.ROUTE_CLUSTER) < 6.0:
					r["seg_open"][sg] = t - dark - r["seg_t0"][sg]
					break
		if r["fern_t"] < 0.0:
			for fe in ev.ferns.ferns:
				if Vector2(fe.pos.x, fe.pos.z).distance_to(EcoFern.ROUTE_CLUSTER) >= 6.0:
					continue
				if fe.lit and r["lit_t"] < 0.0:
					r["lit_t"] = t - dark
				if fe.open > EcoFern.FEED_OPEN:
					r["fern_t"] = t - dark
					r["mollusk_t"] = t - dark   # раскрыт на FEED_OPEN — моллюски под листьями видны
		if mid:
			for sw in ev.raduzh.swarms:
				if sw.glow > EcoRaduzh.FLARE_ON and not lit.has(sw.index):
					lit[sw.index] = {"t": t - dark, "d": sw.c.distance_to(ship.pos)}
	r["flare"] = lit
	r["goals0"] = goals
	r["path0"] = path0["near"]
	r["hunt0"] = path0["hunt"]
	for k in open:
		var c: Dictionary = open[k]
		var pe: Vector3 = ev.preds.all[k].agent.p
		c["t1"] = t
		c["to"] = Vector2(pe.x, pe.z)
		spread["chases"].append(c)
	r["spread"] = spread
	w.bus.emitted.disconnect(listen)
	ev.free()
	return r


## Засада глазуна в слышимости (`repeat=1`, уровни и ГД 14.11): участок и время от его начала, глазун и где он, где
## корабль (x, z), расстояние, свет и ход, ближайший серпохвост к глазуну (номер, режим, м), живых монетников в стайке.
static func ambush_note(ev: EcoView, e: EcoBus.Event, seg: String, t: float) -> Dictionary:
	var gi := -1
	var gd := INF
	for gz in ev.coins.glazuns:
		var dd := gz.pos.distance_to(e.pos)
		if dd < gd:
			gd = dd
			gi = gz.index
	var alive := -1
	for sc in ev.coins.schools:
		if sc.glazun != null and sc.glazun.index == gi:
			alive = sc.alive_count()
	var pn := {"who": -1, "mode": "", "d": INF}
	for pr in ev.preds.all:
		var dp := pr.agent.p.distance_to(e.pos)
		if dp < pn["d"]:
			pn = {"who": pr.index, "mode": EcoPred.Mode.keys()[pr.mode].to_lower(), "d": dp}
	var sh: EcoLink.ShipState = ev.world.ship
	return {"seg": seg, "t": t, "gz": gi, "at": Vector2(e.pos.x, e.pos.z), "ship": Vector2(sh.pos.x, sh.pos.z),
		"d": e.pos.distance_to(sh.pos), "light": sh.light_on, "speed": sh.speed, "pred": pn, "coins": alive}


## Строка засады на приборах (`EcoWorld.repeat`, ONCE): услышанная засада идёт с текстом, только если прежняя
## услышанная была не ближе ONCE_GAP с (любой глазун: ключ «вид:заметка» один); отметку двигает каждая услышанная, не
## только показанная. Время — мира (`r["gz_last"]`); самая долгая тишина между услышанными — `r["gz_quiet"]` (короче
## ONCE_GAP — эпизод не кончается и строка не возвращается).
static func line_shown(r: Dictionary, time: float) -> bool:
	var was: float = r["gz_last"]
	r["gz_last"] = time
	if is_finite(was):
		r["gz_quiet"] = maxf(r.get("gz_quiet", 0.0), time - was)
	return time - was >= EcoWorld.ONCE_GAP


static func ambush_line(a: Dictionary) -> String:
	var pn: Dictionary = a["pred"]
	return ("СТРОКА " if a.get("line", false) else "") + "%s %.1f с: глазун %d (%.0f; %.0f), корабль (%.0f; %.0f) в %.0f м, %s, %s; серпохвост №%d %s в %.0f м; монетников %d" \
		% [a["seg"], a["t"], a["gz"], a["at"].x, a["at"].y, a["ship"].x, a["ship"].y, a["d"],
		"свет" if a["light"] else "без света", "ход" if a["speed"] > 0.0 else "стоит", pn["who"], pn["mode"], pn["d"], a["coins"]]


## Строка участков зерна (`repeat=1`): по участку — от его начала волнолист у прохода раскрыт на FEED_OPEN (моллюски
## видны, как `mollusk_t`), рыбы приплыли к моллюскам (`EcoFern` "mollusk"), первый серпохвост в «замере» (0,0 — «замер»
## шёл уже на прежнем участке), серпохвост ближе всего, угрозы.
static func seg_line(r: Dictionary) -> String:
	var parts: Array[String] = []
	for sg in SEGS:
		if not r["seg_t0"].has(sg):
			parts.append("%s — не дошёл" % sg)
			continue
		var bits: Array[String] = ["с %.0f с" % r["seg_t0"][sg]]
		if r["seg_open"].has(sg):
			bits.append("волнолист %.1f" % r["seg_open"][sg])
		if r["seg_moll"].has(sg):
			bits.append("рыбы к моллюскам %.1f" % r["seg_moll"][sg])
		if r["seg_alert"].has(sg):
			bits.append("«замер» %.1f" % r["seg_alert"][sg])   # 0,0 — «замер» шёл уже на прежнем участке
		bits.append("серпохвост ≥ %.0f м" % r["seg_pred"].get(sg, INF))
		var got: Dictionary = r["threat_" + sg]
		if not got.is_empty():
			bits.append(_keys(got))
		parts.append("%s: %s" % [sg, " ".join(bits)])
	return "; ".join(parts)


static func report(seeds: int) -> Array[String]:
	var lines: Array[String] = []
	var homes: Array[Vector2] = EcoRaduzh.HOMES.duplicate()
	for k in moves:
		homes[k] = moves[k]
	var band := ("цели №0 у стай %s — x %.0f…%.0f, z %.0f…%.0f" % [str(BAND_HOMES), band0.position.x, band0.end.x, band0.position.y, band0.end.y]) if band0.has_area() else "цели №0 как в игре"
	var fh: Array[Vector3] = EcoFish.HOMES.duplicate()
	for k in fish_moves:
		fh[k] = Vector3(fish_moves[k].x, 0.0, fish_moves[k].y)
	put(lines, "== дома радужников %s, старт серпохвоста №0 %s, %s, тихий круг серпохвоста %s, ответ экипажа %s, %d зёрен, путь %s, стоянка %.0f с у середины%s" % [str(homes), str(start0 if start0.is_finite() else EcoPred.STARTS[0]), band, "вкл" if probe else "выкл", ("через %.1f с, %.0f с без света" % [delay, hold]) if answer else "нет", seeds, str(PATH), STOP, (", повтор 00→01→00→01, предел %.0f с + %.0f с на ответ" % [limit, hold if answer else 0.0]) if repeat else ""])
	for k in watch:
		if k == EcoGrot.RIDERS:
			put(lines, "== стая светляков %d — на спине гротовика, дом идёт с ним по кругу %s (%s; fish=%d не действует), тёмная стоянка %.0f с" % [k, str(EcoGrot.route), "EcoGrot.ROUTE" if EcoGrot.route == EcoGrot.ROUTE else "проба grot=", k, dark])
		else:
			put(lines, "== дом стаи светляков %d (%.0f; %.0f), тёмная стоянка %.0f с" % [k, fh[k].x, fh[k].z, dark])
	if sites:
		for k in watch:
			if k == EcoGrot.RIDERS:
				for q in EcoGrot.route:
					put(lines, site_line("точка круга гротовика (стая %d)" % k, q))
			elif not fish_moves.has(k):
				put(lines, site_line("дом стаи %d" % k, Vector2(fh[k].x, fh[k].z)))
		for b in EcoCoral.BASES:
			put(lines, site_line("риф", b))
	for k in fish_moves:
		put(lines, site_line("перенос стаи %d" % k, fish_moves[k]))
		put(lines, site_line("прежний дом стаи %d" % k, Vector2(EcoFish.HOMES[k].x, EcoFish.HOMES[k].z)))
	var order := {"done": 0, "mollusk": [], "alert": [], "near0": [], "goal": [], "seg": [], "path0": []}
	var sp := {"shoals": {}, "hunt_exit": [], "hunt_path": [], "prey": {}, "exit20": 0}
	for k in watch:
		sp["shoals"][k] = {"far": [], "exit": [], "path": [], "n": 0, "seeds": 0, "exit20": 0, "path20": 0}
	var fern := 0
	var flared := {}
	var betray_mid := 0
	var betray_01 := 0
	var threats_mid := {}
	var threats_01 := {}
	var pred_near := INF
	var segs := {}
	var quiet: Array = []   # самая долгая тишина между засадами в слышимости, по зёрнам
	var second := 0   # зёрен со строкой засады во втором проходе (mid2, 012)
	for sg in SEGS:
		segs[sg] = {"n": 0, "threats": {}, "alert": [], "moll_first": 0, "pred": [], "ambush": 0, "lines": 0, "line_seeds": 0}
	for s in seeds:
		var r := run(20261018 + s * 7919)
		var parts: Array[String] = []
		if r["fern_t"] >= 0.0:
			fern += 1
			parts.append("волнолист раскрыт на %.1f с" % r["fern_t"])
		else:
			parts.append("волнолист у прохода не раскрылся")
		for k in r["flare"]:
			flared[k] = flared.get(k, 0) + 1
			parts.append("стая %d вспыхнула на %.1f с в %.0f м" % [k, r["flare"][k]["t"], r["flare"][k]["d"]])
		if r["betray_mid"] > 0:
			betray_mid += 1
			parts.append("зов хищника в середине ×%d" % r["betray_mid"])
		if r["betray_01"] > 0:
			betray_01 += 1
		for side in ["mid", "01"]:
			var got: Dictionary = r["threat_" + side]
			var tot: Dictionary = threats_mid if side == "mid" else threats_01
			if not got.is_empty():
				parts.append("угрозы %s: %s" % ["в середине" if side == "mid" else "у 01", _keys(got)])
			for k in got:
				tot[k] = tot.get(k, 0) + 1
		pred_near = minf(pred_near, r["pred_mid"])
		if r["answers"] > 0:
			parts.append("ответов %d" % r["answers"])
		parts.append(chain_line(r))
		var gs := goal_stats(r)
		parts.append(goal_line(gs))
		var rs: Dictionary = r["spread"]
		parts.append(spread_line(rs))
		for k in ["hunt_exit", "hunt_path"]:
			if is_finite(rs[k]):
				sp[k].append(rs[k])
		for k in watch:
			var sd: Dictionary = rs["shoals"][k]
			var acc: Dictionary = sp["shoals"][k]
			for key in ["far", "exit", "path"]:
				if is_finite(sd[key]):
					acc[key].append(sd[key])
			var mine := (rs["chases"] as Array).filter(func(c: Dictionary) -> bool: return c["shoal"] == k)
			acc["n"] += mine.size()
			if not mine.is_empty():
				acc["seeds"] += 1
			if mine.any(func(c: Dictionary) -> bool: return c["exit"] < EXIT_NEAR):
				acc["exit20"] += 1
			if mine.any(func(c: Dictionary) -> bool: return c["path"] < EXIT_NEAR):
				acc["path20"] += 1
		if not (rs["chases"] as Array).is_empty():
			parts.append("погони на стаи %s: %s" % [str(watch), chases_line(rs["chases"])])
		if rs["hunt_exit"] < EXIT_NEAR:
			sp["exit20"] += 1
		for k in rs["prey"]:
			sp["prey"][k] = sp["prey"].get(k, 0) + 1
		order["goal"].append(gs["goal"])
		order["seg"].append(gs["seg"])
		order["path0"].append(r["path0"])
		if chain_done(r):
			order["done"] += 1
		if r["mollusk_t"] >= 0.0:
			order["mollusk"].append(r["mollusk_t"])
		if r["alert_t"] >= 0.0:
			order["alert"].append(r["alert_t"])
		order["near0"].append(r["near0"])
		put(lines, "  зерно %d: %s" % [s, ", ".join(parts)])
		if repeat:
			put(lines, "    участки: " + seg_line(r))
			for a in r["ambush"]:
				put(lines, "    засада " + ambush_line(a))
			var amb: Array = r["ambush"]
			var with_line := amb.filter(func(a: Dictionary) -> bool: return a.get("line", false))
			put(lines, "    засад в слышимости %d, со строкой %d; самая долгая тишина между ними %.1f с (ONCE_GAP %.0f с)" \
				% [amb.size(), with_line.size(), r["gz_quiet"], EcoWorld.ONCE_GAP])
			quiet.append(r["gz_quiet"])
			if with_line.any(func(a: Dictionary) -> bool: return a["seg"] in ["mid2", "012"]):
				second += 1
			for sg in SEGS:
				var acc: Dictionary = segs[sg]
				if not r["seg_t0"].has(sg):
					continue
				acc["n"] += 1
				var got: Dictionary = r["threat_" + sg]
				for k in got:
					acc["threats"][k] = acc["threats"].get(k, 0) + 1
				if r["seg_alert"].has(sg):
					acc["alert"].append(r["seg_alert"][sg])
				if r["seg_open"].has(sg) and (not r["seg_alert"].has(sg) or r["seg_open"][sg] < r["seg_alert"][sg]):
					acc["moll_first"] += 1
				acc["pred"].append(r["seg_pred"].get(sg, INF))
				var here := (r["ambush"] as Array).filter(func(a: Dictionary) -> bool: return a["seg"] == sg)
				acc["ambush"] += here.size()
				var shown := here.filter(func(a: Dictionary) -> bool: return a.get("line", false)).size()
				acc["lines"] += shown
				acc["line_seeds"] += 1 if shown > 0 else 0
	var fl: Array[String] = []
	for k in homes.size():
		fl.append("стая %d — %d/%d" % [k, flared.get(k, 0), seeds])
	put(lines, "итог: волнолист %d/%d; вспышки в середине: %s; зов хищника вспышкой в середине %d/%d, на подходе к 01 %d/%d" \
		% [fern, seeds, ", ".join(fl), betray_mid, seeds, betray_01, seeds])
	put(lines, "угрозы в середине (зёрен из %d): %s; серпохвост ближе всего %.0f м" \
		% [seeds, _keys(threats_mid) if not threats_mid.is_empty() else "нет", pred_near])
	put(lines, "угрозы на подходе к 01 (зёрен из %d): %s" % [seeds, _keys(threats_01) if not threats_01.is_empty() else "нет"])
	put(lines, "порядок: моллюски до первого «замера» %d/%d; реакция моллюсков %s; первый «замер» %s; №0 ближе всего (медиана) %.0f м" \
		% [order["done"], seeds, _spread(order["mollusk"], seeds), _spread(order["alert"], seeds), _median(order["near0"])])
	put(lines, "путь середины %s → %s: ближе всего цель №0 %s; отрезок между целями %s; сам №0, пока корабль в середине, %s" \
		% [str(PATH[0]), str(PATH[1]), _metres(order["goal"]), _metres(order["seg"]), _metres(order["path0"])])
	for k in watch:
		var acc: Dictionary = sp["shoals"][k]
		put(lines, "стая %d: дальше всего от дома %s; ближе всего к выходу 00 %s, к пути середины %s; погонь на неё %d в %d/%d зёрнах, ближе %.0f м к выходу 00 — %d/%d зёрен, к пути середины — %d/%d" \
			% [k, _metres_max(acc["far"]), _metres(acc["exit"]), _metres(acc["path"]), acc["n"], acc["seeds"], seeds,
			EXIT_NEAR, acc["exit20"], seeds, acc["path20"], seeds])
	if repeat:
		for sg in SEGS:
			var acc: Dictionary = segs[sg]
			put(lines, "участок %s (прошли %d/%d): моллюски раньше «замера» %d/%d; первый «замер» от начала участка %s; серпохвост ближе всего %s; засад глазуна в слышимости %d, со строкой %d (в %d/%d зёрнах); угрозы (зёрен): %s" \
				% [sg, acc["n"], seeds, acc["moll_first"], acc["n"], _spread(acc["alert"], acc["n"]), _metres(acc["pred"]),
				acc["ambush"], acc["lines"], acc["line_seeds"], acc["n"], _keys(acc["threats"]) if not acc["threats"].is_empty() else "нет"])
	if repeat:
		put(lines, "строка засады во втором проходе (mid2, 012): %d/%d зёрен; самая долгая тишина между засадами в слышимости %s (ONCE_GAP %.0f с)" \
			% [second, seeds, _spread(quiet, seeds), EcoWorld.ONCE_GAP])
	put(lines, "погони (HUNT, все серпохвосты): ближе всего к выходу 00 %s (ближе %.0f м — %d/%d зёрен), к пути середины %s; кто → стая (зёрен): %s" \
		% [_metres(sp["hunt_exit"]), EXIT_NEAR, sp["exit20"], seeds, _metres(sp["hunt_path"]), _keys(sp["prey"]) if not sp["prey"].is_empty() else "погонь нет"])
	return lines


## Среда у дома (уровни, #1400, 12.11: «проверить грунт/кораллы и свободный объём стаи»): глубина дна, вода до льда,
## уклон и грунт [песок, ил, галька] (`Seabed.Ground.weights`), ближайший куст огнецвета (`EcoCoral.BASES`) и что из
## живого мира стоит ближе SITE_R м (объекты систем с полем pos — счёт по системам, мир зерна 20261018).
const SITE_R := 25.0
static func site_line(label: String, xz: Vector2) -> String:
	var y := Seabed.mesh_height(xz.x, xz.y)
	var e := 1.0
	var n := Vector3(Seabed.mesh_height(xz.x - e, xz.y) - Seabed.mesh_height(xz.x + e, xz.y), 2.0 * e,
		Seabed.mesh_height(xz.x, xz.y - e) - Seabed.mesh_height(xz.x, xz.y + e)).normalized()
	var w: Array = Seabed.Ground.weights(xz.x, xz.y, n.y, -y)
	var bush := INF
	for b in EcoCoral.BASES:
		bush = minf(bush, b.distance_to(xz))
	var rough := 0.0   # перепад дна в круге 15 м, м
	for k in 16:
		var a := TAU * k / 16.0
		var q := xz + Vector2(cos(a), sin(a)) * 15.0
		rough = maxf(rough, absf(Seabed.mesh_height(q.x, q.y) - y))
	var ev := EcoView.new()
	ev.ground = Seabed.mesh_height
	ev.world.reset(20261018)
	var near := {}
	for sys in ev.world.systems:
		for prop in sys.get_property_list():
			if prop["type"] != TYPE_ARRAY:
				continue
			var arr = sys.get(prop["name"])
			if not (arr is Array):
				continue
			for it in arr:
				if not (it is Object) or not ("pos" in it):
					continue
				var pv = it.get("pos")
				var q2: Vector2 = Vector2(pv.x, pv.z) if pv is Vector3 else (pv as Vector2 if pv is Vector2 else Vector2.INF)
				if q2.distance_to(xz) < SITE_R:
					var key := "%s.%s" % [sys.get_script().get_global_name(), prop["name"]]
					near[key] = near.get(key, 0) + 1
	ev.free()
	return "== %s (%.0f; %.0f): дно %.1f м, уклон %.2f, перепад в 15 м %.1f м, грунт песок %.2f / ил %.2f / галька %.2f, огнецвет в %.0f м; ближе %.0f м: %s" \
		% [label, xz.x, xz.y, y, 1.0 - n.y, rough, w[0], w[1], w[2], bush, SITE_R, _keys(near) if not near.is_empty() else "ничего"]


## Погоня ближе EXIT_NEAR м к выходу 00 — «охота через выход» в итоге.
const EXIT_NEAR := 20.0


## «стая 0: до 22 м от дома, к выходу 00 9 м, к пути середины 12 м; погони: к выходу 4 м, к пути 3 м (№0→0 ×120)».
static func spread_line(rs: Dictionary) -> String:
	var sh: Array[String] = []
	for k in rs["shoals"]:
		var sd: Dictionary = rs["shoals"][k]
		sh.append("стая %d: до %.0f м от дома, к выходу 00 %.0f м, к пути середины %.0f м" % [k, sd["far"], sd["exit"], sd["path"]])
	return "%s; погони: к выходу %s, к пути %s (кадров погони: %s)" \
		% ["; ".join(sh), ("%.0f м" % rs["hunt_exit"]) if is_finite(rs["hunt_exit"]) else "нет",
		("%.0f м" % rs["hunt_path"]) if is_finite(rs["hunt_path"]) else "нет", _keys(rs["prey"]) if not rs["prey"].is_empty() else "погонь нет"]


## Погони на стаи watch: «№1→5 −12…4 с (60; 40)→(70; 52), к выходу 00 70 м, к пути середины 45 м» (время — от света).
static func chases_line(chases: Array) -> String:
	var out: Array[String] = []
	for c in chases:
		out.append("№%d→%d %.0f…%.0f с (%.0f; %.0f)→(%.0f; %.0f), к выходу 00 %.0f м, к пути середины %.0f м" % [c["who"],
			c["shoal"], c["t0"] - dark, c["t1"] - dark, c["from"].x, c["from"].y, c["to"].x, c["to"].y, c["exit"], c["path"]])
	return "; ".join(out)


## «макс 30 м, медиана 22 м» по зёрнам.
static func _metres_max(v: Array) -> String:
	var s := v.duplicate()
	s.sort()
	return "макс %.0f м, медиана %.0f м" % [s[-1], _median(s)] if not s.is_empty() else "нет"


## «мин 12 м, медиана 40 м» по зёрнам.
static func _metres(v: Array) -> String:
	var s := v.duplicate()
	s.sort()
	return "мин %.0f м, медиана %.0f м" % [s[0], _median(s)] if not s.is_empty() else "нет"


## Цели патруля №0 прохода r против пути середины: {n, band (в полосе band0), goal, seg — ближе всего цель и отрезок
## между соседними целями к пути PATH[0] → PATH[1], м; seg_at — номер цели, с которой начинается ближний отрезок}.
static func goal_stats(r: Dictionary) -> Dictionary:
	var gl: Array = r["goals0"]
	var out := {"n": gl.size(), "band": 0, "goal": INF, "seg": INF, "seg_at": -1}
	for k in gl.size():
		var g: Vector2 = gl[k]
		if band0.has_area() and band0.grow(0.01).has_point(g):
			out["band"] += 1
		out["goal"] = minf(out["goal"], to_mid_path(g, g))
		if k > 0:
			var d := to_mid_path(gl[k - 1], g)
			if d < out["seg"]:
				out["seg"] = d
				out["seg_at"] = k - 1
	return out


## «цели №0: 9 (в полосе 4), ближе к пути середины: цель 51 м, отрезок 3 м (цели 2→3), сам №0 18 м».
static func goal_line(gs: Dictionary) -> String:
	var seg := ("отрезок %.0f м (цели %d→%d)" % [gs["seg"], gs["seg_at"], gs["seg_at"] + 1]) if gs["seg_at"] >= 0 else "отрезков нет"
	return "цели №0: %d (в полосе %d), ближе к пути середины: цель %.0f м, %s" % [gs["n"], gs["band"], gs["goal"], seg]


## Наблюдение цепочки закончено до вынужденного ответа: моллюски показались, а «замера» не было или он позже.
static func chain_done(r: Dictionary) -> bool:
	return r["mollusk_t"] >= 0.0 and (r["alert_t"] < 0.0 or r["mollusk_t"] < r["alert_t"])


## «свет 0 → луч на волнолисте 2,0 с → моллюски видны 3,1 с (рыбы нет) → замер №0 12,0 с в 30 м; путь №0: старт
## (−60; 20), 0 с (−18; 13) 70 м, …; №0 ближе всего 4 м на 20,1 с».
static func chain_line(r: Dictionary) -> String:
	var t := "свет 0 → луч на волнолисте %s → моллюски видны %s (рыбы %s) → замер %s" % [_t(r["lit_t"]),
		_t(r["mollusk_t"]), _t(r["fish_t"]),
		("№%d %.1f с в %.0f м" % [r["alert_who"], r["alert_t"], r["alert_d"]]) if r["alert_t"] >= 0.0 else "нет"]
	var tr: Array[String] = ["старт (%.0f; %.0f)" % [r["born0"].x, r["born0"].y]]
	for k in (r["track0"] as Array).size():
		var pt: Array = r["track0"][k]
		tr.append("%d с (%.0f; %.0f) %.0f м" % [roundi(k * TRACK_EVERY), pt[0].x, pt[0].y, pt[1]])
	return t + "; путь №0 (при свете — %s): " % r.get("mode0_lit", "?") + ", ".join(tr) \
		+ "; №0 ближе всего %.0f м на %.1f с, к пути середины %.0f м, охота на рыб %.0f с" % [r["near0"], r["near0_t"], r.get("path0", INF), r.get("hunt0", 0.0)]


static func _t(v: float) -> String:
	return "%.1f с" % v if v >= 0.0 else "нет"


## «в 12/16, 3,1–9,8 с, медиана 5,2 с».
static func _spread(v: Array, seeds: int) -> String:
	if v.is_empty():
		return "в 0/%d" % seeds
	var s := v.duplicate()
	s.sort()
	return "в %d/%d, %.1f–%.1f с, медиана %.1f с" % [s.size(), seeds, s[0], s[-1], _median(s)]


static func _median(v: Array) -> float:
	if v.is_empty():
		return INF
	var s := v.duplicate()
	s.sort()
	var m := s.size() / 2
	return float(s[m]) if s.size() % 2 == 1 else (float(s[m - 1]) + float(s[m])) * 0.5


## {ключ → раз} или {ключ → {n, t, d}} строкой: «ключ ×n» или «ключ ×n с t с в d м» (для режима — кадров).
static func _keys(d: Dictionary) -> String:
	var out: Array[String] = []
	for k in d:
		var v = d[k]
		if v is Dictionary:
			out.append("%s ×%d с %.1f с в %.0f м" % [k, v["n"], v["t"], v["d"]])
		else:
			out.append("%s ×%d" % [k, v])
	return ", ".join(out)
