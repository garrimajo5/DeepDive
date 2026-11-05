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
## «Экономно» (Б6, `set_lite`): в каждой стайке рисуются две рыбки из трёх (каждой третьей по месту в стайке —
## LITE_SKIP — нет; 27 → 18): видимые — в начале буфера (`order`), `visible_instance_count` отрезает остальных. Мир
## (стайка, испуг, глазун, сонар, гость) считает всех; глазуны — все. Вызовов столько же.
## Хвост монетника машет (Б3): хвост-конус и задний край диска гнутся вбок бегущей волной к кончику (±4 см на
## кончике, 1,2 взмаха в секунду, у рыбки своя фаза — альфа цвета экземпляра). Рисует общий шейдер растений
## `EcoShaders.PLANT` (режим `TENTACLE` без светящихся кончиков; волна — uniform `breath`, время мира `t`, в меше
## UV.x — сдвиг фазы вдоль хвоста, UV.y — доля изгиба, UV2 — вбок), шейдеров не прибавилось; двойник на CPU —
## `tail_offset`. «Экономно» — `sway_k` (EcoShaders.set_sway_lite).
## Новая рыбка над мхом не возникает за кадр (Б3): вырастает за COIN_RISE (доли coin_k по времени мира, у гостя то же);
## схваченная глазуном пропадает сразу — её проглотили.
## Глаза глазуна в луче не щёлкают (Б3): доля луча eye_lit (по времени мира, у гостя то же) растёт за EYE_RISE и гаснет
## за EYE_FADE; альфа экземпляра (`eye_alpha`) и раздувание шарика в шейдере (`tip_grow` — по альфе выше EYE_FROM)
## идут за ней плавно. Строка на приборах и мир (`EcoCoins.Glazun.lit`) — сразу, как раньше.
## «Дыхание» глазуна (Б3, `glazun_breath`): тело в песке набирает воду и выталкивает её — высота ± GLAZUN_BREATH_H,
## ширина ± GLAZUN_BREATH_W за GLAZUN_BREATH_T с (ритм ± GLAZUN_BREATH_SPREAD и фаза — EcoVary), длина та же —
## стебельки и глаза едут с телом на миллиметры. В луче затаился — GLAZUN_HELD размаха (по плавной доле eye_lit),
## в броске размах гаснет вместе с `lunge` — без скачка. Масштаб экземпляра по времени мира (у гостя то же) — даром,
## и на «Экономно»; мир (глаза для луча и сканера) не меняется.
## «Дыхание» монетника (Б3, `coin_breath`): рыбка качает воду жабрами — диск толще на ± COIN_BREATH_W и выше на
## ± COIN_BREATH_H за COIN_BREATH_T с (ритм ± COIN_BREATH_SPREAD и фаза — EcoVary), длина та же — нос и хвост на месте.
## Пасётся — во весь размах, на бегу (ход Coin.vel меняется плавно) размах гаснет до COIN_RUSH_K между COIN_CALM и
## COIN_RUSH м/с — без скачка. Масштаб экземпляра по времени мира (у гостя то же) — даром, и на «Экономно».

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
## Хвост: гнётся всё, что позади TAIL_FROM (м по оси меша, нос +Z), доля изгиба — квадрат пути к кончику TAIL_TIP;
## размах на кончике TAIL_AMP (м), взмахов в секунду TAIL_RATE, длина бегущей волны TAIL_WAVE (м).
const TAIL_FROM := -0.05
const TAIL_TIP := -0.24
const TAIL_AMP := 0.04
const TAIL_RATE := 1.2
const TAIL_WAVE := 0.5

var coins: EcoCoins
var fish: MultiMeshInstance3D
## Глазуны целиком (тело, стебли, глаза) — один MultiMesh, один вызов отрисовки (#849).
var bodies: MultiMeshInstance3D
## Последние буферы (для тестов): у глазунов — transform и цвет экземпляра (белый, альфа — `eye_alpha`).
var coin_buffer := PackedFloat32Array()
var body_buffer := PackedFloat32Array()
## Разброс по номеру монетника: размер, ритм, оттенок r g b (хеш — раз, не в каждом кадре).
var _vary := PackedFloat32Array()
## Чисел разброса на рыбку в _vary: размер, ритм покачивания, оттенок (3), частота и фаза дыхания.
const VARY := 7
var dust := EcoCoinsDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()
## Доля размера монетника по номеру рыбки: 0 — съеден, 1 — во весь размер.
var coin_k := PackedFloat32Array()
## Доля луча на глазах глазуна по его номеру: 0 — без света (мерцают), 1 — в луче (раздуты и ярки).
var eye_lit := PackedFloat32Array()
var _k_t := 0.0
var _k_fresh := true
## «Экономно»: в каждой стайке не рисуется монетник с местом k % LITE_SKIP == LITE_SKIP − 1.
const LITE_SKIP := 3
var lite := false
## Место монетника в буфере по его номеру (стайка · PER + место; только «Экономно», пусто — по номеру).
var order := PackedInt32Array()
## Материал монетников (общий шейдер растений): время мира для волны хвоста.
var mat: ShaderMaterial


