class_name EcoOrganDust
extends RefCounted
## Выдох трубного органа (docs/grafika-plan-eco.md, Б3 «Мелочь жизни», «облачка и пузырьки от существ»): губка
## гонит воду сквозь трубы и выдыхает из устьев отцеженную муть. В такт гулу (тление губки EcoOrgan.glow —
## sin 1,7 t, период ≈ 3,7 с) каждая труба в свой момент (своя фаза) выпускает над устьем маленькое облачко —
## не каждый раз, а с долей BREATH_CHANCE. Корабль рядом (ближе EcoOrgan.MASK_R, «в гуле») губка чувствует: трубы
## дышат каждый такт, облачка гуще и крупнее. Облачка те же, что у скребунов (EcoGrazerDust: стоят, где выдохнуты,
## растут, поднимаются, уплывают по течению, тают; светлее в луче прожектора) — свой пул на POOL мест, цвет —
## бледная взвесь, отцеженная губкой. Мир и его случай не меняются: такт — по времени мира, выдохнет ли труба и
## разброс — хешем EcoVary от номера трубы и такта, близость — по месту корабля; у гостя сети время мира то же
## (EcoLink.synced_time), поэтому и выдохи те же.
## Рисует OrganView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки, шейдеров
## не прибавилось. «Экономно» — общий выключатель мелочи жизни EcoGrazerDust.lite.

## Мест в пуле: труба выдыхает не чаще такта (3,7 с) при жизни облачка 3,6 с — у губки до 7 облачков разом; губки
## в 100 м друг от друга, корабль рядом только с одной (у дальней — меньше половины тактов). Пул мал — буфер
## MultiMesh переписывается каждый кадр (замер шага мира test_eco_speed); старое уступает новому.
const POOL := 10
## Такт выдоха — такт тления губки (EcoOrgan.glow: sin 1,7 t), в тактах за секунду.
const RATE := 1.7 / TAU
## Доля тактов, в которые труба выдыхает, когда корабля рядом нет (рядом — каждый такт).
const BREATH_CHANCE := 0.45
## Непрозрачность и доля размера облачка (размер скребуна 0,5 → 1,6 м): вдали — слабое и мелкое, корабль у самой
## губки — гуще и крупнее (по близости, closeness).
const ALPHA := 0.45
const ALPHA_NEAR := 0.8
const SCALE := 0.7
const SCALE_NEAR := 1.1
## Близость корабля: дальше EcoOrgan.MASK_R — 0, ближе FULL_R к середине губки — 1 (м).
const FULL_R := 8.0
## Над устьем трубы в начале (м) и разброс места поперёк (м).
const LIFT := 0.15
const SCATTER := 0.08
## Цвет: бледная бурая взвесь, отцеженная губкой (в тон труб #9a7f6a); в луче — светлая.
const COLOR := Color(0.27, 0.24, 0.21)
const LIT := Color(0.80, 0.74, 0.64)
const SALT := 151

var dust := EcoGrazerDust.new(POOL)
## Такт, до которого каждая труба уже выдохнула (по номеру трубы: губка × TUBES + труба).
var _cycle := PackedInt64Array()
var _made := 0
var _last := -1e9
## Когда начнётся ближайший новый такт у какой-нибудь трубы: до него шаг ничего не делает (замер шага мира).
var _due := -1e9


## Номер трубы k губки og во всех губках.
static func tube_id(og: EcoOrgan.Organ, k: int) -> int:
	return og.index * EcoOrgan.TUBES + k


## Фаза трубы j в такте (0…1): трубы губки дышат вразнобой.
static func phase(j: int) -> float:
	return EcoVary.unit(j, SALT)


## Такт трубы j в момент t (растёт на 1 каждые 1 / RATE с).
static func cycle(j: int, t: float) -> int:
	return int(floor(t * RATE + phase(j)))


## Когда начался такт c трубы j (время мира).
static func cycle_start(j: int, c: int) -> float:
	return (float(c) - phase(j)) / RATE


## Устье трубы k губки og (верх трубы).
static func mouth(og: EcoOrgan.Organ, k: int) -> Vector3:
	return og.tube_base[k] + Vector3(0, og.tube_len[k], 0)


## Близость корабля ship к губке og: 0 — дальше MASK_R, 1 — ближе FULL_R.
static func closeness(og: EcoOrgan.Organ, ship: Vector3) -> float:
	return clampf((EcoOrgan.MASK_R - ship.distance_to(og.base)) / (EcoOrgan.MASK_R - FULL_R), 0.0, 1.0)


## Выдохнет ли труба j в такт c при близости корабля k: рядом — всегда, вдали — с долей BREATH_CHANCE.
static func breathes(j: int, c: int, k: float) -> bool:
	return EcoVary.unit(c * 64 + j, SALT + 1) < lerpf(BREATH_CHANCE, 1.0, k)


## Где встаёт облачко трубы k губки og (ключ разброса key): над устьем, с разбросом поперёк.
static func spot(og: EcoOrgan.Organ, k: int, key: int) -> Vector3:
	var sx := (EcoVary.unit(key, SALT + 2) * 2.0 - 1.0) * SCATTER
	var sz := (EcoVary.unit(key, SALT + 3) * 2.0 - 1.0) * SCATTER
	return mouth(og, k) + Vector3(sx, LIFT, sz)


## Шаг в момент t (время мира): трубы, у которых начался новый такт, выдыхают. ship — корабль: близость и дальность
## (дальше EcoGrazerDust.NEAR — нет).
func update(system: EcoOrgan, t: float, ship: Vector3) -> void:
	if system == null:
		return
	var n := system.organs.size() * EcoOrgan.TUBES
	if t < _last or _last < -1e8 or _cycle.size() != n:
		_cycle.resize(n)
		for og in system.organs:
			for k in EcoOrgan.TUBES:
				var j := tube_id(og, k)
				_cycle[j] = cycle(j, t)
		_last = t
		_due = _next_due()
		return
	_last = t
	if t < _due:
		return
	for og in system.organs:
		var far := EcoGrazerDust.lite or og.base.distance_to(ship) > EcoGrazerDust.NEAR
		var near_k := closeness(og, ship)
		for k in EcoOrgan.TUBES:
			var j := tube_id(og, k)
			var c := cycle(j, t)
			if c <= _cycle[j]:
				continue
			_cycle[j] = c   # долгий кадр — только последний такт: прошлые облачка уже растаяли бы
			if far or not breathes(j, c, near_k):
				continue
			_made += 1
			var key := c * 64 + j
			var a := lerpf(ALPHA, ALPHA_NEAR, near_k) * EcoVary.spread(key, SALT + 4, 0.2)
			dust.add(spot(og, k, key), cycle_start(j, c), a, key, lerpf(SCALE, SCALE_NEAR, near_k))
	_due = _next_due()


## Начало ближайшего следующего такта среди всех труб.
func _next_due() -> float:
	var d := INF
	for j in _cycle.size():
		d = minf(d, cycle_start(j, int(_cycle[j]) + 1))
	return d
