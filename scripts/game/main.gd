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
var breach := Breach.new()     ## событие «пробоина»: струя, вода, сварка удержанием
var silt := Silt.new()         ## событие «сонарная тьма»: облака ила (на дне от удара, у Края отмели — оползни)
var silt_view: SiltView
var run := Run.new()           ## маршрут забега: выбор у голостола, точки по местам отмели
var breach_view: BreachView
var debug_weld := false        ## снимок: сварку держат без пальца
var save := SaveGame.new()     ## груз трюма, поднятые образцы и изученные виды в user:// (js/save.js)
var scanner := Scanner.new()   ## сканер биолога: цели от живого мира, изученные виды
var at_scanner := false        ## игрок у поста «Сканер»: мир шлёт цели (ShipState.scan_range)
var journal_page := 0          ## страница журнала лаборатории: 0 — сводка, дальше карточки видов (Lab.page_lines)
var engine := EngineRoom.new()   ## машинное: вентиль сброса пара и щиток «Аварийный сброс»
var debug_vent := false          ## снимок: вентиль держат без пальца
var debug_winch := false         ## снимок: кнопку у лебёдки держат без пальца
var zap_light: OmniLight3D   ## вспышка разряда вокруг корпуса (за бортом)
## Первые кадры вспышка горит почти без света: шейдеры дна и корпуса со светом от неё собираются при старте,
## а не в момент первого разряда (issue #50: 10 к/с на разряде).
const ZAP_WARM_STEPS := 3
var zap_warm := ZAP_WARM_STEPS
var hit_flash: ColorRect
var visor: ColorRect          ## щиток сварщика: затемнение, пока свой игрок варит (Breach.VISOR)
var sonar_view: SonarView
var time := 0.0             ## секунды игры (для сонара и событий)
var power := Reactor.Console.new()   ## выбор на пульте энергии
var at_power := false              ## игрок у пульта энергии: крестовина правит доли
var press_post := ""               ## пост, у которого только что нажали кнопку (руки на нём CrewHands.PRESS с)
var press_t := 0.0
var power_panel: PowerPanel
var at_vote := false               ## игрок решает у голостола «глубже или наверх» (или смотрит итог)
var vote_panel: VotePanel
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
	silt_view = SiltView.new()
	add_child(silt_view)
	eco = EcoView.new()
	eco.name = "Живой мир"
	eco.ground = Seabed.height
	eco.world.scanned = scanner.is_scanned
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
	breach_view = BreachView.new(breach)
	ship.add_child(breach_view)
	crew_view = CrewView.new()
	ship.add_child(crew_view)
	crew_view.set_members(crew, me)
	walker.stand = layout.can_stand
	posts = Deck.posts()
	posts.append(Deck.Post.new("winch", Samples.POST_AT, Samples.POST_R, "Лебёдка"))
	posts.append(Deck.Post.new("breach", breach.post_at(), Breach.POST_R, "Сварка"))
	posts.append(Deck.Post.new("route", ROUTE_POST, ROUTE_POST_R, run.label()))
	posts.append_array(Lab.posts())
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
	me.smooth_lean = true   # камера в голове: наклон к посту плавный
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
	vote_panel = VotePanel.new()
	vote_panel.name = "Решение экипажа"
	ui.add_child(vote_panel)
	hit_flash = ColorRect.new()
	hit_flash.name = "Вспышка удара"
	hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_flash.color = Color(1.0, 0.36, 0.42, 0.0)
	ui.add_child(hit_flash)
	visor = ColorRect.new()
	visor.name = "Щиток сварщика"
	visor.set_anchors_preset(Control.PRESET_FULL_RECT)
	visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visor.color = Breach.VISOR
	visor.visible = false
	ui.add_child(visor)
	vitals.hit_taken.connect(_on_hit)
	vitals.destroyed.connect(_on_destroyed)
	overlay = TouchOverlay.new()
	overlay.name = "Управление"
	ui.add_child(overlay)
	reactor.message.connect(func(title: String, _text: String) -> void: say(title))
	airlock.message.connect(say)
	samples.message.connect(say)
	engine.message.connect(say)
	breach.message.connect(say)
	if QaRunner.pending():   # прогон тестера — всегда с чистого трюма и без записи
		save.path = ""
	save.load_into(samples, scanner)
	_begin_run()
	samples.changed.connect(save.mark)
	scanner.changed.connect(save.mark)
	scanner.message.connect(say)
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


