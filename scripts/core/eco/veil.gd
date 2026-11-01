class_name EcoVeil
extends EcoSystem
## Фонарные вуали (initVeils/veilUpdate в js/creatures.js; бестиарий): колонии медуз размером с автобус — купол 6 м,
## щупальца на 15 м вниз. Две вуали на местах браузера, купол в 21 м над дном (не выше −9 м); дрейфуют у своего места
## (± 0,6 м/с, тянет домой 0,004 /с), не опускаются щупальцами ниже 3 м над дном, качаются по высоте ± 1,2 м,
## купол пульсирует (1 ± 0,07, 1,3 рад/с) и мерцает кромкой.
## Светляки обходят вуаль (толчок 2,2 вбок в цилиндре r + 3 под куполом), а подплывшую под купол рыбку
## (ближе 0,85 r) вуаль жалит — с вероятностью 0,22 в секунду, наблюдение «sting». Серпохвост обходит вуаль стороной
## (толчок 8 в цилиндре r + 9; EcoPred, поле veils), наблюдение хищника «avoid» — раз в 40 с на хищника. Корабль под
## куполом (ближе r + 6 по горизонтали, от 1 м над куполом до 6 м под щупальцами) спрятан от хищников: бросок
## сорван, наблюдение «hide» (EcoPred.ship_hidden). Заметна сонару и сканеру — в 3 м под куполом.

const ID := "veil"
## Места (x, z) — как в браузере (js: [[-28, 42], [85, 25]]).
const PLACES: Array[Vector2] = [Vector2(-28, 42), Vector2(85, 25)]
## Купол: радиус, длина щупалец (м); над дном (м) и потолок купола (м).
const R := 6.0
const LEN := 15.0
const ABOVE_FLOOR := 21.0
const TOP_Y := -9.0
## Дрейф: скорость покачивания (м/с), тяга домой (/с); щупальца не ниже FLOOR_PAD над дном; потолок купола в пути.
const DRIFT := 0.6
const HOME_PULL := 0.004
const FLOOR_PAD := 3.0
const CEIL_Y := -7.0
const BOB := 1.2
## Пульс купола: 1 ± PULSE (1,3 рад/с); внутренний купол — 1 ± PULSE_IN, отстаёт на 0,6 рад.
const PULSE := 0.07
const PULSE_IN := 0.09
const PULSE_W := 1.3
## Светляки: толкает вбок в цилиндре r + FISH_PAD от FISH_UP над куполом до низа щупалец; жалит под куполом ближе
## STING_R · r и ниже 0,5 м под ним, с вероятностью STING_RATE в секунду.
const FISH_PAD := 3.0
const FISH_UP := 2.0
const FISH_PUSH := 2.2
const STING_R := 0.85
const STING_RATE := 0.22
## Серпохвост: обходит в цилиндре r + PRED_PAD от PRED_UP над куполом до PRED_DOWN под щупальцами, толчок PRED_PUSH;
## наблюдение «avoid» — раз в AVOID_CD с.
const PRED_PAD := 9.0
const PRED_UP := 4.0
const PRED_DOWN := 2.0
const PRED_PUSH := 8.0
const AVOID_CD := 40.0
## Корабль под куполом: ближе r + SHIP_PAD по горизонтали, не выше SHIP_UP над куполом, не ниже SHIP_DOWN под щупальцами.
const SHIP_PAD := 6.0
const SHIP_UP := 1.0
const SHIP_DOWN := 6.0
## Цель сонара и сканера — в SCAN_DOWN под куполом, размер TARGET_R.
const SCAN_DOWN := 3.0
const TARGET_R := 7.0
## Щупалец на вуаль и звеньев на щупальце; маленьких колокольчиков вокруг купола.
const TENTACLES := 40
const SEGMENTS := 10
const SMALL := 9


## Вуаль.
class Veil:
	extends RefCounted
	var index := 0
	var p := Vector3.ZERO
	var home := Vector3.ZERO
	var ph := 0.0
	## Щупальца: угол, расстояние от середины (доля r уже умножена), длина.
	var tent_a := PackedFloat32Array()
	var tent_r := PackedFloat32Array()
	var tent_len := PackedFloat32Array()
	## Колокольчики: размер 0,5–1 м, высота под кромкой (−3…−1 м), фаза пульса.
	var small_size := PackedFloat32Array()
	var small_y := PackedFloat32Array()
	var small_ph := PackedFloat32Array()
	## Сколько раз ужалила светляка и где последний (облачка слизи — EcoVeilDust).
	var stings := 0
	var sting_at := Vector3.ZERO

	## Цель сонара и сканера (vl.scanP).
	func scan_point() -> Vector3:
		return p - Vector3(0, SCAN_DOWN, 0)


var veils: Array[Veil] = []

var _rnd: EcoRandom
var _spots: Array[Vector2]


