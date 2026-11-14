extends RefCounted
## Подготовка сцены к снимку для tools/shot.gd (и сценовых тестов): ключи командной строки → состояние игры
## (сесть за штурвал, провести корабль, пробоина, товарищи, графика…). Описание ключей — в шапке tools/shot.gd.
## Раньше жило в Main.debug_setup; вынесено, чтобы отладка не раздувала main.gd и не шла в APK (tools/ не
## экспортируется).

## Плавный ход сцены 00 → 01 (scena=, #1400) — из расчёта прохода.
const PassBox := preload("res://tools/pass_box.gd")
const PassPlan := preload("res://tools/pass_plan.gd")


## Аргументы после «--»: имя файла, ключи «ключ=значение» и флаги Godot, попавшие сюда по ошибке («--resolution
## 1280x720» после «--» молча снимал 1600×720 в файл «1280x720», #1350 12.11). Флаг «--…» и его значение без «=» —
## в "stray", не в имя файла.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var out := "shot.png"
	var kv := {}
	var stray: Array[String] = []
	var flag := false   # прошлый аргумент — флаг «--…» без «=»: следующий без «=» — его значение
	for a in args:
		if a.begins_with("--"):
			stray.append(a)
			flag = not a.contains("=")
		elif flag and not a.contains("="):
			stray[-1] += " " + a
			flag = false
		elif a.contains("="):
			var p := a.split("=", true, 1)
			kv[p[0]] = p[1]
			flag = false
		else:
			out = a
	return {"out": out, "kv": kv, "stray": stray}


