class_name MossView
extends MeshInstance3D
## Светящийся мох в сцене: все 22 пятна — один меш (один вызов отрисовки), как W.moss в браузере. Своя яркость вершины
## (EcoMossLook.base) лежит в цвете вершины, номер пятна — в UV.x; яркость пятна целиком — массив glow в общем
## шейдере мха (EcoShaders.MOSS, один на все места), обновляется, только когда пятно заметно разгорелось или
## потускнело. Свет свой (без освещения), полупрозрачный.
## Пятна не клоны (Б4): у пятна своя краска — светлее-темнее ± SHADE_SPREAD, желтее-голубее ± HUE_SPREAD по номеру
## пятна (`EcoVary`, `patch_tint`, множитель ÷ 2 в COLOR.gba вершин). Вызовов и шейдеров столько же, и на «Экономно».
## Стоит на слое отмели (OceanView.LAYER_WORLD).
## «Экономно» (Б6, `set_lite`): пятно — 4 × 4 клетки вместо 8 × 8 (`EcoMossLook.LITE_CELLS`, 128 → 32 треугольника,
## меньше вершин под полупрозрачным мхом), материал и яркость пятен те же; сброс мира уровень не теряет.
## Колония мерцает (Б3): по пятну бегут две медленные волны свечения (период ≈ 7 и 11 с, длина ≈ 6–9 м) — ± SHIMMER
## яркости вершины по её месту и времени мира (`shimmer` — двойник шейдера, `set_time` — uniform `now`, у гостя то же).
## Яркость пятна целиком (объели — потускнело) остаётся миром: мерцание только множит её. Шейдеров и вызовов не
## прибавилось, и на «Экономно».

## Меньше этой разницы яркость пятна не обновляем (как mossAlpha в браузере).
const EPS := 0.002
## Разброс краски пятна: светлее-темнее и желтее-голубее (доля красного против синего).
const SHADE_SPREAD := 0.15
const HUE_SPREAD := 0.06
## Размах мерцания колонии: яркость вершины ± SHIMMER.
const SHIMMER := 0.22

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
	var tints := {}
	for v in look.verts.size():
		var p := look.patch[v]
		if not tints.has(p):
			tints[p] = patch_tint(moss.patches[p].index)
		var t: Color = tints[p]
		colors[v] = Color(look.base[v], t.r * 0.5, t.g * 0.5, t.b * 0.5)
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
			_mat.set_shader_parameter("shimmer", SHIMMER)
		m.surface_set_material(0, _mat)
	mesh = m


## Множитель краски пятна j (по каналам, около 1): светлее-темнее ± SHADE_SPREAD, желтее (больше красного) или
## голубее (больше синего) ± HUE_SPREAD. Один и тот же у хоста и гостя.
static func patch_tint(j: int) -> Color:
	var s := EcoVary.spread(j, EcoVary.SHADE, SHADE_SPREAD)
	var h := (EcoVary.unit(j, EcoVary.HUE) * 2.0 - 1.0) * HUE_SPREAD
	return Color(s * (1.0 + h), s, s * (1.0 - h))


## Цвет пятна j на экране без яркости (цвет мха × краска пятна) — двойник шейдера.
static func patch_color(j: int) -> Color:
	var t := patch_tint(j)
	var c := EcoMossLook.COLOR
	return Color(c.r * t.r, c.g * t.g, c.b * t.b)


## Множитель яркости вершины в точке (x, z) мира в момент t (время мира) — двойник шейдера `EcoShaders.MOSS`.
static func shimmer(x: float, z: float, t: float) -> float:
	var w := 0.6 * sin(t * 0.9 + x * 0.8 + z * 0.55) + 0.4 * sin(t * 0.55 - x * 0.35 + z * 0.9)
	return 1.0 + SHIMMER * w


## Время мира t — в шейдер (мерцание колонии).
func set_time(t: float) -> void:
	if _mat:
		_mat.set_shader_parameter("now", t)


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
