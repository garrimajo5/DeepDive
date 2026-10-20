class_name Main
extends Node3D
## Сцена собирается из кода: отмель, корабль с мостиком, игрок на палубе или за штурвалом, экранное управление.
## Мир неподвижен, корабль (узел «Корабль») движется по Helm.Ship; камера — глаза игрока в осях корабля.

var walker := Deck.Walker.new()
var pilot := Deck.Pilot.new()
var me := Crew.Member.new(Crew.Role.PILOT)   ## свой игрок как фигура (видят другие и он сам)
var crew: Array = [me]                       ## экипаж на борту; позже — игроки по сети
var crew_view: CrewView
var layout := ShipLayout.new()
var airlock := Airlock.new()
var posts: Array[Deck.Post] = []
var helm := Helm.Ship.new()
var reactor := Reactor.new()
var sonar := Sonar.new()
var vitals := Vitals.new()   ## корпус и заряд корабля
var zap := Zap.new()
var samples := Samples.new()   ## образцы на дне и лебёдка трюма
var samples_view: SamplesView
var engine := EngineRoom.new()   ## машинное: вентиль сброса пара и щиток «Аварийный сброс»
var debug_vent := false          ## снимок: вентиль держат без пальца
var debug_winch := false         ## снимок: кнопку у лебёдки держат без пальца
var zap_light: OmniLight3D   ## вспышка разряда вокруг корпуса (за бортом)
## Первые кадры вспышка горит почти без света: шейдеры дна и корпуса со светом от неё собираются при старте,
## а не в момент первого разряда (issue #50: 10 к/с на разряде).
const ZAP_WARM_STEPS := 3
var zap_warm := ZAP_WARM_STEPS
var hit_flash: ColorRect
var sonar_view: SonarView
var time := 0.0             ## секунды игры (для сонара и событий)
var power := Reactor.Console.new()   ## выбор на пульте энергии
var at_power := false              ## игрок у пульта энергии: крестовина правит доли
var power_panel: PowerPanel
var current := Helm.SeaCurrent.new()

var ocean: OceanView
var eco: EcoView            ## живой мир отмели (поток Б), связь — EcoLink
var eco_ship := EcoLink.ShipState.new()
var ship: Node3D            ## корабль: всё, что движется вместе с ним
var bridge: BridgeView
var rooms: RoomsView
var searchlight: SearchlightView
var hull: HullView          ## корпус снаружи (HullPlan), роторы и рули — по hull_motion
var hull_motion := HullMesh.Motion.new()
var light_on := true        ## прожектор включён (кнопка «Свет» за штурвалом)
var camera: Camera3D
var overlay: TouchOverlay
var hint: Label            ## строка состояния на приборах (Status), по строкам экрана
var message := Status.Message.new()
const SAT_MSG := "Вы за штурвалом"
var env: Environment
var qa: QaRunner           ## прогон сценария тестера, если он есть (docs/QA.md)


