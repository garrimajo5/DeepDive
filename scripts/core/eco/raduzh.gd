class_name EcoRaduzh
extends EcoSystem
## Радужники (initSwarms/swarmUpdate в js/creatures.js): три стаи гребневиков по 28 штук в толще воды, 9 м над дном
## (не выше −8 м), медленно дрейфуют вокруг своего дома (±10 м за ~2 мин). Своего света нет: когда луч прожектора
## (EcoWorld.in_beam) задевает стаю, она вспыхивает радугой (glow растёт за ~0,3 с, гаснет за ~1,7 с). Вспышка
## выдаёт корабль издалека: серпохвост дальше своего чутья, но ближе 110 м плывёт проверить (EcoPred, поле raduzh).
## Наблюдения журнала: «flare» — вспыхнула в луче (раз в 30 с на стаю), «fade» — прожектор погашен и стая погасла
## (ближе 60 м, раз в 60 с), «betray» — серпохвост заметил вспышку (шлёт EcoPred, раз в 30 с на хищника).
## Стая — цель сонара и сканера.

const ID := "raduzh"
## Гребневиков в стае и радиус стаи, м (RD_N, RD_R).
const PER_SWARM := 28
const R := 4.0
## Дальше этого вспышку стаи хищник не видит (FLARE_REACH).
const FLARE_REACH := 110.0
## Дома стай (x, z) из браузера; высота — 9 м над дном, не выше CEILING. Первая — в браузере (−25, 40); здесь
## на 30 м западнее: с места 00 на 30 м (#827) стая не попадает в луч в первые секунды (test_eco_start).
const HOMES: Array[Vector2] = [Vector2(-55, 40), Vector2(45, 0), Vector2(-70, -50)]
const ABOVE := 9.0
const CEILING := -8.0
## Дрейф дома: ±10 м по x и z, ±1,2 м по высоте.
const DRIFT := 10.0
const DRIFT_Y := 1.2
## Вспышка: разгорается 3 в секунду, гаснет 0,6 в секунду; ярче FLARE_ON — видна хищникам.
const GLOW_UP := 3.0
const GLOW_DOWN := 0.6
const FLARE_ON := 0.5
const FLARE_CD := 30.0
const FADE_CD := 60.0
const FADE_NEAR := 60.0
## Ближе этого к кораблю гребневики расступаются перед корпусом (RD_R + 26).
const NEAR_SHIP := R + 26.0
const HULL_GAP := 0.3


## Гребневик: смещение от центра стаи, фаза покачивания и оттенок радуги.
class Member:
	extends RefCounted
	var o := Vector3.ZERO
	var phase := 0.0
	var hue := 0.0


## Стая гребневиков.
class Swarm:
	extends RefCounted
	var index := 0
	var home := Vector3.ZERO
	## Центр стаи в этот шаг.
	var c := Vector3.ZERO
	## Вспышка 0…1.
	var glow := 0.0
	## Луч задевает стаю в этот шаг.
	var lit := false
	var flare_cd := 0.0
	var fade_cd := 0.0
	var phase := 0.0
	var members: Array[Member] = []


var swarms: Array[Swarm] = []
## Самая яркая вспышка в этот шаг (E.flare) и её стая (E.flareSw).
var flare := 0.0
var flare_swarm: Swarm

var _homes: Array[Vector2]


## homes — свои места стай (для тестов), пусто — по браузеру.
func _init(homes: Array[Vector2] = []) -> void:
	_homes = homes.duplicate() if not homes.is_empty() else HOMES.duplicate()


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 7031) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	var rnd := EcoWorld.seeded_for(seed_for(world.seed_value))
	swarms.clear()
	flare = 0.0
	flare_swarm = null
	for h in _homes:
		var sw := Swarm.new()
		sw.index = swarms.size()
		var y := CEILING
		if world.ground.is_valid():
			y = minf(float(world.ground.call(h.x, h.y)) + ABOVE, CEILING)
		sw.home = Vector3(h.x, y, h.y)
		sw.c = sw.home
		sw.phase = rnd.range_f(0.0, 6.0)
		for k in PER_SWARM:
			var m := Member.new()
			var dir := Vector3(rnd.range_f(-1, 1), rnd.range_f(-0.6, 0.6), rnd.range_f(-1, 1))
			if dir.length_squared() < 1e-6:
				dir = Vector3.RIGHT
			m.o = dir.normalized() * R * pow(rnd.next(), 1.0 / 3.0)
			m.phase = rnd.range_f(0.0, TAU)
			m.hue = rnd.next()
			sw.members.append(m)
		swarms.append(sw)


