class_name CoinsView
extends Node3D
## Монетники и песчаные глазуны в сцене (initCoins, coinsRender в js/creatures.js): монетник — плоский диск
## 30 см боком к воде (#e8d48a, слабое свечение #3a3010) с хвостом-конусом (#b59a50), нос по скорости, покачивается;
## съеденные сжаты в точку. Глазун — плоское тело в песке (#8a7a60) со стебельками глаз (#6a5a44), в броске
## приподнимается; глаза — светящиеся шарики, в луче прожектора крупнее и ярче. Три MultiMesh — три вызова
## отрисовки; стоят на слое отмели (OceanView.LAYER_WORLD). Разброс монетников (Б4, EcoVary по номеру рыбки): свой
## размер, ритм покачивания и оттенок диска (цвет экземпляра × краска вершины) — стайка не клоны, мир не меняется.
## Муть у дна (EcoCoinsDust: бросок глазуна — клуб песка кольцом у тела, сонар рассыпал стайку — облачка из-под
## низко висевших рыбок) — дочерний MultiMesh «Муть» на общем шейдере EcoShaders.MIST: +1 вызов.

const COIN := Color("e8d48a")
const FIN := Color("b59a50")
const COIN_GLOW := Color("3a3010")
const SAND := Color("8a7a60")
const STALK := Color("6a5a44")
## Чисел на экземпляр: transform 3 × 4 и цвет (4).
const STRIDE := 12
const STRIDE_C := 16
## Разброс монетников: размер ±12 %, светлее-темнее ±15 %, теплее-холоднее на 6 %, покачивание ±25 % около ROCK_RATE.
const SIZE_SPREAD := 0.12
const SHADE_SPREAD := 0.15
const HUE_SPREAD := 0.06
const RATE_SPREAD := 0.25
const ROCK_RATE := 2.0

var coins: EcoCoins
var fish: MultiMeshInstance3D
var bodies: MultiMeshInstance3D
var eyes: MultiMeshInstance3D
## Последние буферы (для тестов).
var coin_buffer := PackedFloat32Array()
var body_buffer := PackedFloat32Array()
var eye_buffer := PackedFloat32Array()
## Разброс по номеру монетника: размер, ритм, оттенок r g b (хеш — раз, не в каждом кадре).
var _vary := PackedFloat32Array()
var dust := EcoCoinsDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()


func _init(system: EcoCoins) -> void:
	coins = system
	name = "Монетники"
	fish = EcoMM.instance(self, "Монетники", build_coin(), coins.coins.size(), true)
	_vary.resize(coins.coins.size() * 5)
	for cn in coins.coins:
		var tn := coin_tint(cn)
		var row := [coin_scale(cn), coin_rate(cn), tn.r, tn.g, tn.b]
		for q in 5:
			_vary[cn.index * 5 + q] = row[q]
	bodies = EcoMM.instance(self, "Глазуны", build_glazun(), coins.glazuns.size(), false)
	eyes = EcoMM.instance(self, "Глаза", build_eye(), coins.glazuns.size() * 2, true)
	dust_view = GrazerView.build_dust(EcoCoinsDust.POOL)
	add_child(dust_view)
	visible = not coins.schools.is_empty()
	sync(0.0)


## Расставить монетников и глазунов в момент t (время мира). ship — корабль (муть — ближе EcoGrazerDust.NEAR,
## светлее в луче прожектора; null — мути нет), flow — течение мира (уносит муть).
func sync(t: float, ship: EcoLink.ShipState = null, flow := Vector3.ZERO) -> void:
	_sync_dust(t, ship, flow)
	coin_buffer.resize(coins.coins.size() * STRIDE_C)
	for cn in coins.coins:
		var q := cn.index * 5
		var tr := Transform3D(EcoCoins.coin_basis(cn, t, _vary[q + 1]) * _vary[q], cn.pos) if cn.alive \
			else Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -999, 0))
		var j := cn.index * STRIDE_C
		EcoMM.put(coin_buffer, j, tr)
		coin_buffer[j + 12] = _vary[q + 2]; coin_buffer[j + 13] = _vary[q + 3]; coin_buffer[j + 14] = _vary[q + 4]
		coin_buffer[j + 15] = 1.0
	fish.multimesh.buffer = coin_buffer
	body_buffer.resize(coins.glazuns.size() * STRIDE)
	eye_buffer.resize(coins.glazuns.size() * 2 * STRIDE_C)
	for gz in coins.glazuns:
		var tr := EcoCoins.glazun_transform(gz)
		EcoMM.put(body_buffer, gz.index * STRIDE, tr)
		var c := EcoCoins.eye_color(gz, t)
		var s := 1.6 if gz.lit else 1.0
		for e in 2:
			var j := (gz.index * 2 + e) * STRIDE_C
			var p: Vector3 = gz.eyes[e] + Vector3(0, gz.lunge * 0.35, 0)
			EcoMM.put(eye_buffer, j, Transform3D(Basis.from_scale(Vector3.ONE * s), p))
			eye_buffer[j + 12] = c.r; eye_buffer[j + 13] = c.g; eye_buffer[j + 14] = c.b; eye_buffer[j + 15] = 1.0
	bodies.multimesh.buffer = body_buffer
	eyes.multimesh.buffer = eye_buffer


