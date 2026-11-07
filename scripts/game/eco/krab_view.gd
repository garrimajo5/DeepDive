class_name KrabView
extends Node3D
## Кольчужник в сцене (initKelp — нора, crabUpdate, crabSpines в js/creatures.js): нора из пяти приплюснутых камней
## (#4f4a5c, гранёные), тело — панцирь-эллипсоид (#8a4a2e, слабое свечение #1a0804) и шесть ног одним мешем,
## клешни отдельным мешем (поднимаются на 0,9 · raise), иглы ежей на панцире — MultiMesh на 10 игл (стержень со
## светом, кончик светится сам; лишние сжаты в точку), переписывается, только когда игл стало больше (EcoKrab.dirty) и пока новая игла растёт:
## вплетённая игла вырастает из панциря за SPINE_RISE (доля spine_k, по времени мира), а не появляется за кадр. Тело в 1,25 раза крупнее, на ходу
## подпрыгивает до HOP = 3 см — размах по доле хода (hop: полный с HOP_FULL м/с), трогаясь и вставая, шаг мельче, а не
## включается и пропадает за кадр. Муть у дна из-под ног и от клешней (EcoKrabDust) — дочерний MultiMesh «Муть» в мировых
## координатах, общий шейдер EcoShaders.MIST (INK), бурый цвет EcoKrabDust.COLOR/LIT. Шесть вызовов отрисовки (у игл две поверхности); стоит на слое
## отмели (OceanView.LAYER_WORLD).
## Иглы не клоны (Б4, `EcoVary`): у иглы своя длина (±SPINE_LEN_SPREAD) и толщина (±SPINE_THICK_SPREAD) по её номеру —
## в `spine_transform`, вызовов и шейдеров столько же.
## «Экономно» (Б6, `set_lite`): панцирь 7 × 4 вместо 10 × 6, щипцы 6 × 3 вместо 8 × 5 (LITE_*) — тело и клешни 324 →
## 186 треугольников (с норой 424 → 286); меши пересобираются с теми же материалами (свечение панциря). Нора та же:
## камни 4 × 2 становятся ромбами-кристаллами, а не камнями. Ноги, руки, иглы, муть и вызовы те же. Сброс мира
## уровень не теряет (EcoView.set_lite).
## «Дыхание» (Б3, `breath`): панцирь набирает воду и выталкивает её — высота ± BREATH_H, ширина ± BREATH_W за
## BREATH_T с, длина та же (клешни и иглы на месте), низ тела на дне (масштаб от узла тела). Напуган (скальник,
## `EcoKrab.Crab.scared`) — затаил дыхание: HELD размаха; доля `calm` догоняет цель за CALM_T с — размах не прыгает.
## По времени мира (у гостя то же), масштаб узла — даром, и на «Экономно».

const ROCK := Color("4f4a5c")
const SHELL := Color("8a4a2e")
const LEG := Color("6a3a26")
const ARM := Color("7a4028")
const PINCER := Color("c06a3a")
const GLOW := Color("1a0804")
const SPINE_BASE := Color(0.3, 0.15, 0.4)
const SPINE_TIP := Color(0.55, 0.95, 1.0)
const SCALE := 1.25
## За сколько секунд вплетённая игла вырастает из панциря (и уходит, если игл стало меньше).
const SPINE_RISE := 0.6
## Разброс игл: длина и толщина.
const SPINE_LEN_SPREAD := 0.2
const SPINE_THICK_SPREAD := 0.12
## Подскок тела на ходу (м), с какой скорости по дну он во весь размах (м/с — ход к норе) и ритм (рад/с).
const HOP := 0.03
const HOP_FULL := 0.8
const HOP_RATE := 8.0
## Шаг ног на ходу (Б3): ноги ходят вперёд-назад вокруг бедра двумя тройками вразнобой (передняя и задняя одного
## борта с средней другого) — до LEG_SWING рад, вперёд — с подъёмом стопы до LEG_LIFT м; ритм — HOP_RATE, полшага на
## подскок тела; размах — по доле хода, как подскок. Стоит — ноги на месте. На CPU: меш тела пересобирается из
## готовых массивов, только пока ноги двигаются; шейдеров и вызовов не прибавилось.
const LEG_SWING := 0.35
const LEG_LIFT := 0.05
## Ноги в построении тела: борт (−1, +1) × место вдоль тела; бедро — у панциря.
const LEG_Z: Array[float] = [-0.25, 0.0, 0.25]
const HIP_X := 0.4
const HIP_Y := 0.33
## Дальше LEG_FAR м от корабля ноги не шагают (их не разглядеть) — меш не пересобирается.
const LEG_FAR := 50.0
## Камни норы: смещение (нос норы — наружу от рощи, +Z) и размер 0,8…1,1 м, приплюснуты до 0,6 по высоте.
const ROCKS: Array[Vector3] = [Vector3(-1.3, 0.3, -0.4), Vector3(1.3, 0.3, -0.4), Vector3(0, 0.8, -1.1),
	Vector3(-0.6, 1.3, -0.9), Vector3(0.7, 0.2, -1.6)]
