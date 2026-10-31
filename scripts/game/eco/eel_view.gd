class_name EelView
extends Node3D
## Стеклоусты в сцене (initEels/eelRender в js/creatures.js; ART-006, `docs/concept-art/stekloust-skrebun.md`): четыре
## MultiMesh на всех — камни логов (бурые, гранёные), прозрачная оболочка (#9AD9E8, звенья тела и голова), внутренности
## вместе с глазами (#607F89 без своего света и два красных глаза #E34D50, светятся сами — единственный свет вида;
## один шар, цвет экземпляра, свет глаз — по альфе цвета на общем шейдере растений `EcoShaders.Plant.TENTACLE`,
## #849: было два вызова отрисовки) и кольцо присоски у пасти (на стекле расплющено). Муть у дна (EcoEelDust: клуб у устья при выходе и возвращении, след у дна в броске) —
## дочерний MultiMesh «Муть» в мировых координатах, общий шейдер EcoShaders.MIST (INK). Стоит на слое отмели
## (OceanView.LAYER_WORLD).
## «Экономно» (`set_lite`, Б6): оболочка звеньев — шар грубее (SHELL_LITE: 7 × 4 вместо 10 × 6, треугольников вдвое
## меньше; прозрачные звенья накладываются друг на друга — перерисовка у окна тоже меньше), внутренности, глаза, мир и
## муть не меняются, вызовов столько же; сброс мира уровень не теряет.

const SHELL := Color(0.604, 0.851, 0.91, 0.3)   ## #9AD9E8, прозрачный край
const SHELL_GLOW := Color("16323a")
const ORGANS := Color("607f89")
const EYE := Color("e34d50")
const RING := Color("e8b8a8")
const ROCK := Color("5f586c")
## Звено k: радиус 0,34 · (1 − 0,7 k / SEGS) (в браузере 0,28), вытянуто вдоль тела в 2,6 раза; голова крупнее, чем
## в браузере (0,3 × (1; 0,8; 1,6)) — по концепту ART-006 пасть-присоска шире тела: 0,46 × 0,4 × 0,6 м.
const SEG_R := 0.34
const SEG_STRETCH := 2.6
const HEAD := Vector3(0.46, 0.4, 0.6)
## Внутренности — 0,45 звена, чуть ниже оси; глаза — по бокам головы сверху; кольцо — у пасти.
const ORGAN_K := 0.45
const EYE_R := 0.07
const EYES: Array[Vector3] = [Vector3(-0.24, 0.2, 0.3), Vector3(0.24, 0.2, 0.3)]
const RING_AT := Vector3(0, 0, 0.56)
const RING_FLAT := Vector3(1.35, 1.35, 0.5)
## На ходу тело виляет: смещение вбок sin(10t − 0,9k) · 0,05k.
const WAG := 0.05
const STRIDE := 12
## Запись экземпляра с цветом: трансформ и RGBA.
const CSTRIDE := 16
## Шар оболочки (меридианов, колец): обычный и на «Экономно».
const SHELL_SPHERE := Vector2i(10, 6)
const SHELL_LITE := Vector2i(7, 4)

var eels: EcoEel
## «Экономно» (set_lite).
var lite := false
var rocks: MultiMeshInstance3D
var shell: MultiMeshInstance3D
## Внутренности и глаза одним MultiMesh (#849): сначала n · (SEGS − 1) звеньев, потом n · 2 глаза.
var organs: MultiMeshInstance3D
var rings: MultiMeshInstance3D
## Глаза вдали (#970): мягкое красное пятно лицом к камере на каждом глазу (EcoEel.glint), общий шейдер мути
## EcoShaders.MIST (INK) — своего шейдера нет. Корабль ближе GLINT_NEAR или дальше GLINT_OFF — узел скрыт.
## Цвет пятна ярче единицы (GLINT_GAIN): туман воды на 45 м смешивает его с цветом воды, и обычный красный
## становится розовой точкой на светлом песке; с запасом красный остаётся красным, а на устройстве ещё и светится
## (bloom). Сложение цвета (SPOT) не годится: в луче прожектора песок почти белый, к белому красное не прибавить.
var glints: MultiMeshInstance3D
var glint_buffer := PackedFloat32Array()
## Пятно ярче самого глаза: в мути у дна вода съедает часть красного.
const GLINT_COLOR := Color(1.0, 0.16, 0.12)
const GLINT_GAIN := 4.0
const GLINT_ALPHA := 0.95
## Пятно чуть впереди глаза к кораблю, чтобы голова его не закрывала.
const GLINT_LIFT := 0.25
## Последние буферы (для тестов).
var shell_buffer := PackedFloat32Array()
var ring_buffer := PackedFloat32Array()