## Игру сворачивают или закрывают — несохранённое записать сразу.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		save.flush(samples, scanner)


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
	var hold_weld := false
	var hold_scan := false
	at_scanner = false
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
	elif at_vote:
		helm.in_thrust = 0.0
		helm.in_turn = 0.0
		helm.in_vert = 0.0
		walker.look(overlay.look_points())
		var choice := "" if run.ended else run.vote_nav(r.move)
		if choice != "":
			decide(choice)
		if r.action_pressed:
			close_vote()
	else:
		helm.in_thrust = 0.0
		helm.in_turn = 0.0
		helm.in_vert = 0.0
		walker.look(overlay.look_points())
		walker.speed_k = breach.slow(ShipLayout.room_at(walker.z))
		walker.walk(Vector2(r.move), dt)
		var post := Deck.nearest(posts, walker.x, walker.z)
		if post and r.action_pressed:
			use_post(post.id)
		hold_valve = post != null and post.id == "valve" and r.action_down
		hold_winch = post != null and post.id == "winch" and r.action_down
		hold_weld = post != null and post.id == "breach" and r.action_down
		at_scanner = post != null and post.id == "scanner"
		hold_scan = at_scanner and r.action_down
	layout.update(dt)
	airlock.update(dt)
	var ship_xf := Samples.ship_xform(helm.pos, helm.yaw)
	if (hold_winch or debug_winch) and airlock.fully_open():
		samples.hold(Samples.lock_point(ship_xf), dt)
	samples.update(dt)
	samples_view.sync()
	save.tick(dt, samples, scanner)
	if hold_scan:
		scanner.hold(dt)
	scanner.update(dt)
	if hold_weld or debug_weld:
		breach.hold(dt)
	for p in posts:
		if p.id.begins_with("door"):
			p.label = "Закрыть люк" if layout.doors[int(p.id.substr(4))].open else "Открыть люк"
		elif p.id == "airlock":
			p.label = airlock.label()
		elif p.id == "winch":
			p.label = samples.label()
		elif p.id == "breach":
			p.at = breach.post_at()
			p.label = breach.label()
		elif p.id == "scanner":
			p.label = scanner.label()
		elif p.id == "route":
			p.label = run.label()
		elif p.id.begins_with("flask"):
			p.label = Lab.flask_label(samples.cargo, int(p.id.substr(5)))
	current.update(dt)
	var silt_msg := silt.update(dt, helm.pos, current.vel())
	if not silt_msg.is_empty():
		say(silt_msg)
	silt_view.apply(silt, time, helm.pos, helm.yaw)
	var run_msg := run.update(helm.pos.x, helm.pos.z)
	if not run_msg.is_empty():
		say(run_msg)
	reactor.update(dt, Reactor.near_vent(helm.pos.x, helm.pos.z))
	engine.update(dt, reactor, hold_valve or debug_vent)
	helm.update(dt, reactor.k(Reactor.Sys.ENGINES), current.vel())
	hull_motion.update(dt, helm.in_thrust, helm.in_vert, reactor.k(Reactor.Sys.ENGINES))
	helm.speed = vitals.scrape(helm.bump / maxf(dt, 1e-4), helm.speed)
	if vitals.update(dt, helm.in_thrust, helm.in_vert, Searchlight.lit(light_on, reactor.k(Reactor.Sys.LAMP)), reactor.k(Reactor.Sys.LIFE)):
		light_on = false
		overlay.set_light(false)
		say("Прожектор погас: не хватает энергии")
	vitals.hull = breach.update(dt, reactor.k(Reactor.Sys.LIFE), vitals.hull)
	breach_view.apply()
	_hands(dt, hold_valve, hold_winch, hold_scan)
	if breach.welding and breach.active:   # свой игрок варит: резак в руке, щиток опущен
		me.weld(breach.active.p, breach.active.n)
	else:
		me.weld(Vector3.INF)
	visor.visible = me.welding()
	breach.end_step()
	searchlight.apply(light_on, reactor.k(Reactor.Sys.LAMP), silt.beam_k())
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
	bridge.set_zap_lever(zap.lever_deg(time), zap.ready(time))
	_step_eco(dt)
	for i in Reactor.Sys.size():
		bridge.set_slider(i, reactor.share[i] / float(Reactor.MAX))
	bridge.set_hatch(layout.doors[0].offset())
	sonar_view.show_state(sonar, helm.pos, helm.yaw, time, reactor.k(Reactor.Sys.SONAR) > 0.0, silt.noise(time))
	sonar_view.show_waypoint(run.waypoint())
	rooms.apply(layout, reactor, airlock, engine)
	var carry_c: Color = Samples.COLORS[samples.target.kind] if samples.target else Color.WHITE
	rooms.set_winch(samples.hook_local(Samples.ship_xform(helm.pos, helm.yaw)), samples.carrying(), carry_c)
	rooms.set_lab(Lab.contents(samples.cargo), Lab.page_lines(samples, scanner, journal_page), time)
	bridge.set_scanner_screen(scanner.screen_lines())
	message.update(dt)
	me.follow(walker.x, walker.z, walker.yaw, pilot.seated, helm.turn, dt)
	me.ease_lean(dt)
	crew_view.apply()
	_place_ship()
	_place_camera()
	_update_ui()
	r.end_frame()