const ROCK_SIZES: Array[float] = [0.95, 1.05, 0.85, 0.9, 1.0]
const CLAWS_AT := Vector3(0, 0.35, 0.3)
## Граней эллипсоидов (по кругу × по высоте): панцирь, щипцы, камни норы; LITE_* — то же на «Экономно» (нора — нет).
const SHELL_SEG := Vector2i(10, 6)
const PINCER_SEG := Vector2i(8, 5)
const ROCK_SEG := Vector2i(5, 3)
const LITE_SHELL_SEG := Vector2i(7, 4)
const LITE_PINCER_SEG := Vector2i(6, 3)
## Дыхание панциря: доли высоты и ширины, период (с), размах затаившегося и за сколько секунд доля меняется целиком.
const BREATH_H := 0.035
const BREATH_W := 0.018
const BREATH_T := 5.0
const HELD := 0.25
const CALM_T := 1.0

var krab: EcoKrab
var den: MeshInstance3D
var body: MeshInstance3D
var claws: MeshInstance3D
var spines: MultiMeshInstance3D
## Сколько игл видно (для тестов) и сколько раз переписаны иглы.
var shown_spines := 0
var spine_writes := 0
## Последний буфер игл (KelpView.transform_at с шагом KelpView.STRIDE).
var spine_buffer := PackedFloat32Array()
## Доля роста каждой иглы 0…1 (1 — во всю длину).
var spine_k := PackedFloat32Array()
var _spine_t := 0.0
var _spine_fresh := true
## Муть от краба и её MultiMesh; буфер мути — для тестов.
var dust := EcoKrabDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()
## На «Экономно» — грубее панцирь и щипцы (set_lite).
var lite := false
## Поза ног: углы ног в последнем меше тела и готовые массивы тела в покое (body_rest).
var leg_angles := PackedFloat32Array()
var _rest: Dictionary = {}
## Доля размаха дыхания 0…1 (HELD…1): 1 — спокоен, 0 — затаился; и время прошлого sync.
var calm := 1.0
var _last_t := 0.0


func _init(system: EcoKrab, on_lite := false) -> void:
	krab = system
	lite = on_lite
	name = "Кольчужник"
	var cr := krab.crab
	den = _mesh("Нора", build_den(), self)
	_rest = body_rest(lite)
	body = _mesh("Тело", _rest["mesh"], self)
	claws = _mesh("Клешни", build_claws(lite), body)
	claws.position = CLAWS_AT
	spines = MultiMeshInstance3D.new()
	spines.name = "Иглы"
	spines.layers = OceanView.LAYER_WORLD
	spines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = build_spine()
	mm.instance_count = EcoKrab.SPINE_MAX
	spines.multimesh = mm
	spines.custom_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	body.add_child(spines)
	body.scale = Vector3.ONE * SCALE
	dust_view = GrazerView.build_dust(EcoKrabDust.POOL)
	add_child(dust_view)
	visible = cr != null
	if cr:
		den.transform = Transform3D(Basis(Vector3.UP, atan2(cr.out.x, cr.out.z)), cr.den)
	krab.dirty = true
	sync(0.0)


## «Экономно» — панцирь и щипцы пересобраны грубее (материалы те же); назад — полные.
func set_lite(on: bool) -> void:
	if lite == on:
		return
	lite = on
	_rest = body_rest(lite)
	_swap(body, _rest["mesh"])
	leg_angles = PackedFloat32Array()
	_swap(claws, build_claws(lite))


static func _swap(mi: MeshInstance3D, m: ArrayMesh) -> void:
	m.surface_set_material(0, mi.mesh.surface_get_material(0))
	mi.mesh = m


## Треугольников в норе, теле и клешнях (без игл; для тестов).
func tris() -> int:
	var n := 0
	for mi in [den, body, claws]:
		n += (mi.mesh as ArrayMesh).surface_get_array_len(0) / 3
	return n