func _ready() -> void:
	_build_world()
	ocean = OceanView.new()
	ocean.name = "Отмель"
	add_child(ocean)
	eco = EcoView.new()
	eco.name = "Живой мир"
	eco.ground = Seabed.height
	add_child(eco)
	samples_view = SamplesView.new(samples)
	samples_view.name = "Образцы"
	add_child(samples_view)
	helm.ground = Seabed.height
	ship = Node3D.new()
	ship.name = "Корабль"
	add_child(ship)
	bridge = BridgeView.new()
	bridge.name = "Мостик"
	ship.add_child(bridge)
	zap_light = OmniLight3D.new()
	zap_light.name = "Вспышка разряда"
	zap_light.light_color = Color("5ef2d6")
	zap_light.light_cull_mask = OceanView.LAYER_WORLD
	zap_light.position = Vector3(0, 1.6, 8)
	zap_light.omni_range = Zap.BASE_RADIUS
	zap_light.light_energy = 0.001
	ship.add_child(zap_light)
	sonar_view = SonarView.new()
	bridge.add_child(sonar_view)
	rooms = RoomsView.new()
	rooms.name = "Отсеки"
	ship.add_child(rooms)
	crew_view = CrewView.new()
	ship.add_child(crew_view)
	crew_view.set_members(crew, me)
	walker.stand = layout.can_stand
	posts = Deck.posts()
	posts.append(Deck.Post.new("winch", Samples.POST_AT, Samples.POST_R, "Лебёдка"))
	for i in layout.doors.size():
		posts.append(Deck.Post.new("door%d" % i, Vector2(0.0, ShipLayout.DOOR_Z[i]), 1.2, "Открыть люк"))
	searchlight = SearchlightView.new()
	searchlight.name = "Прожектор"
	ship.add_child(searchlight)
	hull = HullView.new()
	hull.name = "Корпус"
	ship.add_child(hull)
	camera = Camera3D.new()
	camera.name = "Глаза"
	camera.fov = Deck.FOV
	camera.near = 0.05
	camera.far = 400.0
	ship.add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	ui.name = "Интерфейс"
	add_child(ui)
	hint = Label.new()
	hint.name = "Приборы"
	hint.position = Vector2(24, 14)
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_constant_override("line_spacing", -2)
	ui.add_child(hint)
	current.changed.connect(func(_i: int) -> void: say("Течение сменилось"))
	power_panel = PowerPanel.new()
	power_panel.name = "Пульт энергии"
	ui.add_child(power_panel)
	hit_flash = ColorRect.new()
	hit_flash.name = "Вспышка удара"
	hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_flash.color = Color(1.0, 0.36, 0.42, 0.0)
	ui.add_child(hit_flash)
	vitals.hit_taken.connect(_on_hit)
	vitals.destroyed.connect(_on_destroyed)
	overlay = TouchOverlay.new()
	overlay.name = "Управление"
	ui.add_child(overlay)
	reactor.message.connect(func(title: String, _text: String) -> void: say(title))
	airlock.message.connect(say)
	samples.message.connect(say)
	engine.message.connect(say)
	_place_ship()
	_place_camera()
	if QaRunner.pending():
		start_qa()


## Запустить сценарий тестера: из user://qa/scenario.json или из текста (тесты).
func start_qa(text: String = "") -> QaRunner:
	qa = QaRunner.new()
	qa.name = "Сценарий тестера"
	add_child(qa)
	qa.start(self, text)
	return qa


func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _process(dt: float) -> void:
	step(dt)


