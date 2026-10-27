class_name GradeView
extends CanvasLayer
## Виньетка и цветокоррекция по глубине ART-065: один полноэкранный ColorRect под интерфейсом (слой −1, HUD — слой 1).
## Числа и смесь — `Grade`; LUT 256×16 пересобирается на CPU, только когда смесь сдвинулась больше `Grade.EPS`.
## `apply(depth, silt)` — каждый шаг (глубина камеры), `set_lite(true)` — «Экономно», `set_on(false)` — проход выключен.

const SHADER := preload("res://shaders/grade.gdshader")
## «Экономно»: овал умножением, без копии экрана (#842).
const LITE_SHADER := preload("res://shaders/grade_lite.gdshader")

var rect := ColorRect.new()
var mat := ShaderMaterial.new()
var tex: ImageTexture
var mix := Grade.Mix.new()   ## смесь, из которой собрана текущая LUT
var lite := false
var rebuilds := 0            ## сколько раз LUT пересобрана (тесты)


func _init() -> void:
	name = "Цветокоррекция"
	layer = -1
	mat.shader = SHADER
	rect.name = "Виньетка"
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	_build(Grade.blend(0.0))
	tex = ImageTexture.create_from_image(Grade.lut_image(mix))
	mat.set_shader_parameter("lut_tex", tex)


func _build(m: Grade.Mix) -> void:
	mix = m
	mat.set_shader_parameter("blue_column", m.blue())
	if tex:
		tex.update(Grade.lut_image(m))
	rebuilds += 1


func apply(depth: float, silt: float = 0.0) -> void:
	var m := Grade.blend(depth, silt)
	mat.set_shader_parameter("strength", Grade.LITE if lite else m.strength)
	if not lite and m.differs(mix):
		_build(m)


func set_lite(on: bool) -> void:
	lite = on
	mat.shader = LITE_SHADER if on else SHADER
	if not on:
		mat.set_shader_parameter("lut_tex", tex)
		mat.set_shader_parameter("blue_column", mix.blue())
	mat.set_shader_parameter("strength", Grade.LITE if on else mix.strength)


func set_on(on: bool) -> void:
	visible = on