func _mesh(n: String, m: Mesh, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.layers = OceanView.LAYER_WORLD
	EcoShadows.cast(mi)
	parent.add_child(mi)
	return mi


## Расставить краба в момент t (время мира). ship — корабль (дальше EcoGrazerDust.NEAR муть не поднимается, в луче
## прожектора светлее), flow — течение мира (уносит муть).
func sync(t: float, ship: EcoLink.ShipState = null, flow: Vector3 = Vector3.ZERO) -> void:
	var cr := krab.crab
	if cr == null:
		return
	_sync_dust(t, ship, flow)
	var p := cr.pos
	var speed := Vector2(cr.vel.x, cr.vel.z).length()
	p.y += hop(t, speed)
	var far := ship != null and ship.pos.distance_to(cr.pos) > LEG_FAR
	_step_legs(t, 0.0 if far else speed)
	var dt := clampf(t - _last_t, 0.0, 0.25)
	_last_t = t
	calm = move_toward(calm, 0.0 if cr.scared > 0.0 else 1.0, dt / CALM_T)
	var yaw := Basis(Vector3.UP, atan2(cr.dir.x, cr.dir.z))
	body.transform = Transform3D(yaw * Basis.from_scale(breath(calm, t) * SCALE), p)
	claws.rotation = Vector3(-cr.raise * 0.9, 0, 0)
	var grew := _grow_spines(t, cr.spines)
	if krab.dirty or grew:
		krab.dirty = false
		spine_buffer.resize(EcoKrab.SPINE_MAX * KelpView.STRIDE)
		for k in EcoKrab.SPINE_MAX:
			EcoMM.put(spine_buffer, k * KelpView.STRIDE, spine_at(k, spine_k[k]))
		spines.multimesh.buffer = spine_buffer
		shown_spines = cr.spines
		spine_writes += 1


## Подскок тела в момент t при скорости по дну speed (м/с): |sin| ритма HOP_RATE, размах — по доле хода до HOP_FULL
## с мягким входом; стоит — 0. Раньше подскок включался по EcoKrab.Crab.moving (ход > 1 см/с): на подходе к ежу и в
## нору краб ползёт 5 см/с и прыгал во весь размах, а встав — опускался на 3 см за кадр.
static func hop(t: float, speed: float) -> float:
	return absf(sin(t * HOP_RATE)) * HOP * smoothstep(0.0, 1.0, clampf(speed / HOP_FULL, 0.0, 1.0))


## Масштаб панциря в момент t при спокойствии calm (0 — затаился): вдох — выше и шире, длина та же; затаился — HELD
## размаха.
static func breath(calm_k: float, t: float) -> Vector3:
	var k := lerpf(HELD, 1.0, clampf(calm_k, 0.0, 1.0)) * sin(t * TAU / BREATH_T)
	return Vector3(1.0 + BREATH_W * k, 1.0 + BREATH_H * k, 1.0)


## Ход ноги i (0…5: борт −1 — 0…2, +1 — 3…5; вдоль тела — LEG_Z) в момент t при скорости speed: x — доля шага
## −1…1 (вперёд — к носу +Z), y — подъём стопы 0…1 (на ходу вперёд). Размах — по доле хода, как hop.
static func leg_step(i: int, t: float, speed: float) -> Vector2:
	var k := smoothstep(0.0, 1.0, clampf(speed / HOP_FULL, 0.0, 1.0))
	if k <= 0.0:
		return Vector2.ZERO
	var ph := t * HOP_RATE + PI * float((int(i / 3.0) + i % 3) % 2)
	return Vector2(sin(ph) * k, maxf(0.0, cos(ph)) * k)


## Угол поворота ноги i вокруг бедра (по вертикали) при доле шага s: стопа вперёд к носу при s > 0.
static func leg_yaw(i: int, s: float) -> float:
	var sx := -1.0 if i < 3 else 1.0
	return -sx * s * LEG_SWING


## Поставить ноги к моменту t: меш тела пересобирается, только если углы сдвинулись (стоит — один раз в покой).
func _step_legs(t: float, speed: float) -> void:
	var a := PackedFloat32Array()
	a.resize(12)
	for i in 6:
		var st := leg_step(i, t, speed)
		a[i * 2] = leg_yaw(i, st.x)
		a[i * 2 + 1] = st.y * LEG_LIFT
	if a == leg_angles:
		return
	leg_angles = a
	var m := body.mesh as ArrayMesh
	var mat := m.surface_get_material(0)
	m.clear_surfaces()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, pose_arrays(_rest, a))
	m.surface_set_material(0, mat)


