class_name Main
extends Node3D
## Сцена собирается из кода: отмель, корабль с мостиком, игрок на палубе или за штурвалом, экранное управление.
## Мир неподвижен, корабль (узел «Корабль») движется по Helm.Ship; камера — глаза игрока в осях корабля.

var walker := Deck.Walker.new()
var pilot := Deck.Pilot.new()
var posts: Array[Deck.Post] = Deck.posts()
var helm := Helm.Ship.new()
var current := Helm.SeaCurrent.new()

var ocean: OceanView
var ship: Node3D            ## корабль: всё, что движется вместе с ним
var bridge: BridgeView
var camera: Camera3D
var overlay: TouchOverlay
var hint: Label
var env: Environment


func _ready() -> void:
	_build_world()
	ocean = OceanView.new()
	ocean.name = "Отмель"
	add_child(ocean)
	helm.ground = Seabed.height
	ship = Node3D.new()
	ship.name = "Корабль"
	add_child(ship)
	bridge = BridgeView.new()
	bridge.name = "Мостик"
	ship.add_child(bridge)
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
	hint.position = Vector2(24, 16)
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 6)
	ui.add_child(hint)
	overlay = TouchOverlay.new()
	overlay.name = "Управление"
	ui.add_child(overlay)
	_place_ship()
	_place_camera()


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
	var r := overlay.router
	if pilot.seated:
		helm.in_thrust = r.move.y
		helm.in_turn = r.move.x
		helm.in_vert = r.vert()
		walker.look(overlay.look_points())
		if r.action_pressed:
			stand_up()
	else:
		helm.in_thrust = 0.0
		helm.in_turn = 0.0
		helm.in_vert = 0.0
		walker.look(overlay.look_points())
		walker.walk(Vector2(r.move), dt)
		var post := Deck.nearest(posts, walker.x, walker.z)
		if post and r.action_pressed and post.id == "helm":
			sit_at_helm()
	current.update(dt)
	helm.update(dt, 1.0, current.vel())
	_place_ship()
	_place_camera()
	_update_ui()
	r.end_frame()


func sit_at_helm() -> void:
	pilot.sit(walker)
	overlay.set_pilot(true)


func stand_up() -> void:
	pilot.stand(walker)
	overlay.set_pilot(false)


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
		var below := helm.pos.y - Seabed.height(helm.pos.x, helm.pos.z)
		hint.text = "За штурвалом · глубина %d м · ход %.1f м/с · до дна %d м" % [roundi(helm.depth()), helm.speed, roundi(below)]
	else:
		var post := Deck.nearest(posts, walker.x, walker.z)
		overlay.set_action_label("Штурвал" if post else "")
		hint.text = post.label if post else "Мостик · глубина %d м" % roundi(helm.depth())


## Для tools/shot.gd: сесть за штурвал и провести корабль перед снимком (ключи pilot, thrust, turn, vert, secs).
func debug_setup(kv: Dictionary) -> void:
	if kv.get("pilot", "0") == "1":
		sit_at_helm()
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
