class_name PlayCaption
extends RefCounted
## Подпись кадра Google Play (ART-046) картинкой: строка текста `PlayFrame.TEXT` размером `PlayFrame.FONT_PX` на
## прозрачном фоне, шрифт игры (тот же, что в интерфейсе). Рисует одноразовый SubViewport под узлом parent — нужен
## настоящий рендер: в headless картинки нет (null), кадр тогда собирается без подписи.


## Отрисовать подпись; ждёт кадр отрисовки. null — без рендера (headless) или пустой текст.
static func render(parent: Node, text: String) -> Image:
	if text.is_empty() or DisplayServer.get_name() == "headless":
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(PlayFrame.SIZE.x, PlayFrame.PLATE_H)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var label := Label.new()
	label.text = text
	label.size = Vector2(vp.size)
	label.position.y = PlayFrame.TEXT_CENTER.y - PlayFrame.PLATE_H / 2.0   # центр строки — на y 78
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", PlayFrame.FONT_PX)
	label.add_theme_color_override("font_color", PlayFrame.TEXT)
	vp.add_child(label)
	parent.add_child(vp)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	return img
