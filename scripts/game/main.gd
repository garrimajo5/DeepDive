class_name Main
extends Node3D
## Сцена собирается из кода: мостик «Ковчега-7», игрок на палубе, экранное управление.

var walker := Deck.Walker.new()
var posts: Array[Deck.Post] = Deck.posts()
var ship: Node3D            ## корабль: всё, что движется вместе с ним
var bridge: BridgeView
var camera: Camera3D
var overlay: TouchOverlay
var hint: Label
var env: Environment


func _ready() -> void:
	_build_world()
	ship = Node3D.new()
	ship.name = "Корабль"
	add_child(ship)
	bridge = BridgeView.new()
	bridge.name = "Мостик"
	ship.add_child(bridge)
	camera = Camera3D.new()
	camera.name = "Глаза"
	camera.fov = 70.0
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
	_place_camera()


func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Seabed.Water.fog_color(20.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.7, 0.75)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _process(dt: float) -> void:
	var r := overlay.router
	walker.look(overlay.look_points())
	walker.walk(Vector2(r.move), dt)
	var post := Deck.nearest(posts, walker.x, walker.z)
	overlay.set_action_label(post.label if post else "")
	hint.text = post.label if post else ""
	_place_camera()
	r.end_frame()


func _place_camera() -> void:
	camera.position = Vector3(walker.x, Deck.Walker.EYE, walker.z)
	camera.rotation = Vector3(walker.pitch, walker.yaw, 0.0)
