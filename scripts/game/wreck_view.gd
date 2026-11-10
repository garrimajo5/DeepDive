class_name WreckView
extends CanvasLayer
## Шторка «Корпус разрушен» ART-036 поверх живой сцены (`main.wreck_view`): виньетка, трещины во весь экран, заголовок
## и подпись, сплошная шторка в конце. Время и доли — `Wreck`. Слой выше крестовины и кнопки (они скрыты на это
## время), ниже заставки прогрева. Пока шторки нет — корень скрыт (прогрев показывает его на кадр).

const LAYER := 90

var root: Control
var vignette: ColorRect
var cracks: TextureRect
var title: Label
var sub: Label
var solid: ColorRect
var shown_t := -1.0   ## время шторки последнего show (для тестов)


func _init() -> void:
	name = "Корпус разрушен"
	layer = LAYER
	root = Control.new()
	root.name = "Шторка"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	add_child(root)
	vignette = ColorRect.new()
	vignette.name = "Виньетка"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/wreck_vignette.gdshader")
	vignette.material = mat
	root.add_child(vignette)
	cracks = TextureRect.new()
	cracks.name = "Трещины"
	cracks.texture = load(Wreck.CRACKS)
	cracks.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cracks.stretch_mode = TextureRect.STRETCH_SCALE   # растянута на весь экран (заметка художника)
	cracks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cracks)
	title = _label(Wreck.TITLE, Wreck.AMBER)
	sub = _label(Wreck.SUB, Wreck.INK)
	solid = ColorRect.new()
	solid.name = "Сплошная"
	solid.set_anchors_preset(Control.PRESET_FULL_RECT)
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	solid.color = Wreck.DARK
	root.add_child(solid)


func _ready() -> void:
	get_viewport().size_changed.connect(layout)
	layout()


## Кадр шторки во время t (< 0 — скрыть).
func show_at(t: float) -> void:
	shown_t = t
	var on := t >= 0.0 and t < Wreck.END
	root.visible = on
	if not on:
		return
	(vignette.material as ShaderMaterial).set_shader_parameter("k", Wreck.vignette(t))
	cracks.modulate.a = Wreck.cracks(t)
	var a := Wreck.text(t)
	title.modulate.a = a
	sub.modulate.a = a
	solid.color.a = Wreck.solid(t)
	_place_cracks(t)


func layout() -> void:
	if not is_inside_tree():
		return
	var size := get_viewport().get_visible_rect().size
	var s := Splash.scale(size)
	_center(title, Wreck.TITLE_TOP, Wreck.TITLE_PX * s, size)
	_center(sub, Wreck.SUB_TOP, Wreck.SUB_PX * s, size)
	_place_cracks(maxf(shown_t, 0.0))


func _place_cracks(t: float) -> void:
	if not is_inside_tree():
		return
	var size := get_viewport().get_visible_rect().size
	cracks.position = Wreck.shift(t) * Splash.scale(size)
	cracks.size = size


func _label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


## Надпись по центру макета (x 1200), top — верх видимых глифов в макете.
func _center(l: Label, top: float, px: float, size: Vector2) -> void:
	var fs := maxi(roundi(px), 8)
	l.add_theme_font_size_override("font_size", fs)
	var font := l.get_theme_font("font")
	var p := Splash.to_screen(Vector2(Wreck.W_CENTER, top), size)
	l.size = l.get_minimum_size()
	l.position = Vector2(p.x - l.size.x * 0.5, p.y - (font.get_ascent(fs) - Splash.CAP_H * fs))