## Массивы тела с ногами в позе a (по две числа на ногу: угол вокруг бедра, подъём стопы в м): вершины ноги
## поворачиваются вокруг вертикали через бедро, стопа поднимается пропорционально выносу от бедра.
static func pose_arrays(rest: Dictionary, a: PackedFloat32Array) -> Array:
	var arr: Array = (rest["arrays"] as Array).duplicate()
	var v: PackedVector3Array = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var n: PackedVector3Array = (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var leg: PackedInt32Array = rest["leg"]
	var hips: Array = rest["hips"]
	var reach := 0.55
	for j in v.size():
		var i := leg[j]
		if i < 0:
			continue
		var yaw := a[i * 2]
		var hip: Vector3 = hips[i]
		var d := v[j] - hip
		var out := Vector2(d.x, d.z).length()
		var b := Basis(Vector3.UP, yaw)
		v[j] = hip + b * d + Vector3(0, a[i * 2 + 1] * out / reach, 0)
		n[j] = b * n[j]
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	return arr


## Доли роста игл к моменту t: первые count — к 1, остальные — к 0, за SPINE_RISE. Первый шаг и время назад — сразу.
## true — какая-то доля сдвинулась (буфер переписать).
func _grow_spines(t: float, count: int) -> bool:
	if spine_k.size() != EcoKrab.SPINE_MAX:
		spine_k.resize(EcoKrab.SPINE_MAX)
		_spine_fresh = true
	var dt := t - _spine_t
	_spine_t = t
	var snap := _spine_fresh or dt < 0.0
	_spine_fresh = false
	var moved := false
	for k in EcoKrab.SPINE_MAX:
		var goal := 1.0 if k < count else 0.0
		var v := goal if snap else move_toward(spine_k[k], goal, dt / SPINE_RISE)
		if v != spine_k[k]:
			moved = true
			spine_k[k] = v
	return moved


## Игла k при доле роста grow 0…1: растёт из панциря от основания (мягкий вход и выход); 0 — сжата в точку.
static func spine_at(k: int, grow: float) -> Transform3D:
	if grow <= 0.0:
		return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	var tr := spine_transform(k)
	return Transform3D(tr.basis * Basis.from_scale(Vector3.ONE * smoothstep(0.0, 1.0, grow)), tr.origin)


func _sync_dust(t: float, ship: EcoLink.ShipState, flow: Vector3) -> void:
	dust.update(krab, t, ship.pos if ship else Vector3.ZERO)
	_dust.pack(dust.dust, t, flow, ship, EcoKrabDust.COLOR, EcoKrabDust.LIT,
			Seabed.mesh_height)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


## Место иглы k на панцире: по кругу, наклонена наружу (crab spineM); длина и толщина — свои (spine_size).
static func spine_transform(k: int) -> Transform3D:
	var a := float(k) / EcoKrab.SPINE_MAX * TAU + 0.3
	var b := Basis(Vector3.RIGHT, sin(a) * 0.9) * Basis(Vector3.BACK, -cos(a) * 0.9)
	return Transform3D(b * Basis.from_scale(spine_size(k)), Vector3(cos(a) * 0.38, 0.45, sin(a) * 0.3))


## Масштаб иглы k: x и z — толщина, y — длина (стержень растёт по оси y); один и тот же при каждом вызове.
static func spine_size(k: int) -> Vector3:
	var th := EcoVary.spread(k, EcoVary.SHADE, SPINE_THICK_SPREAD)
	return Vector3(th, EcoVary.spread(k, EcoVary.SIZE, SPINE_LEN_SPREAD), th)


## Нора: пять гранёных камней, приплюснутых по высоте.
static func build_den() -> ArrayMesh:
	var st := _begin()
	var g := ROCK_SEG
	for i in ROCKS.size():
		var s := ROCK_SIZES[i]
		EcoMM.ellipsoid(st, ROCKS[i], Vector3(s, s * 0.6, s), g.x, g.y, ROCK, 0.17 * i)
	return _commit(st, false)


## Панцирь и шесть ног (по три с борта, разведены веером и опущены к дну) — в покое.
static func build_body(on_lite := false) -> ArrayMesh:
	return body_rest(on_lite)["mesh"]


## Тело в покое: меш, его массивы, номер ноги у каждой вершины (−1 — панцирь) и бёдра ног (для pose_arrays).
static func body_rest(on_lite := false) -> Dictionary:
	var g := LITE_SHELL_SEG if on_lite else SHELL_SEG
	var st := _begin()
	EcoMM.ellipsoid(st, Vector3(0, 0.35, 0), Vector3(0.55, 0.22, 0.42), g.x, g.y, SHELL)
	var arr := st.commit_to_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var leg := PackedInt32Array()
	leg.resize(v.size())
	leg.fill(-1)
	var hips: Array[Vector3] = []
	var i := 0
	for sx in [-1.0, 1.0]:
		for z: float in LEG_Z:
			var yaw: float = -z * 1.5 if sx > 0 else PI + z * 1.5
			var b := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, -0.5)
			var hip := Vector3(sx * HIP_X, HIP_Y, z)
			hips.append(hip)
			var ls := _begin()
			_box(ls, Transform3D(b, hip), Vector3(0.27, 0, 0), Vector3(0.55, 0.05, 0.06), LEG)
			var la := ls.commit_to_arrays()
			v.append_array(la[Mesh.ARRAY_VERTEX])
			n.append_array(la[Mesh.ARRAY_NORMAL])
			c.append_array(la[Mesh.ARRAY_COLOR])
			var add := PackedInt32Array()
			add.resize((la[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
			add.fill(i)
			leg.append_array(add)
			i += 1
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = v
	out[Mesh.ARRAY_NORMAL] = n
	out[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.emission_enabled = true
	mat.emission = GLOW
	m.surface_set_material(0, mat)
	return {"mesh": m, "arrays": out, "leg": leg, "hips": hips}


## Клешни: две руки вперёд и щипцы на концах.
static func build_claws(on_lite := false) -> ArrayMesh:
	var st := _begin()
	var g := LITE_PINCER_SEG if on_lite else PINCER_SEG
	for sx in [-1.0, 1.0]:
		_box(st, Transform3D.IDENTITY, Vector3(sx * 0.22, 0, 0.2), Vector3(0.08, 0.08, 0.4), ARM)
		EcoMM.ellipsoid(st, Vector3(sx * 0.24, 0, 0.5), Vector3(0.11, 0.08, 0.2), g.x, g.y, PINCER)
	return _commit(st, true)


## Игла ежа: четырёхгранный конус 0,3 м и светящийся кончик-ромб. Стержень освещается (ловит свет сквозь лёд,
## прожектор и тени), сам светится только кончик — две поверхности, см. spine_mesh.
static func build_spine() -> ArrayMesh:
	var shaft := _begin()
	var glow := _begin()
	var tip := Vector3(0, 0.3, 0)
	var ring: Array[Vector3] = []
	for j in 4:
		var t := j * TAU / 4.0
		ring.append(Vector3(cos(t), 0, sin(t)) * 0.025)
	var mid := Vector3(0, 0.1, 0)
	for j in 4:
		EcoMM.tri(shaft, ring[j], ring[(j + 1) % 4], tip, SPINE_BASE, mid)
		EcoMM.tri(shaft, ring[(j + 1) % 4], ring[j], Vector3.ZERO, SPINE_BASE, mid)
	var e := 0.03
	var pts: Array[Vector3] = [tip + Vector3(e, 0, 0), tip + Vector3(0, 0, e), tip - Vector3(e, 0, 0), tip - Vector3(0, 0, e)]
	for j in 4:
		EcoMM.tri(glow, pts[j], pts[(j + 1) % 4], tip + Vector3(0, e, 0), SPINE_TIP, tip)
		EcoMM.tri(glow, pts[j], pts[(j + 1) % 4], tip - Vector3(0, e, 0), SPINE_TIP, tip)
	return spine_mesh(shaft, glow)


## Игла из двух поверхностей: 0 — стержень со светом (цвет вершин, матовый — тот же шейдер, что у норы), 1 — кончик
## без освещения (светится сам). Новых шейдеров нет; у MultiMesh игл — два вызова отрисовки.
static func spine_mesh(shaft: SurfaceTool, glow: SurfaceTool) -> ArrayMesh:
	var m := shaft.commit()
	var lit := StandardMaterial3D.new()
	lit.vertex_color_use_as_albedo = true
	lit.roughness = 0.6
	m.surface_set_material(0, lit)
	glow.commit(m)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	m.surface_set_material(1, mat)
	return m


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _commit(st: SurfaceTool, glow: bool) -> ArrayMesh:
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	if glow:
		mat.emission_enabled = true
		mat.emission = GLOW
	m.surface_set_material(0, mat)
	return m




## Брусок размером size с серединой at в системе tr.
static func _box(st: SurfaceTool, tr: Transform3D, at: Vector3, size: Vector3, col: Color) -> void:
	var h := size / 2.0
	var v: Array[Vector3] = []
	for k in 8:
		v.append(tr * (at + Vector3(h.x if k & 1 else -h.x, h.y if k & 2 else -h.y, h.z if k & 4 else -h.z)))
	var mid := tr * at
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		EcoMM.tri(st, v[f[0]], v[f[1]], v[f[2]], col, mid)
		EcoMM.tri(st, v[f[0]], v[f[2]], v[f[3]], col, mid)