## Короткая подпись на кнопке действия у поста.
const POST_BUTTON := {"helm": "Штурвал", "energy": "Энергия", "scanner": "Сканер", "sonar": "Сонар", "zap": "Разряд", "airlock": "Шлюз", "winch": "Лебёдка",
	"valve": "Вентиль", "scram": "Сброс", "breach": "Сварка", "journal": "Журнал", "route": "Маршрут"}
## Где встать у пульта энергии (у поста «energy») и куда смотреть, рад: ниже — ползунки и рука на выбранном.
const POWER_STAND := Vector2(-3.9, -2.0)
const POWER_PITCH := -0.6
## Пост «Маршрут» — у правого борта голостола (с остальных сторон стол — сонар).
const ROUTE_POST := Vector2(1.5, BridgeProps.TABLE_Z)
const ROUTE_POST_R := 0.6


## Руки своего игрока на посте (CrewHands): у пульта энергии, пока держит вентиль, лебёдку или сканер; после
## нажатия у голостола, рычага и щитка — ещё CrewHands.PRESS секунд.
func _hands(dt: float, valve: bool, winch: bool, scan: bool) -> void:
	press_t = maxf(press_t - dt, 0.0)
	var g := CrewHands.none()
	if pilot.seated:
		pass
	elif at_power:
		g = CrewHands.energy(power.sel, reactor.share[power.sel] / float(Reactor.MAX))
	elif valve:
		g = CrewHands.valve()
	elif winch:
		g = CrewHands.winch(walker.x, walker.z)
	elif scan:
		g = CrewHands.scanner()
	elif press_t > 0.0:
		match press_post:
			"sonar", "route":
				g = CrewHands.table(walker.x, walker.z)
			"zap":
				g = CrewHands.lever(zap.lever_deg(time))
			"scram":
				g = CrewHands.scram()
	me.hold(g[0], g[1])


## Кнопка действия у поста.
func use_post(id: String) -> void:
	if id in ["sonar", "zap", "scram", "route"]:
		press_post = id
		press_t = CrewHands.PRESS
	match id:
		"helm":
			sit_at_helm()
		"energy":
			open_power()
		"sonar":
			ping_sonar()
		"route":
			if run.done:
				open_vote()
			else:
				say(run.cycle())
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
			scanner.press()
		"journal":   # листать: сводка → карточки видов → сводка
			journal_page = (journal_page + 1) % Lab.pages(scanner)
			say(Lab.journal_info(samples) if journal_page == 0 else Lab.card_info(scanner, Lab.cards(scanner)[journal_page - 1]))
		_ when id.begins_with("flask"):
			say(Lab.flask_info(samples.cargo, int(id.substr(5))))
		_ when id.begins_with("door"):
			var d: ShipLayout.Door = layout.doors[int(id.substr(4))]
			d.open = not d.open


