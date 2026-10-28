class_name CoinsView
extends Node3D
## Монетники и песчаные глазуны в сцене (initCoins, coinsRender в js/creatures.js): монетник — плоский диск
## 30 см боком к воде (#e8d48a, слабое свечение #3a3010) с хвостом-конусом (#b59a50), нос по скорости, покачивается;
## съеденные сжаты в точку. Глазун — плоское тело в песке (#8a7a60) со стебельками глаз (#6a5a44), в броске
## приподнимается и задирает голову; глаза — светящиеся шарики на стебельках, в луче прожектора крупнее и ярче.
## Глазун целиком (тело, стебли, глаза) — один меш и один MultiMesh (#849: было два вызова отрисовки — тела и глаза)
## на общем шейдере растений `Plant.TENTACLE`: глаза светятся по альфе цвета (вершина 1, тело 0) × альфе экземпляра
## (`eye_alpha` — мерцание и луч), в луче раздуваются по гладкой нормали (`tip_grow`, альфа экземпляра 1).
## Два MultiMesh — два вызова отрисовки; стоят на слое отмели (OceanView.LAYER_WORLD). Разброс монетников (Б4,
## EcoVary по номеру рыбки): свой размер, ритм покачивания и оттенок диска (цвет экземпляра × краска вершины) —
## стайка не клоны, мир не меняется.
## Муть у дна (EcoCoinsDust: бросок глазуна — клуб песка кольцом у тела, сонар рассыпал стайку — облачка из-под
## низко висевших рыбок) — дочерний MultiMesh «Муть» на общем шейдере EcoShaders.MIST: +1 вызов.

const COIN := Color("e8d48a")
const FIN := Color("b59a50")
const COIN_GLOW := Color("3a3010")
const SAND := Color("8a7a60")
const STALK := Color("6a5a44")
## Глаз глазуна: радиус шарика, м; в луче — в EYE_LIT раз крупнее (прибавка по нормали в шейдере).
const EYE_R := 0.045
const EYE_LIT := 1.6
## Краска глаза (цвет вершины, ≤ 1) и сила свечения: свет = EYE_PAINT · EYE_GLOW · альфа² — у прежних глаз
## без света цвет был EcoCoins.eye_color: (k + 0,2, k + 0,25, 0,45k), в луче k = 1 → (1,2, 1,25, 0,45). Краска
## вдвое темнее, свечение вдвое сильнее: глаз светится как прежде, а внешний свет (лёд, прожектор) его почти не
## осветляет — шарик не белеет на свету.
const EYE_PAINT := Color(0.48, 0.5, 0.18, 1.0)
const EYE_GLOW := 2.5
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
## Глазуны целиком (тело, стебли, глаза) — один MultiMesh, один вызов отрисовки (#849).
var bodies: MultiMeshInstance3D
## Последние буферы (для тестов): у глазунов — transform и цвет экземпляра (белый, альфа — `eye_alpha`).
var coin_buffer := PackedFloat32Array()
var body_buffer := PackedFloat32Array()
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
	bodies = EcoMM.instance(self, "Глазуны", build_glazun(), coins.glazuns.size(), true)
	dust_view = GrazerView.build_dust(EcoCoinsDust.POOL)
	add_child(dust_view)
	visible = not coins.schools.is_empty()
	var pts := PackedVector3Array()
	for gz in coins.glazuns:
		pts.append(gz.pos)
	EcoMM.fit([bodies], pts, GLAZUN_GROW)
	sync(0.0)


## Запас рамки глазунов (#849): стоят на месте, стебель с глазами до 2,2 м вверх.
const GLAZUN_GROW := 4.0


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
	body_buffer.resize(coins.glazuns.size() * STRIDE_C)
	for gz in coins.glazuns:
		var j := gz.index * STRIDE_C
		EcoMM.put(body_buffer, j, EcoCoins.glazun_transform(gz))
		body_buffer[j + 12] = 1.0; body_buffer[j + 13] = 1.0; body_buffer[j + 14] = 1.0
		body_buffer[j + 15] = eye_alpha(gz, t)
	EcoMM.send(bodies, body_buffer)


func _sync_dust(t: float, ship: EcoLink.ShipState, flow: Vector3) -> void:
	dust.update(coins, t, ship.pos if ship else Vector3(INF, INF, INF))
	_dust.pack(dust.dust, t, flow, ship, EcoCoinsDust.COLOR, EcoCoinsDust.LIT,
			Seabed.mesh_height)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


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


## Альфа экземпляра глазуна — свет глаз: альфа² = (k + 0,25) / 1,25 по яркости EcoCoins.eye_k (в луче 1 —
## глаза раздуваются, шейдер ждёт альфу больше 0,9; вне луча — не больше 0,75).
static func eye_alpha(gz: EcoCoins.Glazun, t: float) -> float:
	return 1.0 if gz.lit else sqrt((EcoCoins.eye_k(gz, t) + 0.25) / 1.25)


## Глазун одним мешем и одной поверхностью: сплющенное тело 0,9 × 0,16 × 0,6 м и два стебелька впереди (+Z) —
## альфа вершины 0, глаза — шарики EYE_R на концах стебельков (EcoCoins.EYE в осях тела, 6 × 4, гладкие нормали —
## по ним шарик раздувается) с альфой 1. Все грани лицом наружу.
static func build_glazun() -> ArrayMesh:
	var st := KrabView._begin()
	EcoMM.ellipsoid(st, Vector3.ZERO, Vector3(0.45, 0.08, 0.3), 10, 6, Color(SAND, 0.0))
	for sx in [-1.0, 1.0]:
		var at := Vector3(sx * EcoCoins.EYE.x, 0.08, EcoCoins.EYE.z)
		KrabView._box(st, Transform3D.IDENTITY, at, Vector3(0.028, 0.12, 0.028), Color(STALK, 0.0))
	for sx in [-1.0, 1.0]:
		_eye(st, Vector3(sx * EcoCoins.EYE.x, EcoCoins.EYE.y, EcoCoins.EYE.z))
	var m := st.commit()
	m.surface_set_material(0, EcoShaders.plant(EcoShaders.Plant.TENTACLE, {"rough": 0.42, "spec": 0.55,
		"tip_glow": Vector2(0.0, EYE_GLOW), "tip_grow": Vector2(EYE_R, EYE_LIT - 1.0), "back": Vector3.ZERO}))
	return m


## Шарик глаза с центром c: 6 долей × 4 ряда, нормаль — от центра (гладкая), лицом наружу.
static func _eye(st: SurfaceTool, c: Vector3) -> void:
	var pts := EcoMM.ellipsoid_rows(c, Vector3.ONE * EYE_R, 6, 4)
	for i in 4:
		for j in 6:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][(j + 1) % 6]
			var d: Vector3 = pts[i + 1][j]
			var e: Vector3 = pts[i + 1][(j + 1) % 6]
			_smooth_tri(st, a, b, d, c)
			_smooth_tri(st, b, e, d, c)


static func _smooth_tri(st: SurfaceTool, a: Vector3, b: Vector3, d: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(d - a)
	if n.length_squared() < 1e-12:
		return
	if n.dot((a + b + d) / 3.0 - c) > 0.0:
		var t := b
		b = d
		d = t
	for p in [a, b, d]:
		st.set_color(EYE_PAINT)
		st.set_normal((p - c).normalized())
		st.add_vertex(p)


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
