class_name SkalnikView
extends Node3D
## Скальник в сцене (initSkalnik, skRender в js/creatures.js): мантия-эллипсоид с двумя рогами и глазами — один
## гранёный меш, восемь щупалец по шесть шаров — MultiMesh. Цвет общий: камень #4f4a5c, без маскировки — кожа
## #b8553c и слабое свечение. Щупальца колышутся, у камня поджаты (0,55), на ходу тянутся за телом и ложатся
## на дно. Вдали (дальше FAR от корабля) неподвижный камень щупальца не переписывает. Украденный образец —
## светящийся октаэдр 0,22 м над мантией между рогами (carryM), виден, только пока несёт. Муть у дна (EcoSkalnikDust:
## клуб, когда «камень» снимается с места и оседает, след щупалец у дна) — дочерний MultiMesh «Муть» в мировых
## координатах, общий шейдер EcoShaders.MIST (INK). Три вызова отрисовки (с добычей — четыре), слой отмели
## (OceanView.LAYER_WORLD).

const ROCK := Color("4f4a5c")
const SKIN := Color("b8553c")
const GLOW := Color(0.12, 0.03, 0.02)
## Добыча: цвет и высота над скальником.
const CARRY := Color("9dffd0")   # светится, как камешки образцов на дне
const CARRY_UP := 1.2
const ARMS := 8
const SEG := 6
const STRIDE := 12
## Дальше этого от корабля неподвижный камень не шевелит щупальцами (не видно).
const FAR := 80.0

var skalnik: EcoSkalnik
var body: MeshInstance3D
var arms: MultiMeshInstance3D
var material: StandardMaterial3D
## Украденный образец в щупальцах.
var carry: MeshInstance3D
## Сколько раз переписаны щупальца (тесты).
var arm_writes := 0
## Сколько раз мерили дно под щупальцами (дорого: Seabed.height — шум).
var ground_reads := 0
var _buf := PackedFloat32Array()
## Дно под каждым щупальцем (на середине длины) и где стоял скальник, когда мерили.
var _floor := PackedFloat32Array()
var _floor_at := Vector3.INF
var _camo := 1.0
## Муть от скальника и её MultiMesh; буфер мути — для тестов.
var dust := EcoSkalnikDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()


func _init(system: EcoSkalnik) -> void:
	skalnik = system
	name = "Скальник"
	material = StandardMaterial3D.new()
	material.albedo_color = ROCK
	material.roughness = 0.95
	material.emission_enabled = true
	material.emission = Color.BLACK
	body = MeshInstance3D.new()
	body.name = "Тело"
	body.mesh = build_body()
	body.material_override = material
	body.layers = OceanView.LAYER_WORLD
	EcoShadows.cast(body)
	add_child(body)
	arms = MultiMeshInstance3D.new()
	arms.name = "Щупальца"
	arms.layers = OceanView.LAYER_WORLD
	EcoShadows.cast(arms)
	arms.material_override = material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 6
	sphere.rings = 4
	mm.mesh = sphere
	mm.instance_count = ARMS * SEG
	arms.multimesh = mm
	add_child(arms)
	carry = MeshInstance3D.new()
	carry.name = "Добыча"
	carry.mesh = build_carry()
	carry.layers = OceanView.LAYER_WORLD
	carry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = CARRY
	carry.material_override = cm
	carry.visible = false
	add_child(carry)
	dust_view = GrazerView.build_dust(EcoSkalnikDust.POOL)
	add_child(dust_view)
	_buf.resize(ARMS * SEG * STRIDE)
	visible = skalnik.octo != null
	sync(0.0, Vector3(INF, INF, INF), true)


## Цвет кожи при маскировке camo (1 — камень).
static func skin_color(camo: float) -> Color:
	return ROCK.lerp(SKIN, 1.0 - camo)


