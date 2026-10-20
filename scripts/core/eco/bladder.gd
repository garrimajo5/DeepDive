class_name EcoBladder
extends EcoSystem
## Пузырчатка-фонарь (bladder в js/creatures.js: initBladders, bladdersUpdate; ART-004, бестиарий): тонкие стебли около
## метра с прозрачными луковицами светящегося сока. Три куста по семь стеблей у трёх пятен мха, ближайших к старту
## (в браузере — у стай монетников, а они стоят у тех же пятен: initCoins берёт три ближайших пятна не ближе 25 м
## друг к другу), в 4,5 м от середины пятна. Луковицы зреют 70 с и лопаются облаком светящихся спор на 12 с;
## спелее 0,6 — лопаются и от корабля, проходящего над кустом на ходу. На споры слетаются спокойные стаи светляков
## ближе 35 м и монетники своей стайки (EcoCoins). Наблюдения журнала: «pop» (лопнули), «feed» (рыбы у спор
## ближе 6 м, раз в 60 с). Заметна сонару и сканеру.

const ID := "bladder"
## Кустов — по пятнам мха у старта; стеблей на куст и спор в облаке (PZ_STEMS, PZ_SPORE_N).
const BUSHES := 3
const STEMS := 7
const SPORES := 60
## Облако спор живёт 12 с; от лопнувших до спелых луковиц — 70 с (PZ_LIFE, PZ_RIPEN).
const LIFE := 12.0
const RIPEN := 70.0
## Стаи ближе 35 м плывут к спорам; ближе 6 м — «приплыли» (PZ_CALL_R).
const CALL_R := 35.0
const CAME_R := 6.0
const FEED_CD := 60.0
## Пятна для кустов — не ближе 25 м друг к другу; куст — в 4,5 м от середины пятна.
const PICK_GAP := 25.0
const OFFSET := 4.5
## Облако спор — на 2,2 м над подножием, радиусом до 2,5 м.
const CLOUD_UP := 2.2
const CLOUD_R := 2.5
## Корабль лопает спелые (> 0,6) луковицы: на ходу быстрее 0,5 м/с, ближе 6,5 м по горизонтали и ниже 3 м над кустом.
const SHIP_RIPE := 0.6
const SHIP_SPEED := 0.5
const SHIP_R := 6.5
const SHIP_UP := 3.0


## Куст пузырчатки.
class Bush:
	extends RefCounted
	var index := 0
	## Подножие на дне и середина облака спор.
	var base := Vector3.ZERO
	var cloud := Vector3.ZERO
	## Спелость луковиц 0…1; облако спор живёт ещё life с (0 — облака нет).
	var ripe := 0.0
	var life := 0.0
	var feed_cd := 0.0
	## Стебли: основание на дне, вершина (там луковица), фаза покачивания.
	var stem_base := PackedVector3Array()
	var stem_top := PackedVector3Array()
	var stem_phase := PackedFloat32Array()
	## Смещения спор в облаке (длина ≤ CLOUD_R).
	var spores := PackedVector3Array()

	## Облако спор над кустом.
	func popped() -> bool:
		return life > 0.0


var bushes: Array[Bush] = []
## Стаи, что слетаются на споры (null — некого звать).
var fish: EcoFish
## Монетники: стайка i кормится на спорах куста i (EcoCoins.bladders) — тоже «слетаются рыбы». Слабая ссылка:
## монетники держат пузырчатку, обратная сильная ссылка — цикл RefCounted и утечка при выходе.
var coins: EcoCoins:
	get:
		return _coins.get_ref() if _coins else null
	set(value):
		_coins = weakref(value) if value else null

var _coins: WeakRef

var _spots: Array[Vector3]


## prey_fish — светляки мира (подключены раньше); spots — свои места кустов (для тестов), пусто — у пятен мха.
func _init(prey_fish: EcoFish = null, spots: Array[Vector3] = []) -> void:
	fish = prey_fish
	_spots = spots.duplicate() if not spots.is_empty() else default_spots()


## Три пятна мха, ближайших к старту корабля, не ближе PICK_GAP друг к другу (initCoins), и куст i — в OFFSET м
## от пятна под углом i · 1,9 + 2,6 (initBladders). y — пятна; на дно куст встаёт при сбросе.
static func default_spots() -> Array[Vector3]:
	var picks := EcoCoins.default_spots()
	var out: Array[Vector3] = []
	for i in picks.size():
		var a := i * 1.9 + 2.6
		out.append(picks[i] + Vector3(cos(a) * OFFSET, 0.0, sin(a) * OFFSET))
	return out


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 8813) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	var rnd := EcoWorld.seeded_for(seed_for(world.seed_value))
	bushes.clear()
	for p in _spots:
		var bl := Bush.new()
		bl.index = bushes.size()
		bl.base = Vector3(p.x, _floor(world, p.x, p.z, p.y), p.z)
		bl.cloud = bl.base + Vector3(0, CLOUD_UP, 0)
		bl.ripe = rnd.range_f(0.2, 0.8)
		for k in STEMS:
			# стебли по золотому углу: первый в середине, дальше кольцами 0,35 / 0,55 / 0,75 м, наклон наружу
			var r := 0.35 + (k % 3) * 0.2 if k > 0 else 0.0
			var b := k * 2.39996
			var h := rnd.range_f(0.8, 1.4)
			var x := bl.base.x + cos(b) * r
			var z := bl.base.z + sin(b) * r
			var at := Vector3(x, _floor(world, x, z, bl.base.y) - 0.05, z)
			var tilt := Vector3(cos(b) * r * 0.25, 1.0, sin(b) * r * 0.25).normalized()
			bl.stem_base.append(at)
			bl.stem_top.append(at + tilt * h)
			bl.stem_phase.append(rnd.range_f(0.0, 6.0))
		for k in SPORES:
			var v := Vector3(rnd.range_f(-1, 1), rnd.range_f(-0.5, 1), rnd.range_f(-1, 1))
			if v.length_squared() > 1.0:
				v = v.normalized()
			bl.spores.append(v * CLOUD_R * pow(rnd.next(), 1.0 / 3.0))
		bushes.append(bl)


