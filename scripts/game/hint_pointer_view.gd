class_name HintPointerView
extends Node3D
## Указатель над постом-целью подсказки первого забега ART-038 (`HintPointer`): одна ячейка атласа
## `textures/podskazki/ukazatel.png` на Sprite3D в осях корабля, слой корабля; плашка параллельна экрану (как метка
## «Занято»), символ 96…160 px по расстоянию, покачивание ±4 px. Флаги — как у табличек и меток «Занято» (без света,
## двусторонние, без билборда), новый шейдер не нужен. Пост вне кадра — мировой скрыт, `show_pointer` отдаёт стрелку
## у края экрана: её рисует `TutorialPanel`.

var sprite: Sprite3D
var tex: Texture2D
var amber: Texture2D   ## тот же атлас белым по альфе — под янтарь тревоги (#1361, `HintPointer.white_image`)
var time := 0.0   ## часы покачивания
var symbol := Rect2()   ## символ мирового указателя на экране этого кадра (подпись над кольцом); пусто — не в мире


func _ready() -> void:
	tex = load(HintPointer.PATH)
	amber = ImageTexture.create_from_image(HintPointer.white_image(tex.get_image()))
	sprite = Sprite3D.new()
	sprite.name = "Указатель"
	sprite.texture = tex
	sprite.region_enabled = true
	sprite.region_rect = HintPointer.SEEN
	sprite.pixel_size = 1.0 / HintPointer.CELL   # ячейка — 1 м, масштаб — узлом
	sprite.set("shaded", false)
	sprite.set("double_sided", true)
	sprite.set("alpha_cut", SpriteBase3D.ALPHA_CUT_DISABLED)
	sprite.set("billboard", BaseMaterial3D.BILLBOARD_DISABLED)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.layers = OceanView.LAYER_SHIP
	sprite.render_priority = 2
	sprite.visible = false
	add_child(sprite)


## Поставить указатель на пост target ("" — скрыть): near — игрок в радиусе поста, a — прозрачность подсказки,
## dt — шаг времени, cam — камера, которой смотрим (не своя — облёт: скрыт). Возвращает стрелку у края
## [Rect2, зеркалить] или [] — её рисует TutorialPanel. top — порог острия, как в `show_at` (#1367: под плашкой
## подсказки, `HintPointer.top_under`).
func show_pointer(target: String, near: bool, a: float, dt: float, cam: Camera3D, own_cam: Camera3D,
		top := -1.0) -> Array:
	if not HintPointer.ANCHORS.has(target):
		return show_at(Vector3.ZERO, false, 0.0, dt, cam, own_cam)
	return show_at(HintPointer.ANCHORS[target], near, a, dt, cam, own_cam, Color.WHITE, top)


## То же для любого места в осях корабля (`anchor` — остриё шеврона); tint — цвет символа: белый — атлас как есть
## (подсказки), иначе — белый атлас `amber` × tint (указатель тревоги, #1361). a ≤ 0 — скрыть. top — цель перед
## камерой, но остриё выше top px (при H = 1080; люк вплотную): кольцо опускается до top (`HintPointer.lower_tip`), а
## не уходит стрелкой вбок; top < 0 — как подсказки. roof — потолок отсека (y в осях корабля): символ под ним,
## остриё опускается (`HintPointer.under_roof`, #1722); INF — как подсказки.
func show_at(anchor: Vector3, near: bool, a: float, dt: float, cam: Camera3D, own_cam: Camera3D,
		tint := Color.WHITE, top := -1.0, roof := INF) -> Array:
	time = fmod(time + dt, HintPointer.BOB_PERIOD)
	sprite.visible = false
	symbol = Rect2()
	if a <= 0.0 or cam == null or cam != own_cam:
		return []
	var tip := to_global(anchor)
	var local := cam.global_transform.affine_inverse() * tip
	var size := cam.get_viewport().get_visible_rect().size
	var p := cam.unproject_position(tip) if -local.z > 0.0 else Vector2(-1.0, -1.0)
	if roof < INF and -local.z > HintPointer.MIN_DEPTH:
		var depth0 := -local.z
		var h0 := HintPointer.cell_height(cam.global_position.distance_to(tip), depth0, cam.fov)
		var y := HintPointer.under_roof(anchor.y, h0, 2.0 * depth0 * tan(deg_to_rad(cam.fov) * 0.5) / HintPointer.REF_H,
			roof)
		if y < anchor.y:
			tip = to_global(Vector3(anchor.x, y, anchor.z))
			local = cam.global_transform.affine_inverse() * tip
			p = cam.unproject_position(tip) if -local.z > 0.0 else Vector2(-1.0, -1.0)
	if top >= 0.0:
		var low := HintPointer.lower_tip(p, -local.z, size, top)
		if low != p:   # вплотную над головой (ближе MIN_DEPTH) — кольцо на MIN_DEPTH перед камерой (#1367)
			p = low
			tip = cam.project_position(p, maxf(-local.z, HintPointer.MIN_DEPTH))
			local = cam.global_transform.affine_inverse() * tip
	match HintPointer.mode(local, p, size):
		"world":
			var depth := -local.z
			var d := cam.global_position.distance_to(tip)
			var h := HintPointer.cell_height(d, depth, cam.fov)
			var m_ref := 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5) / HintPointer.REF_H   # м на px при H = 1080
			var up := HintPointer.TIP * h + HintPointer.bob(time) * m_ref
			var bz := cam.global_basis.z
			var ang := atan2(bz.x, bz.z)
			var t := tex if tint == Color.WHITE else amber
			if sprite.texture != t:
				sprite.texture = t
			sprite.region_rect = HintPointer.cell(near)
			sprite.global_transform = Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * h),
				tip + Vector3.UP * up)
			sprite.modulate = Color(tint, a)
			sprite.visible = true
			var sym := HintPointer.px(d) * size.y / HintPointer.REF_H   # символ на экране, px
			var c := p - Vector2(0.0, (up / m_ref) * size.y / HintPointer.REF_H)
			symbol = Rect2(c - Vector2(sym, sym) * 0.5, Vector2(sym, sym))
			return []
		"edge":
			return HintPointer.edge(local, p, size)
	return []
