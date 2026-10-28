class_name HvatenView
extends Node3D
## Хватни и пестрянки в сцене (initAnemones в js/creatures.js): три MultiMesh — тела (столб 0,45 → 0,32 м высотой
## 0,8 м и розовый диск щупалец, своё слабое свечение #2a0a24; дышат и сжимаются по ширине — EcoHvaten.body), щупальца (тонкие конусы 1 м с цветом по длине:
## лиловые у диска, светлее к кончикам; тело ловит свет, к кончикам светится само и колышется в течении мира —
## общий шейдер растений EcoShaders.PLANT, режим TENTACLE, двойник на CPU — `tentacle_offset`) и пестрянки
## (форма EcoPestrLook: тело 7 × 10 × 19 см, хвост-веер, спинной и грудные плавники; оранжевые и белая — цвет
## в INSTANCE_CUSTOM.rgb, фаза плавников — в альфе цвета экземпляра; рисует шейдер светляков FishView: хвост машет,
## грудные гребут, «Экономно» — sway_k через EcoShaders.follow). Стоят на слое отмели (OceanView.LAYER_WORLD).

## Цвета пестрянок по порядку (pc в браузере).
const PESTR_COLORS: Array[Color] = [Color("ff7a2a"), Color("fff1d0"), Color("ff9a4a")]
const BODY_GLOW := Color("2a0a24")
## Чисел на экземпляр: transform 3 × 4, у пестрянок ещё цвет (4: белый, в альфе — фаза плавников) и INSTANCE_CUSTOM
## (4: свечение, оттенок тела 1).
const STRIDE := 12
const STRIDE_P := 20
## Колыхание щупальца (доли длины на полном течении: крен, волна, поперёк) — мягче ленты ленточника, но заметно на
## метровом щупальце; сдвиг фазы по углу щупальца вокруг вертикали — щупальца одного диска извиваются вразнобой.
const BEND := Vector3(0.1, 0.16, 0.12)
const PHASE_AXIS := 10.0
## Свечение щупальца: у диска — доля цвета, у кончика — почти полный (раньше светилось целиком, MeshBasicMaterial).
const TIP_GLOW := Vector2(0.15, 0.9)

var hvaten: EcoHvaten
var bodies: MultiMeshInstance3D
var tents: MultiMeshInstance3D
var pestr: MultiMeshInstance3D
## Последние буферы тел, щупалец и пестрянок (для тестов — сервер отрисовки без экрана экземпляры не хранит).
var body_buffer := PackedFloat32Array()
var tent_buffer := PackedFloat32Array()
var pestr_buffer := PackedFloat32Array()
## Муть у дна (EcoHvatenDust: рывком прячет щупальца — клуб ила вокруг основания) — дочерний MultiMesh «Муть» на
## общем шейдере EcoShaders.MIST, +1 вызов; буфер — для тестов.
var dust := EcoHvatenDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()


func _init(system: EcoHvaten) -> void:
	hvaten = system
	name = "Хватни"
	var n := hvaten.anemones.size()
	bodies = EcoMM.instance(self, "Тела", build_body(), n, false)
	tents = EcoMM.instance(self, "Щупальца", build_tentacle(), n * EcoHvaten.TENT, false)
	pestr = EcoMM.instance(self, "Пестрянки", build_pestr(), n * EcoHvaten.PESTR_N, true, true)
	body_buffer.resize(n * STRIDE)
	tent_buffer.resize(n * EcoHvaten.TENT * STRIDE)
	pestr_buffer.resize(n * EcoHvaten.PESTR_N * STRIDE_P)
	dust_view = GrazerView.build_dust(EcoHvatenDust.POOL)
	add_child(dust_view)
	for hv in hvaten.anemones:
		for k in EcoHvaten.PESTR_N:
			var c := PESTR_COLORS[k % PESTR_COLORS.size()] * EcoPestrLook.GLOW
			var i := (hv.index * EcoHvaten.PESTR_N + k) * STRIDE_P
			pestr_buffer[i + 12] = 1.0; pestr_buffer[i + 13] = 1.0; pestr_buffer[i + 14] = 1.0
			pestr_buffer[i + 15] = EcoPestrLook.phase(hv, k)
			pestr_buffer[i + 16] = c.r; pestr_buffer[i + 17] = c.g; pestr_buffer[i + 18] = c.b; pestr_buffer[i + 19] = 1.0
	var pts := PackedVector3Array()
	for hv in hvaten.anemones:
		pts.append(hv.base)
	EcoMM.fit([bodies, tents, pestr], pts, FRAME_GROW)
	sync(0.0)


## Запас рамки вокруг хватней (#849): щупальца тянутся на 1,9 м, пестрянки кружат рядом, течение гнёт.
const FRAME_GROW := 5.0


## Тело: столб (0,32 сверху, 0,45 снизу, 0,8 м) цвета (0,48, 0,22, 0,42) и диск (0,4 → 0,32, 0,08 м) на 0,82 м —
## (0,95, 0,55, 0,75). Девять граней, как в браузере.
static func build_body() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cylinder(st, 0.32, 0.45, 0.8, 0.4, Color(0.48, 0.22, 0.42), 9, 1, true)
	_add_cylinder(st, 0.4, 0.32, 0.08, 0.82, Color(0.95, 0.55, 0.75), 9, 1, true)
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = BODY_GLOW
	m.surface_set_material(0, mat)
	return m