func step(world: EcoWorld, dt: float) -> void:
	var t := world.time
	var s := world.ship
	flare = 0.0
	flare_swarm = null
	for sw in swarms:
		sw.flare_cd -= dt
		sw.fade_cd -= dt
		sw.c = center(sw, t)
		var was := sw.lit
		sw.lit = _lit(world, sw, t)
		var prev := sw.glow
		sw.glow = minf(1.0, sw.glow + dt * GLOW_UP) if sw.lit else maxf(0.0, sw.glow - dt * GLOW_DOWN)
		if sw.lit and not was and sw.flare_cd <= 0.0:
			sw.flare_cd = FLARE_CD
			world.emit(ID, "flare", sw.c, _text(world,
				"Стая %s вспыхивает радугой в луче прожектора — корабль видно издалека"))
		if prev > FLARE_ON and sw.glow <= FLARE_ON and not s.light_on and sw.fade_cd <= 0.0 \
				and s.pos.distance_to(sw.c) < FADE_NEAR:
			sw.fade_cd = FADE_CD
			world.emit(ID, "fade", sw.c, _text(world, "Прожектор погашен — стая %s гаснет"))
		if sw.glow > flare:
			flare = sw.glow
			flare_swarm = sw


## Луч задевает стаю: проверяем каждого третьего гребневика (k % 3 == 0, как в браузере). Стаю дальше луча
## и радиуса не проверяем вовсе.
func _lit(world: EcoWorld, sw: Swarm, t: float) -> bool:
	var s := world.ship
	if not s.light_on:
		return false
	var reach := EcoWorld.BEAM_R * (s.light_range / Searchlight.BASE_RANGE if s.light_range > 0.0 else 1.0)
	if s.pos.distance_to(sw.c) > reach + R + 12.0:
		return false
	for k in range(0, PER_SWARM, 3):
		if world.in_beam(member_pos(sw, k, t)):
			return true
	return false


## Центр стаи в момент t: дом с медленным дрейфом.
static func center(sw: Swarm, t: float) -> Vector3:
	return Vector3(sw.home.x + sin(t * 0.05 + sw.phase) * DRIFT, sw.home.y + sin(t * 0.21 + sw.phase) * DRIFT_Y,
		sw.home.z + cos(t * 0.04 + sw.phase * 1.3) * DRIFT)


## Где гребневик k стаи в момент t (без корпуса корабля).
static func member_pos(sw: Swarm, k: int, t: float) -> Vector3:
	var m := sw.members[k]
	var p := sw.c + m.o
	p.x += sin(t * 0.6 + m.phase) * 0.5
	p.y += sin(t * 0.8 + m.phase * 1.7) * 0.4
	return p


## То же, но гребневик не заходит в корпус корабля (S.pushOut у стаи ближе NEAR_SHIP).
static func member_pos_outside(sw: Swarm, k: int, t: float, ship_pos: Vector3, ship_yaw: float) -> Vector3:
	var p := member_pos(sw, k, t)
	if ship_pos.distance_to(sw.c) < NEAR_SHIP:
		var res := EcoHull.push_out(p, ship_pos, ship_yaw, HULL_GAP)
		if not res.is_empty():
			p = res[0]
	return p


## Цвет гребневика в момент t: без света — едва заметный голубоватый силуэт, в луче — бегущая по ресничкам радуга.
static func member_color(sw: Swarm, k: int, t: float) -> Color:
	var m := sw.members[k]
	var base := 0.07 + 0.05 * maxf(0.0, sin(t * 0.9 + m.phase))
	var rainbow := Color.from_hsv(fposmod(m.hue + t * 0.35, 1.0), 0.9, 1.0)
	var dark := Color(base * 0.7, base * 0.9, base * 1.2)
	return dark.lerp(rainbow, sw.glow)


## Каждая стая видна сонару и сканеру.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for sw in swarms:
		out.append(EcoWorld.target(ID, sw.c, R))


## Видна ли вспышка хищнику в p (дальше его чутья, но ближе FLARE_REACH к кораблю — как в браузере, от корабля).
func flare_seen(d_ship: float, reach: float) -> bool:
	return flare > FLARE_ON and d_ship >= reach and d_ship < FLARE_REACH


## Текст события собирается в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой, без self.
## fmt — с одним %s для «радужников» в родительном падеже.
static func _text(world: EcoWorld, fmt: String) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		return fmt % (w.nm(ID, Species.Case.GEN) if w else Species.called(ID, Species.Case.GEN))