## Открыть пробоину в месте n и поставить игрока у неё лицом к борту (сценарий тестера, снимки).
func open_breach(n: int) -> void:
	var s: Breach.Spot = breach.all[clampi(n, 0, breach.all.size() - 1)]
	breach.cd = 0.0
	if breach.active:
		breach.active = null
	breach.start(s)
	if pilot.seated:
		stand_up()
	walker.x = s.at.x
	walker.z = s.at.y
	walker.yaw = atan2(s.n.x, s.n.z)
	walker.pitch = atan2(s.p.y - Deck.Walker.EYE, Vector2(s.p.x, s.p.z).distance_to(s.at))   # взгляд на пробоину
	breach_view.apply()


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
	var at: Vector2 = POWER_STAND   # шаг к пульту: из радиуса поста руки не достали бы до ползунков (#107)
	walker.x = at.x
	walker.z = at.y
	walker.yaw = PI / 2.0   # пульт на левом борту (−X)
	walker.pitch = POWER_PITCH   # взгляд на ползунки: рука на выбранном видна
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


## Пройти выбранный маршрут разом (или первый, если не выбран): сценарий тестера и снимки.
func complete_route() -> void:
	if run.route < 0:
		run.choose(0)
	for k in Run.ROUTES[run.route]["places"]:
		var p := Run.place_xz(k)
		say(run.update(p.x, p.y))


## Импульс сонара: сила — доля «Сонар»; существ в этот же шаг сообщит живой мир (EcoLink.NEAR).
func ping_sonar() -> void:
	if reactor.k(Reactor.Sys.SONAR) > 0.0 and sonar.can_ping(time) and vitals.energy < Vitals.SONAR_COST:
		say("Мало энергии: для импульса нужно %d единиц" % int(Vitals.SONAR_COST))
		return
	var msg := sonar.ping(time, reactor.k(Reactor.Sys.SONAR))
	if msg == "Сонар: импульс":
		vitals.spend(Vitals.SONAR_COST)
		eco_ship.sonar_ping = true   # существа слышат импульс и в иле
		eco_ship.sonar_range = sonar.range_m
		if silt.jam_ping(time):
			sonar.jammed = true
			msg = Silt.JAM_MSG
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
	s.light_range = Searchlight.range_m(reactor.k(Reactor.Sys.LAMP)) * silt.beam_k() if s.light_on else 0.0
	s.hull_noise = engine.noise(clampf(absf(helm.speed) / 6.7, 0.0, 1.0))
	s.scan_range = Scanner.RANGE if at_scanner else 0.0
	var events := eco.step(dt, s)
	scanner.take(events if at_scanner else [])
	if s.sonar_ping and not sonar.jammed:
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
		EcoLink.OBSERVE:   # наблюдение в журнал (handleEvents в js/game.js)
			var sp := str(e.get("species", ""))
			var fresh := scanner.observe(sp, str(e.get("note", "")))
			var text := str(e.get("text", ""))
			if text != "":
				say(text)
			elif fresh:
				say("Новое наблюдение: %s" % Species.called(sp, Species.Case.NOM, scanner.is_scanned(sp)))


func _on_hit(percent: int, kind: String) -> void:
	if kind == "scrape":   # удар о дно поднимает ил
		silt.on_scrape(helm.pos, Seabed.height(helm.pos.x, helm.pos.z))
	if breach.on_hit(percent, vitals.hull):
		return   # о пробоине скажет Breach
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
	say("Корпус разрушен. Ковчег поднят к началу спуска")
	_restart()


## Корабль у начала спуска, целый и заряженный, забег с нуля (корпус разрушен или новый забег после итога).
func _restart() -> void:
	if at_vote:
		at_vote = false
		vote_panel.visible = false
	helm.reset()
	vitals.reset()
	breach.reset()
	silt.reset()
	walker.reset()
	light_on = true
	overlay.set_light(true)
	_begin_run()


func _begin_run() -> void:
	run.begin(time, samples.cargo.size(), scanner.scanned.size(), breach.count)