func _init(system: EcoCoins, on_lite := false) -> void:
	coins = system
	name = "Монетники"
	fish = EcoMM.instance(self, "Монетники", build_coin(), coins.coins.size(), true)
	mat = fish.multimesh.mesh.surface_get_material(0)
	_vary.resize(coins.coins.size() * VARY)
	for cn in coins.coins:
		var tn := coin_tint(cn)
		var br := coin_breath_rate(cn)
		var row := [coin_scale(cn), coin_rate(cn), tn.r, tn.g, tn.b, br.x, br.y]
		for q in VARY:
			_vary[cn.index * VARY + q] = row[q]
	bodies = EcoMM.instance(self, "Глазуны", build_glazun(), coins.glazuns.size(), true)
	dust_view = GrazerView.build_dust(EcoCoinsDust.POOL)
	add_child(dust_view)
	visible = not coins.schools.is_empty()
	var pts := PackedVector3Array()
	for gz in coins.glazuns:
		pts.append(gz.pos)
	EcoMM.fit([bodies], pts, GLAZUN_GROW)
	if on_lite:
		set_lite(true)
	sync(0.0)


## «Экономно» — рисуются две рыбки из трёх в каждой стайке; буфер переписывается в следующем sync.
func set_lite(on: bool) -> void:
	lite = on
	var n := coins.coins.size()
	order = lite_order(n) if on else PackedInt32Array()
	fish.multimesh.visible_instance_count = lite_count(n) if on else -1


## Рисуется ли на «Экономно» монетник с местом k в стайке.
static func lite_shown(k: int) -> bool:
	return k % LITE_SKIP != LITE_SKIP - 1


## Сколько монетников рисуется на «Экономно» из n (стайки по EcoCoins.PER).
static func lite_count(n: int) -> int:
	var k := 0
	for i in n:
		if lite_shown(i % EcoCoins.PER):
			k += 1
	return k


## Места в буфере на «Экономно»: сначала видимые по номеру, за ними — скрытые.
static func lite_order(n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(n)
	var at := 0
	for pass_shown: bool in [true, false]:
		for i in n:
			if lite_shown(i % EcoCoins.PER) == pass_shown:
				out[i] = at
				at += 1
	return out


## Место монетника номер n в буфере.
func slot_of(n: int) -> int:
	return order[n] if not order.is_empty() else n


## Сколько монетников рисуется сейчас.
func drawn() -> int:
	var v := fish.multimesh.visible_instance_count
	return fish.multimesh.instance_count if v < 0 else v


## Появилась — вырастает за COIN_RISE с; время назад или скачок дальше SNAP_DT (сброс, вход гостя) — сразу.
const COIN_RISE := 1.0
const SNAP_DT := 1.0
## Запас рамки глазунов (#849): стоят на месте, стебель с глазами до 2,2 м вверх.
const GLAZUN_GROW := 4.0
## Глаза глазуна: попал в луч — раздуваются и разгораются за EYE_RISE с, вышел — гаснут за EYE_FADE с.
const EYE_RISE := 0.3
const EYE_FADE := 0.6
## Дыхание глазуна: высота и ширина тела (доли), период, с, разброс ритма; в луче — доля размаха.
const GLAZUN_BREATH_H := 0.04
const GLAZUN_BREATH_W := 0.02
const GLAZUN_BREATH_T := 5.0
const GLAZUN_BREATH_SPREAD := 0.2
const GLAZUN_HELD := 0.3
## Соль номера глазуна для EcoVary — не в фазе с монетниками тех же номеров.
const GLAZUN_SALT := 1000
## Дыхание монетника: толщина диска и высота (доли), период, с, разброс ритма; на бегу — доля размаха между
## COIN_CALM и COIN_RUSH м/с; соль номера — не в фазе с покачиванием и хвостом.
const COIN_BREATH_W := 0.08
const COIN_BREATH_H := 0.03
const COIN_BREATH_T := 1.8
const COIN_BREATH_SPREAD := 0.2
const COIN_RUSH_K := 0.3
const COIN_CALM := 1.0
const COIN_RUSH := 4.0
const COIN_SALT := 2000


## Расставить монетников и глазунов в момент t (время мира). ship — корабль (муть — ближе EcoGrazerDust.NEAR,
## светлее в луче прожектора; null — мути нет), flow — течение мира (уносит муть).
func sync(t: float, ship: EcoLink.ShipState = null, flow := Vector3.ZERO) -> void:
	_sync_dust(t, ship, flow)
	if lite and order.size() != coins.coins.size():
		set_lite(true)   # мир пересобран — места заново
	mat.set_shader_parameter("t", t)
	coin_buffer.resize(coins.coins.size() * STRIDE_C)
	grow(t)
	for cn in coins.coins:
		var q := cn.index * VARY
		var g := coin_k[cn.index]
		var tr := Transform3D(EcoCoins.coin_basis(cn, t, _vary[q + 1]) * Basis.from_scale(
				breath_at(_vary[q + 5], _vary[q + 6], cn.vel.length(), t) * (_vary[q] * smoothstep(0.0, 1.0, g))), cn.pos) \
			if cn.alive and g > 0.0 else Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -999, 0))
		var j := slot_of(cn.index) * STRIDE_C
		EcoMM.put(coin_buffer, j, tr)
		coin_buffer[j + 12] = _vary[q + 2]; coin_buffer[j + 13] = _vary[q + 3]; coin_buffer[j + 14] = _vary[q + 4]
		coin_buffer[j + 15] = tail_phase(cn)
	fish.multimesh.buffer = coin_buffer
	body_buffer.resize(coins.glazuns.size() * STRIDE_C)
	for gz in coins.glazuns:
		var j := gz.index * STRIDE_C
		var gtr := EcoCoins.glazun_transform(gz)
		gtr.basis = gtr.basis * Basis.from_scale(glazun_breath(gz, t, eye_lit[gz.index]))
		EcoMM.put(body_buffer, j, gtr)
		body_buffer[j + 12] = 1.0; body_buffer[j + 13] = 1.0; body_buffer[j + 14] = 1.0
		body_buffer[j + 15] = eye_alpha(gz, t, eye_lit[gz.index])
	EcoMM.send(bodies, body_buffer)


