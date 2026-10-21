class_name CoralView
extends MeshInstance3D
## Огнецвет в сцене: все кусты — один меш (один вызов отрисовки) по форме EcoCoralLook. Номер куста — в UV.x,
## кончик — UV.y = 1. Кончики светятся оранжевым (#F6AE55) с яркостью куста из массива glow в шейдере и, погаснув,
## становятся цвета ветвей (ART-004: «горит» / «погас»); массив обновляется, только когда свет заметно изменился.
## Стоит на слое отмели (OceanView.LAYER_WORLD).

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 tip_paint : source_color;
uniform vec3 tip_glow : source_color;
uniform vec3 dark_color : source_color;
uniform float glow[%d];
varying vec3 paint;
varying float lit;
void vertex() {
	paint = COLOR.rgb;
	lit = UV.y * glow[int(UV.x + 0.5)];
	if (UV.y > 0.5) {
		paint = mix(dark_color, tip_paint, lit);
	}
}
void fragment() {
	ALBEDO = paint;
	ROUGHNESS = 0.8;
	EMISSION = tip_glow * lit;
}
"""

## Краска и свечение кончика: при ярком свете сквозь лёд светлая #F6AE55 выгорает в белый, поэтому краска гуще,
## а свечение — тот же оранжевый.
const TIP_PAINT := Color(0.85, 0.33, 0.06)
const TIP_GLOW := Color(0.95, 0.42, 0.1)

## Меньше этой разницы свет куста не обновляем.
const EPS := 0.01

var coral: EcoCoral
## Свет кустов, отданный шейдеру (для тестов: в headless сервер отрисовки параметры не возвращает).
var glows := PackedFloat32Array()
var uploads := 0
## Вершины всего меша (для тестов).
var verts := PackedVector3Array()

var _mat: ShaderMaterial


func _init(system: EcoCoral) -> void:
	coral = system
	name = "Огнецвет"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var n := EcoCoralLook.verts.size()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for b in coral.bushes:
		var tr := EcoCoralLook.transform(b)
		var v0 := verts.size()
		for i in n:
			verts.append(tr * EcoCoralLook.verts[i])
			nor.append((tr.basis * EcoCoralLook.normals[i]).normalized())
			col.append(EcoCoralLook.colors[i])
			uv.append(Vector2(b.index, 1.0 if EcoCoralLook.parts[i] == EcoCoralLook.Part.TIP else 0.0))
		for t in EcoCoralLook.tris:
			idx.append(v0 + t)
	var m := ArrayMesh.new()
	if not verts.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = nor
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = idx
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_mat = ShaderMaterial.new()
		_mat.shader = EcoShaders.shader(SHADER % maxi(1, coral.bushes.size()))
		_mat.set_shader_parameter("tip_paint", TIP_PAINT)
		_mat.set_shader_parameter("tip_glow", TIP_GLOW)
		_mat.set_shader_parameter("dark_color", EcoCoralLook.BODY)
		m.surface_set_material(0, _mat)
	mesh = m
	glows.resize(coral.bushes.size())
	glows.fill(-1.0)
	sync()


## Отдать шейдеру свет кустов, если хоть один заметно изменился. true — отдали.
func sync() -> bool:
	var dirty := false
	for b in coral.bushes:
		if absf(b.glow - glows[b.index]) >= EPS or (b.glow >= 1.0 and glows[b.index] < 1.0):
			glows[b.index] = b.glow
			dirty = true
	if dirty and _mat:
		_mat.set_shader_parameter("glow", glows)
		uploads += 1
	return dirty
