class_name GoalPlateView
extends Control
## Плашка цели маршрута за штурвалом (#1344): подложка `UiStyle.DARK`, рамка по виду (`GoalPlate.edge`), значок —
## стрелка или разворот (рисуется линиями, без глифов шрифта), текст. Состояние и место — `GoalPlate`, шаг —
## `OverlayFlow.goal_step`. Касаний не ловит.

var plate: GoalPlate
var rect := Rect2()   ## место этого кадра; пусто — плашки нет
var _rev := -1
var k := 1.0          ## доля кегля текста и значка (`GoalPlate.fit`)
var atlas: Texture2D  ## значки постов ART-042 — у задачи места (`GoalPlate.Kind.TASK`, #1635)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	atlas = load(ShipMap.ATLAS)


## Ширина текста плашки p в кегле экрана высотой h.
func text_width(p: GoalPlate, h: float) -> float:
	var px := roundi(GoalPlate.TEXT_PX * h / GoalPlate.REF_H)
	return get_theme_default_font().get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


## Показать p на месте r (on = false — скрыть). Перерисовка — только при смене вида или места.
func show_plate(p: GoalPlate, r: Rect2, on: bool, kk := 1.0) -> void:
	if not on:
		if visible:
			visible = false
		rect = Rect2()
		return
	if visible and p == plate and p.rev == _rev and r == rect and kk == k:
		return
	plate = p
	rect = r
	k = kk
	_rev = p.rev
	visible = true
	queue_redraw()


## Прогрев (WarmRunner): под шторкой плашка рисует свой кегль — цифры, «°», кириллицу — в кэш шрифта до первого
## раза за штурвалом. on = false — снова скрыта.
func warm(on: bool) -> void:
	if not on:
		show_plate(plate, Rect2(), false)
		return
	var p := GoalPlate.new()
	p.kind = GoalPlate.Kind.TASK   # значок поста из атласа — тоже в прогрев (#1635)
	p.task = "gate"
	p.text = "0123456789°   " + GoalPlate.NONE_TEXT + " · " + GoalPlate.VOTE_TEXT + " — узнано ближе ниже"
	p.rev = -2
	show_plate(p, Rect2(Vector2(40, 40), Vector2(600, 60)), true)


func _draw() -> void:
	if plate == null or not rect.has_area():
		return
	var s := get_viewport_rect().size.y / GoalPlate.REF_H
	draw_style_box(UiStyle.box(Color(UiStyle.DARK, GoalPlate.FILL_A), GoalPlate.RADIUS * s, plate.edge(), 2.0 * s), rect)
	var x := rect.position.x + GoalPlate.PAD * s
	var cy := rect.get_center().y
	var post := plate.task_icon()
	if post != "":
		var d := GoalPlate.ARROW_PX * s * k
		var big := d * GoalPlate.POST_K   # у ячейки атласа свои поля — значок крупнее места стрелки, по тому же центру
		draw_texture_rect_region(atlas, Rect2(Vector2(x + (d - big) * 0.5, cy - big * 0.5), Vector2(big, big)),
			ShipMap.cell(post), UiStyle.ACCENT)
		x += (GoalPlate.ARROW_PX + GoalPlate.ICON_GAP) * s * k
	elif plate.has_icon():
		_icon(Vector2(x + GoalPlate.ARROW_PX * s * k * 0.5, cy), GoalPlate.ARROW_PX * s * k, plate.kind)
		x += (GoalPlate.ARROW_PX + GoalPlate.ICON_GAP) * s * k
	var px := float(roundi(GoalPlate.TEXT_PX * s * k))
	draw_string(get_theme_default_font(), Vector2(x, cy + Splash.CAP_H * px * 0.5), plate.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px), plate.text_color())


## Значок в центре c размером d: ▲ прямо, ◀ ▶ — куда поворачивать, ↻ — развернуться.
func _icon(c: Vector2, d: float, k: GoalPlate.Kind) -> void:
	var r := d * 0.42
	var col := UiStyle.ACCENT
	match k:
		GoalPlate.Kind.AHEAD:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)]), col)
		GoalPlate.Kind.LEFT:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r * 0.8, -r), c + Vector2(r * 0.8, r)]), col)
		GoalPlate.Kind.RIGHT:
			draw_colored_polygon(PackedVector2Array([c + Vector2(r, 0), c + Vector2(-r * 0.8, r), c + Vector2(-r * 0.8, -r)]), col)
		GoalPlate.Kind.BEHIND:
			var w := maxf(2.0, d * 0.11)
			var rr := r * 0.8
			draw_arc(c, rr, deg_to_rad(-60.0), deg_to_rad(230.0), 32, col, w, true)
			var tip := c + Vector2.from_angle(deg_to_rad(230.0)) * rr   # наконечник на конце дуги, по часовой
			var dir := Vector2.from_angle(deg_to_rad(320.0))   # касательная по часовой (y экрана — вниз)
			var side := dir.orthogonal()
			draw_colored_polygon(PackedVector2Array([tip + dir * r * 0.45, tip - side * r * 0.4 - dir * r * 0.1,
				tip + side * r * 0.4 - dir * r * 0.1]), col)