## Буфер внутренностей и глаз (трансформ и цвет экземпляра, CSTRIDE): цвета пишутся один раз при сборке.
var organ_buffer := PackedFloat32Array()
## Муть от угрей и её MultiMesh; буфер мути — для тестов.
var dust := EcoEelDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()


func _init(system: EcoEel, lite_on := false) -> void:
	eels = system
	name = "Стеклоусты"
	var n := eels.eels.size()
	rocks = EcoMM.instance(self, "Камни логов", build_rock(), n * EcoEel.ROCKS.size(), false)
	lite = lite_on
	shell = EcoMM.instance(self, "Оболочка", build_shell(lite), n * EcoEel.SEGS, false)
	organs = EcoMM.instance(self, "Внутренности", _sphere(6, 4, _organ_material()), n * (EcoEel.SEGS - 1 + EYES.size()),
		true)
	_paint_organs(n)
	rings = EcoMM.instance(self, "Присоска", _ring(), n, false)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = EcoShaders.mist(EcoShaders.Mist.INK)
	glints = EcoMM.instance(self, "Глаза вдали", quad, n * EYES.size(), true)
	dust_view = GrazerView.build_dust(EcoEelDust.POOL)
	add_child(dust_view)
	_place_rocks()
	sync(0.0)


## «Экономно»: оболочка — грубый шар; назад — обычный.
func set_lite(on: bool) -> void:
	if lite == on:
		return
	lite = on
	shell.multimesh.mesh = build_shell(on)


## Шар оболочки звена (на «Экономно» — SHELL_LITE).
static func build_shell(lite_on := false) -> SphereMesh:
	var k := SHELL_LITE if lite_on else SHELL_SPHERE
	return _sphere(k.x, k.y, _shell_material())


