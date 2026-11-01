class_name MossView
extends MeshInstance3D
## Светящийся мох в сцене: все 22 пятна — один меш (один вызов отрисовки), как W.moss в браузере. Своя яркость вершины
## (EcoMossLook.base) лежит в цвете вершины, номер пятна — в UV.x; яркость пятна целиком — массив glow в общем
## шейдере мха (EcoShaders.MOSS, один на все места), обновляется, только когда пятно заметно разгорелось или
## потускнело. Свет свой (без освещения), полупрозрачный.
## Стоит на слое отмели (OceanView.LAYER_WORLD).
## «Экономно» (Б6, `set_lite`): пятно — 4 × 4 клетки вместо 8 × 8 (`EcoMossLook.LITE_CELLS`, 128 → 32 треугольника,
## меньше вершин под полупрозрачным мхом), материал и яркость пятен те же; сброс мира уровень не теряет.

## Меньше этой разницы яркость пятна не обновляем (как mossAlpha в браузере).
const EPS := 0.002

var moss: EcoMoss
var look: EcoMossLook.MossMesh
## Яркость пятен, отданная шейдеру (для тестов: в headless сервер отрисовки параметры не возвращает).
var glows := PackedFloat32Array()
## Сколько раз отдавали яркость шейдеру.
var uploads := 0

## На «Экономно» — сетка пятна грубее (set_lite).
var lite := false

var _mat: ShaderMaterial
var _ground: Callable


func _init(system: EcoMoss, ground: Callable = Callable(), on_lite := false) -> void:
	moss = system
	name = "Мох"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground = ground
	lite = on_lite
	_build()
	glows.resize(moss.patches.size())
	glows.fill(-1.0)
	sync()


## «Экономно» — меш пересобран грубее тем же материалом (яркость пятен остаётся); назад — полный.
func set_lite(on: bool) -> void:
	if lite == on:
		return
	lite = on
	_build()


func _build() -> void:
	look = EcoMossLook.build(moss.patches, _ground, EcoMossLook.LITE_CELLS if lite else EcoMossLook.CELLS)
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	colors.resize(look.verts.size())
	uv.resize(look.verts.size())
	for v in look.verts.size():
		colors[v] = Color(look.base[v], 0, 0)
		uv[v] = Vector2(look.patch[v], 0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = look.verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = look.tris
	var m := ArrayMesh.new()
	if not look.verts.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if _mat == null:
			_mat = ShaderMaterial.new()
			_mat.shader = EcoShaders.shader(EcoShaders.MOSS)
			_mat.set_shader_parameter("moss_color", EcoMossLook.COLOR)
		m.surface_set_material(0, _mat)
	mesh = m


## Отдать шейдеру яркость пятен, если хоть одно заметно изменилось. true — отдали.
func sync() -> bool:
	var dirty := false
	for p in moss.patches:
		var g := p.glow()
		if absf(g - glows[p.index]) >= EPS:
			glows[p.index] = g
			dirty = true
	if dirty and _mat:
		_mat.set_shader_parameter("glow", EcoShaders.moss_glow(glows))
		uploads += 1
	return dirty
