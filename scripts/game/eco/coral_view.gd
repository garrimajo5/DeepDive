class_name CoralView
extends MeshInstance3D
## Огнецвет в сцене: все кусты — один меш (один вызов отрисовки) по форме EcoCoralLook. Номер куста — в UV.x,
## кончик — UV.y = 1. Кончики светятся оранжевым (#F6AE55) с яркостью куста из массива glow в шейдере и, погаснув,
## становятся цвета ветвей (ART-004: «горит» / «погас»); массив обновляется, только когда свет заметно изменился.
## Стоит на слое отмели (OceanView.LAYER_WORLD). Кусты колышутся в течении мира (план реализма Б3): доля высоты
## вершины над подножием — UV2.x, подножие и высота куста — массивы foot/tall, формула — общий кусок EcoShaders.SWAY
## (двойник EcoCurrent.sway); коралл жёсткий — изгиб BEND меньше, чем у веерника. «Экономно» — EcoShaders.set_sway_lite.

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 tip_paint : source_color;
uniform vec3 tip_glow : source_color;
uniform vec3 dark_color : source_color;
uniform float glow[%d];
uniform vec3 foot[%d];
uniform float tall[%d];
uniform vec3 bend = vec3(0.0);
""" + EcoShaders.SWAY + """
varying vec3 paint;
varying float lit;
void vertex() {
	int i = int(UV.x + 0.5);
	if (sway_k > 0.0) {
		VERTEX += eco_sway(foot[i], UV2.x, tall[i], bend);
	}
	paint = COLOR.rgb;
	lit = UV.y * glow[i];
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

## Изгиб куста в течении (крен, волна, поперёк — доли высоты на полном течении): коралл твёрже веерника
## (FanView.BEND), вершина со станцией огнёвок уходит не дальше пары десятков сантиметров.
const BEND := Vector3(0.035, 0.02, 0.012)

## Меньше этой разницы свет куста не обновляем.
const EPS := 0.01

var coral: EcoCoral
## Свет кустов, отданный шейдеру (для тестов: в headless сервер отрисовки параметры не возвращает).
var glows := PackedFloat32Array()
var uploads := 0
## Вершины всего меша и их доля высоты над подножием (UV2.x) — для тестов и двойника offset.
var verts := PackedVector3Array()
var heights := PackedFloat32Array()
## Подножие и высота каждого куста (uniform foot/tall).
var feet := PackedVector3Array()
var talls := PackedFloat32Array()

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
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for b in coral.bushes:
		var tr := EcoCoralLook.transform(b)
		var v0 := verts.size()
		feet.append(b.base)
		talls.append(EcoCoral.HEIGHT * b.scale)
		for i in n:
			verts.append(tr * EcoCoralLook.verts[i])
			var h := clampf(EcoCoralLook.verts[i].y / EcoCoral.HEIGHT, 0.0, 1.0)
			heights.append(h)
			uv2.append(Vector2(h, 0.0))
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
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_INDEX] = idx
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_mat = ShaderMaterial.new()
		var nb := maxi(1, coral.bushes.size())
		_mat.shader = EcoShaders.shader(SHADER % [nb, nb, nb])
		_mat.set_shader_parameter("tip_paint", TIP_PAINT)
		_mat.set_shader_parameter("tip_glow", TIP_GLOW)
		_mat.set_shader_parameter("dark_color", EcoCoralLook.BODY)
		_mat.set_shader_parameter("foot", feet)
		_mat.set_shader_parameter("tall", talls)
		_mat.set_shader_parameter("bend", BEND)
		EcoShaders.follow(_mat)
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


## Смещение вершины i в течении flow в момент t — двойник шейдера (EcoCurrent.sway с подножием и высотой куста).
func offset(i: int, t: float, flow: Vector3 = EcoShaders.flow) -> Vector3:
	var b := i / maxi(1, EcoCoralLook.verts.size())
	return EcoCurrent.sway(feet[b], heights[i], talls[b], t, flow, BEND)


## Материал кустов (для тестов).
func material() -> ShaderMaterial:
	return _mat