## Один шаг игры: ввод, игрок, корабль, вода. Вынесен из _process для тестов.
func step(dt: float) -> void:
	time += dt
	if qa:
		qa.tick(dt)
	var r := overlay.router
	var hold_valve := false
	var hold_winch := false
	if pilot.seated:
		helm.in_thrust = r.move.y
		helm.in_turn = r.move.x
		helm.in_vert = r.vert()
		if r.light_pressed:
			toggle_light()
		walker.look(overlay.look_points())
		if r.action_pressed:
			stand_up()
	elif at_power:
		helm.in_thrust = 0.0
		helm.in_turn = 0.0
		helm.in_vert = 0.0
		walker.look(overlay.look_points())
		power.nav(reactor, r.move, dt)
		if r.action_pressed:
			close_power()
	else:
		helm.in_thrust = 0.0
		helm.in_turn = 0.0
		helm.in_vert = 0.0
		walker.look(overlay.look_points())
		walker.walk(Vector2(r.move), dt)
		var post := Deck.nearest(posts, walker.x, walker.z)
		if post and r.action_pressed:
			use_post(post.id)
		hold_valve = post != null and post.id == "valve" and r.action_down
		hold_winch = post != null and post.id == "winch" and r.action_down
	layout.update(dt)
	airlock.update(dt)
	var ship_xf := Samples.ship_xform(helm.pos, helm.yaw)
	if (hold_winch or debug_winch) and airlock.fully_open():
		samples.hold(Samples.lock_point(ship_xf), dt)
	samples.update(dt)
	samples_view.sync()
	for p in posts:
		if p.id.begins_with("door"):
			p.label = "Закрыть люк" if layout.doors[int(p.id.substr(4))].open else "Открыть люк"
		elif p.id == "airlock":
			p.label = airlock.label()
		elif p.id == "winch":
			p.label = samples.label()
	current.update(dt)
	reactor.update(dt, Reactor.near_vent(helm.pos.x, helm.pos.z))
	engine.update(dt, reactor, hold_valve or debug_vent)
	helm.update(dt, reactor.k(Reactor.Sys.ENGINES), current.vel())
	hull_motion.update(dt, helm.in_thrust, helm.in_vert, reactor.k(Reactor.Sys.ENGINES))
	helm.speed = vitals.scrape(helm.bump / maxf(dt, 1e-4), helm.speed)
	if vitals.update(dt, helm.in_thrust, helm.in_vert, Searchlight.lit(light_on, reactor.k(Reactor.Sys.LAMP)), reactor.k(Reactor.Sys.LIFE)):
		light_on = false
		overlay.set_light(false)
		say("Прожектор погас: не хватает энергии")
	searchlight.apply(light_on, reactor.k(Reactor.Sys.LAMP))
	zap.update(dt)
	zap_warm = maxi(0, zap_warm - 1)
	if zap.flicker > 0.0:
		hit_flash.color = Color(0.37, 0.95, 0.84, zap.flicker / Zap.FLICKER * 0.4)
		zap_light.visible = true
		zap_light.omni_range = zap.radius
		zap_light.light_energy = 4.0 * zap.flicker / Zap.FLICKER
	else:
		hit_flash.color = Color(1.0, 0.36, 0.42, vitals.flash * 0.35)
		zap_light.visible = zap_warm > 0
	bridge.set_zap_lever(zap.flicker > 0.0)
	_step_eco(dt)
	for i in Reactor.Sys.size():
		bridge.set_slider(i, reactor.share[i] / float(Reactor.MAX))
	bridge.set_hatch(layout.doors[0].offset())
	sonar_view.show_state(sonar, helm.pos, helm.yaw, time, reactor.k(Reactor.Sys.SONAR) > 0.0)
	rooms.apply(layout, reactor, airlock, engine)
	var carry_c: Color = Samples.COLORS[samples.target.kind] if samples.target else Color.WHITE
	rooms.set_winch(samples.hook_local(Samples.ship_xform(helm.pos, helm.yaw)), samples.carrying(), carry_c)
	message.update(dt)
	me.follow(walker.x, walker.z, walker.yaw, pilot.seated, helm.turn, dt)
	crew_view.apply()
	_place_ship()
	_place_camera()
	_update_ui()
	r.end_frame()


## Короткая подпись на кнопке действия у поста.
const POST_BUTTON := {"helm": "Штурвал", "energy": "Энергия", "scanner": "Сканер", "sonar": "Сонар", "zap": "Разряд", "airlock": "Шлюз", "winch": "Лебёдка",
	"valve": "Вентиль", "scram": "Сброс"}


## Кнопка действия у поста.
func use_post(id: String) -> void:
	match id:
		"helm":
			sit_at_helm()
		"energy":
			open_power()
		"sonar":
			ping_sonar()
		"zap":
			fire_zap()
		"airlock":
			if samples.state != Samples.State.IDLE:
				say("Захват за бортом — шлюз не закрыть")
			else:
				airlock.toggle()
		"winch":
			var why := samples.why_not(airlock.fully_open(), Samples.lock_point(Samples.ship_xform(helm.pos, helm.yaw)))
			if why != "":
				say(why)
		"scram":
			engine.press(reactor)
		"scanner":
			say("Сканер: рядом никого")
		_ when id.begins_with("door"):
			var d: ShipLayout.Door = layout.doors[int(id.substr(4))]
			d.open = not d.open


## Поставить корабль над образцом n: шлюз в 8 м над ним, корабль стоит, шлюз открыт (сценарий тестера, снимки).
func park_over_sample(n: int) -> void:
	var smp: Samples.Sample = samples.all[clampi(n, 0, samples.all.size() - 1)]
	helm.speed = 0.0
	helm.vy = 0.0
	helm.pos = smp.pos + Vector3(0.0, 8.0 - Airlock.Y, 0.0) - Basis(Vector3.UP, helm.yaw) * Vector3(0.0, 0.0, Airlock.Z)
	airlock.open = true
	airlock.t = 1.0
	rooms.apply(layout, reactor, airlock, engine)
	_place_ship()