func _sync_dust(t: float, ship: EcoLink.ShipState, flow: Vector3) -> void:
	dust.update(coins, t, ship.pos if ship else Vector3(INF, INF, INF))
	_dust.pack(dust.dust, t, flow, ship, EcoCoinsDust.COLOR, EcoCoinsDust.LIT,
			Seabed.mesh_height)
	if _dust.changed:   # мути нет и не было — буфер тот же, не грузим (issue #133)
		dust_view.multimesh.buffer = _dust.data


## Размер монетника (множитель формы).
static func coin_scale(cn: EcoCoins.Coin) -> float:
	return EcoVary.spread(cn.index, EcoVary.SIZE, SIZE_SPREAD)


## Частота покачивания монетника, рад/с.
static func coin_rate(cn: EcoCoins.Coin) -> float:
	return ROCK_RATE * EcoVary.spread(cn.index, EcoVary.RATE, RATE_SPREAD)


## Множитель красок монетника — цвет экземпляра: светлее или темнее, теплее (к меди) или холоднее (к серебру).
static func coin_tint(cn: EcoCoins.Coin) -> Color:
	var k := EcoVary.spread(cn.index, EcoVary.SHADE, SHADE_SPREAD)
	var h := (EcoVary.unit(cn.index, EcoVary.HUE) * 2.0 - 1.0) * HUE_SPREAD
	return Color(k * (1.0 + h), k, k * (1.0 - h))


## Монетник: диск радиусом 0,15 м толщиной 3,5 см боком (ось — x), хвост-конус назад (−Z), нос — +Z.
static func build_coin() -> ArrayMesh:
	var st := KrabView._begin()
	EcoMM.ellipsoid(st, Vector3.ZERO, Vector3(0.0175, 0.15, 0.15), 12, 6, COIN)
	var ring: Array[Vector3] = []
	for j in 4:
		var a := j * TAU / 4.0
		ring.append(Vector3(cos(a) * 0.06, sin(a) * 0.06, -0.12))
	var tip := Vector3(0, 0, -0.24)
	var mid := Vector3(0, 0, -0.16)
	for j in 4:
		EcoMM.tri(st, ring[j], ring[(j + 1) % 4], tip, FIN, mid)
		EcoMM.tri(st, ring[(j + 1) % 4], ring[j], Vector3(0, 0, -0.12), FIN, mid + Vector3(0, 0, -0.01))
	return _commit(st, COIN_GLOW)


## Глазун: сплющенное тело 0,9 × 0,16 × 0,6 м и два стебелька глаз впереди (+Z).
static func build_glazun() -> ArrayMesh:
	var st := KrabView._begin()
	EcoMM.ellipsoid(st, Vector3.ZERO, Vector3(0.45, 0.08, 0.3), 10, 6, SAND)
	for sx in [-1.0, 1.0]:
		var at := Vector3(sx * EcoCoins.EYE.x, 0.08, EcoCoins.EYE.z)
		KrabView._box(st, Transform3D.IDENTITY, at, Vector3(0.028, 0.12, 0.028), STALK)
	return _commit(st, Color.BLACK)


## Глаз: шарик 4,5 см без освещения, цвет — от экземпляра (EcoCoins.eye_color).
static func build_eye() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.045
	m.height = 0.09
	m.radial_segments = 6
	m.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	return m


static func _commit(st: SurfaceTool, glow: Color) -> ArrayMesh:
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	if glow != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = glow
	m.surface_set_material(0, mat)
	return m