## Расставить скальника в момент t; ship — центр корабля (вдали камень не шевелится); force — переписать всё;
## info — корабль целиком (муть светлее в луче прожектора), flow — течение мира (уносит муть).
func sync(t: float, ship: Vector3, force := false, info: EcoLink.ShipState = null, flow := Vector3.ZERO) -> void:
	var sk := skalnik.octo
	if sk == null:
		return
	_sync_dust(t, ship, info, flow)
	body.transform = Transform3D(Basis(Vector3.UP, atan2(sk.dir.x, sk.dir.z)), sk.pos)
	carry.visible = sk.loot >= 0
	if carry.visible:
		carry.transform = Transform3D(Basis(Vector3.UP, t * 1.5), sk.pos + Vector3(0, CARRY_UP, 0))
	if absf(sk.camo - _camo) > 0.002:
		_camo = sk.camo
		material.albedo_color = skin_color(sk.camo)
		material.emission = GLOW * (1.0 - sk.camo)
	var moving := sk.vel.length_squared() > 0.01
	if not force and not moving and sk.state == EcoSkalnik.State.ROCK and sk.pos.distance_to(ship) > FAR:
		return
	var spread := 0.55 if sk.state == EcoSkalnik.State.ROCK else 1.0
	var back := sk.vel.normalized() if moving else Vector3.ZERO
	_measure_floor(sk)
	var aabb := AABB(sk.pos, Vector3.ZERO)
	for a in ARMS:
		var ang := float(a) / ARMS * TAU + 0.2
		var ca := cos(ang)
		var sa := sin(ang)
		for j in SEG:
			var r := (0.35 + j * 0.24) * spread
			var w := sin(t * 2.5 + a + j * 0.7) * 0.06 * j
			var p := Vector3(sk.pos.x + ca * r + w, sk.pos.y + 0.25 - j * 0.05, sk.pos.z + sa * r - w)
			if moving:
				p -= back * (j * 0.22)
			var h := _floor[a] + 0.06
			if p.y < h:
				p.y = h
			var sc := 0.2 * (1.0 - float(j) / SEG * 0.65)
			EcoMM.put_basis(_buf, (a * SEG + j) * STRIDE, Basis.from_scale(Vector3(sc, sc * 0.75, sc)), p)
			aabb = aabb.expand(p)
	arms.multimesh.buffer = _buf
	arms.custom_aabb = aabb.grow(0.3)
	arm_writes += 1


func _sync_dust(t: float, ship: Vector3, info: EcoLink.ShipState, flow: Vector3) -> void:
	dust.update(skalnik, t, ship)
	_dust.pack(dust.dust, t, flow, info, EcoSkalnikDust.COLOR, EcoSkalnikDust.LIT,
			Seabed.mesh_height)
	if _dust.changed:   # мути нет и не было — буфер тот же, не грузим (issue #133)
		dust_view.multimesh.buffer = _dust.data


## Дно под щупальцами меряется заново, только когда скальник сдвинулся больше чем на 0,25 м.
func _measure_floor(sk: EcoSkalnik.Octo) -> void:
	if _floor_at != Vector3.INF and sk.pos.distance_squared_to(_floor_at) < 0.0625:
		return
	_floor_at = sk.pos
	_floor.resize(ARMS)
	var g := skalnik.ground
	for a in ARMS:
		var ang := float(a) / ARMS * TAU + 0.2
		var x := sk.pos.x + cos(ang) * 0.9
		var z := sk.pos.z + sin(ang) * 0.9
		_floor[a] = float(g.call(x, z)) if g.is_valid() else sk.home.y
	ground_reads += 1


## Мантия (0,6 × 0,5 × 0,75, сдвинута назад), два рога-конуса в стороны и два глаза спереди (+Z).
static func build_body() -> ArrayMesh:
	var st := KrabView._begin()
	EcoMM.ellipsoid(st, Vector3(0, 0.45, -0.15), Vector3(0.6, 0.5, 0.75), 12, 8, Color.WHITE)
	for sx in [-1.0, 1.0]:
		_horn(st, Vector3(sx * 0.35, 0.95, 0.15), -sx * 0.5)
		EcoMM.ellipsoid(st, Vector3(sx * 0.3, 0.55, 0.45), Vector3(0.08, 0.08, 0.08), 6, 4, Color.WHITE)
	return st.commit()


## Рог: пятигранный конус 0,45 м с основанием 0,08, наклонён на tilt рад вокруг оси Z.
static func _horn(st: SurfaceTool, at: Vector3, tilt: float) -> void:
	var b := Basis(Vector3.BACK, tilt)
	var tip := at + b * Vector3(0, 0.225, 0)
	var base := at + b * Vector3(0, -0.225, 0)
	var mid := at
	var ring: Array[Vector3] = []
	for k in 5:
		var t := k * TAU / 5.0
		ring.append(base + b * Vector3(cos(t) * 0.08, 0, sin(t) * 0.08))
	for k in 5:
		EcoMM.tri(st, ring[k], ring[(k + 1) % 5], tip, Color.WHITE, mid)
		EcoMM.tri(st, ring[(k + 1) % 5], ring[k], base, Color.WHITE, mid)


## Октаэдр 0,22 м (OctahedronGeometry(0.22) в браузере) — камешек в щупальцах.
static func build_carry() -> ArrayMesh:
	var st := KrabView._begin()
	var r := 0.22
	var v: Array[Vector3] = [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
	var top := Vector3(0, r, 0)
	var bot := Vector3(0, -r, 0)
	for k in 4:
		EcoMM.tri(st, v[k], v[(k + 1) % 4], top, Color.WHITE, Vector3.ZERO)
		EcoMM.tri(st, v[(k + 1) % 4], v[k], bot, Color.WHITE, Vector3.ZERO)
	return st.commit()
