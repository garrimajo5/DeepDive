class_name EcoRemoraDust
extends RefCounted
## Слизь присосок (docs/grafika-plan-eco.md, Б3 «Мелочь жизни», «облачка и пузырьки от существ»): присоска-диск
## прилипалы держится на слизи. Легла на корпус или на спину ледокрыла — из-под диска выжимается маленькое облачко
## (LATCH); снялась со ската сама — ещё слабее (LET_GO); сорвана разрядом с корпуса — клуб из TORN облачков на
## месте, где сидела: диск отрывают резко. Облачка те же, что у скребунов (EcoGrazerDust: стоят, где подняты,
## растут, поднимаются, уплывают по течению, тают; светлее в луче прожектора) — свой пул на POOL мест, цвет —
## бледная слизь в тон диска (RemoraView.DISC). Корабль уходит — облачко с корпуса остаётся в воде за ним.
## Мир и его случай не меняются: что делает рыба — по её режиму между шагами, разброс — хешем EcoVary; у гостя сети
## прилипалы идут в его мире (разряд — флагом корабля), облачка те же по виду.
## Рисует RemoraView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки,
## шейдеров не прибавилось. «Экономно» — общий выключатель мелочи жизни EcoGrazerDust.lite.

## Мест в пуле: разряд срывает до шести рыб по три облачка, и ещё легли/снялись.
const POOL := 24
## Что случилось с рыбой: ничего, легла (корпус или скат), снялась со ската, сорвана с корпуса.
enum Kind { NONE, LATCH, LET_GO, TORN }
## Непрозрачность и доля размера (размер скребуна 0,5 → 1,6 м): рыба 0,35 м — облачка мелкие.
const LATCH_ALPHA := 0.4
const LATCH_SCALE := 0.3
const LET_GO_ALPHA := 0.28
const LET_GO_SCALE := 0.18
const TORN := 3
const TORN_ALPHA := 0.65
const TORN_SCALE := 0.45
## Разброс места у диска (м); клуб сорванной — шире.
const SCATTER := 0.08
const TORN_SCATTER := 0.2
const SALT := 241
## Цвет: бледная серо-голубая слизь в тон диска (#d8e6ea); в темноте — тусклая, в луче — светлая.
const COLOR := Color(0.24, 0.28, 0.30)
const LIT := Color(0.76, 0.84, 0.86)

var dust := EcoGrazerDust.new(POOL)
## Режим каждой рыбы и где она была на прошлом шаге (по номеру).
var _mode := PackedByteArray()
var _at := PackedVector3Array()
var _made := 0
var _last := -1e9


## Что случилось с рыбой между шагами: был режим was, стал now (EcoRemora.Mode).
static func kind(was: int, now: int) -> Kind:
	if was == now:
		return Kind.NONE
	if was == EcoRemora.Mode.SWIM and (now == EcoRemora.Mode.HULL or now == EcoRemora.Mode.RAY):
		return Kind.LATCH
	if was == EcoRemora.Mode.RAY:
		return Kind.LET_GO
	if was == EcoRemora.Mode.HULL:
		return Kind.TORN
	return Kind.NONE


## Где поднять облачко с ключом key около at: с разбросом r.
static func spot(at: Vector3, key: int, r: float) -> Vector3:
	return at + Vector3(EcoVary.unit(key, SALT) * 2.0 - 1.0, EcoVary.unit(key, SALT + 1) * 2.0 - 1.0,
			EcoVary.unit(key, SALT + 2) * 2.0 - 1.0) * r


## Шаг в момент t (время мира): легла, снялась, сорвана — облачка. ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoRemora, t: float, ship: Vector3) -> void:
	if system == null:
		return
	var list := system.remoras
	var n := list.size()
	if _mode.size() != n or t < _last:   # первый шаг или время мира пошло назад — запомнить, без облачков
		_mode.resize(n)
		_at.resize(n)
		for i in n:
			_mode[i] = list[i].mode
			_at[i] = list[i].p
		_last = t
		return
	_last = t
	for i in n:
		var rm := list[i]
		var k := kind(_mode[i], rm.mode)
		var was := _at[i]
		_mode[i] = rm.mode
		_at[i] = rm.p
		if k == Kind.NONE or EcoGrazerDust.lite or rm.p.distance_to(ship) > EcoGrazerDust.NEAR:
			continue
		match k:
			Kind.LATCH:
				_puff(rm.p, i, t, LATCH_ALPHA, LATCH_SCALE, SCATTER)
			Kind.LET_GO:
				_puff(was, i, t, LET_GO_ALPHA, LET_GO_SCALE, SCATTER)
			Kind.TORN:   # там, где сидела: за шаг рыба уже отплыла
				for c in TORN:
					_puff(was, i, t, TORN_ALPHA, TORN_SCALE, TORN_SCATTER)


func _puff(at: Vector3, i: int, t: float, alpha: float, scale: float, r: float) -> void:
	_made += 1
	var key := _made * 8 + i
	dust.add(spot(at, key, r), t, alpha * EcoVary.spread(key, SALT + 3, 0.2), key,
			scale * EcoVary.spread(key, SALT + 4, 0.15))
