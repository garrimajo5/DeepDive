class_name FernView
extends Node3D
## Волнолист в сцене: все листья — один MultiMesh из одного листа-пера (12 треугольников, загнут наружу), моллюски
## у подножий — второй MultiMesh из полусферы (initFerns в js/creatures.js). Цвет листа #3D9D91, края и кончик
## светлее (#68E6DC, ART-004) — отражённый свет, своей эмиссии нет; виден с обеих сторон;
## лист — общий шейдер растений (EcoShaders.PLANT). Стоит на слое отмели (OceanView.LAYER_WORLD). Моллюски у корабля дышат (ниже).
## Муть (EcoFernDust) — третий MultiMesh «Муть» на общем шейдере EcoShaders.MIST.
## «Экономно» (Б6, `set_lite`): лист — 3 отрезка вместо 6 (6 треугольников вместо 12, `LITE_SEGMENTS`), моллюск —
## полусфера 5 × 2 вместо 7 × 3 (`LITE_SHELL_SEG`); материалы, места, колыхание, муть и вызовы те же. Сброс мира
## уровень не теряет (EcoView.set_lite).
## Моллюски дышат (Б3, `shell_breath`): створки приоткрываются и смыкаются — высота ± SHELL_BREATH_H, ширина
## ± SHELL_BREATH_W за SHELL_BREATH_T с (ритм ± SHELL_BREATH_SPREAD и фаза — `EcoVary` по номеру моллюска), низ на дне.
## Только ближе SHELL_BREATH_FAR м к кораблю (размах гаснет к краю); дальше и на «Экономно» (`EcoShaders.sway_lite`) —
## в покое, буфер моллюсков переписывается, только пока хоть один куст дышит или только что затих. По времени мира
## (у гостя то же), масштаб экземпляра MultiMesh — шейдеров и вызовов не прибавилось.

const LEAF := Color("3D9D91")
const EDGE := Color("68E6DC")
const SHELL := Color("9a8fb2")
## Колыхание листа в течении (EcoCurrent.sway, в шейдере): крен, волна вверх, поперёк — доли длины листа.
const BEND := Vector3(0.1, 0.06, 0.04)
## Отрезков листа по длине и загиб кончика наружу (м при длине 1,4).
const SEGMENTS := 6
const LITE_SEGMENTS := 3
const CURL := 0.22
## Граней полусферы моллюска (по кругу × колец); LITE_* — на «Экономно».
const SHELL_SEG := Vector2i(7, 3)
const LITE_SHELL_SEG := Vector2i(5, 2)
## Чисел на экземпляр в буфере: transform 3 × 4 по строкам; у листьев ещё цвет экземпляра (4).
const STRIDE := 12
const STRIDE_C := 16
## Б4 «не клоны»: у каждого листа своя длина (±15 %), ширина (±8 %), поворот вокруг стебля (±0,2 рад при шаге
## 1,05 рад) и оттенок (светлее/темнее ±12 %, зеленее/синее ±0,06) — хешем от номера листа (`EcoVary`), мир (раскрытие,
## свет, сканер) не меняется. Оттенок — цвет экземпляра, ветка листа в PLANT умножает краски на COLOR.
const LEAF_LEN_SPREAD := 0.15
const LEAF_W_SPREAD := 0.08
const LEAF_TURN := 0.2
const LEAF_SHADE_SPREAD := 0.12
const LEAF_HUE_SPREAD := 0.06
## «Дыхание» моллюсков: размах по высоте и ширине, период, разброс ритма, дальность от корабля, м.
const SHELL_BREATH_H := 0.12
const SHELL_BREATH_W := 0.03
const SHELL_BREATH_T := 5.0
const SHELL_BREATH_SPREAD := 0.2
const SHELL_BREATH_FAR := 40.0

var ferns: EcoFern
var leaves: MultiMeshInstance3D
var shells: MultiMeshInstance3D
## Последний буфер листьев (для тестов).
var buffer := PackedFloat32Array()
## Муть (EcoFernDust: раскрываясь, листья стряхивают ил; рыбы клюют моллюсков) — дочерний MultiMesh «Муть» на общем
## шейдере EcoShaders.MIST, +1 вызов; буфер — для тестов.
var dust := EcoFernDust.new()
var dust_view: MultiMeshInstance3D
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()
var _ground := Callable()
## На «Экономно» — лист и моллюск грубее (set_lite).
var lite := false
## Поворот и размер каждого листа (Б4) — считаются один раз, с первым буфером.
var _turn: Array[Basis] = []
var _size := PackedVector3Array()
## Расстановка моллюсков в покое и буфер, отданный MultiMesh (для тестов); сколько раз его переписывали.
var _shell_rest: Array[Transform3D] = []
var shell_buffer := PackedFloat32Array()
var shell_writes := 0
## Куст дышал в прошлом кадре — его моллюски не в покое.
var _shell_live: Array[bool] = []


