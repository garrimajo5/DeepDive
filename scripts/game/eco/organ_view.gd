class_name OrganView
extends MeshInstance3D
## Трубные органы в сцене (organGeo в js/creatures.js; ART-004): все губки — один меш (один вызов отрисовки).
## Труба — открытый усечённый конус (10 граней, видна с обеих сторон), у устья светлый обод-кольцо. Трубы через одну
## #9a7f6a и #6f5b4c, обод #ffd9a0; губка чуть тлеет тёплым (EcoOrgan.glow — в общем шейдере растений
## EcoShaders.PLANT по TIME).
## Стоит на слое отмели (OceanView.LAYER_WORLD).
## Выдох губки (EcoOrganDust: в такт гулу трубы выпускают над устьями облачка отцеженной мути, корабль рядом —
## чаще и гуще) — дочерний MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» (Б6, `set_lite`): трубы — шесть граней вместо десяти, обод — 6 × 3 вместо 10 × 4 (LITE_*) — 100 → 48
## треугольников на трубу; меш пересобирается с тем же материалом (тление, оттенки труб), устья на тех же местах,
## муть и вызовы те же. Сброс мира уровень не теряет (EcoView.set_lite).
## «Дыхание» губки (Б3): каждая труба в такт своего выдоха (EcoOrganDust: фаза трубы, такт 1,7 / 2π в секунду)
## сжимается — устье уже на BREATH м в миг выдоха облачка, через полтакта набрало воды и шире; подножие неподвижно,
## размах растёт к устью, обод едет с устьем. В шейдере растений (EcoShaders.PLANT, uniform `breath` и время мира
## `t` — у гостя то же); в меше доля такта трубы — UV.x, доля высоты — UV.y, наружу от оси — UV2. Двойник на CPU —
## `breath_offset`. Шейдеров и вызовов не прибавилось; «Экономно» — `sway_k` (EcoShaders.set_sway_lite).

const LIGHT := Color("9a7f6a")
const DARK := Color("6f5b4c")
const RIM := Color("ffd9a0")
## Краска гуще: при ярком свете сквозь лёд светлая губка выгорает в белый (как у огнецвета).
const PAINT_K := 0.45
## Тление губки (линейный цвет): GLOW + GLOW_WAVE · sin(TIME · 1,7).
const GLOW := Vector3(0.1, 0.06, 0.03)
const GLOW_WAVE := Vector3(0.05, 0.0, 0.0)
## Граней у трубы, у обода — 10 × 4 (CylinderGeometry(…, 10), TorusGeometry(0,32, 0,05, 4, 10)).
const SIDES := 10
const RIM_TUBE := 0.05
const RIM_SIDES := 4
## То же на «Экономно»: шесть граней — устье ещё читается кругом, обод — треугольник в сечении.
const LITE_SIDES := 6
const LITE_RIM_SIDES := 3
## Размах «дыхания» у устья (м): радиус 0,32 ± 0,035 — заметно у самой губки, издали не дрожит.
const BREATH := 0.035

var organs: EcoOrgan
var dust := EcoOrganDust.new()
var dust_view: MultiMeshInstance3D
var dust_buffer := PackedFloat32Array()
var _dust_empty := false
## Буфер мути для общего слоя EcoDustLayer (#849): свой рисунок губок (pack), сюда — готовые числа.
var _dust := EcoDustBuffer.new()
var _packed := PackedByteArray()
## Вершины и треугольники всего меша (для тестов).
var verts := PackedVector3Array()
var tris := 0

var _nor := PackedVector3Array()
var _col := PackedColorArray()
var _idx := PackedInt32Array()
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()
## На «Экономно» — грубее трубы и ободы (set_lite).
var lite := false
var _mat: ShaderMaterial


func _init(system: EcoOrgan, on_lite := false) -> void:
	organs = system
	lite = on_lite
	name = "Трубный орган"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = BREATH   # дыхание раздувает устья за рамку меша
	_mat = EcoShaders.plant(EcoShaders.Plant.ORGAN, {"shade": PAINT_K, "rough": 1.0,
		"spec": 0.1, "glow": GLOW, "glow_wave": GLOW_WAVE, "breath": Vector2(BREATH, EcoOrganDust.RATE)})
	_build()
	dust_view = GrazerView.build_dust(EcoOrganDust.POOL)
	add_child(dust_view)


## «Экономно» — трубы и ободы пересобраны грубее (тот же материал); назад — полные.
func set_lite(on: bool) -> void:
	if lite == on:
		return
	lite = on
	_build()


## Граней у трубы и обода по уровню.
func sides() -> int:
	return LITE_SIDES if lite else SIDES


func rim_sides() -> int:
	return LITE_RIM_SIDES if lite else RIM_SIDES


func _build() -> void:
	verts.clear()
	_nor.clear()
	_col.clear()
	_idx.clear()
	_uv.clear()
	_uv2.clear()
	for og in organs.organs:
		for k in EcoOrgan.TUBES:
			var b := og.tube_base[k]
			var top := b + Vector3(0, og.tube_len[k], 0)
			var ph := EcoOrganDust.phase(EcoOrganDust.tube_id(og, k))
			_tube(b, top, LIGHT if k % 2 else DARK, ph)
			_rim(top, ph)
	var m := ArrayMesh.new()
	if not verts.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = _nor
		arrays[Mesh.ARRAY_COLOR] = _col
		arrays[Mesh.ARRAY_TEX_UV] = _uv
		arrays[Mesh.ARRAY_TEX_UV2] = _uv2
		arrays[Mesh.ARRAY_INDEX] = _idx
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		m.surface_set_material(0, _mat)
	mesh = m
	tris = _idx.size() / 3


