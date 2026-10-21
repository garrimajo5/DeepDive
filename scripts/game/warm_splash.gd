class_name WarmSplash
extends CanvasLayer
## Заставка прогрева по ART-034 поверх сцены (`main.curtain`): фон во весь экран, название, строка состояния, проценты,
## полоса по доле прогрева, подсказка по кругу. Числа и раскладка — `Splash`. Слой выше крестовины и кнопки — они
## закрыты; после прогрева Main освобождает узел вместе с текстурой фона.

var bg: TextureRect
var title: Label
var line: Label
var percent: Label
var hint: Label
var track: Panel
var fill: Panel
var progress := 0.0
var time := 0.0


func _init() -> void:
	name = "Шторка"
	layer = 100
	var root := Control.new()
	root.name = "Заставка"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dark := ColorRect.new()   # под фоном: если текстура не загрузилась, экран всё равно закрыт
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.color = Color("#0B1C24")
	root.add_child(dark)
	bg = TextureRect.new()
	bg.name = "Фон"
	bg.texture = load(Splash.BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	title = _label(root, "Погружение", Splash.INK)
	line = _label(root, Splash.status(0.0), Splash.SOFT)
	percent = _label(root, Splash.percent(0.0), Splash.INK)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint = _label(root, Splash.hint(0.0), Splash.INK)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track = _bar(root, Splash.TRACK)
	fill = _bar(root, Splash.FILL)


func _ready() -> void:
	get_viewport().size_changed.connect(layout)
	layout()


func _process(dt: float) -> void:
	time += dt
	var h := Splash.hint(time)
	if hint.text != h:
		hint.text = h


## Доля прогрева 0…1: полоса, проценты, строка состояния.
func set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	line.text = Splash.status(progress)
	percent.text = Splash.percent(progress)
	layout()


## Места надписей и полосы на экране текущего размера.
func layout() -> void:
	if not is_inside_tree():
		return
	var size := get_viewport().get_visible_rect().size
	var s := Splash.scale(size)
	_place(title, Splash.TITLE_AT, Splash.TITLE_PX * s, size)
	_place(line, Splash.STATUS_AT, Splash.LINE_PX * s, size)
	_place(percent, Splash.PERCENT_RIGHT, Splash.LINE_PX * s, size)
	percent.position.x -= percent.size.x   # правый край — x макета
	_place(hint, Vector2(Splash.HINT_X.x, Splash.HINT_TOP), Splash.HINT_PX * s, size)
	hint.size.x = (Splash.HINT_X.y - Splash.HINT_X.x) * s
	var r := Splash.rect_to_screen(Splash.BAR, size)
	track.position = r.position
	track.size = r.size
	fill.position = r.position
	fill.size = Vector2(maxf(r.size.x * progress, r.size.y), r.size.y)   # не уже скругления
	fill.visible = progress > 0.0
	for p: Panel in [track, fill]:
		(p.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(roundi(Splash.BAR_RADIUS * s))


func _label(root: Control, text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	root.add_child(l)
	return l


func _bar(root: Control, color: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	p.add_theme_stylebox_override("panel", sb)
	root.add_child(p)
	return p


## Надпись: at — левый край и верх видимых глифов в макете; верх строки выше на ascent − высота заглавных.
func _place(l: Label, at: Vector2, px: float, size: Vector2) -> void:
	var fs := maxi(roundi(px), 8)
	l.add_theme_font_size_override("font_size", fs)
	var font := l.get_theme_font("font")
	var p := Splash.to_screen(at, size)
	p.y -= font.get_ascent(fs) - Splash.CAP_H * fs
	l.position = p
	l.size = l.get_minimum_size()