func _init(system: EcoFern, ground: Callable = Callable(), on_lite := false) -> void:
	ferns = system
	_ground = ground
	lite = on_lite
	name = "Волнолист"
	leaves = EcoMM.instance(self, "Листья", build_leaf(LITE_SEGMENTS if lite else SEGMENTS),
		ferns.ferns.size() * EcoFern.LEAVES, true, false, false)
	shells = EcoMM.instance(self, "Моллюски", build_shell(LITE_SHELL_SEG if lite else SHELL_SEG),
		ferns.ferns.size() * EcoFern.SHELLS, false, false, false)
	shell_buffer.resize(shells.multimesh.instance_count * STRIDE)
	_shell_rest.resize(shells.multimesh.instance_count)
	_shell_live.resize(ferns.ferns.size())
	_shell_live.fill(false)
	for fe in ferns.ferns:
		for j in EcoFern.SHELLS:
			var p := EcoFern.shell_pos(fe, j, ground)
			var a := float(j) / EcoFern.SHELLS * TAU + fe.yaw
			var b := Basis(Vector3.UP, a).scaled_local(Vector3(1.0, 0.5, 1.3) * fe.scale)
			var n := fe.index * EcoFern.SHELLS + j
			_shell_rest[n] = Transform3D(b, p)
			EcoMM.put(shell_buffer, n * STRIDE, _shell_rest[n])
	shells.multimesh.buffer = shell_buffer
	dust_view = GrazerView.build_dust(EcoFernDust.POOL)
	add_child(dust_view)
	sync(0.0)


## «Экономно» — лист и моллюск пересобраны грубее с теми же материалами; назад — полные.
func set_lite(on: bool) -> void:
	if lite == on:
		return
	lite = on
	leaves.multimesh.mesh = build_leaf(LITE_SEGMENTS if lite else SEGMENTS, leaves.multimesh.mesh.surface_get_material(0))
	shells.multimesh.mesh = build_shell(LITE_SHELL_SEG if lite else SHELL_SEG,
		(shells.multimesh.mesh as SphereMesh).material)