## spots — свои места (x, z) вуалей (для тестов), пусто — места браузера PLACES.
func _init(spots: Array[Vector2] = []) -> void:
	_spots = spots.duplicate()


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 8111) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	veils.clear()
	var places := PLACES if _spots.is_empty() else _spots
	for i in places.size():
		var x := places[i].x
		var z := places[i].y
		var top := minf(_floor(world, x, z, TOP_Y - ABOVE_FLOOR) + ABOVE_FLOOR, TOP_Y)
		var vl := Veil.new()
		vl.index = i
		vl.p = Vector3(x, top, z)
		vl.home = vl.p
		vl.ph = i * 2.1
		vl.p.y = height(world, vl, world.time)
		for k in SMALL:
			vl.small_size.append(_rnd.range_f(0.5, 1.0))
			vl.small_y.append(_rnd.range_f(-3.0, -1.0))
			vl.small_ph.append(_rnd.range_f(0.0, 6.0))
		for k in TENTACLES:
			vl.tent_a.append(k / float(TENTACLES) * TAU + _rnd.range_f(-0.05, 0.05))
			vl.tent_r.append(R * _rnd.range_f(0.25, 0.9))
			vl.tent_len.append(LEN * _rnd.range_f(0.6, 1.0))
		veils.append(vl)


func step(world: EcoWorld, dt: float) -> void:
	var t := world.time
	for vl in veils:
		vl.p.x += sin(t * 0.031 + vl.ph) * DRIFT * dt + (vl.home.x - vl.p.x) * HOME_PULL * dt
		vl.p.z += cos(t * 0.027 + vl.ph * 1.7) * DRIFT * dt + (vl.home.z - vl.p.z) * HOME_PULL * dt
		vl.p.y = height(world, vl, t)


## Высота купола над (p.x, p.z) в момент t: своё место, но щупальца не ниже FLOOR_PAD над дном и купол не выше
## CEIL_Y, плюс покачивание ± BOB. Сброс ставит ту же высоту — раньше купол стоял без покачивания и на первом шаге
## прыгал до 1,2 м (у второй вуали — на 1 м за кадр).
static func height(world: EcoWorld, vl: Veil, t: float) -> float:
	var low := _floor(world, vl.p.x, vl.p.z, vl.home.y - LEN - FLOOR_PAD) + LEN + FLOOR_PAD
	return minf(maxf(vl.home.y, low), CEIL_Y) + sin(t * 0.3 + vl.ph) * BOB


## Пульс купола в момент t: (наружный, внутренний) масштаб по ширине (по высоте — обратный).
static func pulse(vl: Veil, t: float) -> Vector2:
	return Vector2(1.0 + sin(t * PULSE_W + vl.ph) * PULSE, 1.0 + sin(t * PULSE_W + vl.ph - 0.6) * PULSE_IN)


## Яркость кромки 0,2…1 (0,6 + 0,4 sin(2,6 t + ph)).
static func rim_glow(vl: Veil, t: float) -> float:
	return 0.6 + 0.4 * sin(t * 2.6 + vl.ph)


## Жизнь щупалец (план реализма Б3): сокращение купола бежит волной вниз по щупальцам — звено j повторяет пульс
## купола с отставанием WAVE_LAG рад на звено, размах к кончику растёт в (1 + WAVE_GROW) раз; течение сносит нити —
## кончик по потоку на TRAIL длины на полном течении (растёт как доля длины², порыв 0,7…1 за ~16 с), звено
## поднимается, чтобы нить не вытягивалась. Без этого (live = false, «Экономно») — колыхание браузера.
const WAVE_LAG := 0.35
const WAVE_GROW := 1.0
const TRAIL := 0.12


## Точка j (0…SEGMENTS) щупальца k относительно середины купола в момент t — как veilUpdate, плюс волна пульса и
## снос течением flow (м/с) при live; та же формула — в шейдере VeilView (EcoShaders.MIST, режим TENTACLE).
static func tentacle_point(vl: Veil, k: int, j: int, t: float, flow := Vector3.ZERO, live := false) -> Vector3:
	var s := pulse(vl, t).x
	var x0 := cos(vl.tent_a[k]) * vl.tent_r[k]
	var z0 := sin(vl.tent_a[k]) * vl.tent_r[k]
	if j == 0:
		return Vector3(x0 * s, -0.1, z0 * s)
	var h := j / float(SEGMENTS)
	var sj := s
	if live:
		sj = 1.0 + sin(t * PULSE_W + vl.ph - j * WAVE_LAG) * PULSE * (1.0 + WAVE_GROW * h)
	var step_len := vl.tent_len[k] / SEGMENTS
	var p := Vector3(x0 * sj + sin(t * 0.9 + (j - 1) * 0.45 + k) * j * 0.12, -j * step_len,
		z0 * sj + cos(t * 0.7 + (j - 1) * 0.4 + k * 1.3) * j * 0.12)
	if live:
		p += trail(vl, h, j * step_len, t, flow)
	return p