## У голостола после пройденного маршрута: мнения ролей, крестовина — решение, кнопка — отложить.
func open_vote() -> void:
	at_vote = true
	run.open_vote()
	vote_panel.show_vote(run.depth, Run.opinions(vitals.hull, vitals.energy, reactor.hot, silt.inside != null,
		samples.cargo.size()))


func close_vote() -> void:
	at_vote = false
	vote_panel.visible = false
	if run.ended:
		_restart()
		say("Новый забег: Ковчег у начала спуска")


## Решение экипажа: "deep" — следующий спуск, "up" — итог забега на экране.
func decide(choice: String) -> void:
	if choice == "deep":
		at_vote = false
		vote_panel.visible = false
		say(run.go_deeper())
		return
	var rows := run.finish(time, samples.cargo.size(), scanner.scanned.size(), breach.count, vitals.hull)
	vote_panel.show_results(rows, run.score)
	say("Экипаж поднялся наверх: очки %d" % run.score)


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
	ocean.apply_water(env, helm.depth(), helm.pos, silt.k)


func _place_camera() -> void:
	camera.position = pilot.eye(walker) + me.eye_offset()   # наклон к посту — камера в голове
	if vitals.shake > 0.0:   # тряска после удара: детерминированная, затухает за 0,6 с
		var a := vitals.shake / 0.6 * 0.04
		camera.position += Vector3(sin(time * 61.0) * a, sin(time * 47.0 + 1.3) * a, 0.0)
	camera.rotation = Vector3(walker.pitch, walker.yaw, 0.0)


func _update_ui() -> void:
	if pilot.seated:
		overlay.set_action_label("Встать")
	elif at_power:
		overlay.set_action_label("Закрыть")
	elif at_vote:
		overlay.set_action_label("Дальше" if run.ended else "Позже")
	else:
		var post := Deck.nearest(posts, walker.x, walker.z)
		var label := ""
		if post:
			label = POST_BUTTON.get(post.id, "Люк" if post.id.begins_with("door") else "Колба" if post.id.begins_with("flask") else "")
		overlay.set_action_label(label)
	var font := hint.get_theme_font("font")
	var fs := hint.get_theme_font_size("font_size")
	var width := minf(900.0, get_viewport().get_visible_rect().size.x - 48.0)
	hint.text = "\n".join(Status.lines(status_parts(),
		func(t: String) -> float: return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, width))


## Части строки состояния: где игрок, глубина, ход, у штурвала — до дна, курс и прожектор, течение, пост рядом, сообщение.
func status_parts() -> Array:
	var parts: Array = []
	var alarm := Status.alarm([breach.status(), reactor.alert(), silt.alarm(), vitals.warning()])
	if not alarm.is_empty():
		parts.append(alarm)
	parts.append("За штурвалом" if pilot.seated else ShipLayout.ROOM_NAMES[ShipLayout.room_at(walker.z)])
	parts.append("глубина %d м" % roundi(helm.depth()))
	parts.append("ход %s м/с" % _num(helm.speed))
	parts.append("корпус %d%%" % roundi(vitals.hull))
	parts.append("энергия %d" % floori(vitals.energy))
	if pilot.seated:
		parts.append("до дна %d м" % roundi(helm.pos.y - Seabed.height(helm.pos.x, helm.pos.z)))
		parts.append("курс %d°" % Status.course_deg(helm.yaw))
		parts.append("прожектор %s" % ("вкл" if light_on else "выкл"))
	parts.append(run.status(helm.pos.x, helm.pos.z))
	if reactor.alert().is_empty():
		parts.append("реактор %d/%d" % [reactor.used(), reactor.limit()])
	parts.append("течение на %s %s м/с" % [Status.rumb(current.vel()), _num(Helm.SeaCurrent.SPEED)])
	if not airlock.closed():
		parts.append("шлюз открыт" if airlock.fully_open() else "шлюз в движении")
	if not pilot.seated and not at_power and not at_vote:
		var post := Deck.nearest(posts, walker.x, walker.z)
		if post:
			parts.append(post.label)
	if message.visible():
		parts.append(message.text)
	return parts