## Лист-перо 0,28 × 1,4 м (PlaneGeometry с шириной sin(y/1,4 · π) · 1,2, как в браузере): основание у подножия,
## растёт по +Y, кончик загнут в −Z — туда же лист ложится при раскрытии (EcoFern.leaf_basis).
## segments — отрезков по длине, mat — готовый материал (иначе новый).
static func build_leaf(segments := SEGMENTS, mat: Material = null) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nr := PackedVector3Array()
	for i in segments + 1:
		var k := float(i) / segments
		var y := k * EcoFern.LEAF_LEN
		var w := EcoFern.LEAF_W / 2.0 * sin(minf(1.0, k) * PI) * 1.2
		var z := -CURL * k * k
		for s in [-1.0, 1.0]:
			v.append(Vector3(s * w, y, z))
			uv.append(Vector2(0.5 + s * 0.5, 1.0 - k))
			nr.append(Vector3(0, 2.0 * CURL * k / EcoFern.LEAF_LEN, 1).normalized())
	var idx := PackedInt32Array()
	for i in segments:
		var a := i * 2
		# лицом к +Z по правилу Godot: (b − a) × (c − a) смотрит в −Z
		idx.append_array([a, a + 3, a + 1, a, a + 2, a + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nr
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if mat == null:
		mat = EcoShaders.plant(EcoShaders.Plant.LEAF, {"paint": LEAF, "edge": EDGE, "rough": 0.7, "bend": BEND,
			"reach": EcoFern.LEAF_LEN})
	mesh.surface_set_material(0, mat)
	return mesh


## Моллюск — полусфера радиусом 0,11 м (сплющена в расстановке); seg — граней по кругу × колец, mat — готовый
## материал (иначе новый).
static func build_shell(seg := SHELL_SEG, mat: Material = null) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.11
	m.height = 0.11
	m.is_hemisphere = true
	m.radial_segments = seg.x
	m.rings = seg.y
	if mat == null:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = SHELL
		sm.roughness = 0.5
		mat = sm
	m.material = mat
	return m


## Расставить листья в момент t (время мира). info — корабль (муть дальше 80 м не встаёт, светлее в луче),
## flow — течение мира (уносит муть); без корабля мути нет.
func sync(t: float, info: EcoLink.ShipState = null, flow := Vector3.ZERO) -> void:
	if info != null:
		dust.update(ferns, t, info.pos, _ground)
		_dust.pack(dust.dust, t, flow, info, EcoFernDust.COLOR, EcoFernDust.LIT, Seabed.mesh_height)
		_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)
	_sync_shells(t, info)
	var fresh := buffer.size() != leaves.multimesh.instance_count * STRIDE_C
	buffer.resize(leaves.multimesh.instance_count * STRIDE_C)
	if fresh:
		_turn.resize(leaves.multimesh.instance_count)
		_size.resize(leaves.multimesh.instance_count)
	for fe in ferns.ferns:
		for j in EcoFern.LEAVES:
			var n := fe.index * EcoFern.LEAVES + j
			var i := n * STRIDE_C
			if fresh:
				_turn[n] = leaf_turn(n)
				_size[n] = leaf_size(n)
			EcoMM.put(buffer, i, Transform3D((_turn[n] * EcoFern.leaf_basis(fe, j, t)).scaled_local(_size[n]), fe.pos))
			if fresh:
				var c := leaf_tint(n)
				buffer[i + 12] = c.r; buffer[i + 13] = c.g; buffer[i + 14] = c.b; buffer[i + 15] = 1.0
	EcoMM.send(leaves, buffer)


## Моллюски дышат у корабля (info — корабль; без него — в покое). Буфер — только если кто-то двигался.
func _sync_shells(t: float, info: EcoLink.ShipState) -> void:
	var dirty := false
	for fe in ferns.ferns:
		var d := INF if info == null else info.pos.distance_to(fe.pos)
		var live := not EcoShaders.sway_lite and d < SHELL_BREATH_FAR
		if not live and not _shell_live[fe.index]:
			continue
		_shell_live[fe.index] = live
		dirty = true
		for j in EcoFern.SHELLS:
			var n := fe.index * EcoFern.SHELLS + j
			var r := _shell_rest[n]
			var sc := shell_breath(n, t, d, live)
			EcoMM.put(shell_buffer, n * STRIDE, Transform3D(r.basis.scaled_local(sc), r.origin))
	if dirty:
		shells.multimesh.buffer = shell_buffer
		shell_writes += 1


## Множитель размера моллюска n в осях раковины в момент t: dist — от куста до корабля, м; live = false — ровно 1.
static func shell_breath(n: int, t: float, dist: float, live := true) -> Vector3:
	if not live or dist >= SHELL_BREATH_FAR:
		return Vector3.ONE
	var k := smoothstep(SHELL_BREATH_FAR, SHELL_BREATH_FAR * 0.7, dist)
	if k <= 0.0:
		return Vector3.ONE
	var rate := TAU / (SHELL_BREATH_T * EcoVary.spread(n, EcoVary.RATE, SHELL_BREATH_SPREAD))
	var s := sin(t * rate + EcoVary.unit(n, EcoVary.HUE) * TAU) * k
	return Vector3(1.0 + SHELL_BREATH_W * s, 1.0 + SHELL_BREATH_H * s, 1.0 + SHELL_BREATH_W * s)


## Лист n своей формы: повёрнут вокруг стебля на свой угол, длиннее или короче, шире или уже (оси листа).
static func leaf_shape(n: int, b: Basis) -> Basis:
	return (leaf_turn(n) * b).scaled_local(leaf_size(n))


## Поворот листа n вокруг стебля.
static func leaf_turn(n: int) -> Basis:
	return Basis(Vector3.UP, (EcoVary.unit(n, EcoVary.TURN) * 2.0 - 1.0) * LEAF_TURN)


## Ширина и длина листа n (множители по осям листа X и Y).
static func leaf_size(n: int) -> Vector3:
	return Vector3(EcoVary.spread(n, EcoVary.RATE, LEAF_W_SPREAD), EcoVary.spread(n, EcoVary.SIZE, LEAF_LEN_SPREAD), 1.0)


## Множитель красок листа n — цвет экземпляра.
static func leaf_tint(n: int) -> Color:
	var k := EcoVary.spread(n, EcoVary.SHADE, LEAF_SHADE_SPREAD)
	var h := (EcoVary.unit(n, EcoVary.HUE) * 2.0 - 1.0) * LEAF_HUE_SPREAD
	return Color(k * (1.0 - h * 0.5), k * (1.0 + h * 0.5), k * (1.0 - h))


## Расстановка экземпляра n из буфера.
static func transform_at(buf: PackedFloat32Array, n: int, stride := STRIDE) -> Transform3D:
	var i := n * stride
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