static func apply(g: Main, kv: Dictionary) -> void:
	g.flyby.stop()   # снимки — с мостика; flyby=start|surface — вид с борта (age=<с> от начала)
	g.message.clear(Flyby.START_MSG)
	if kv.get("pilot", "0") == "1":
		g.sit_at_helm()
	if kv.get("light", "1") == "0":
		g.toggle_light()
	if kv.get("power", "0") == "1":  # у пульта энергии
		g.walker.x = -3.9
		g.walker.z = -2.0
		g.open_power()
	if kv.get("ping", "0") == "1":  # импульс сонара с тремя пробными отметками (живого мира ещё нет)
		g.sonar.ping(g.time, 1.0)
		g.sonar.take_contacts([
			EcoLink.near("serpohvost", "серпохвост", g.helm.pos + Vector3(35, 0, -40), g.helm.pos),
			EcoLink.near("svetlyak", "светляк", g.helm.pos + Vector3(-50, 0, -20), g.helm.pos),
			EcoLink.near("veil", "вуаль", g.helm.pos + Vector3(10, 0, 60), g.helm.pos)], g.helm.pos)
		g.time += float(kv.get("age", "1.0"))
		g.sonar_view.show_state(g.sonar, g.helm.pos, g.helm.yaw, g.time, true)
	if kv.get("zap", "0") == "1":  # разряд: рычаг внизу, шкала готовности погашена
		g.fire_zap()
	if kv.get("lock", "0") == "1":  # открытый шлюз трюма
		g.airlock.open = true
		g.airlock.t = 1.0
		g.rooms.apply(g.layout, g.reactor, g.airlock)
		if kv.has("lock_event"):  # lock_event=enter|exit — кольца от троса / всплеск захвата ART-073, lock_age=<с>
			var exit: bool = kv["lock_event"] == "exit"
			g.lock_water._event(LockWater.Kind.EXIT if exit else LockWater.Kind.ENTER, 1.0, LockWater.CENTER)
			g.lock_water.event_age = float(kv.get("lock_age", "0.36"))
	if kv.has("mate"):  # mate=x,z,курс°[,роль 0…3[,внешность 0…1]] — ещё один член экипажа стоит на палубе; mate=helm — сидит за штурвалом, mate=energy — инженер у пульта
		if kv["mate"] == "helm":
			g.add_mate(0.0, Deck.SEAT_Z, 0.0, Crew.Role.SONAR, 0, true)
		elif kv["mate"] == "energy":   # инженер у пульта энергии (метка «Занято»)
			var e := g.add_mate(Main.POWER_STAND.x, Main.POWER_STAND.y, PI * 0.5, Crew.Role.ENGINEER, 0)
			e.at_power = true
			e.sync_post()
		else:  # несколько — через «;»
			for one: String in kv["mate"].split(";"):
				var m: PackedFloat64Array = one.split_floats(",")
				g.add_mate(m[0], m[1], deg_to_rad(m[2]) if m.size() > 2 else 0.0, int(m[3]) if m.size() > 3 else Crew.Role.SONAR,
					int(m[4]) if m.size() > 4 else 1)
		if kv.has("tag"):  # tag=a;l;- — состояния табличек товарищей по порядку (ART-033): a — нажимает, l — нет связи
			var st: PackedStringArray = kv["tag"].split(";")
			for k in mini(st.size(), g.crew.size() - 1):
				var mm: Crew.Member = g.crew[k + 1]
				mm.press = -1e3 if st[k] == "a" else INF   # на время снимка
				mm.lost = st[k] == "l"
		if kv.get("gone", "0") == "1":  # gone=1 — последний товарищ отключился: у хоста плашка ART-043
			g.mate_gone(g.crew[-1])
	if kv.get("silt", "0") == "1":  # silt=1 — корабль в облаке ила (снимок сонарной тьмы); с ping=1 — импульс завяз
		g.open_silt()   # (jam_age=<с> — сколько прошло с завязшего импульса, ART-048)
		if kv.get("ping", "0") == "1":
			g.sonar.ping(g.time, 1.0, true)
			g.silt.jam_ping(g.time)
			g.time += float(kv.get("jam_age", "0.4"))
	if kv.has("hot"):  # hot=1 — перегрев (для снимка табло)
		g.reactor.start_hot(false)
		g.reactor.heat = float(kv["hot"])
	if kv.has("hull"):  # hull=<%> — прочность корпуса (следы повреждений ART-049 снаружи, износ внутри ART-074)
		g.vitals.hull = float(kv["hull"])
		g.wear.snap(g.vitals.hull)
	if kv.get("relief", "1") == "0":  # relief=0 — уровень «Экономно» ART-044 (рельеф ART-053…056, частицы, пост)
		g._apply_graphics(Graphics.ECONOMY)
	if kv.has("grafika"):  # grafika=0|1|2 — уровень графики ART-044 (0 — «Экономно», 2 — «Красиво»)
		g._apply_graphics(int(kv["grafika"]))
	if kv.get("luch_ten", "1") == "0":  # luch_ten=0 — прожектор без тени (#1400: цена тени на «Обычно»), после grafika=
		g.searchlight.spot.shadow_enabled = false
	if kv.get("glints", "1") == "0":  # glints=0 — без бликов воды в мостике ART-067 (сравнить)
		g.glints.lite = true
	if kv.has("layers"):  # layers=<сила> — слои воды ART-069 (0 — выкл, 0,6 — «Обычно», 0,9 — «Красиво»)
		g.ocean.set_layers_level(float(kv["layers"]))
	if kv.get("grade", "1") == "0":  # grade=0 — без виньетки и цветокоррекции ART-065 (сравнить)
		g.grade.set_on(false)
	if kv.has("energy"):  # energy=<ед.> — заряд корабля (меньше 20 — «МАЛО ЗАРЯДА» на табло)
		g.vitals.energy = float(kv["energy"])
	if kv.get("drain", "0") == "1":  # drain=1 — стеклоуст на корпусе (табло и рамка у щитка разряда)
		g.vitals.drain(g.eco.world.nm("eel"), 0.01)   # имя — как у мира: до скана без имени (#1787)
		g.vitals.drain_left = 60.0
	if kv.has("kamen"):  # kamen=<n> — у каждого ряда каменщиков первые n гнёзд спрятали венчики (#1337)
		for r in g.eco.kamen.rows:
			for i in mini(int(kv["kamen"]), r.worms.size()):
				r.worms[i].open = 0.0
				r.worms[i].quiet = 999.0
			r.calm = false
		g.eco.kamen.changed = true
	if kv.get("steam", "0") == "1":  # пар из вентиля и открытая крышка щитка (для снимка машинного)
		g.debug_vent = true
		g.engine.pressed = 30.0
		g.engine.lid = 1.0
	if kv.has("sample"):  # sample=n — корабль над образцом n, шлюз открыт; grab=<с> — столько держать кнопку у лебёдки
		g.park_over_sample(int(kv["sample"]))
		g.walker.x = Samples.POST_AT.x - 0.7
		g.walker.z = Samples.POST_AT.y + 0.3
		var lock := Samples.lock_point(Samples.ship_xform(g.helm.pos, g.helm.yaw))
		var held := float(kv.get("grab", "0"))
		g.debug_winch = held > 0.0 and held < Samples.GRAB_TIME
		while held > 0.0:
			g.samples.hold(lock, 0.05)
			g.samples.update(0.05)
			held -= 0.05
		g.rooms.set_winch(g.samples.hook_local(Samples.ship_xform(g.helm.pos, g.helm.yaw)), g.samples.carrying(),
			Samples.COLORS[g.samples.target.kind] if g.samples.target else Color.WHITE)
	if kv.has("cargo"):  # cargo=0,2,1 — виды образцов в трюме (и в колбах лаборатории)
		g.samples.cargo.clear()
		for k in kv["cargo"].split(",", false):
			g.samples.cargo.append([clampi(int(k), 0, Samples.NAMES.size() - 1), -1])
		g.rooms.set_lab(Lab.contents(g.samples.cargo), Lab.page_lines(g.samples, g.scanner, g.journal_page), g.time)
	if kv.has("observe"):  # observe=fish:flee,pred:ping — наблюдения в журнале; scanned=fish,pred — изученные виды;
		# journal=n — страница журнала (0 — сводка)
		for pair in kv["observe"].split(",", false):
			var kn: PackedStringArray = pair.split(":")
			if kn.size() == 2:
				g.scanner.observe(kn[0], kn[1])
	if kv.has("scanned"):
		for id in kv["scanned"].split(",", false):
			g.scanner.scanned[id] = true
	if kv.has("route"):   # маршрут n (0…2) выбран у голостола
		g.say(g.run.choose(int(kv["route"])))   # как нажатие у стола: строка на приборах (#938)
	if kv.has("goal_yaw") and g.run.next_key() != "":   # плашка цели за штурвалом (#1344): цель на столько ° левее (− — правее)
		var d := Run.place_xz(g.run.next_key()) - Vector2(g.helm.pos.x, g.helm.pos.z)
		g.helm.yaw = atan2(-d.x, -d.y) - deg_to_rad(float(kv["goal_yaw"]))
	if kv.get("vote", "") in ["1", "up"]:   # маршрут пройден, решение у голостола; vote=up — итог забега
		g.complete_route()
		g.open_vote()
		if kv["vote"] == "up":
			g.decide("up")
			if not kv.has("flyby"):
				g.flyby.stop()   # снимок итога — с мостика: итог на голограмме над столом
	if kv.get("vote", "") == "coop":   # двое у стола: товарищи (mate=…) голосуют, свой — «глубже», решение ждёт их
		g.complete_route()
		g.open_vote()
		for m: Crew.Member in g.crew:
			m.at_vote = true
		g.ballot.cast(g.me.get_instance_id(), g.me.role, "deep")
	if kv.has("journal"):
		g.journal_page = clampi(int(kv["journal"]), 0, Lab.pages(g.scanner) - 1)
		g.rooms.set_lab(Lab.contents(g.samples.cargo), Lab.page_lines(g.samples, g.scanner, g.journal_page), g.time)
	if kv.has("breach"):  # breach=n — пробоина в месте n (0 мостик, 1 коридор, 2 лаборатория, 3 машинное), игрок у неё;
		# weld=<доля> — шов заварен на долю (1 — заварен, шов горячий); water=<м> — вода на полу
		g.open_breach(int(kv["breach"]))
		var w := float(kv.get("weld", "0"))
		if w >= 1.0:
			g.breach.hold(1.0 / Breach.WELD_RATE)
		elif w > 0.0:
			g.breach.weld = w
			g.debug_weld = true
		if kv.has("water"):
			g.breach.water = float(kv["water"])
		g.breach.time = 0.25
		for i in 60:   # частицы ART-072 уже летят: секунда пробоины (и сварки, если weld)
			g.breach.welding = g.debug_weld
			g.breach_view.apply(1.0 / 60.0)
		g.breach.time = 0.25
	if kv.has("ship"):  # ship=x,y,z[,курс°] — поставить корабль (y — высота, глубина со знаком минус)
		var p: PackedFloat64Array = kv["ship"].split_floats(",")
		if p.size() > 3:   # ship=x,y,z,курс° — курс корабля, как шаг «ship» сценария тестера
			g.helm.yaw = deg_to_rad(p[3])
			g.helm.turn = 0.0
		g.park_at(Vector3(p[0], p[1], p[2]))
	if kv.has("place"):  # place=NN|ключ — корабль у места слоя 1 носом к ориентиру, камера снаружи корпуса (#1358);
		# place_cam=front|back — перед носом / позади и выше корабля, place_dist=<м> — от ориентира, place_side=<°> — откуда
		var pose := place_pose(kv["place"], kv.get("place_cam", "front"), float(kv.get("place_dist", str(PLACE_DIST))),
			float(kv["place_side"]) if kv.has("place_side") else NAN)
		if not pose.is_empty():
			g.helm.yaw = pose["yaw"]
			g.helm.turn = 0.0
			g.park_at(pose["ship"])
			var cam := Camera3D.new()
			cam.fov = Deck.FOV
			cam.far = 400.0
			g.add_child(cam)
			cam.global_position = pose["cam"]
			cam.look_at(pose["look"])
			cam.make_current()
	if kv.get("kupol", "0") == "1":  # kupol=1 — купольник у гнезда 07 поднимает створку (#837, модель MOD-022),
		# камера в 6 м сбоку-сзади от него
		var d: EcoDome = g.eco.dome
		d.pos = d.stand()
		d.yaw = 0.0
		d.state = EcoDome.State.OPEN
		d.t = float(kv.get("kupol_t", "0"))
		g.eco.dome_view.sync(g.eco.world.time, d.pos)
		var kc := Camera3D.new()
		kc.fov = Deck.FOV
		kc.far = 400.0
		g.add_child(kc)
		kc.global_position = cam_above(d.pos + Vector3(3.5, 2.0, 5.0))   # гнездо на лице опоры над полом кармана (#1757): камера не под дном
		kc.look_at(d.pos + Vector3(0.0, 0.5, 0.0))
		kc.make_current()
	if kv.has("grot") or kv.has("grot_t"):  # grot=x,z;… — круг гротовика на пробу; grot_t=<с> — он один прошёл столько
		# секунд круга, корабль в grot_dist м от него (grot_cam=bok|nos|korma|mid), за штурвалом — штатная камера (#1400)
		if kv.has("grot"):
			EcoGrot.route = grot_route(kv["grot"])
		grot_walk(g, float(kv.get("grot_t", "0")))
		var gp := grot_pose(g.eco.grot.grot, String(kv.get("grot_cam", "bok")), float(kv.get("grot_dist", str(GROT_DIST))))
		g.helm.yaw = gp["yaw"]
		g.helm.turn = 0.0
		g.park_at(gp["ship"])
		if not g.pilot.seated:
			g.sit_at_helm()
		print(grot_line(g.eco.grot.grot, gp["ship"]) + ", спина ниже взгляда на %.0f°" % rad_to_deg(gp["down"]))
	if kv.has("scena"):  # scena=1|2|3 — контрольный ракурс сцены 00 → 01 (#1400): штатная камера пилота, нос к 01
		var back := float(kv.get("scena_back", "0"))   # scena_back=<м> — раньше по тому же пути
		var sp := scena_pose(int(kv["scena"]), back)
		if not sp.is_empty():
			var ride := scena_ride(int(kv["scena"]), String(kv.get("scena_y", "")), back)   # scena_y=<y>|dno — высота хода
			sp["ship"].y = ride["y"]
			g.set_meta("scena_src", ride["src"])
			g.helm.yaw = sp["yaw"] + deg_to_rad(float(kv.get("scena_yaw", "0")))   # scena_yaw=<°> — левее, минус — правее
			g.helm.turn = 0.0
			g.park_at(sp["ship"])
			if not g.pilot.seated:
				g.sit_at_helm()
			if kv.has("zamer"):   # zamer=bok|korma|nos — проба фазы «замер» #1498, серпохвост №0 рядом с кораблём
				zamer_setup(g, sp["ship"], g.helm.yaw, String(kv["zamer"]))
			if kv.has("strah"):   # strah=<м> — хищник №0 за стаей рифа у 01 на столько метров от неё (реакция стаи)
				strah_setup(g, sp["ship"], float(kv["strah"]))
				strah_log(g, 0.0)
			if kv.has("scena_t"):   # scena_t=<с> — мир идёт столько секунд, корабль висит в точке ракурса (кадры движения)
				scena_run(g, sp["ship"], float(kv["scena_t"]), float(kv.get("zamer_off", "-1")),   # zamer_off=<с> — свет гаснет
						kv.has("zamer"), kv.has("strah"))
				if kv.has("zamer"):
					zamer_log(g)
				if kv.has("strah"):
					strah_log(g, float(kv["scena_t"]))
	if kv.has("lore"):  # lore=d07_return,shell03 — знания слоя 1 (#825; ключи LayerLore.KEYS)
		for k in kv["lore"].split(",", false):
			g.lore.learn(k)
	if kv.get("spusk_vote", "") in ["1", "later", "coop"]:   # корабль в круге 10 — панель спуска у стола (#1362); later — «позже»
		if not kv.has("ship"):
			var p10 := Run.place_xz(Run.DESCENT)
			g.park_at(Vector3(p10.x, Seabed.height(p10.x, p10.y) + 15.0, p10.y))
		g.say(g.run.descent(g.helm.pos.x, g.helm.pos.z))
		g.walker.x = Main.ROUTE_POST.x   # у поста «Маршрут» справа от голостола
		g.walker.z = Main.ROUTE_POST.y
		g.walker.yaw = PI / 2.0
		if kv["spusk_vote"] != "later":
			g.open_vote()
		if kv["spusk_vote"] == "coop":   # с mate=…: все у стола, свой голос «вниз», ждём товарищей
			for m: Crew.Member in g.crew:
				m.at_vote = true
			g.ballot.cast(g.me.get_instance_id(), g.me.role, "deep")
	if kv.has("scorch"):  # scorch=n — n следов разряда на дне перед носом через 4 м (первый — старое пятно)
		var n := int(kv["scorch"])
		for i in n:
			var at := g.helm.pos + g.helm.nose() * (9.0 + 4.0 * i)
			var fy := Seabed.height(at.x, at.z)
			g.scorch.add(Vector3(at.x, fy + Helm.Ship.CLEARANCE, at.z), fy, 1.0,
					g.time - (Seabed.Scorch.OLD.y if i == 0 else 0.0))
		g.ocean.set_scorch(g.scorch.uniforms(g.time))
	if kv.has("use"):  # use=<пост> — встать (x, z, yaw) и нажать кнопку действия у поста, шаг игры 0,3 с — снимок
		g.walker.x = float(kv.get("x", str(g.walker.x)))
		g.walker.z = float(kv.get("z", str(g.walker.z)))
		g.walker.yaw = deg_to_rad(float(kv.get("yaw", "0")))
		g.use_post(kv["use"])
		for i in 9:
			g.step(1.0 / 30.0)
	if kv.has("secs"):
		var secs := float(kv["secs"])
		var dt := 1.0 / 30.0
		for i in int(secs / dt):
			g.helm.in_thrust = float(kv.get("thrust", "0"))
			g.helm.in_turn = float(kv.get("turn", "0"))
			g.helm.in_vert = float(kv.get("vert", "0"))
			g.current.update(dt)
			g.helm.update(dt, 1.0, g.current.vel())
			g.hull_motion.update(dt, g.helm.in_thrust, g.helm.in_vert, 1.0)
			g._wake(dt)
		g._place_ship()
		g._place_camera()
		g._update_ui()
	if kv.has("flyby"):
		g.flyby.start(Flyby.Kind.SURFACE if kv["flyby"] == "surface" else Flyby.Kind.START)
		g.flyby.update(float(kv.get("age", "2.0")))
		g._place_camera()
	if kv.has("vent"):  # vent=<с> — выпуски у сервисных крышек ART-063 через столько секунд после продувки
		g.wake.vent()
		for i in int(float(kv["vent"]) * 30.0):
			g._wake(1.0 / 30.0)
	if kv.has("view"):  # view=x,y,z — камера снаружи в осях корабля, смотрит на середину корпуса (снимок корпуса)
		var v: PackedFloat64Array = kv["view"].split_floats(",")
		var out := Camera3D.new()
		out.fov = Deck.FOV
		out.far = 400.0
		g.add_child(out)
		var want: Vector3 = g.ship.to_global(Vector3(v[0], v[1], v[2]))
		out.global_position = cam_above(want)
		if out.global_position.y > want.y:   # молча поднятая камера — другой кадр: строка в лог снимка
			print("view=: камера была под дном — поднята на %s м (не ниже %s м над видимым дном)" % [
				_num(out.global_position.y - want.y), _num(CAM_FLOOR)])
		out.look_at(g.ship.to_global(Vector3(0.0, HullPlan.CENTER_Y, 10.0)))
		out.make_current()
	if kv.get("mate_hold", "0") == "1" and g.crew.size() > 1:   # последний товарищ держит кнопку (сварка, вентиль…)
		if kv.has("x"):   # свой игрок — на своём месте до шагов: пост держит товарищ
			g.walker.x = float(kv["x"])
			g.walker.z = float(kv.get("z", "0"))
		var mate: Crew.Member = g.crew[-1]
		mate.pad.hold = true
		for i in int(float(kv.get("hold_s", "1.5")) * 10.0):
			g.step(0.1)


