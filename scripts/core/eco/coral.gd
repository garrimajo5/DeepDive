class_name EcoCoral
extends EcoSystem
## Огнецвет (ART-004, `docs/concept-art/flora-otmeli.md`): три куста высотой около 4 м с оранжевыми кончиками —
## на местах станций чистки огнёвок из js/creatures.js (initStations: места кораллов у (−45, 35), (38, 72), (22, −42);
## у их подножия лежат образцы «Ветка огнецвета», Samples). Кончики светятся сами; от шума корабля рядом (быстрый
## ход ближе 18 м), импульса сонара и разряда гаснут, в тишине медленно разгораются снова. Огнёвки и их станции
## придут партией «Риф».

## Подножия кустов (x, z): места станций из браузера (образец лежит в 1,6 м к востоку и 0,4 м к югу).
const BASES: Array[Vector2] = [Vector2(-56.95, 22.84), Vector2(33.3, 56.8), Vector2(54.88, -68.69)]
## Высота куста (м) при масштабе 1; вершина станции в браузере — на 4,2 м над подножием.
const HEIGHT := 4.0
const TOP := 4.2
## Шум: корабль ближе NOISE_R к вершине быстрее NOISE_SPEED (как слух серпохвоста, HEAR_SPEED) — гаснет за ~1 с.
const NOISE_R := 18.0
const NOISE_SPEED := 3.0
const DIM_RATE := 0.8
## Сонар ближе PING_R гасит половину света, разряд — весь.
const PING_R := 40.0
const PING_DIM := 0.5
## Погасший куст тлеет; разгорается за 25 с.
const MIN_GLOW := 0.08
const RELIGHT := 0.04
## Сообщение «гаснет» — не чаще раза в 40 с.
const MSG_CD := 40.0
## Свет ниже этого — куст «погас» (для сообщения).
const DARK := 0.5


## Куст огнецвета.
class Bush:
	extends RefCounted
	var index := 0
	## Подножие на дне.
	var base := Vector3.ZERO
	## Вершина (там держат станцию огнёвки).
	var top := Vector3.ZERO
	## Поворот и масштаб куста (±10 %, как разброс флоры).
	var yaw := 0.0
	var scale := 1.0
	## Свет кончиков: 1 — горит, MIN_GLOW — погас.
	var glow := 1.0


var bushes: Array[Bush] = []
## Секунд до следующего сообщения.
var msg_cd := 0.0

var _bases: Array[Vector2]


## bases — свои места (для тестов); пусто — места из браузера.
func _init(bases: Array[Vector2] = []) -> void:
	_bases = bases if not bases.is_empty() else BASES


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 7004) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	var rnd := EcoWorld.seeded_for(seed_for(world.seed_value))
	bushes.clear()
	msg_cd = 0.0
	for i in _bases.size():
		var b := Bush.new()
		b.index = i
		var xz := _bases[i]
		var y: float = world.ground.call(xz.x, xz.y) if world.ground.is_valid() else -40.0
		b.base = Vector3(xz.x, y, xz.y)
		b.yaw = rnd.range_f(0.0, TAU)
		b.scale = rnd.range_f(0.9, 1.1)
		b.top = b.base + Vector3(0, TOP * b.scale, 0)
		bushes.append(b)


func step(world: EcoWorld, dt: float) -> void:
	msg_cd -= dt
	var s := world.ship
	var loud := absf(s.speed) > NOISE_SPEED
	var dimmed := false
	for b in bushes:
		var was := b.glow
		if loud and s.pos.distance_to(b.top) < NOISE_R:
			b.glow = maxf(MIN_GLOW, b.glow - dt * DIM_RATE)
		else:
			b.glow = minf(1.0, b.glow + dt * RELIGHT)
		if was >= DARK and b.glow < DARK:
			dimmed = true
	if dimmed:
		_say(world, "Огнецвет гасит огни — корабль шумит рядом")


func on_ping(world: EcoWorld, pos: Vector3) -> void:
	var dimmed := false
	for b in bushes:
		if pos.distance_to(b.top) < PING_R:
			var was := b.glow
			b.glow = maxf(MIN_GLOW, b.glow - PING_DIM)
			dimmed = dimmed or (was >= DARK and b.glow < DARK)
	if dimmed:
		_say(world, "Огнецвет гасит огни от импульса сонара")


func on_zap(world: EcoWorld, radius: float) -> void:
	var hit := false
	for b in bushes:
		if world.ship.pos.distance_to(b.top) < radius + HEIGHT:
			b.glow = MIN_GLOW
			hit = true
	if hit:
		msg_cd = 0.0
		_say(world, "Огнецвет гаснет от разряда")


## Свет куста i (для сцены).
func glow_of(i: int) -> float:
	return bushes[i].glow


func _say(world: EcoWorld, text: String) -> void:
	if msg_cd > 0.0:
		return
	msg_cd = MSG_CD
	world.send(EcoLink.message(text))
