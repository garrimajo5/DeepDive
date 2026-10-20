class_name EcoCushion
extends EcoSystem
## Подушечник (cushion в js/creatures.js: initCushions, squeeze, inkAt, cushionsUpdate; ART-004, бестиарий): мягкий
## коралл-подушка около 2 м в бархатных полипах. Две подушки у стай светляков 3 и 4, в 3 м от дома стаи. От касания —
## корабль у самой подушки или напуганная стая, нырнувшая в неё, — сжимается и выпускает облако чернил радиусом 5,5 м
## на 9 с, снова — через 40 с. В чернилах серпохвост теряет светляка (EcoPred: охота сорвана, наблюдение «hide»,
## раз в 30 с) и корабль (ближе 7,5 м к середине облака: бросок сорван, наблюдение «ship»; корабль его не манит).
## Наблюдение «touch» — при каждом сжатии. Заметен сонару и сканеру.

const ID := "cushion"
## Подушки — у этих стай светляков (E.shoals[3], [4]); стай должно быть хотя бы пять.
const SHOALS: Array[int] = [3, 4]
const MIN_SHOALS := 5
## Подушка в 3 м от дома стаи под углом i · 2,4 + 1,1; основание на 0,1 м в дне, макушка — на 1,4 м выше.
const OFFSET := 3.0
const SINK := 0.1
const TOP_UP := 1.4
## Середина облака — на 2 м над основанием (inkC); частиц 70, радиус 5,5 м (PD_INK_N, PD_INK_R).
const INK_UP := 2.0
const INK_N := 70
const INK_R := 5.5
## Облако живёт 9 с, подушка снова сжимается через 40 с (PD_INK_LIFE, PD_RECHARGE).
const INK_LIFE := 9.0
const RECHARGE := 40.0
## Корабль задел: ближе 6,8 м по горизонтали к основанию и не выше SHIP_UP над макушкой. В браузере — 1,2 м, но там
## корабль опускается до 1,2 м над дном (S.clearance + 1,2), а здесь — до Helm.Ship.CLEARANCE = 3 м: запас на 1,8 м
## больше, иначе над ровным дном подушку не задеть.
const SHIP_R := 6.8
const SHIP_UP := Helm.Ship.CLEARANCE
## Напуганная стая (alarm > 0) задела: живая рыбка ближе 2,2 м к макушке.
const FISH_R := 2.2
## Корабль в чернилах — ближе INK_R + 2 м к середине облака.
const SHIP_INK_PAD := 2.0
## Наблюдение «hide» — не чаще раза в 30 с у подушки.
const HIDE_CD := 30.0
## Сжатие спадает на 0,15 в секунду.
const RELAX := 0.15


## Подушка подушечника.
class Cushion:
	extends RefCounted
	var index := 0
	## Стая, у которой растёт (null — свои места из теста).
	var shoal: EcoFish.Shoal
	## Основание на дне, макушка, середина облака чернил.
	var base := Vector3.ZERO
	var top := Vector3.ZERO
	var ink_c := Vector3.ZERO
	## Сжатие 1 → 0; пауза до следующего сжатия; сколько ещё живёт облако (≤ 0 — облака нет); пауза «hide».
	var squeeze := 0.0
	var cd := 0.0
	var ink := 0.0
	var hide_cd := 0.0
	## Смещения частиц облака от середины (длина ≤ INK_R).
	var off := PackedVector3Array()

	func inked() -> bool:
		return ink > 0.0


var cushions: Array[Cushion] = []
## Светляки, у чьих стай растут подушки (null — подушек нет, если не заданы свои места).
var fish: EcoFish

var _spots: Array[Vector3]


## prey_fish — светляки мира (подключены раньше); spots — свои места подушек (для тестов), пусто — у стай 3 и 4.
func _init(prey_fish: EcoFish = null, spots: Array[Vector3] = []) -> void:
	fish = prey_fish
	_spots = spots.duplicate()


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 6271) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	var rnd := EcoWorld.seeded_for(seed_for(world.seed_value))
	cushions.clear()
	var places: Array[Vector3] = []
	var owners: Array[EcoFish.Shoal] = []
	if not _spots.is_empty():
		places = _spots.duplicate()
		for p in places:
			owners.append(null)
	elif fish and fish.shoals.size() >= MIN_SHOALS:
		for i in SHOALS.size():
			var sh := fish.shoals[SHOALS[i]]
			var a := i * 2.4 + 1.1
			places.append(sh.home + Vector3(cos(a) * OFFSET, 0.0, sin(a) * OFFSET))
			owners.append(sh)
	for i in places.size():
		var p := places[i]
		var cu := Cushion.new()
		cu.index = i
		cu.shoal = owners[i]
		cu.base = Vector3(p.x, _floor(world, p.x, p.z, p.y) - SINK, p.z)
		cu.top = cu.base + Vector3(0, TOP_UP, 0)
		cu.ink_c = cu.base + Vector3(0, INK_UP, 0)
		for k in INK_N:
			var v := Vector3(rnd.range_f(-1, 1), rnd.range_f(-0.6, 1), rnd.range_f(-1, 1))
			if v.length_squared() > 1.0:
				v = v.normalized()
			cu.off.append(v * INK_R * pow(rnd.next(), 1.0 / 3.0))
		cushions.append(cu)


