class_name Main
extends Node3D
## Сцена собирается из кода: отмель, корабль с мостиком, игрок на палубе или за штурвалом, экранное управление.
## Мир неподвижен, корабль (узел «Корабль») движется по Helm.Ship; камера — глаза игрока в осях корабля.

var walker := Deck.Walker.new()
var pilot := Deck.Pilot.new()
var layout := ShipLayout.new()
var posts: Array[Deck.Post] = []
var helm := Helm.Ship.new()
var reactor := Reactor.new()
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
	helm.ground = Seabed.height
	ship = Node3D.new()
	ship.name = "Корабль"
	add_child(ship)
	bridge = BridgeView.new()
	bridge.name = "Мостик"
	ship.add_child(bridge)
	rooms = RoomsView.new()
	rooms.name = "Отсеки"
	ship.add_child(rooms)
	walker.stand = layout.can_stand
	posts = Deck.posts()
	for i in layout.doors.size():
		posts.append(Deck.Post.new("door%d" % i, Vector2(0.0, ShipLayout.DOOR_Z[i]), 1.5, "Открыть люк"))
	searchlight = SearchlightView.new()
	searchlight.name = "Прожектор"
	ship.add_child(searchlight)
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
	overlay = TouchOverlay.new()
	overlay.name = "Управление"
	ui.add_child(overlay)
	reactor.message.connect(func(title: String, _text: String) -> void: say(title))
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
	if qa:
		qa.tick(dt)
	var r := overlay.router
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
	layout.update(dt)
	for p in posts:
		if p.id.begins_with("door"):
			p.label = "Закрыть люк" if layout.doors[int(p.id.substr(4))].open else "Открыть люк"
	current.update(dt)
	reactor.update(dt, Reactor.near_vent(helm.pos.x, helm.pos.z))
	helm.update(dt, reactor.k(Reactor.Sys.ENGINES), current.vel())
	searchlight.apply(light_on, reactor.k(Reactor.Sys.LAMP))
	_step_eco(dt)
	for i in Reactor.Sys.size():
		bridge.set_slider(i, reactor.share[i] / float(Reactor.MAX))
	bridge.set_hatch(layout.doors[0].offset())
	rooms.apply(layout, reactor)
	message.update(dt)
	_place_ship()
	_place_camera()
	_update_ui()
	r.end_frame()


## Короткая подпись на кнопке действия у поста.
const POST_BUTTON := {"helm": "Штурвал", "energy": "Энергия", "scanner": "Сканер"}


## Кнопка действия у поста.
func use_post(id: String) -> void:
	match id:
		"helm":
			sit_at_helm()
		"energy":
			open_power()
		"scanner":
			say("Сканер: рядом никого")
		_ when id.begins_with("door"):
			var d: ShipLayout.Door = layout.doors[int(id.substr(4))]
			d.open = not d.open


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
	light_on = not light_on
	searchlight.apply(light_on, reactor.k(Reactor.Sys.LAMP))
	overlay.set_light(light_on)
	say("Прожектор включён" if light_on else "Прожектор погашен")


## Сообщение на приборах, гаснет через 4,2 с.
func say(msg: String) -> void:
	message.say(msg)


## Шаг живого мира: корабль отдаёт своё состояние, получает события (EcoLink) и решает, что с ними делать.
func _step_eco(dt: float) -> void:
	var s := eco_ship
	s.pos = helm.pos
	s.yaw = helm.yaw
	s.speed = helm.speed
	s.light_on = Searchlight.lit(light_on, reactor.k(Reactor.Sys.LAMP))
	s.light_range = Searchlight.range_m(reactor.k(Reactor.Sys.LAMP)) if s.light_on else 0.0
	s.hull_noise = clampf(absf(helm.speed) / 6.7, 0.0, 1.0)
	for e in eco.step(dt, s):
		on_eco_event(e)
	s.sonar_ping = false
	s.zap = false


## Событие живого мира (EcoLink). Пока — на приборы; урон корпусу и тревога — задачи потока А.
func on_eco_event(e: Dictionary) -> void:
	match e.get("type", ""):
		EcoLink.HIT:
			say("Удар по корпусу: %s" % e.get("by", "?"))
		EcoLink.MESSAGE:
			say(str(e.get("text", "")))


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
	bridge.set_wheel_turn(helm.turn)
	ocean.apply_water(env, helm.depth(), helm.pos)


func _place_camera() -> void:
	camera.position = pilot.eye(walker)
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
	parts.append("За штурвалом" if pilot.seated else ShipLayout.ROOM_NAMES[ShipLayout.room_at(walker.z)])
	parts.append("глубина %d м" % roundi(helm.depth()))
	parts.append("ход %s м/с" % _num(helm.speed))
	if pilot.seated:
		parts.append("до дна %d м" % roundi(helm.pos.y - Seabed.height(helm.pos.x, helm.pos.z)))
		parts.append("курс %d°" % Status.course_deg(helm.yaw))
		parts.append("прожектор %s" % ("вкл" if light_on else "выкл"))
	if reactor.alert().is_empty():
		parts.append("реактор %d/%d" % [reactor.used(), reactor.limit()])
	parts.append("течение на %s %s м/с" % [Status.rumb(current.vel()), _num(Helm.SeaCurrent.SPEED)])
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
	if kv.has("hot"):  # hot=1 — перегрев (для снимка табло)
		reactor.start_hot(false)
		reactor.heat = float(kv["hot"])
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
		_place_ship()
		_place_camera()
		_update_ui()