## Встать к пульту энергии: взгляд на пульт, крестовина правит доли, кнопка — закрыть.
func open_power() -> void:
	at_power = true
	walker.yaw = PI / 2.0   # пульт на левом борту (−X)
	walker.pitch = -0.3
	power_panel.show_for(reactor, power)


func close_power() -> void:
	at_power = false
	power_panel.visible = false


func toggle_light() -> void:
	if not light_on and vitals.energy < 3.0:
		say("Мало энергии: прожектор не включить")
		return
	light_on = not light_on
	searchlight.apply(light_on, reactor.k(Reactor.Sys.LAMP))
	overlay.set_light(light_on)
	say("Прожектор включён" if light_on else "Прожектор погашен")


## Сообщение на приборах, гаснет через 4,2 с.
func say(msg: String) -> void:
	message.say(msg)


## Импульс сонара: сила — доля «Сонар»; существ в этот же шаг сообщит живой мир (EcoLink.NEAR).
func ping_sonar() -> void:
	if reactor.k(Reactor.Sys.SONAR) > 0.0 and sonar.can_ping(time) and vitals.energy < Vitals.SONAR_COST:
		say("Мало энергии: для импульса нужно %d единиц" % int(Vitals.SONAR_COST))
		return
	var msg := sonar.ping(time, reactor.k(Reactor.Sys.SONAR))
	if msg == "Сонар: импульс":
		vitals.spend(Vitals.SONAR_COST)
		eco_ship.sonar_ping = true
		eco_ship.sonar_range = sonar.range_m
	if not msg.is_empty():
		say(msg)


## Разряд по корпусу: живой мир узнаёт о нём в этот же шаг (ShipState.zap, zap_radius).
func fire_zap() -> void:
	var msg := zap.fire(time, reactor.k(Reactor.Sys.ZAP), vitals)
	if zap.fired_at(time):
		eco_ship.zap = true
		eco_ship.zap_radius = zap.radius
	say(msg)


## Шаг живого мира: корабль отдаёт своё состояние, получает события (EcoLink) и решает, что с ними делать.
func _step_eco(dt: float) -> void:
	var s := eco_ship
	s.pos = helm.pos
	s.yaw = helm.yaw
	s.speed = helm.speed
	s.light_on = Searchlight.lit(light_on, reactor.k(Reactor.Sys.LAMP))
	s.light_range = Searchlight.range_m(reactor.k(Reactor.Sys.LAMP)) if s.light_on else 0.0
	s.hull_noise = engine.noise(clampf(absf(helm.speed) / 6.7, 0.0, 1.0))
	var events := eco.step(dt, s)
	if s.sonar_ping:
		sonar.take_contacts(events, helm.pos)
		say("Сонар: контактов %d" % sonar.blips.size())
	for e in events:
		on_eco_event(e)
	s.sonar_ping = false
	s.zap = false


## Событие живого мира (EcoLink). Пока — на приборы; урон корпусу и тревога — задачи потока А.
func on_eco_event(e: Dictionary) -> void:
	match e.get("type", ""):
		EcoLink.HIT:
			vitals.hit(roundi(float(e.get("damage", 0.0)) * 100.0), str(e.get("by", "")))
		EcoLink.DRAIN:
			vitals.drain_ext += float(e.get("units", 0.0))
		EcoLink.MESSAGE:
			say(str(e.get("text", "")))


func _on_hit(percent: int, kind: String) -> void:
	if kind == "scrape":
		say("Удар о дно: корпус −%d%%" % percent)
	elif kind.is_empty():
		say("Удар по корпусу: −%d%%" % percent)
	else:
		say("%s бьёт по корпусу: −%d%%" % [kind, percent])


## Корпус разрушен: забег проигран. Пока забега нет — подъём к старту с целым корпусом (как restart в браузере).
func _on_destroyed() -> void:
	if pilot.seated:
		stand_up()
	if at_power:
		close_power()
	helm.reset()
	vitals.reset()
	walker.reset()
	light_on = true
	overlay.set_light(true)
	say("Корпус разрушен. Ковчег поднят к началу спуска")