func step(world: EcoWorld, dt: float) -> void:
	var s := world.ship.pos
	for cu in cushions:
		cu.cd -= dt
		cu.ink -= dt
		cu.hide_cd -= dt
		if Vector2(s.x - cu.base.x, s.z - cu.base.z).length() < SHIP_R and s.y < cu.top.y + SHIP_UP:
			squeeze(world, cu, true)
		elif _shoal_dived(cu):
			squeeze(world, cu, false)
		cu.squeeze = maxf(0.0, cu.squeeze - dt * RELAX)


## Напуганная стая нырнула в подушку: живая рыбка ближе FISH_R к макушке.
func _shoal_dived(cu: Cushion) -> bool:
	if cu.shoal == null or cu.shoal.alarm <= 0.0:
		return false
	for f: EcoFish.Fish in cu.shoal.members:
		if f.agent.alive and f.agent.p.distance_to(cu.top) < FISH_R:
			return true
	return false


## Сжаться и выпустить облако (squeeze): by_ship — задел корабль. false — ещё не набрался чернил.
func squeeze(world: EcoWorld, cu: Cushion, by_ship: bool) -> bool:
	if cu.cd > 0.0:
		return false
	cu.cd = RECHARGE
	cu.squeeze = 1.0
	cu.ink = INK_LIFE
	world.emit(ID, "touch", cu.top, _touch_text(world, by_ship))
	return true


## Облако чернил, в котором точка p (ближе INK_R к середине); null — не в чернилах (inkAt).
func ink_at(p: Vector3) -> Cushion:
	for cu in cushions:
		if cu.inked() and p.distance_to(cu.ink_c) < INK_R:
			return cu
	return null


## Есть ли сейчас хоть одно облако чернил.
func any_ink() -> bool:
	for cu in cushions:
		if cu.inked():
			return true
	return false


## Облако, в котором корабль (ближе INK_R + 2 м); null — корабль не в чернилах (E.shipInk).
func ship_ink(world: EcoWorld) -> Cushion:
	for cu in cushions:
		if cu.inked() and world.ship.pos.distance_to(cu.ink_c) < INK_R + SHIP_INK_PAD:
			return cu
	return null


## Серпохвост потерял светляка в чернилах: наблюдение «hide», раз в HIDE_CD у подушки.
func hid_fish(world: EcoWorld, cu: Cushion) -> void:
	if cu.hide_cd <= 0.0:
		cu.hide_cd = HIDE_CD
		world.emit(ID, "hide", cu.ink_c, _hide_text(world))


## Серпохвост потерял корабль в чернилах — наблюдение «ship» (at — где хищник).
func hid_ship(world: EcoWorld, at: Vector3) -> void:
	world.emit(ID, "ship", at, _ship_text(world))


## Каждая подушка видна сонару и сканеру — по макушке.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for cu in cushions:
		out.append(EcoWorld.target(ID, cu.top, 1.3))


## Облако растёт за 0,5 с (grow) и тает последние 2 с (k).
static func ink_grow(cu: Cushion) -> float:
	return clampf((INK_LIFE - cu.ink) * 2.0, 0.0, 1.0)


static func ink_fade(cu: Cushion) -> float:
	return clampf(cu.ink / 2.0, 0.0, 1.0)


## Частица j облака в момент t: смещение растёт с облаком, частицы плавают на ±0,3 м.
static func ink_point(cu: Cushion, j: int, t: float) -> Vector3:
	var o := cu.off[j] * ink_grow(cu)
	return cu.ink_c + o + Vector3(sin(t * 0.5 + j) * 0.3, 0.0, cos(t * 0.4 + j) * 0.3)


## Масштаб подушки: сжатая — ниже и уже (s = 1 − 0,45 · squeeze, по высоте ещё × (1 − 0,2 · squeeze)).
static func squash(cu: Cushion) -> Vector3:
	var s := 1.0 - cu.squeeze * 0.45
	return Vector3(s, s * (1.0 - cu.squeeze * 0.2), s)


static func _floor(world: EcoWorld, x: float, z: float, fallback: float) -> float:
	return float(world.ground.call(x, z)) if world.ground.is_valid() else fallback


## Тексты собираются в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой (событие лежит в шине мира).
static func _touch_text(world: EcoWorld, by_ship: bool) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var name := w.nm(ID) if w else Species.called(ID)
		return "%s сжимается и выпускает облако чернил%s" % [Species.cap(name), " — корабль его задел" if by_ship else ""]


static func _hide_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var fish := w.nm(EcoFish.ID) if w else Species.called(EcoFish.ID)
		var cush := w.nm(ID, Species.Case.GEN) if w else Species.called(ID, Species.Case.GEN)
		var pred := w.nm(EcoPred.ID) if w else Species.called(EcoPred.ID)
		return "%s: стая скрылась в чернилах %s, %s её потерял" % [Species.cap(fish), cush, pred]


static func _ship_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var cush := w.nm(ID, Species.Case.GEN) if w else Species.called(ID, Species.Case.GEN)
		var pred := w.nm(EcoPred.ID) if w else Species.called(EcoPred.ID)
		return "Корабль в чернилах %s: %s потерял его из виду" % [cush, pred]