## Камера снимка со сдвигом от объекта или корабля (kupol=, view=, place=) — не ниже стольких метров над видимым
## дном: на склоне она оказывалась под сеткой дна, и кадр резал «чёрный клин» (#1350, 13.11, PR #1818).
const CAM_FLOOR := 1.5


## Точка p, поднятая до CAM_FLOOR над видимой сеткой дна (`Seabed.mesh_height`); выше — как есть.
static func cam_above(p: Vector3, ground: Callable = Seabed.mesh_height) -> Vector3:
	return Vector3(p.x, maxf(p.y, float(ground.call(p.x, p.z)) + CAM_FLOOR), p.z)


## Ракурс place=NN (#1358): от ориентира до середины корпуса, м.
const PLACE_DIST := 38.0
## Камера в осях корабля: перед носом (front) и позади-выше (back) — вне корпуса HullPlan.
const PLACE_CAM := {"front": Vector3(0.0, 3.0, -17.0), "back": Vector3(0.0, 16.0, 62.0)}
## Над дном: корабль и камера не ниже стольких метров.
const PLACE_FLOOR := 7.0


## Поза снимка места слоя 1: id из LayerMap.POINTS ("03") или ключ Run.PLACES ("shell"). Корабль на глубине ориентира
## (не ниже PLACE_FLOOR над дном) в dist м от него, со стороны середины карты (side — пеленг от ориентира, °,
## 0 — с юга, +z), носом к ориентиру. {ship, yaw, cam, look}; пусто — нет такого места.
static func place_pose(name: String, kind: String = "front", dist: float = PLACE_DIST, side: float = NAN) -> Dictionary:
	var id := name if LayerMap.POINTS.has(name) else LayerMap.id_of(name)
	if id == "":
		return {}
	var at := LayerMap.at(id)
	var away := Vector2(-at.x, -at.z).normalized()   # к середине карты
	if not is_nan(side):
		away = Vector2(sin(deg_to_rad(side)), cos(deg_to_rad(side)))
	elif away == Vector2.ZERO:
		away = Vector2(0.0, 1.0)
	var sx := at.x + away.x * dist
	var sz := at.z + away.y * dist
	var ship := Vector3(sx, maxf(at.y, Seabed.height(sx, sz) + PLACE_FLOOR), sz)
	var yaw := atan2(away.x, away.y)   # нос (−sin, −cos) — от корабля к ориентиру
	var local: Vector3 = PLACE_CAM.get(kind, PLACE_CAM["front"])
	var cam := ship + local.rotated(Vector3.UP, yaw)
	cam.y = maxf(cam.y, Seabed.height(cam.x, cam.z) + PLACE_FLOOR)
	cam = cam_above(cam)   # видимая сетка дна на изломе выше гладкого рельефа
	var look := Vector3(at.x, maxf(at.y - 4.0, Seabed.height(at.x, at.z) + 2.0), at.z)
	return {"ship": ship, "yaw": yaw, "cam": cam, "look": look}