func sit_at_helm() -> void:
	pilot.sit(walker)
	overlay.set_pilot(true)
	say(SAT_MSG)


func stand_up() -> void:
	pilot.stand(walker)
	overlay.set_pilot(false)
	message.clear(SAT_MSG)


func _place_ship() -> void:
	ship.position = helm.pos
	ship.rotation = Vector3(0.0, helm.yaw, 0.0)
	hull.apply(hull_motion)
	bridge.set_wheel_turn(helm.turn)
	ocean.apply_water(env, helm.depth(), helm.pos)


func _place_camera() -> void:
	camera.position = pilot.eye(walker)
	if vitals.shake > 0.0:   # тряска после удара: детерминированная, затухает за 0,6 с
		var a := vitals.shake / 0.6 * 0.04
		camera.position += Vector3(sin(time * 61.0) * a, sin(time * 47.0 + 1.3) * a, 0.0)
	camera.rotation = Vector3(walker.pitch, walker.yaw, 0.0)


func _update_ui() -> void:
	if pilot.seated:
		overlay.set_action_label("Встать")
	elif at_power:
		overlay.set_action_label("Закрыть")
	else:
		var post := Deck.nearest(posts, walker.x, walker.z)
		var label := ""
		if post:
			label = POST_BUTTON.get(post.id, "Люк" if post.id.begins_with("door") else "")
		overlay.set_action_label(label)
	var font := hint.get_theme_font("font")
	var fs := hint.get_theme_font_size("font_size")
	var width := minf(900.0, get_viewport().get_visible_rect().size.x - 48.0)
	hint.text = "\n".join(Status.lines(status_parts(),
		func(t: String) -> float: return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, width))


## Части строки состояния: где игрок, глубина, ход, у штурвала — до дна, курс и прожектор, течение, пост рядом, сообщение.
func status_parts() -> Array:
	var parts: Array = []
	if not reactor.alert().is_empty():
		parts.append(reactor.alert())
	if reactor.alert().is_empty() and not vitals.warning().is_empty():
		parts.append(vitals.warning())
	parts.append("За штурвалом" if pilot.seated else ShipLayout.ROOM_NAMES[ShipLayout.room_at(walker.z)])
	parts.append("глубина %d м" % roundi(helm.depth()))
	parts.append("ход %s м/с" % _num(helm.speed))
	parts.append("корпус %d%%" % roundi(vitals.hull))
	parts.append("энергия %d" % floori(vitals.energy))
	if pilot.seated:
		parts.append("до дна %d м" % roundi(helm.pos.y - Seabed.height(helm.pos.x, helm.pos.z)))
		parts.append("курс %d°" % Status.course_deg(helm.yaw))
		parts.append("прожектор %s" % ("вкл" if light_on else "выкл"))
	if reactor.alert().is_empty():
		parts.append("реактор %d/%d" % [reactor.used(), reactor.limit()])
	parts.append("течение на %s %s м/с" % [Status.rumb(current.vel()), _num(Helm.SeaCurrent.SPEED)])
	if not airlock.closed():
		parts.append("шлюз открыт" if airlock.fully_open() else "шлюз в движении")
	if not pilot.seated and not at_power:
		var post := Deck.nearest(posts, walker.x, walker.z)
		if post:
			parts.append(post.label)
	if message.visible():
		parts.append(message.text)
	return parts


