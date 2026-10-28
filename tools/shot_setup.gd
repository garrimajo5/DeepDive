extends RefCounted
## Подготовка сцены к снимку для tools/shot.gd (и сценовых тестов): ключи командной строки → состояние игры
## (сесть за штурвал, провести корабль, пробоина, товарищи, графика…). Описание ключей — в шапке tools/shot.gd.
## Раньше жило в Main.debug_setup; вынесено, чтобы отладка не раздувала main.gd и не шла в APK (tools/ не
## экспортируется).


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
	if kv.get("glints", "1") == "0":  # glints=0 — без бликов воды в мостике ART-067 (сравнить)
		g.glints.lite = true
	if kv.has("layers"):  # layers=<сила> — слои воды ART-069 (0 — выкл, 0,6 — «Обычно», 0,9 — «Красиво»)
		g.ocean.set_layers_level(float(kv["layers"]))
	if kv.get("grade", "1") == "0":  # grade=0 — без виньетки и цветокоррекции ART-065 (сравнить)
		g.grade.set_on(false)
	if kv.has("energy"):  # energy=<ед.> — заряд корабля (меньше 20 — «МАЛО ЗАРЯДА» на табло)
		g.vitals.energy = float(kv["energy"])
	if kv.get("drain", "0") == "1":  # drain=1 — стеклоуст на корпусе (табло и рамка у щитка разряда)
		g.vitals.drain("Стеклоуст", 0.01)
		g.vitals.drain_left = 60.0
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
		out.global_position = g.ship.to_global(Vector3(v[0], v[1], v[2]))
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