## Кадры дрейфа гротовика (#1400): корабль от середины тела, м; над видимым дном не ниже GROT_FLOOR (чуть выше
## `Helm.Ship.CLEARANCE`) и над телом не ниже GROT_UP — нос к телу, штатная камера пилота (взгляд −8°).
const GROT_DIST := 24.0
const GROT_UP := 1.5
const GROT_FLOOR := 4.5
## Луч от спины к кораблю — по GROT_RAYS точкам, над видимым дном не ниже GROT_CLEAR, м (иначе корабль выше).
const GROT_RAYS := 12
const GROT_CLEAR := 1.0
## Глаз пилота за штурвалом от середины корабля: вперёд, вверх, м (замер headless, корабль ровно).
const GROT_EYE := Vector2(4.85, 9.1)
## Спина ниже взгляда не круче GROT_DOWN° (окно пилота при взгляде −8° — до ~20°); иначе корабль дальше на GROT_STEP м,
## не дальше GROT_FAR.
const GROT_DOWN := 15.0
const GROT_STEP := 4.0
const GROT_FAR := 44.0
## Шаг, которым гротовик один проходит grot_t (как `tools/mid_calm.gd grot_path`).
const GROT_DT := 0.1


## Круг гротовика из «x,z;x,z;…».
static func grot_route(s: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for part in s.split(";", false):
		var xz := part.split_floats(",")
		if xz.size() >= 2:
			out.append(Vector2(xz[0], xz[1]))
	return out if out.size() >= 2 else EcoGrot.ROUTE


## Гротовик заново с первой точки круга `EcoGrot.route` и один (корабль далеко) идёт seconds секунд шагом GROT_DT;
## стая рифа — снова на спине (как в `EcoGrot.reset`).
static func grot_walk(g, seconds: float) -> void:
	var w: EcoWorld = g.eco.world
	var gs: EcoGrot = g.eco.grot
	var ship := w.ship.pos
	w.ship.pos = Vector3(0.0, 0.0, -2000.0)
	gs.reset(w)
	for i in int(round(seconds / GROT_DT)):
		gs.step(w, GROT_DT)
	w.ship.pos = ship
	var sh := gs.shoal
	if sh:
		var from := sh.center
		for f: EcoFish.Fish in sh.members:
			f.agent.p += sh.home - from
			f.agent.home = sh.home
		sh.center = sh.home
		sh.goal = sh.home


## Поза корабля для кадра гротовика: bok — сбоку от курса тела (с той стороны, откуда спину видно ниже), nos — перед
## телом, korma — позади, mid — на стоянке середины сцены (SCENA[1]); нос к телу. Глаз пилота — на GROT_EYE выше и
## впереди середины корабля: спина ниже взгляда круче GROT_DOWN — под пультом, корабль отходит дальше (до GROT_FAR).
## {ship, yaw, down — угол от глаза вниз на спину, рад}.
static func grot_pose(gr: EcoGrot.Walker, kind: String, dist: float) -> Dictionary:
	var at := Vector2(gr.p.x, gr.p.z)
	var f := Vector2(sin(gr.yaw), cos(gr.yaw))
	var left := Vector2(cos(gr.yaw), -sin(gr.yaw))
	var best := {}
	var d := dist
	while true:
		var spots: Array[Vector2] = []
		match kind:
			"nos": spots = [at + f * d]
			"korma": spots = [at - f * d]
			"mid": spots = [SCENA[1]]
			_: spots = [at - left * d, at + left * d]
		for xz in spots:
			var pose := _grot_spot(gr, xz)
			if best.is_empty() or pose["down"] < best["down"] - 1e-4:
				best = pose
		d += GROT_STEP
		if kind == "mid" or best["down"] <= deg_to_rad(GROT_DOWN) or d > GROT_FAR + 1e-3:
			return best
	return best


## Корабль в xz носом к телу: над дном GROT_FLOOR, над телом GROT_UP, луч от спины к глазу над дном на GROT_CLEAR.
static func _grot_spot(gr: EcoGrot.Walker, xz: Vector2) -> Dictionary:
	var at := Vector2(gr.p.x, gr.p.z)
	var away := (xz - at).normalized() if xz != at else Vector2(0.0, 1.0)
	var eye := xz - away * GROT_EYE.x
	var y := maxf(float(Seabed.mesh_height(xz.x, xz.y)) + GROT_FLOOR, gr.body_y + GROT_UP)
	var back := gr.body_y + EcoGrot.BACK_UP
	for i in range(1, GROT_RAYS):   # гребень между глазом и телом не закрывает спину
		var s := float(i) / GROT_RAYS
		var q := at.lerp(eye, s)
		y = maxf(y, back + (float(Seabed.mesh_height(q.x, q.y)) + GROT_CLEAR - back) / s - GROT_EYE.y)
	return {"ship": Vector3(xz.x, y, xz.y), "yaw": atan2(away.x, away.y),
		"down": atan2(y + GROT_EYE.y - back, maxf(at.distance_to(eye), 0.1))}


## Строка в лог: где гротовик, курс, наклон (тангаж/крен, цель по дну), шаг, точка пути, расстояние до корабля.
static func grot_line(gr: EcoGrot.Walker, ship: Vector3) -> String:
	return "гротовик: (%.1f; %.1f) дно %.1f, курс %.0f°, наклон %.2f/%.2f (по дну %.2f/%.2f, предел %.2f), шаг %.2f, к точке %d %s; корабль (%.1f; %.1f; %.1f) в %.1f м" % [
		gr.p.x, gr.p.z, gr.p.y, rad_to_deg(gr.yaw), gr.tilt.x, gr.tilt.y, gr.tilt_want.x, gr.tilt_want.y,
		EcoGrot.TILT_MAX, gr.stride, gr.wp, str(EcoGrot.route[gr.wp]), ship.x, ship.y, ship.z,
		Vector2(ship.x - gr.p.x, ship.z - gr.p.z).length()]


## Контрольные ракурсы сцены 00 → 01 (#1400, docs/urovni/sloj-1.md «Пакет сравнения»): выход из 00, середина
## перехода, подход к 01 — точки (x, z), на них сняты кадры «до» в #1400 (main 9b26569).
const SCENA: Array[Vector2] = [Vector2(4.0, 80.0), Vector2(20.0, 22.5), Vector2(33.0, -22.0)]
## Цель взгляда сцены — место 01 (Каменный цветок).
const SCENA_GOAL := "01"
## Корабль над видимым дном в ракурсе сцены, м (как кадры «до»: 6–8 м).
const SCENA_FLOOR := 7.0


## Кадры движения сцены (#1400): игра шагает seconds секунд ровным шагом SCENA_DT, корабль после каждого шага
## возвращается в точку ракурса (течение не уносит взгляд), курс и свет — как поставлены; мир — стаи, луч на флоре — идёт сам.
const SCENA_DT := 1.0 / 30.0


## light_off ≥ 0 — через столько секунд прожектор гаснет (ответ экипажа на «замер», zamer_off=).
## trace — с zamer=: в лог каждая смена режима хищника №0 и строк приборов с секундой мира (момент потери цели, #1400).
## shoal — с strah=: в лог раз в секунду мира — хищник №0 и стая STRAH_SHOAL (#1400).
static func scena_run(g: Node, ship: Vector3, seconds: float, light_off := -1.0, trace := false,
		shoal := false) -> void:
	var n := int(round(seconds / SCENA_DT))
	var off_at := int(round(light_off / SCENA_DT)) if light_off >= 0.0 else -1
	var was := {"mode": -1, "parts": []}
	for i in n:
		if i == off_at and g.light_on:
			g.toggle_light()
			if trace:
				print("zamer: %s с — прожектор погашен" % _num((i + 1) * SCENA_DT))
		g.step(SCENA_DT)
		g.park_at(ship)
		if trace:
			for line in zamer_trace(g, was, (i + 1) * SCENA_DT):
				print(line)
		if shoal and (i + 1) % int(round(1.0 / SCENA_DT)) == 0:
			strah_log(g, (i + 1) * SCENA_DT)


## Что сменилось за шаг (scena_run с trace): режим хищника №0 и строки приборов со словами (числа без слов —
## глубина, курс — не печатаем). was — прошлое состояние {mode, parts}, обновляется. Строки для лога.
static func zamer_trace(g: Node, was: Dictionary, t: float) -> Array[String]:
	var out: Array[String] = []
	var ps: EcoPred = g.eco.preds
	if ps != null and not ps.all.is_empty():
		var pr: EcoPred.Pred = ps.all[0]
		if pr.mode != was["mode"]:
			out.append("zamer: %s с — хищник №0: %s, до корабля %s м" % [_num(t), EcoPred.Mode.keys()[pr.mode],
				_num(pr.agent.distance_to(g.helm.pos))])
			was["mode"] = pr.mode
	var parts: Array = []
	for p in g.status_parts():
		if String(p).length() > 12:
			parts.append(String(p))
	for p in parts:
		if not was["parts"].has(p):
			out.append("zamer: %s с — строка «%s»" % [_num(t), p])
	for p in was["parts"]:
		if not parts.has(p):
			out.append("zamer: %s с — ушла «%s»" % [_num(t), p])
	was["parts"] = parts
	return out


## Кадры знака #1498 (zamer=): длина фазы и отход — как в игре (вариант 1 гейм-дизайнера, включён PR #1663).
const ZAMER_ALERT := EcoPred.ALERT_ON
const ZAMER_LEAVE := EcoPred.ALERT_LEAVE_ON
## Где и как ставим хищника — постановка мира `EcoPred.stage_*` (общая с шагом `zamer` сценария тестера).
const ZAMER_DIST := EcoPred.STAGE_DIST
const ZAMER_FLOOR := EcoPred.STAGE_FLOOR
const ZAMER_SIDES := EcoPred.STAGE_SIDES


static func zamer_spot(ship: Vector3, yaw: float, side: String) -> Vector3:
	return EcoPred.stage_spot(ship, yaw, side)


## Включает фазу «замер» в мире снимка и ставит голодного хищника №0 в zamer_spot; остальных уводит за 400 м.
static func zamer_setup(g: Node, ship: Vector3, yaw: float, side: String) -> void:
	var at := zamer_spot(ship, yaw, side)
	var ps: EcoPred = g.eco.preds
	if at == Vector3.INF or ps == null or ps.all.is_empty():
		push_warning("zamer=%s: нет стороны или хищников" % side)
		return
	ps.alert = ZAMER_ALERT
	ps.alert_leave = ZAMER_LEAVE
	ps.stage_near(0, at, ship)
	if not g.light_on:
		g.toggle_light()


## В лог снимка — режим хищника №0 и расстояние до корабля (что поймал кадр).
static func zamer_log(g: Node) -> void:
	var pr: EcoPred.Pred = g.eco.preds.all[0]
	print("zamer: хищник №0 — %s, до корабля %.1f м, свет %s" % [EcoPred.Mode.keys()[pr.mode],
		pr.agent.distance_to(g.helm.pos), "горит" if g.light_on else "погашен"])


## Реакция стаи у 01 (strah=, #1400): стая рифа (55; −69) — пятая в EcoFish.HOMES, видна между ветвями цветка.
const STRAH_SHOAL := 4


## Ставит голодного хищника №0 за стаей STRAH_SHOAL — на dist метров от её центра, на продолжении линии
## корабль → стая (причина — с дальней стороны), на высоте стаи; остальных уводит за 400 м. Фаза «замер» — как в игре.
## Хищник идёт к краю рифа против стаи (strah_goal); ближе EcoFish.PRED_ALARM — стая в тревоге и прячется у дома.
static func strah_setup(g: Node, ship: Vector3, dist: float) -> void:
	var ps: EcoPred = g.eco.preds
	var fs: EcoFish = g.eco.fish
	if ps == null or ps.all.is_empty() or fs == null or fs.shoals.size() <= STRAH_SHOAL:
		push_warning("strah=: нет хищников или стаи")
		return
	var c: Vector3 = fs.shoals[STRAH_SHOAL].center
	var at := strah_spot(ship, c, dist)
	for pr in ps.all:
		pr.cooldown = 999.0 if pr.index != 0 else 0.0
		pr.agent.v = Vector3.ZERO
		pr.agent.p = at if pr.index == 0 else ship + Vector3(400.0 + 30.0 * pr.index, 0.0, 0.0)
		pr.agent.goal = strah_goal(ps, c) if pr.index == 0 else pr.agent.p
		pr.prey = null
		EcoPred._set_mode(pr, EcoPred.Mode.PATROL, 30.0)
	ps.all[0].hunger = 0.5


## Где ставить хищника strah=: на dist метров за стаей c по линии от корабля, на высоте стаи, не ниже ZAMER_FLOOR
## над видимым дном.
static func strah_spot(ship: Vector3, c: Vector3, dist: float) -> Vector3:
	var dir := Vector3(c.x - ship.x, 0.0, c.z - ship.z).normalized()
	var at := c + dir * dist
	at.y = maxf(c.y, Seabed.mesh_height(at.x, at.z) + ZAMER_FLOOR)
	return at


## Цель патруля хищника strah=: стая у 01 — внутри кольца рифа (EcoPred.REEF_KEEP от оси цветка), туда хищник не
## заходит; идёт к краю кольца против стаи — как обычный патруль к дому стаи (EcoPred.outside_reef).
static func strah_goal(ps: EcoPred, c: Vector3) -> Vector3:
	return EcoPred.outside_reef(ps.reef_axis(), c, EcoPred.REEF_KEEP)


## Строка лога strah=: секунда мира, хищник №0 (режим, до стаи и до корабля), стая (в тревоге, спрятались, живых,
## центр до дома).
static func strah_line(g: Node, t: float) -> String:
	var pr: EcoPred.Pred = g.eco.preds.all[0]
	var sh: EcoFish.Shoal = g.eco.fish.shoals[STRAH_SHOAL]
	var hid := 0
	for f in sh.members:
		if f.agent.alive and f.agent.state == EcoAgent.State.HIDE:
			hid += 1
	return "strah: %s с — хищник №0 %s, до стаи %.1f м, до корабля %.1f м; стая: тревога %s, спрятались %d из %d, центр от дома %.1f м" % [
		_num(t), EcoPred.Mode.keys()[pr.mode], pr.agent.p.distance_to(sh.center), pr.agent.distance_to(g.helm.pos),
		"да" if sh.alarm > 0.0 else "нет", hid, sh.alive, sh.center.distance_to(sh.home)]


static func strah_log(g: Node, t: float) -> void:
	print(strah_line(g, t))


## Поза ракурса scena=n (1…3): корабль в точке SCENA[n − 1] на SCENA_FLOOR над видимым дном, носом к 01.
## {ship, yaw}; пусто — нет такого ракурса.
## back > 0 — на столько метров раньше по тому же пути `tools/pass_plan.gd` (scena_back=, #1400).
static func scena_pose(n: int, back := 0.0) -> Dictionary:
	if n < 1 or n > SCENA.size():
		return {}
	var at := scena_at(n, back)
	var to := LayerMap.xz(SCENA_GOAL) - at
	var ship := Vector3(at.x, Seabed.mesh_height(at.x, at.y) + SCENA_FLOOR, at.y)
	return {"ship": ship, "yaw": atan2(-to.x, -to.y)}   # нос (−sin, −cos) — к 01


## Высота хода в ракурсе scena=n и откуда она: how — "" (плавный ход `tools/pass_box.gd`, контур 20×30: H+7 с
## уклоном ≤ SLOPE), "dno" — SCENA_FLOOR над видимым дном в точке (кадры «до» #1400), число — y руками. {y, src}.
static func scena_ride(n: int, how := "", back := 0.0) -> Dictionary:
	var at := scena_at(clampi(n, 1, SCENA.size()), back)
	if how == "dno":
		return {"y": Seabed.mesh_height(at.x, at.y) + SCENA_FLOOR, "src": "%.0f м над дном в точке (scena_y=dno)" % SCENA_FLOOR}
	if how != "":
		return {"y": float(how), "src": "руками (scena_y=%s)" % how}
	var y: float = PassBox.smooth_at(maxf(PassPlan.arc_at(clampi(n, 1, SCENA.size()) - 1) - maxf(back, 0.0), 0.0))
	return {"y": y, "src": "плавный ход tools/pass_box.gd (H+%.0f, уклон ≤ %s)" % [PassBox.RIDE, _num(PassBox.SLOPE)]}


## Точка ракурса scena=n: SCENA[n − 1] или на back м раньше по пути (не дальше начала у 00).
static func scena_at(n: int, back := 0.0) -> Vector2:
	if back <= 0.0:
		return SCENA[n - 1]
	return PassPlan.along(maxf(PassPlan.arc_at(n - 1) - back, 0.0))["at"]


## Подпись контрольного кадра scena= для лога (#1400): точка, фактический y корабля, до дна, курс, источник высоты.
static func scena_line(g: Node) -> String:
	var p: Vector3 = g.helm.pos
	var yaw := wrapf(rad_to_deg(g.helm.yaw), -180.0, 180.0)
	return "кадр сцены (#1400): точка (%s; %s), y корабля %s, до дна %s м, курс %+.0f° от −Z (плюс — левее); высота — %s" % [
		_num(p.x), _num(p.z), _num(p.y), _num(p.y - Seabed.mesh_height(p.x, p.z)), yaw, g.get_meta("scena_src", "—")]


static func _num(v: float) -> String:
	return ("%.1f" % v).replace(".", ",").replace("-", "−")


## С какого расстояния впереди виден грунт в окне пилота (#1400, дизайнер уровней — границу видимости снять заново
## после #1402): по столбцам кадра GROUND_COLS снизу вверх с шагом GROUND_STEP пикселей ищем первый луч, который
## доходит до видимого дна (`Seabed.mesh_height`), не задев мостик и корпус (пульт, штурвал, рама, нос).
## Печатает shot.gd с scena=, чтобы ближний план ставить без проб.
const GROUND_COLS: Array[float] = [0.25, 0.5, 0.75]
const GROUND_STEP := 8
## Шаг луча до дна, м, и дальше этого дна в кадре нет (дальняя вода).
const GROUND_MARCH := 0.5
const GROUND_FAR := 300.0


## Заслоны взгляда: видимые несглаженные сетки под узлами roots в мировых координатах — [{aabb, faces}].
## Стекло окна прозрачно — не заслон; экипаж (сетки со скином) не берём: поза рук меняется.
static func occluders(roots: Array) -> Array:
	var out := []
	for r in roots:
		if r == null:
			continue
		for n in (r as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree() or mi.skin != null or _is_glass(mi):
				continue
			var faces: PackedVector3Array = mi.global_transform * mi.mesh.get_faces()
			if faces.is_empty():
				continue
			out.append({"aabb": mi.global_transform * mi.get_aabb(), "faces": faces})
	return out


static func _is_glass(mi: MeshInstance3D) -> bool:
	var m := mi.material_override as ShaderMaterial
	return m != null and m.shader in [BridgeView.GLASS_SHADER, BridgeView.GLASS_WET_SHADER]


## Луч заслонён ближе reach: попал в лицевую сторону треугольника (обход по часовой, (b − a) × (c − a) — внутрь,
## то есть по лучу); изнанку движок не рисует — она не заслон.
static func blocked(from: Vector3, dir: Vector3, reach: float, occ: Array) -> bool:
	var to := from + dir * reach
	for o in occ:
		if not (o["aabb"] as AABB).grow(0.01).intersects_segment(from, to):
			continue
		var f: PackedVector3Array = o["faces"]
		for i in range(0, f.size() - 2, 3):
			var a := f[i]
			var b := f[i + 1]
			var c := f[i + 2]
			if (b - a).cross(c - a).dot(dir) <= 0.0:
				continue
			var hit: Variant = Geometry3D.ray_intersects_triangle(from, dir, a, b, c)
			if hit != null and from.distance_to(hit) < reach:
				return true
	return false


## Расстояние вдоль луча до дна floor(x, z) → y, м; INF — дна нет ближе GROUND_FAR (луч вверх или в дальнюю воду).
static func ground_hit(from: Vector3, dir: Vector3, floor_y: Callable) -> float:
	if dir.y >= 0.0:
		return INF
	var t := 0.0
	while t < GROUND_FAR:
		var t2 := t + GROUND_MARCH
		var p := from + dir * t2
		if p.y <= float(floor_y.call(p.x, p.z)):
			var a := t
			var b := t2
			for k in 12:
				var m := (a + b) / 2.0
				var q := from + dir * m
				if q.y <= float(floor_y.call(q.x, q.z)):
					b = m
				else:
					a = m
			return b
		t = t2
	return INF


## Ближний видимый грунт в столбце u (0…1 по ширине кадра) камеры cam: {row — строка кадра сверху, dist — по
## горизонтали от глаза, м}; пусто — в столбце дна не видно.
static func ground_ahead(cam: Camera3D, u: float, occ: Array, floor_y: Callable) -> Dictionary:
	var size := cam.get_viewport().get_visible_rect().size
	var y := int(size.y) - 1
	while y > 0:
		var px := Vector2(size.x * u, y)
		var o := cam.project_ray_origin(px)
		var d := cam.project_ray_normal(px)
		var t := ground_hit(o, d, floor_y)
		if t == INF:
			return {}
		if not blocked(o, d, t, occ):
			var p := o + d * t
			return {"row": y, "dist": Vector2(p.x - o.x, p.z - o.z).length()}
		y -= GROUND_STEP
	return {}


## Строка для лога снимка: «грунт в окне (#1400): слева с 14 м, по центру с 18 м, справа с 15 м · кромка на 35/30/35 %
## кадра снизу».
static func ground_line(g: Node) -> String:
	var cam := g.get_viewport().get_camera_3d()
	var occ := occluders([g.bridge, g.hull])
	var h := cam.get_viewport().get_visible_rect().size.y
	var names := ["слева", "по центру", "справа"]
	var dist: Array[String] = []
	var edge: Array[String] = []
	for i in GROUND_COLS.size():
		var r := ground_ahead(cam, GROUND_COLS[i], occ, Seabed.mesh_height)
		dist.append("%s %s" % [names[i], "нет" if r.is_empty() else "с %d м" % roundi(r["dist"])])
		edge.append("—" if r.is_empty() else str(roundi((h - r["row"]) / h * 100.0)))
	return "грунт в окне (#1400): %s · кромка на %s %% кадра снизу" % [", ".join(dist), "/".join(edge)]


## Реплика плашки связи для svyaz=: своя — svyaz_text=, иначе образец для своего или подделки.
static func svyaz_line(kv: Dictionary) -> String:
	var own: String = kv.get("svyaz_text", "").strip_edges()
	if own != "":
		return own
	return "Дайте импульс сонара" if svyaz_fake(kv) else "Сбросьте ход, перегрев"


static func svyaz_fake(kv: Dictionary) -> bool:
	return kv.get("svyaz", "1") in ["fake", "wrong", "exposed", "silent"]


## svyaz=1|fake|wait|match|wrong|exposed|silent — плашка внутренней связи ART-040 в этом состоянии (svyaz_text= — своя строка).
static func svyaz(g: Main, kv: Dictionary) -> void:
	var v: String = kv.get("svyaz", "1")
	g.comms.reset_run(0)
	var fake := svyaz_fake(kv)
	g.on_eco_event(EcoLink.voice(Crew.Role.PILOT if fake else Crew.Role.ENGINEER,
		svyaz_line(kv), fake, "ping" if fake else "", v == "silent"))
	for i in 6:
		g.step(0.05)
	var states := {"wait": Comms.Ask.WAIT, "match": Comms.Ask.MATCH, "wrong": Comms.Ask.WRONG,
		"exposed": Comms.Ask.EXPOSED, "silent": Comms.Ask.SILENT}
	if states.has(v):
		g.comms.state = states[v]
	g.comms_panel.show_comms(g.comms, g.time, g.comms_area())