## Выдохи губок в момент t (время мира); ship — корабль (близость, дальность и луч), flow — течение.
func sync(t: float, ship: EcoLink.ShipState = null, flow := Vector3.ZERO) -> void:
	_mat.set_shader_parameter("t", t)
	dust.update(organs, t, ship.pos if ship else Vector3.ZERO)
	var shown := pack(t, ship, flow)
	_dust.shown = shown
	_dust.changed = not (shown == 0 and _dust_empty)   # мути нет и в буфере пусто — не грузим заново (issue #133)
	_dust_empty = shown == 0
	if _dust.changed:
		_dust.data = dust_buffer
	_dust.upload(dust_view)   # пустой слой мути не рисуется (issue #849); в живом мире — общий слой


## Переписать буфер мути (TRANSFORM_3D + цвет): живые облачка — на месте, растаявшие стянуты в точку один раз.
## Как GrazerView.pack_dust, но буфер не создаётся заново каждый кадр (замер шага мира test_eco_speed).
## Возвращает, сколько облачков видно.
func pack(t: float, ship: EcoLink.ShipState = null, flow := Vector3.ZERO) -> int:
	var shown := 0
	var puffs := dust.dust.puffs
	var stride := GrazerView.DUST_STRIDE
	if dust_buffer.size() != puffs.size() * stride:
		dust_buffer.resize(puffs.size() * stride)
		dust_buffer.fill(0.0)
		_packed.resize(puffs.size())
		_packed.fill(0)
	for n in puffs.size():
		var p := puffs[n]
		var i := n * stride
		var a := EcoGrazerDust.fade(p, t)
		if a <= 0.0:
			if _packed[n] != 0:
				for k in stride:
					dust_buffer[i + k] = 0.0
				_packed[n] = 0
			continue
		_packed[n] = 1
		shown += 1
		var s := EcoGrazerDust.size(p, t)
		var o := EcoGrazerDust.pos(p, t, flow)
		var c := EcoOrganDust.COLOR.lerp(EcoOrganDust.LIT, EcoGrazerDust.light(o, ship))
		dust_buffer[i] = s; dust_buffer[i + 3] = o.x
		dust_buffer[i + 5] = s; dust_buffer[i + 7] = o.y
		dust_buffer[i + 10] = s; dust_buffer[i + 11] = o.z
		dust_buffer[i + 12] = c.r; dust_buffer[i + 13] = c.g; dust_buffer[i + 14] = c.b; dust_buffer[i + 15] = a
	return shown


## Сдвиг наружу от оси трубы (м) у вершины на доле высоты h трубы с фазой ph (EcoOrganDust.phase) в момент t
## времени мира — двойник шейдера: в миг выдоха (начало такта) устье сжато на BREATH, через полтакта — шире.
## sway_k — 0 на «Экономно».
static func breath_offset(ph: float, h: float, t: float, sway_k := 1.0) -> float:
	var f := fposmod(t * EcoOrganDust.RATE + ph, 1.0)
	return -BREATH * h * cos(TAU * f) * sway_k


## Открытый конус от основания b (радиус TUBE_BASE_R) до устья top (TUBE_TOP_R); ph — фаза дыхания трубы.
func _tube(b: Vector3, top: Vector3, c: Color, ph: float) -> void:
	var v0 := verts.size()
	var n_sides := sides()
	var slope := (EcoOrgan.TUBE_BASE_R - EcoOrgan.TUBE_TOP_R) / maxf(0.01, top.y - b.y)
	for i in n_sides + 1:
		var a := TAU * i / n_sides
		var d := Vector3(cos(a), 0, sin(a))
		var n := (d + Vector3(0, slope, 0)).normalized()
		verts.append(b + d * EcoOrgan.TUBE_BASE_R)
		verts.append(top + d * EcoOrgan.TUBE_TOP_R)
		_uv.append(Vector2(ph, 0.0))
		_uv.append(Vector2(ph, 1.0))
		for j in 2:
			_nor.append(n)
			_col.append(c)
			_uv2.append(Vector2(d.x, d.z))
	for i in n_sides:
		var q := v0 + i * 2
		# обход не важен: труба видна с обеих сторон (cull_disabled)
		_idx.append_array([q, q + 1, q + 2, q + 2, q + 1, q + 3])


## Обод у устья: тор радиусом TUBE_TOP_R, толщина RIM_TUBE; едет с устьем (доля высоты 1, фаза ph).
func _rim(c: Vector3, ph: float) -> void:
	var v0 := verts.size()
	var n_sides := sides()
	var n_rim := rim_sides()
	for i in n_sides + 1:
		var a := TAU * i / n_sides
		var d := Vector3(cos(a), 0, sin(a))
		for j in n_rim + 1:
			var b := TAU * j / n_rim
			var n := d * cos(b) + Vector3(0, sin(b), 0)
			verts.append(c + d * EcoOrgan.TUBE_TOP_R + n * RIM_TUBE)
			_nor.append(n)
			_col.append(RIM)
			_uv.append(Vector2(ph, 1.0))
			_uv2.append(Vector2(d.x, d.z))
	var row := n_rim + 1
	for i in n_sides:
		for j in n_rim:
			var q := v0 + i * row + j
			_idx.append_array([q, q + row, q + 1, q + 1, q + row, q + row + 1])
