class_name HintPointerView
extends Node3D
## Указатель над постом-целью подсказки первого забега ART-038 (`HintPointer`): одна ячейка атласа
## `textures/podskazki/ukazatel.png` на Sprite3D в осях корабля, слой корабля; плашка параллельна экрану (как метка
## «Занято»), символ 96…160 px по расстоянию, покачивание ±4 px. Флаги — как у табличек и меток «Занято» (без света,
## двусторонние, без билборда), новый шейдер не нужен. Пост вне кадра — мировой скрыт, `show_pointer` отдаёт стрелку
## у края экрана: её рисует `TutorialPanel`.

var sprite: Sprite3D
var tex: Texture2D
var time := 0.0   ## часы покачивания


func _ready() -> void:
	tex = load(HintPointer.PATH)
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
## [Rect2, зеркалить] или [] — её рисует TutorialPanel.
func show_pointer(target: String, near: bool, a: float, dt: float, cam: Camera3D, own_cam: Camera3D) -> Array:
	time = fmod(time + dt, HintPointer.BOB_PERIOD)
	sprite.visible = false
	if target == "" or a <= 0.0 or cam == null or cam != own_cam or not HintPointer.ANCHORS.has(target):
		return []
	var tip := to_global(HintPointer.ANCHORS[target])
	var local := cam.global_transform.affine_inverse() * tip
	var size := cam.get_viewport().get_visible_rect().size
	var p := cam.unproject_position(tip) if -local.z > 0.0 else Vector2(-1.0, -1.0)
	match HintPointer.mode(local, p, size):
		"world":
			var depth := -local.z
			var h := HintPointer.cell_height(cam.global_position.distance_to(tip), depth, cam.fov)
			var m_ref := 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5) / HintPointer.REF_H   # м на px при H = 1080
			var up := HintPointer.TIP * h + HintPointer.bob(time) * m_ref
			var bz := cam.global_basis.z
			var ang := atan2(bz.x, bz.z)
			sprite.region_rect = HintPointer.cell(near)
			sprite.global_transform = Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * h),
				tip + Vector3.UP * up)
			sprite.modulate = Color(1, 1, 1, a)
			sprite.visible = true
			return []
		"edge":
			return HintPointer.edge(local, p, size)
	return []
