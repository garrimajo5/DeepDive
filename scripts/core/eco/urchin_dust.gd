class_name EcoUrchinDust
extends RefCounted
## Муть у дна от шипоежей (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): ёж, что грызёт ленту у основания,
## иглами и ртом взбивает ил — у стебля встают маленькие облачка; ползущий ёж поднимает позади ещё более слабые,
## бредущий без цели — реже. Ёж мал (~0,5 м с иглами), поэтому облачка — доля SCALE от облачка скребуна. Облачка
## те же, что у скребунов (EcoGrazerDust: стоят, где подняты, растут, поднимаются, уплывают по течению, тают;
## светлее в луче прожектора) — свой пул на POOL мест на всех ежей и свой цвет. Мир и его случай не меняются:
## ритм и разброс — хешем EcoVary; что ёж делает — по его цели (лента или точка брожения), поэтому у гостя сети
## (ежи из кадра хоста — EcoLink.apply_kelp) муть та же по виду.
## Рисует KelpView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» — общий выключатель EcoGrazerDust.lite.

## Мест в пуле на всех ежей (14 ежей · жизнь 3,6 с / пауза 1,5 с ≈ 34 в худшем случае — старое уступает новому).
const POOL := 32
## Доля размера и подъёма облачка скребуна (0,5 → 1,6 м): у ежа 0,2 → 0,64 м.
const SCALE := 0.4
## Пауза между облачками (с): грызёт ленту, ползёт к ленте, бредёт; у каждого облачка ×(1 ± 0,2).
const EAT_EVERY := 1.5
const CRAWL_EVERY := 2.2
const WANDER_EVERY := 3.4
## Непрозрачность в пике: у стебля — гуще, из-под игл в пути — слабее.
const EAT_ALPHA := 0.45
const CRAWL_ALPHA := 0.25
const WANDER_ALPHA := 0.18
## У стебля — к ленте от середины ежа (м), в пути — позади (м); разброс (м), над дном (м).
const MOUTH := 0.25
const BEHIND := 0.3
const SCATTER := 0.12
const BASE_LIFT := 0.1
## Ёж стоит, если до цели ближе (м) — как в EcoKelp._step_urchin.
const STILL := 0.05
const SALT := 41
## Цвет: бурый ил у корней ленточника — темнее светлого песка в луче (как у кольчужника, чуть светлее).
const COLOR := Color(0.24, 0.22, 0.18)
const LIT := Color(0.52, 0.48, 0.40)

var dust := EcoGrazerDust.new(POOL)
## Время следующего облачка у каждого ежа (по номеру).
var _next := PackedFloat32Array()
var _made := 0
var _last := -1e9


## Куда ёж u держит путь: лента-цель или точка брожения (горизонтально, y — его).
static func aim(kelp: EcoKelp, u: EcoKelp.Urchin) -> Vector3:
	var to := u.wander
	if u.goal >= 0 and u.grove < kelp.groves.size() and u.goal < kelp.groves[u.grove].stalks.size():
		to = kelp.groves[u.grove].stalks[u.goal].pos
	return Vector3(to.x, u.pos.y, to.z)


## Чем ёж поднимает муть сейчас: 0 — ничем (съеден, стоит), 1 — бредёт, 2 — ползёт к ленте, 3 — грызёт ленту.
static func mode(kelp: EcoKelp, u: EcoKelp.Urchin) -> int:
	if kelp == null or u == null or not u.alive:
		return 0
	var dist := u.pos.distance_to(aim(kelp, u))
	if u.goal >= 0:
		if dist < EcoKelp.EAT_DIST:
			return 3 if kelp.groves[u.grove].stalks[u.goal].f > EcoKelp.F_MIN else 0
		return 2
	return 1 if dist > STILL else 0


static func every(m: int) -> float:
	return [0.0, WANDER_EVERY, CRAWL_EVERY, EAT_EVERY][m]


static func alpha(m: int) -> float:
	return [0.0, WANDER_ALPHA, CRAWL_ALPHA, EAT_ALPHA][m]


## Где поднять облачко номер n: у стебля (m = 3) или позади ежа в пути, с разбросом; на дне под ежом.
static func spot(kelp: EcoKelp, u: EcoKelp.Urchin, m: int, n: int) -> Vector3:
	var fw := aim(kelp, u) - u.pos
	fw.y = 0.0
	fw = fw.normalized() if fw.length_squared() > 1e-6 else Vector3.FORWARD
	var ahead := MOUTH if m == 3 else -BEHIND
	var sx := (EcoVary.unit(n, SALT) * 2.0 - 1.0) * SCATTER
	var sz := (EcoVary.unit(n, SALT + 1) * 2.0 - 1.0) * SCATTER
	return u.pos + fw * ahead + Vector3(sx, BASE_LIFT - EcoKelp.UP, sz)


## Шаг мути в момент t (время мира); ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(kelp: EcoKelp, t: float, ship: Vector3) -> void:
	if kelp == null:
		return
	if _next.size() != kelp.urchins.size() or t < _last:
		_next.resize(kelp.urchins.size())
		for u in kelp.urchins:
			_next[u.index] = t + EcoVary.unit(u.index, SALT + 2) * EAT_EVERY
	_last = t
	for u in kelp.urchins:
		var m := mode(kelp, u)
		if m == 0:
			_next[u.index] = maxf(_next[u.index], t)
			continue
		if t < _next[u.index]:
			continue
		var key := (_made + 1) * 16 + u.index
		_next[u.index] = t + every(m) * EcoVary.spread(key, SALT + 3, 0.2)
		if EcoGrazerDust.lite or u.pos.distance_to(ship) > EcoGrazerDust.NEAR:
			continue
		_made += 1
		dust.add(spot(kelp, u, m, key), t, alpha(m) * EcoVary.spread(key, SALT + 4, 0.2), key, SCALE)