## Снос звена течением: h — доля длины щупальца, depth — глубина звена под куполом (м) — двойник шейдера.
static func trail(vl: Veil, h: float, depth: float, t: float, flow: Vector3) -> Vector3:
	var gust := 0.85 + 0.15 * sin(t * 0.4 + vl.ph)
	var off := flow / EcoCurrent.SPEED * (TRAIL * gust * h * depth)
	off.y = off.length_squared() / (2.0 * maxf(depth / maxf(h, 0.01), 0.1))
	return off


## Близко ли к вуали хоть что-то в радиусе pad по горизонтали (для отбора стай перед обходом рыбок).
func near_any(p: Vector3, pad: float) -> bool:
	for vl in veils:
		if Vector2(p.x - vl.p.x, p.z - vl.p.z).length() < R + pad:
			return true
	return false


## Толчок светляку в p (вбок от вуали); жалит под куполом — тогда возвращает вуаль в sting[0]. dt — шаг рыбки.
## Вероятность — генератором вуалей (не сдвигает стаи).
func fish_push(world: EcoWorld, p: Vector3, dt: float, sting: Array) -> Vector3:
	var acc := Vector3.ZERO
	for vl in veils:
		var dx := p.x - vl.p.x
		var dz := p.z - vl.p.z
		var dh := sqrt(dx * dx + dz * dz) + 0.01
		if p.y < vl.p.y + FISH_UP and p.y > vl.p.y - LEN and dh < R + FISH_PAD:
			acc.x += dx / dh * FISH_PUSH
			acc.z += dz / dh * FISH_PUSH
			if dh < R * STING_R and p.y < vl.p.y - 0.5 and _rnd.next() < dt * STING_RATE:
				sting.append(vl)
				vl.stings += 1
				vl.sting_at = p
				world.emit(ID, "sting", p, _sting_text(world))
				return acc
	return acc


## Толчок серпохвосту в p (вбок, сила PRED_PUSH) — пусто, если ни одна вуаль не рядом.
func pred_push(p: Vector3) -> Vector3:
	var acc := Vector3.ZERO
	for vl in veils:
		var dx := p.x - vl.p.x
		var dz := p.z - vl.p.z
		var dh := sqrt(dx * dx + dz * dz) + 0.01
		if dh < R + PRED_PAD and p.y < vl.p.y + PRED_UP and p.y > vl.p.y - LEN - PRED_DOWN:
			acc.x += dx / dh * PRED_PUSH
			acc.z += dz / dh * PRED_PUSH
	return acc


## Вуаль, под куполом которой корабль (E.shipHidden по вуалям); null — ни под одной.
func ship_under(world: EcoWorld) -> Veil:
	var s := world.ship.pos
	for vl in veils:
		if Vector2(s.x - vl.p.x, s.z - vl.p.z).length() < R + SHIP_PAD and s.y < vl.p.y + SHIP_UP \
				and s.y > vl.p.y - LEN - SHIP_DOWN:
			return vl
	return null


## Серпохвост потерял корабль под куполом: наблюдение «hide».
func hid_ship(world: EcoWorld, at: Vector3) -> void:
	world.emit(ID, "hide", at, _text(world, "Корабль под куполом: %s потерял его из виду", EcoPred.ID))


## Серпохвост обходит вуаль стороной: наблюдение хищника «avoid».
func avoided(world: EcoWorld, at: Vector3) -> void:
	world.emit(EcoPred.ID, "avoid", at, _avoid_text(world))


## Каждая вуаль видна сонару и сканеру.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for vl in veils:
		out.append(EcoWorld.target(ID, vl.scan_point(), TARGET_R))


static func _floor(world: EcoWorld, x: float, z: float, fallback: float) -> float:
	return float(world.ground.call(x, z)) if world.ground.is_valid() else fallback


## Текст с названием вида who (в именительном) — в момент показа; мир — слабой ссылкой.
static func _text(world: EcoWorld, fmt: String, who: String) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		return fmt % (w.nm(who) if w else Species.called(who))


## «Фонарная вуаль ужалила светляка».
static func _sting_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var v := w.nm(ID) if w else Species.called(ID)
		var f := w.nm(EcoFish.ID, Species.Case.ACC) if w else Species.called(EcoFish.ID, Species.Case.ACC)
		return "%s ужалила %s" % [Species.cap(v), f]


## «Серпохвост обходит фонарную вуаль стороной».
static func _avoid_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var p := w.nm(EcoPred.ID) if w else Species.called(EcoPred.ID)
		var v := w.nm(ID, Species.Case.ACC) if w else Species.called(ID, Species.Case.ACC)
		return "%s обходит %s стороной" % [Species.cap(p), v]