## Доли размера монетников к моменту t: живой растёт за COIN_RISE, съеденный — сразу 0. Первый шаг, время назад и
## скачок дальше SNAP_DT — сразу к цели.
func grow(t: float) -> void:
	var n := coins.coins.size()
	if coin_k.size() != n:
		coin_k.resize(n)
		_k_fresh = true
	var dt := t - _k_t
	_k_t = t
	var snap := _k_fresh or dt < 0.0 or dt > SNAP_DT
	_k_fresh = false
	for cn in coins.coins:
		var i := cn.index
		if not cn.alive:
			coin_k[i] = 0.0
		else:
			coin_k[i] = 1.0 if snap else minf(1.0, coin_k[i] + dt / COIN_RISE)
	if eye_lit.size() != coins.glazuns.size():
		eye_lit.resize(coins.glazuns.size())
		snap = true
	for gz in coins.glazuns:
		eye_lit[gz.index] = eye_step(eye_lit[gz.index], gz.lit, dt, snap)


## Доля луча на глазах за шаг dt: к 1 за EYE_RISE в луче, к 0 за EYE_FADE без него; snap — сразу к цели.
static func eye_step(k: float, lit: bool, dt: float, snap := false) -> float:
	if snap:
		return 1.0 if lit else 0.0
	return minf(1.0, k + dt / EYE_RISE) if lit else maxf(0.0, k - dt / EYE_FADE)


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


## Фаза волны хвоста рыбки (доля оборота, 0…1): от её фазы покачивания — соседки машут вразнобой.
static func tail_phase(cn: EcoCoins.Coin) -> float:
	return fposmod(cn.phase / TAU, 1.0)


## Доля изгиба точки формы с z: 0 — жёсткая передняя часть диска, 1 — кончик хвоста.
static func tail_bend(z: float) -> float:
	var s := clampf((TAIL_FROM - z) / (TAIL_FROM - TAIL_TIP), 0.0, 1.0)
	return s * s


## Сдвиг фазы волны вдоль хвоста (доля оборота) у точки с z: к кончику волна приходит позже.
static func tail_lag(z: float) -> float:
	return minf(0.0, z - TAIL_FROM) / TAIL_WAVE


## Сдвиг вбок (м, по оси x формы) точки формы с z в момент t времени мира у рыбки с фазой a (tail_phase); sway_k —
## 0 на «Экономно». Двойник вершинного шейдера (EcoShaders.PLANT, ветка breath).
static func tail_offset(z: float, t: float, a: float, sway_k := 1.0) -> float:
	var f := fposmod(t * TAIL_RATE + tail_lag(z) + a, 1.0)
	return -TAIL_AMP * tail_bend(z) * cos(TAU * f) * sway_k


