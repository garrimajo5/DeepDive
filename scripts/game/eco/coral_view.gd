class_name CoralView
extends MeshInstance3D
## Огнецвет в сцене: все кусты — один меш (один вызов отрисовки) по форме EcoCoralLook. Номер куста — в UV.x,
## кончик — UV.y = 1. Кончики светятся оранжевым (#F6AE55) с яркостью куста из массива glow в шейдере и, погаснув,
## становятся цвета ветвей (ART-004: «горит» / «погас»); массив обновляется, только когда свет заметно изменился.
## Стоит на слое отмели (OceanView.LAYER_WORLD). Кусты колышутся в течении мира (план реализма Б3): доля высоты
## вершины над подножием — UV2.x, подножие и высота куста — массивы foot/tall, формула — общий кусок EcoShaders.SWAY
## (двойник EcoCurrent.sway); коралл жёсткий — изгиб BEND меньше, чем у веерника. «Экономно» — EcoShaders.set_sway_lite.
## Матовость — uniform rough/spec, числа «известь» ставит EcoSurface (мокрый известковый скелет, не камень).
## Куст рывком гасит кончики — у них облачка слизи (EcoCoralDust): дочерний MultiMesh «Муть», +1 вызов.
## «Экономно» (Б6, `set_lite`): кусты из грубой формы EcoCoralLook.lite — ветви и кончики четырёхгранные, камни одним
## поясом; меш пересобирается с тем же материалом (свет кончиков, колыхание, муть те же), сброс мира уровень не теряет.

const SHADER := """
shader_type spatial;
render_mode cull_back;
""" + EcoGlow.GLSL + """
uniform vec3 tip_paint : source_color;
uniform vec3 tip_glow : source_color;
uniform vec3 dark_color : source_color;
uniform float glow[%d];
uniform vec3 foot[%d];
uniform float tall[%d];
uniform vec3 bend = vec3(0.0);
uniform float rough = 0.6;
uniform float spec = 0.4;
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
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = eco_bio(tip_glow * lit);
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

## Облачка слизи у кончиков (EcoCoralDust) — дочерний MultiMesh «Муть» на общем шейдере EcoShaders.MIST; буфер —
## для тестов.
var dust := EcoCoralDust.new()
var dust_view: MultiMeshInstance3D
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()

var _mat: ShaderMaterial
## На «Экономно» — грубая форма куста (set_lite); форма, из которой собран меш.
var lite := false
var form: EcoCoralLook.Form
## Треугольников во всём меше.
var tris := 0


func _init(system: EcoCoral, on_lite := false) -> void:
	coral = system
	lite = on_lite
	name = "Огнецвет"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build()
	dust_view = GrazerView.build_dust(EcoCoralDust.POOL)
	add_child(dust_view)
	glows.resize(coral.bushes.size())
	glows.fill(-1.0)
	sync()


## «Экономно» — меш из грубой формы (тот же материал); назад — полный.
func set_lite(on: bool) -> void:
	if lite == on:
		return
	lite = on
	_build()


func _build() -> void:
	form = EcoCoralLook.form(lite)
	verts.clear()
	heights.clear()
	feet.clear()
	talls.clear()
	var n := form.verts.size()
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
			verts.append(tr * form.verts[i])
			var h := clampf(form.verts[i].y / EcoCoral.HEIGHT, 0.0, 1.0)
			heights.append(h)
			uv2.append(Vector2(h, 0.0))
			nor.append((tr.basis * form.normals[i]).normalized())
			col.append(form.colors[i])
			uv.append(Vector2(b.index, 1.0 if form.parts[i] == EcoCoralLook.Part.TIP else 0.0))
		for t in form.tris:
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
		if _mat:
			m.surface_set_material(0, _mat)
			mesh = m
			tris = idx.size() / 3
			return
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
	tris = idx.size() / 3


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


## Облачки слизи в момент t (время мира): ship — корабль (дальние не пылят, в луче — светлее), flow — течение мира.
func sync_dust(t: float, ship: EcoLink.ShipState, flow := Vector3.ZERO) -> void:
	dust.update(coral, t, ship.pos if ship != null else Vector3.ZERO)
	_dust.pack(dust.dust, t, flow, ship, EcoCoralDust.COLOR, EcoCoralDust.LIT)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


## Смещение вершины i в течении flow в момент t — двойник шейдера (EcoCurrent.sway с подножием и высотой куста).
func offset(i: int, t: float, flow: Vector3 = EcoShaders.flow) -> Vector3:
	var b := i / maxi(1, form.verts.size())
	return EcoCurrent.sway(feet[b], heights[i], talls[b], t, flow, BEND)


## Материал кустов (для тестов).
func material() -> ShaderMaterial:
	return _mat