static func _num(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")


## Облако ила вокруг корабля, как от удара о дно (сценарий тестера, снимки).
func open_silt() -> void:
	var cl := silt.spawn(helm.pos, Silt.SCRAPE_R, Silt.SCRAPE_LIFE, "scrape")
	cl.life = Silt.SCRAPE_LIFE - 3.0   # уже густое
	silt.update(0.0, helm.pos, Vector3.ZERO)
	silt.k = 1.0
	silt_view.apply(silt, time, helm.pos, helm.yaw)
	_place_ship()


## Ещё один член экипажа на палубе (снимки и сценарий тестера, пока нет сети): место, курс (рад), роль, внешность.
func add_mate(x: float, z: float, yaw: float, role: int, look: int, seated: bool = false) -> Crew.Member:
	var mate := Crew.Member.new(role)
	mate.look = look
	mate.follow(x, z, yaw, seated, 0.0, 0.1)
	crew.append(mate)
	crew_view.set_members(crew, me)
	crew_view.apply()
	return mate


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
	if kv.get("zap", "0") == "1":  # разряд: рычаг внизу, шкала готовности погашена
		fire_zap()
	if kv.get("lock", "0") == "1":  # открытый шлюз трюма
		airlock.open = true
		airlock.t = 1.0
		rooms.apply(layout, reactor, airlock)
	if kv.has("mate"):  # mate=x,z,курс°[,роль 0…3[,внешность 0…1]] — ещё один член экипажа стоит на палубе; mate=helm — сидит за штурвалом
		if kv["mate"] == "helm":
			add_mate(0.0, Deck.SEAT_Z, 0.0, Crew.Role.SONAR, 0, true)
		else:
			var m: PackedFloat64Array = kv["mate"].split_floats(",")
			add_mate(m[0], m[1], deg_to_rad(m[2]) if m.size() > 2 else 0.0, int(m[3]) if m.size() > 3 else Crew.Role.SONAR,
				int(m[4]) if m.size() > 4 else 1)
	if kv.get("silt", "0") == "1":  # silt=1 — корабль в облаке ила (снимок сонарной тьмы); с ping=1 — импульс завяз
		open_silt()
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
	if kv.has("cargo"):  # cargo=0,2,1 — виды образцов в трюме (и в колбах лаборатории)
		samples.cargo.clear()
		for k in kv["cargo"].split(",", false):
			samples.cargo.append([clampi(int(k), 0, Samples.NAMES.size() - 1), -1])
		rooms.set_lab(Lab.contents(samples.cargo), Lab.page_lines(samples, scanner, journal_page), time)
	if kv.has("observe"):  # observe=fish:flee,pred:ping — наблюдения в журнале; scanned=fish,pred — изученные виды;
		# journal=n — страница журнала (0 — сводка)
		for pair in kv["observe"].split(",", false):
			var kn: PackedStringArray = pair.split(":")
			if kn.size() == 2:
				scanner.observe(kn[0], kn[1])
	if kv.has("scanned"):
		for id in kv["scanned"].split(",", false):
			scanner.scanned[id] = true
	if kv.has("route"):   # маршрут n (0…2) выбран у голостола
		run.choose(int(kv["route"]))
	if kv.get("vote", "") in ["1", "up"]:   # маршрут пройден, решение у голостола; vote=up — итог забега
		complete_route()
		open_vote()
		if kv["vote"] == "up":
			decide("up")
	if kv.has("journal"):
		journal_page = clampi(int(kv["journal"]), 0, Lab.pages(scanner) - 1)
		rooms.set_lab(Lab.contents(samples.cargo), Lab.page_lines(samples, scanner, journal_page), time)
	if kv.has("breach"):  # breach=n — пробоина в месте n (0 мостик, 1 коридор, 2 лаборатория, 3 машинное), игрок у неё;
		# weld=<доля> — шов заварен на долю (1 — заварен, шов горячий); water=<м> — вода на полу
		open_breach(int(kv["breach"]))
		var w := float(kv.get("weld", "0"))
		if w >= 1.0:
			breach.hold(1.0 / Breach.WELD_RATE)
		elif w > 0.0:
			breach.weld = w
			debug_weld = true
		if kv.has("water"):
			breach.water = float(kv["water"])
		breach.time = 0.25
		breach_view.apply()
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