static func _sphere(radial: int, rings_n: int, mat: Material, r: float = 1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = radial
	m.rings = rings_n
	m.material = mat
	return m


static func _shell_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SHELL
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.emission_enabled = true
	mat.emission = SHELL_GLOW
	mat.roughness = 0.2
	return mat


## Внутренности и глаза: шейдер щупалец хватня (Plant.TENTACLE) без колыхания и просвета — цвет экземпляра в
## альбедо, альфа цвета 1 — светится сам (глаз), 0 — без своего света.
static func _organ_material() -> ShaderMaterial:
	return EcoShaders.plant(EcoShaders.Plant.TENTACLE, {"rough": 0.8, "spec": 0.4, "tip_glow": Vector2(0.0, 1.0),
		"back": Vector3.ZERO})


## Цвета экземпляров внутренностей и глаз. Цвет экземпляра — sRGB как есть: снимок сверен с прежним
## StandardMaterial (#607F89), с переводом в линейный внутренности выходили на четверть темнее.
func _paint_organs(n: int) -> void:
	var organ_n := n * (EcoEel.SEGS - 1)
	organ_buffer.resize(organs.multimesh.instance_count * CSTRIDE)
	var oc := ORGANS
	var ec := EYE
	for i in organs.multimesh.instance_count:
		var c := Color(oc, 0.0) if i < organ_n else Color(ec, 1.0)
		var o := i * CSTRIDE + STRIDE
		organ_buffer[o] = c.r; organ_buffer[o + 1] = c.g; organ_buffer[o + 2] = c.b; organ_buffer[o + 3] = c.a


static func _flat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.8
	return mat


## Кольцо присоски: тор 0,24…0,34 м, ось — вперёд (+Z).
static func _ring() -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = 0.24
	m.outer_radius = 0.34
	m.rings = 16
	m.ring_segments = 6
	m.material = _flat(RING)
	return m


## Камень логова: гранёный шар радиуса 1 (додекаэдр с неровностями 0,18, как G.jitter в js/world.js) — вершины
## сдвинуты по направлению от середины на ±18 % по хешу направления, грани плоские.
static func build_rock() -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radial_segments = 7
	sm.rings = 4
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in idx.size():
		var p := v[idx[i]]
		var h := sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453
		st.add_vertex(p * (1.0 + (h - floor(h) - 0.5) * 0.36))
	st.generate_normals()
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROCK
	mat.roughness = 1.0
	m.surface_set_material(0, mat)
	return m


func _place_rocks() -> void:
	var buf := PackedFloat32Array()
	buf.resize(rocks.multimesh.instance_count * STRIDE)
	var n := 0
	for e in eels.eels:
		for r in e.rocks:
			var b := Basis.from_euler(Vector3(n * 1.7, n * 2.3, 0.0)).scaled(Vector3.ONE * r.w)
			EcoMM.put(buf, n * STRIDE, Transform3D(b, Vector3(r.x, r.y, r.z)))
			n += 1
	rocks.multimesh.buffer = buf
	var pts := PackedVector3Array()
	for e in eels.eels:
		for r in e.rocks:
			pts.append(Vector3(r.x, r.y, r.z))
	EcoMM.fit([rocks], pts, ROCK_GROW)


## Запас рамки камней логов (#849): камни неподвижны, запас — их размер. Тело угря выплывает к кораблю —
## ему рамка на всю отмель.
const ROCK_GROW := 3.0


## Расставить тела в момент t (время мира); ship — корабль (муть дальше EcoGrazerDust.NEAR не поднимается, в луче
## прожектора светлее), flow — течение мира (уносит муть), ground — дно мира (след у дна).
func sync(t: float, ship: EcoLink.ShipState = null, flow := Vector3.ZERO, ground := Callable()) -> void:
	_sync_dust(t, ship, flow, ground)
	var n := eels.eels.size()
	shell_buffer.resize(n * EcoEel.SEGS * STRIDE)
	var eye0 := n * (EcoEel.SEGS - 1)
	ring_buffer.resize(n * STRIDE)
	glint_buffer.resize(n * EYES.size() * CSTRIDE)
	var lit := false
	for e in eels.eels:
		var segs := e.segs
		var wag := e.moving()
		for k in range(1, EcoEel.SEGS):
			var dir := segs[k - 1] - segs[k]
			if dir.length_squared() < 1e-6:
				dir = e.face
			dir = dir.normalized()
			var side := Vector3(dir.z, 0.0, -dir.x)
			side = side.normalized() if side.length_squared() > 1e-6 else Vector3.RIGHT
			var pos := segs[k] + side * (sin(t * 10.0 - k * 0.9) * WAG * k if wag else 0.0)
			var r := SEG_R * (1.0 - float(k) / EcoEel.SEGS * 0.7)
			var b := _look(dir)
			EcoMM.put(shell_buffer, (e.index * EcoEel.SEGS + k) * STRIDE,
				Transform3D(b.scaled_local(Vector3(r, r * 0.85, r * SEG_STRETCH)), pos))
			EcoMM.put(organ_buffer, (e.index * (EcoEel.SEGS - 1) + k - 1) * CSTRIDE,
				Transform3D(b.scaled_local(Vector3(r, r * 0.8, r * SEG_STRETCH) * ORGAN_K), pos - Vector3(0, r * 0.15, 0)))
		var hb := _look(e.face)
		var head := Transform3D(hb, segs[0])
		EcoMM.put(shell_buffer, e.index * EcoEel.SEGS * STRIDE, Transform3D(hb.scaled_local(HEAD), segs[0]))
		for j in EYES.size():
			var eye := head * EYES[j]
			EcoMM.put(organ_buffer, (eye0 + e.index * EYES.size() + j) * CSTRIDE,
				Transform3D(hb.scaled_local(Vector3.ONE * EYE_R), eye))
			var g := Vector2.ZERO
			var to := Vector3.ZERO
			if ship:
				to = ship.pos - eye
				g = EcoEel.glint(to.length())
			lit = lit or g.y > 0.0
			var o := (e.index * EYES.size() + j) * CSTRIDE
			EcoMM.put(glint_buffer, o, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * g.x * 2.0),
				eye + to.normalized() * GLINT_LIFT))
			glint_buffer[o + STRIDE] = GLINT_COLOR.r * GLINT_GAIN
			glint_buffer[o + STRIDE + 1] = GLINT_COLOR.g * GLINT_GAIN
			glint_buffer[o + STRIDE + 2] = GLINT_COLOR.b * GLINT_GAIN
			glint_buffer[o + STRIDE + 3] = GLINT_ALPHA * g.y
		var rb := hb * Basis(Vector3.RIGHT, PI / 2.0)
		if e.latched():
			rb = hb.scaled_local(RING_FLAT) * Basis(Vector3.RIGHT, PI / 2.0)
		EcoMM.put(ring_buffer, e.index * STRIDE, Transform3D(rb, head * RING_AT))
	EcoMM.send(shell, shell_buffer)
	EcoMM.send(organs, organ_buffer)
	EcoMM.send(rings, ring_buffer)
	glints.visible = lit
	if lit:
		EcoMM.send(glints, glint_buffer)


func _sync_dust(t: float, ship: EcoLink.ShipState, flow: Vector3, ground: Callable) -> void:
	dust.update(eels, t, ship.pos if ship else Vector3(1e6, 0, 1e6), ground)
	_dust.pack(dust.dust, t, flow, ship, EcoEelDust.COLOR, EcoEelDust.LIT, Seabed.mesh_height)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


## Поворот, у которого +Z смотрит вдоль dir (голова — пастью вперёд).
static func _look(dir: Vector3) -> Basis:
	var up := Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(dir, up, true)


## Расстановка экземпляра n из буфера.
static func transform_at(buf: PackedFloat32Array, n: int, stride := STRIDE) -> Transform3D:
	var i := n * stride
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
