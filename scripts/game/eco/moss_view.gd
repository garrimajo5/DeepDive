class_name MossView
extends MeshInstance3D
## Светящийся мох в сцене: все 22 пятна — один меш (один вызов отрисовки), как W.moss в браузере. Своя яркость вершины
## (EcoMossLook.base) лежит в цвете вершины, номер пятна — в UV.x; яркость пятна целиком — массив glow в шейдере,
## обновляется, только когда пятно заметно разгорелось или потускнело. Свет свой (без освещения), полупрозрачный.
## Стоит на слое отмели (OceanView.LAYER_WORLD).

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform vec3 moss_color : source_color;
uniform float glow[%d];
varying float a;
void vertex() {
	a = COLOR.r * glow[int(UV.x + 0.5)];
}
void fragment() {
	ALBEDO = moss_color;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Меньше этой разницы яркость пятна не обновляем (как mossAlpha в браузере).
const EPS := 0.002

var moss: EcoMoss
var look: EcoMossLook.MossMesh
## Яркость пятен, отданная шейдеру (для тестов: в headless сервер отрисовки параметры не возвращает).
var glows := PackedFloat32Array()
## Сколько раз отдавали яркость шейдеру.
var uploads := 0

var _mat: ShaderMaterial


func _init(system: EcoMoss, ground: Callable = Callable()) -> void:
	moss = system
	name = "Мох"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	look = EcoMossLook.build(moss.patches, ground)
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
		_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SHADER % maxi(1, moss.patches.size())
		_mat.shader = sh
		_mat.set_shader_parameter("moss_color", EcoMossLook.COLOR)
		m.surface_set_material(0, _mat)
	mesh = m
	glows.resize(moss.patches.size())
	glows.fill(-1.0)
	sync()


## Отдать шейдеру яркость пятен, если хоть одно заметно изменилось. true — отдали.
func sync() -> bool:
	var dirty := false
	for p in moss.patches:
		var g := p.glow()
		if absf(g - glows[p.index]) >= EPS:
			glows[p.index] = g
			dirty = true
	if dirty and _mat:
		_mat.set_shader_parameter("glow", glows)
		uploads += 1
	return dirty