## Щупальце: конус 0,05 → 0,015 м длиной 1 м от основания вверх, четыре грани, цвет по высоте k:
## (0,55 + 0,45k, 0,25 + 0,6k, 0,6 + 0,35k), в альфе — k (свечение к кончику); тело со светом (PLANT, TENTACLE).
static func build_tentacle() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cylinder(st, 0.015, 0.05, 1.0, 0.5, Color.WHITE, 4, 3, false)
	var m := st.commit()
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var col := PackedColorArray()
	for p in v:
		var k := clampf(p.y, 0.0, 1.0)
		col.append(Color(0.55 + k * 0.45, 0.25 + k * 0.6, 0.6 + k * 0.35, k))
	arr[Mesh.ARRAY_COLOR] = col
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	out.surface_set_material(0, EcoShaders.plant(EcoShaders.Plant.TENTACLE, {"rough": 0.6, "spec": 0.4,
		"bend": BEND, "reach": 1.0, "phase_axis": PHASE_AXIS, "tip_glow": TIP_GLOW}))
	return out


## Смещение точки v щупальца (в осях меша: y — доля длины) в мире по формуле шейдера PLANT (двойник для тестов):
## tr — расстановка щупальца из буфера, flow — течение мира.
static func tentacle_offset(tr: Transform3D, v: Vector3, t: float, flow: Vector3) -> Vector3:
	var ay := tr.basis.y
	var po := tr.origin + Vector3(atan2(ay.z, ay.x) * PHASE_AXIS, 0.0, 0.0)
	return EcoCurrent.sway(po, clampf(v.y, 0.0, 1.0), ay.length(), t, flow, BEND)


## Пестрянка: форма EcoPestrLook (нос по +Z) на шейдере светляков FishView — тот же ресурс Shader, свой материал
## с тёмной основой плавников; светится цветом экземпляра, плавники машут в шейдере.
static func build_pestr() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = EcoPestrLook.shape
	arrays[Mesh.ARRAY_NORMAL] = EcoPestrLook.normals
	arrays[Mesh.ARRAY_COLOR] = EcoPestrLook.colors
	arrays[Mesh.ARRAY_INDEX] = EcoPestrLook.tris
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = EcoShaders.shader(FishView.shader_code())
	mat.set_shader_parameter("body_color", EcoPestrLook.BODY_COLOR)
	m.surface_set_material(0, EcoShaders.follow(mat))
	return m


## Цилиндр CylinderMesh в SurfaceTool: середина на высоте mid, цвет вершин c; caps — с крышками.
static func _add_cylinder(st: SurfaceTool, top: float, bottom: float, h: float, mid: float, c: Color, seg: int,
		rings: int, caps: bool) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = seg
	cm.rings = rings
	cm.cap_top = caps
	cm.cap_bottom = caps
	var arr := cm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.set_color(c)
		st.set_normal(nr[i])
		st.add_vertex(v[i] + Vector3(0, mid, 0))


## Хватень дальше FAR от корабля не в луче переписывается раз в FAR_EVERY кадров, хватни — вразнобой (бюджет кадра,
## issue #133: метровые щупальца за 50 м в темноте не разглядеть).
const FAR := EcoFish.MID
const FAR_EVERY := 3

var _frame := 0


## Расставить тела (дыхание — EcoHvaten.breath), щупальца и пестрянок в момент t (время мира); all — переписать всех
## хватней сразу. На «Экономно» (EcoShaders.sway_lite) тело не дышит, только сжимается со щупальцами.
## info — корабль целиком (муть светлее в луче прожектора), flow — течение мира (уносит муть).
func sync(t: float, ship_pos := Vector3.ZERO, all := true, info: EcoLink.ShipState = null,
		flow := Vector3.ZERO) -> void:
	_frame += 1
	_sync_dust(t, ship_pos, info, flow)
	var live := not EcoShaders.sway_lite
	for hv in hvaten.anemones:
		if not all and not due(hv, ship_pos, _frame):
			continue
		EcoMM.put(body_buffer, hv.index * STRIDE, EcoHvaten.body(hv, t, live))
		for k in EcoHvaten.TENT:
			EcoMM.put(tent_buffer, (hv.index * EcoHvaten.TENT + k) * STRIDE, EcoHvaten.tentacle(hv, k, t, live))
		for k in EcoHvaten.PESTR_N:
			var tr := EcoHvaten.pestr_pose(hv, k, t)
			tr.basis = tr.basis * Basis.from_scale(Vector3.ONE * EcoPestrLook.SCALE)
			EcoMM.put(pestr_buffer, (hv.index * EcoHvaten.PESTR_N + k) * STRIDE_P, tr)
	EcoMM.send(bodies, body_buffer)
	EcoMM.send(tents, tent_buffer)
	EcoMM.send(pestr, pestr_buffer)


func _sync_dust(t: float, ship: Vector3, info: EcoLink.ShipState, flow: Vector3) -> void:
	dust.update(hvaten, t, ship)
	_dust.pack(dust.dust, t, flow, info, EcoHvatenDust.COLOR, EcoHvatenDust.LIT,
			Seabed.mesh_height)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


## Переписать ли хватня в этом кадре: близкий или в луче — всегда, дальний — в свой кадр из трёх.
static func due(hv: EcoHvaten.Anemone, ship_pos: Vector3, frame: int) -> bool:
	return hv.lit or hv.base.distance_squared_to(ship_pos) < FAR * FAR or (frame + hv.index) % FAR_EVERY == 0


## Расстановка экземпляра n из буфера с шагом stride.
static func transform_at(buf: PackedFloat32Array, n: int, stride: int = STRIDE) -> Transform3D:
	var i := n * stride
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