## Монетник: диск радиусом 0,15 м толщиной 3,5 см боком (ось — x), хвост-конус назад (−Z), нос — +Z. Общий шейдер
## растений (TENTACLE без светящихся кончиков и просвета); для волны хвоста — UV (сдвиг фазы, доля изгиба) и UV2
## (вбок по x).
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
	var arr := st.commit_to_arrays()
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for p in vv:
		uv.append(Vector2(tail_lag(p.z), tail_bend(p.z)))
		uv2.append(Vector2(1.0, 0.0))
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, EcoShaders.plant(EcoShaders.Plant.TENTACLE, {"rough": 0.8, "spec": 0.5,
		"glow": COIN_GLOW.srgb_to_linear(), "back": Vector3.ZERO, "breath": Vector2(TAIL_AMP, TAIL_RATE)}))
	return m


## Масштаб монетника (в осях формы: x — толщина диска, y — высота, z — длина) в момент t: вдох — толще и выше,
## длина та же; на бегу размах гаснет до COIN_RUSH_K.
static func coin_breath(cn: EcoCoins.Coin, t: float) -> Vector3:
	var br := coin_breath_rate(cn)
	return breath_at(br.x, br.y, cn.vel.length(), t)


## Частота дыхания рыбки (рад/с, с разбросом ритма) и фаза (рад) — EcoVary по номеру; считаются раз (в _vary).
static func coin_breath_rate(cn: EcoCoins.Coin) -> Vector2:
	var i := cn.index + COIN_SALT
	return Vector2(TAU / COIN_BREATH_T * EcoVary.spread(i, EcoVary.RATE, COIN_BREATH_SPREAD),
			EcoVary.unit(i, EcoVary.TURN) * TAU)


## Масштаб дыхания при частоте w (рад/с), фазе ph и ходе speed (м/с) в момент t.
static func breath_at(w: float, ph: float, speed: float, t: float) -> Vector3:
	var k := lerpf(1.0, COIN_RUSH_K, smoothstep(COIN_CALM, COIN_RUSH, speed)) * sin(t * w + ph)
	return Vector3(1.0 + COIN_BREATH_W * k, 1.0 + COIN_BREATH_H * k, 1.0)


## Масштаб тела глазуна (в осях тела: x — ширина, y — высота, z — длина) в момент t при доле луча lit: вдох — выше и
## шире, длина та же; в луче затаился (GLAZUN_HELD), в броске (`lunge`) не дышит.
static func glazun_breath(gz: EcoCoins.Glazun, t: float, lit: float) -> Vector3:
	var i := gz.index + GLAZUN_SALT
	var rate := EcoVary.spread(i, EcoVary.RATE, GLAZUN_BREATH_SPREAD)
	var ph := EcoVary.unit(i, EcoVary.TURN) * TAU
	var amp := lerpf(1.0, GLAZUN_HELD, smoothstep(0.0, 1.0, clampf(lit, 0.0, 1.0))) * (1.0 - clampf(gz.lunge, 0.0, 1.0))
	var k := amp * sin(t * TAU / GLAZUN_BREATH_T * rate + ph)
	return Vector3(1.0 + GLAZUN_BREATH_W * k, 1.0 + GLAZUN_BREATH_H * k, 1.0)


## Альфа экземпляра глазуна — свет глаз: без света альфа² = (k + 0,25) / 1,25 по мерцанию EcoCoins.eye_k (не больше
## 0,75), в луче — 1; между ними — по доле луча lit (мягкий вход). Шейдер раздувает шарик по альфе выше EYE_FROM.
static func eye_alpha(gz: EcoCoins.Glazun, t: float, lit: float) -> float:
	var dim := sqrt((0.35 + 0.1 * sin(t * 1.3 + gz.index) + 0.25) / 1.25)
	return lerpf(dim, 1.0, smoothstep(0.0, 1.0, clampf(lit, 0.0, 1.0)))


## Альфа, выше которой шейдер раздувает глаз: доля раздувания = (альфа − EYE_FROM) / (1 − EYE_FROM). Мерцание без
## света — не выше 0,75, глаз не дышит.
const EYE_FROM := 0.76


## Доля раздувания глаза при альфе a — двойник шейдера.
static func eye_grow(a: float) -> float:
	return clampf((a - EYE_FROM) / (1.0 - EYE_FROM), 0.0, 1.0)


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
		"tip_glow": Vector2(0.0, EYE_GLOW), "tip_grow": Vector2(EYE_R, EYE_LIT - 1.0), "tip_from": EYE_FROM, "back": Vector3.ZERO}))
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

