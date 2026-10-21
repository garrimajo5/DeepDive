class_name EcoFern
extends EcoSystem
## Волнолист (fern в js/creatures.js: initFerns, fernsUpdate; ART-004 «Волнолист: закрыт / раскрыт»): спиральный
## папоротник около 1,5 м, две куртины по четыре куста — у стаи светляков рядом со стартом и у третьей стаи.
## В луче прожектора (EcoWorld.in_beam) листья разворачиваются и ложатся наружу (за ~1,7 с), после луча держатся
## раскрытыми ещё 5 с и сворачиваются за ~4 с. Под раскрытыми листьями видны моллюски: спокойные стаи светляков
## ближе 25 м плывут к ним. Сообщения (наблюдения журнала): «разворачивает листья к свету» (раз в 40 с),
## «открылись моллюски — к ним приплыли рыбы» (стая ближе 4 м, раз в 60 с). Заметен сонару и сканеру.

const ID := "fern"
## Листьев на куст и моллюсков у подножия.
const LEAVES := 6
const SHELLS := 3
const PER_CLUSTER := 4
## Куртина рассыпана в квадрате ±2,5 м.
const SPREAD := 2.5
## Куртина у стаи светляков на старте: в браузере (14, 78); здесь на 6 м южнее, чтобы ближайшей целью сканера
## у старта оставалась стая (как у веерника, EcoFan.START). Вторая — у третьей стаи, (−6, +4) от её дома.
const START_CLUSTER := Vector2(14, 72)
const SHOAL_CLUSTER := 2
const SHOAL_OFFSET := Vector2(-6, 4)
## Ширина и длина листа (м) и вершина куста над подножием (top в браузере).
const LEAF_W := 0.42
const LEAF_LEN := 1.4
const TOP := 0.9
## Наклон листа от вертикали: свёрнут и раскрыт (+ к свёрнутому), рад.
const TILT_CLOSED := 0.15
const TILT_OPEN := 0.75
## Моллюски — в 0,35 м от стебля.
const SHELL_R := 0.35
## Раскрытие: быстрее к свету (доля в секунду), медленнее в темноте; после луча ещё LIT_HOLD с раскрыт.
const OPEN_RATE := 0.6
const CLOSE_RATE := 0.25
const LIT_HOLD := 5.0
## Раскрыт настолько — моллюски видны, стаи плывут к ним.
const FEED_OPEN := 0.8
## Сообщение «разворачивает листья» — если куст был свёрнут меньше чем на эту долю.
const OPEN_MSG_BELOW := 0.3
const CALL_R := 25.0
const CAME_R := 4.0
const MSG_CD := 40.0
const FEED_CD := 60.0


## Куст волнолиста.
class Fern:
	extends RefCounted
	var index := 0
	## Подножие на дне и вершина (там его видят луч, сонар и сканер).
	var pos := Vector3.ZERO
	var top := Vector3.ZERO
	## Раскрытие 0 — свёрнут, 1 — листья лежат наружу.
	var open := 0.0
	## В луче в этот шаг.
	var lit := false
	## Секунд раскрытия после луча.
	var lit_t := 0.0
	var phase := 0.0
	var yaw := 0.0
	## Размер куста (±20 %, ART-004).
	var scale := 1.0


var ferns: Array[Fern] = []
## Стаи, которых зовут моллюски (null — некого звать).
var fish: EcoFish
var msg_cd := 0.0
var feed_cd := 0.0

var _clusters: Array[Vector2]


## prey_fish — светляки мира (подключены раньше); clusters — свои места куртин (для тестов), пусто — по браузеру.
func _init(prey_fish: EcoFish = null, clusters: Array[Vector2] = []) -> void:
	fish = prey_fish
	_clusters = clusters.duplicate() if not clusters.is_empty() else default_clusters()