func step(world: EcoWorld, dt: float) -> void:
	var s := world.ship
	for bl in bushes:
		bl.feed_cd -= dt
		if bl.life > 0.0:
			bl.life = maxf(0.0, bl.life - dt)
			if fish or _coins:
				_call_shoals(world, bl)
		else:
			bl.ripe = minf(1.0, bl.ripe + dt / RIPEN)
			if bl.ripe >= 1.0:
				pop(world, bl, false)
			elif bl.ripe > SHIP_RIPE and absf(s.speed) > SHIP_SPEED and s.pos.y < bl.base.y + SHIP_UP \
					and Vector2(s.pos.x - bl.base.x, s.pos.z - bl.base.z).length() < SHIP_R:
				pop(world, bl, true)


## Луковицы лопаются: облако спор на LIFE с, спелость с нуля. by_ship — задел корабль (другой текст).
func pop(world: EcoWorld, bl: Bush, by_ship: bool) -> void:
	bl.ripe = 0.0
	bl.life = LIFE
	world.emit(ID, "pop", bl.cloud, _pop_text(world, by_ship))


## Споры манят спокойные стаи (не в тревоге, от трёх рыбок) ближе CALL_R.
func _call_shoals(world: EcoWorld, bl: Bush) -> void:
	var c := coins
	var came := c != null and c.came_to(bl.index)
	for sh in (fish.shoals if fish else []):
		if sh.alarm > 0.0 or sh.alive < 3:
			continue
		var d := sh.center.distance_to(bl.cloud)
		if d < CALL_R:
			sh.goal = bl.cloud
			sh.goal_timer = maxf(sh.goal_timer, 0.5)
			came = came or d < CAME_R
	if came and bl.feed_cd <= 0.0:
		bl.feed_cd = FEED_CD
		world.emit(ID, "feed", bl.cloud, func() -> String: return "На светящиеся споры слетаются рыбы")


## Каждый куст виден сонару и сканеру — по первому стеблю.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for bl in bushes:
		out.append(EcoWorld.target(ID, bl.stem_top[0], 0.9))


## Луковица стебля k в момент t: место (покачивается по x на 5 см) и радиус-множитель — 0,2 у лопнувших,
## от 0,35 до 1 по спелости.
static func bulb(bl: Bush, k: int, t: float) -> Vector3:
	return bl.stem_top[k] + Vector3(sin(t * 0.8 + bl.stem_phase[k]) * 0.05, 0, 0)


static func bulb_size(bl: Bush) -> float:
	return 0.2 if bl.life > 0.0 else 0.35 + 0.65 * bl.ripe


## Цвет сока по спелости (зелёный #8EE87E у спелых, ART-004).
static func bulb_color(bl: Bush) -> Color:
	return Color(0.3 + 0.5 * bl.ripe, 0.6 + 0.4 * bl.ripe, 0.35 + 0.2 * bl.ripe)


## Спора j облака в момент t: облако расходится от 0,3 до 1,3 размера за 1,7 с и всплывает 8 см/с.
static func spore(bl: Bush, j: int, t: float) -> Vector3:
	var age := LIFE - bl.life
	var spread := 0.3 + minf(1.0, age * 0.6)
	var o := bl.spores[j]
	return bl.cloud + Vector3(o.x * spread + sin(t + j) * 0.2, o.y * spread + age * 0.08, o.z * spread)


## Яркость облака: гаснет за последние 3 с.
static func spore_glow(bl: Bush) -> float:
	return clampf(bl.life / 3.0, 0.0, 1.0)


static func _floor(world: EcoWorld, x: float, z: float, fallback: float) -> float:
	return float(world.ground.call(x, z)) if world.ground.is_valid() else fallback


## Текст собирается в момент показа: у просканированного вида — «луковицы пузырчатки»; мир — слабой ссылкой.
static func _pop_text(world: EcoWorld, by_ship: bool) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		if by_ship:
			return "Корабль задел спелые луковицы — они лопаются облаком светящихся спор"
		var w: EcoWorld = wr.get_ref()
		var known := w != null and w.scanned.is_valid() and bool(w.scanned.call(ID))
		return "Спелые луковицы%s лопаются облаком светящихся спор" % (" пузырчатки" if known else "")