static func _num(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")


## Для tools/shot.gd: сесть за штурвал и провести корабль перед снимком (ключи pilot, thrust, turn, vert, secs).
func debug_setup(kv: Dictionary) -> void:
	if kv.get("pilot", "0") == "1":
		sit_at_helm()
	if kv.get("light", "1") == "0":
		toggle_light()
	if kv.get("power", "0") == "1":  # у пульта энергии
		walker.x = -3.9
		walker.z = -2.0
		open_power()
	if kv.get("ping", "0") == "1":  # импульс сонара с тремя пробными отметками (живого мира ещё нет)
		sonar.ping(time, 1.0)
		sonar.take_contacts([
			EcoLink.near("serpohvost", "серпохвост", helm.pos + Vector3(35, 0, -40), helm.pos),
			EcoLink.near("svetlyak", "светляк", helm.pos + Vector3(-50, 0, -20), helm.pos),
			EcoLink.near("veil", "вуаль", helm.pos + Vector3(10, 0, 60), helm.pos)], helm.pos)
		time += float(kv.get("age", "1.0"))
		sonar_view.show_state(sonar, helm.pos, helm.yaw, time, true)
	if kv.get("lock", "0") == "1":  # открытый шлюз трюма
		airlock.open = true
		airlock.t = 1.0
		rooms.apply(layout, reactor, airlock)
	if kv.has("mate"):  # mate=x,z,курс°[,роль 0…3] — ещё один член экипажа стоит на палубе; mate=helm — сидит за штурвалом
		var mate := Crew.Member.new(Crew.Role.SONAR)
		if kv["mate"] == "helm":
			mate.follow(0.0, Deck.SEAT_Z, 0.0, true, 0.0, 0.1)
		else:
			var m: PackedFloat64Array = kv["mate"].split_floats(",")
			if m.size() > 3:
				mate.role = int(m[3])
			mate.follow(m[0], m[1], deg_to_rad(m[2]) if m.size() > 2 else 0.0, false, 0.0, 0.1)
		crew.append(mate)
		crew_view.set_members(crew, me)
		crew_view.apply()
	if kv.has("hot"):  # hot=1 — перегрев (для снимка табло)
		reactor.start_hot(false)
		reactor.heat = float(kv["hot"])
	if kv.get("steam", "0") == "1":  # пар из вентиля и открытая крышка щитка (для снимка машинного)
		debug_vent = true
		engine.pressed = 30.0
		engine.lid = 1.0
	if kv.has("sample"):  # sample=n — корабль над образцом n, шлюз открыт; grab=<с> — столько держать кнопку у лебёдки
		park_over_sample(int(kv["sample"]))
		walker.x = Samples.POST_AT.x - 0.7
		walker.z = Samples.POST_AT.y + 0.3
		var lock := Samples.lock_point(Samples.ship_xform(helm.pos, helm.yaw))
		var held := float(kv.get("grab", "0"))
		debug_winch = held > 0.0 and held < Samples.GRAB_TIME
		while held > 0.0:
			samples.hold(lock, 0.05)
			samples.update(0.05)
			held -= 0.05
		rooms.set_winch(samples.hook_local(Samples.ship_xform(helm.pos, helm.yaw)), samples.carrying(),
			Samples.COLORS[samples.target.kind] if samples.target else Color.WHITE)
	if kv.has("ship"):  # ship=x,y,z — поставить корабль (y — высота, глубина со знаком минус)
		var p: PackedFloat64Array = kv["ship"].split_floats(",")
		helm.pos = Vector3(p[0], p[1], p[2])
		_place_ship()
	if kv.has("secs"):
		var secs := float(kv["secs"])
		var dt := 1.0 / 30.0
		for i in int(secs / dt):
			helm.in_thrust = float(kv.get("thrust", "0"))
			helm.in_turn = float(kv.get("turn", "0"))
			helm.in_vert = float(kv.get("vert", "0"))
			current.update(dt)
			helm.update(dt, 1.0, current.vel())
			hull_motion.update(dt, helm.in_thrust, helm.in_vert, 1.0)
		_place_ship()
		_place_camera()
		_update_ui()
	if kv.has("view"):  # view=x,y,z — камера снаружи в осях корабля, смотрит на середину корпуса (снимок корпуса)
		var v: PackedFloat64Array = kv["view"].split_floats(",")
		var out := Camera3D.new()
		out.fov = Deck.FOV
		out.far = 400.0
		add_child(out)
		out.global_position = ship.to_global(Vector3(v[0], v[1], v[2]))
		out.look_at(ship.to_global(Vector3(0.0, HullPlan.CENTER_Y, 10.0)))
		out.make_current()