static func default_clusters() -> Array[Vector2]:
	var h := EcoFish.HOMES[SHOAL_CLUSTER]
	return [START_CLUSTER, Vector2(h.x, h.z) + SHOAL_OFFSET]


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 3307) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	var rnd := EcoWorld.seeded_for(seed_for(world.seed_value))
	ferns.clear()
	msg_cd = 0.0
	feed_cd = 0.0
	for c in _clusters:
		for k in PER_CLUSTER:
			var fe := Fern.new()
			fe.index = ferns.size()
			var x := c.x + rnd.range_f(-SPREAD, SPREAD)
			var z := c.y + rnd.range_f(-SPREAD, SPREAD)
			fe.pos = Vector3(x, _floor(world, x, z), z)
			fe.phase = rnd.range_f(0.0, 6.0)
			fe.yaw = rnd.range_f(0.0, TAU)
			fe.scale = rnd.range_f(0.8, 1.2)
			fe.top = fe.pos + Vector3(0, TOP * fe.scale, 0)
			ferns.append(fe)


func step(world: EcoWorld, dt: float) -> void:
	msg_cd -= dt
	feed_cd -= dt
	for fe in ferns:
		var was := fe.lit
		fe.lit = world.in_beam(fe.top)
		fe.lit_t = LIT_HOLD if fe.lit else fe.lit_t - dt
		if fe.lit_t > 0.0:
			fe.open = minf(1.0, fe.open + dt * OPEN_RATE)
		else:
			fe.open = maxf(0.0, fe.open - dt * CLOSE_RATE)
		if fe.lit and not was and fe.open < OPEN_MSG_BELOW and msg_cd <= 0.0:
			msg_cd = MSG_CD
			world.emit(ID, "open", fe.top, _text(world, "%s разворачивает листья к свету прожектора", Species.Case.NOM, true))
		if fe.open > FEED_OPEN and fish:
			_call_shoals(world, fe)


## Открытые моллюски манят спокойные стаи (не в тревоге, от трёх рыбок) ближе CALL_R.
func _call_shoals(world: EcoWorld, fe: Fern) -> void:
	var came := false
	for sh in fish.shoals:
		if sh.alarm > 0.0 or sh.alive < 3 or sh.leader():
			continue
		var d := sh.center.distance_to(fe.top)
		if d < CALL_R:
			sh.goal = fe.top
			sh.goal_timer = maxf(sh.goal_timer, 0.5)
			came = came or d < CAME_R
	if came and feed_cd <= 0.0:
		feed_cd = FEED_CD
		world.emit(ID, "mollusk", fe.top,
			_text(world, "Под листьями %s открылись моллюски — к ним приплыли рыбы", Species.Case.GEN, false))


## Каждый куст виден сонару и сканеру.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for fe in ferns:
		out.append(EcoWorld.target(ID, fe.top, 0.7))


## Расстановка листа j куста в момент t (подножие — fe.pos): поворот вокруг стебля, наклон наружу на
## TILT_CLOSED + TILT_OPEN · open рад с покачиванием у раскрытого, размер (0,6 + 0,4 · open, 0,45 + 0,55 · open, 1)
## × fe.scale. В браузере лист шире не был (0,28 м) и раскрытый ложился почти плашмя (1,25 рад); здесь — как на
## листе состояний ART-004: широкие листья раскрываются кроной вверх и наружу.
static func leaf_basis(fe: Fern, j: int, t: float) -> Basis:
	var o := fe.open
	var a := float(j) / LEAVES * TAU + fe.yaw
	var tilt := (TILT_CLOSED + TILT_OPEN * o) - sin(t * 1.2 + fe.phase + j) * 0.05 * o
	var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -tilt)
	return b.scaled_local(Vector3(0.6 + 0.4 * o, 0.45 + 0.55 * o, 1.0) * fe.scale)


## Где лежит моллюск j куста (на дне, в SHELL_R от стебля).
static func shell_pos(fe: Fern, j: int, ground: Callable) -> Vector3:
	var a := float(j) / SHELLS * TAU + fe.yaw
	var r := SHELL_R * fe.scale
	var x := fe.pos.x + cos(a) * r
	var z := fe.pos.z + sin(a) * r
	var y: float = ground.call(x, z) if ground.is_valid() else fe.pos.y
	return Vector3(x, y + 0.02, z)


static func _floor(world: EcoWorld, x: float, z: float) -> float:
	return float(world.ground.call(x, z)) if world.ground.is_valid() else -40.0


## Текст собирается в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой, без self.
static func _text(world: EcoWorld, fmt: String, c: Species.Case, cap: bool) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var name := w.nm(ID, c) if w else Species.called(ID, c)
		return fmt % (Species.cap(name) if cap else name)
