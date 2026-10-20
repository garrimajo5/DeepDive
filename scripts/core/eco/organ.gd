class_name EcoOrgan
extends EcoSystem
## Трубный орган (organ в js/creatures.js: initOrgans, organsUpdate, hearsShip; ART-004, бестиарий): губка около
## 2,5–3,4 м из семи толстых труб. Две губки на местах из браузера; течение гудит в трубах. Корабль ближе 22 м
## к губке «в гуле»: серпохвост не слышит его двигателей (EcoPred.hears_ship), свет и сонар гул не прячет.
## Наблюдения журнала: «hum» (корабль ближе 30 м, раз в 120 с у каждой губки) и «mask» (гул спрятал корабль
## от патрулирующего или проверяющего звук серпохвоста, раз в 40 с у губки). Заметна сонару и сканеру.

const ID := "organ"
## Места губок (x, z) — как в браузере (js: [[-38, 78], [52, 30]]).
const SPOTS: Array[Vector2] = [Vector2(-38, 78), Vector2(52, 30)]
## Труб в губке; первая в середине, остальные — по золотому углу на 0,75 / 1,1 м.
const TUBES := 7
## Труба: радиус у устья и у основания (м), основание на 0,1 м в дне.
const TUBE_TOP_R := 0.32
const TUBE_BASE_R := 0.42
const SINK := 0.1
## Верх губки для событий и прицела — на 3,2 м над дном.
const TOP_UP := 3.2
## Корабль ближе 22 м к губке — его двигатели тонут в гуле (ORG_R).
const MASK_R := 22.0
## Корабль ближе 30 м — губка «гудит» (наблюдение), раз в 120 с; гул спрятал корабль — раз в 40 с.
const HUM_R := 30.0
const HUM_CD := 120.0
const MASK_CD := 40.0
## Слышно гул ближе 45 м (громкость 1 − d / 45, G.Audio.organ).
const LOUD_R := 45.0


## Губка трубного органа.
class Organ:
	extends RefCounted
	var index := 0
	## Середина на дне и верх (для событий и прицела).
	var base := Vector3.ZERO
	var top := Vector3.ZERO
	var hum_cd := 0.0
	var mask_cd := 0.0
	## Трубы: основание (в дне на SINK) и длина.
	var tube_base := PackedVector3Array()
	var tube_len := PackedFloat32Array()


var organs: Array[Organ] = []
## Громкость гула у корабля 0…1 по ближайшей губке (для звука).
var loudness := 0.0

var _spots: Array[Vector2]


## spots — свои места губок (для тестов), пусто — места из браузера.
func _init(spots: Array[Vector2] = []) -> void:
	_spots = spots.duplicate() if not spots.is_empty() else SPOTS.duplicate()


func reset(world: EcoWorld) -> void:
	organs.clear()
	loudness = 0.0
	for p in _spots:
		var og := Organ.new()
		og.index = organs.size()
		og.base = Vector3(p.x, _floor(world, p.x, p.y, 0.0), p.y)
		og.top = og.base + Vector3(0, TOP_UP, 0)
		for k in TUBES:
			# organGeo: первая труба в середине, дальше 0,75 и 1,1 м через одну; длина 3,4 − 1,2 r + (k mod 3) · 0,4
			var a := k * 2.39996
			var r := 0.75 + (k % 2) * 0.35 if k > 0 else 0.0
			var x := og.base.x + cos(a) * r
			var z := og.base.z + sin(a) * r
			og.tube_base.append(Vector3(x, _floor(world, x, z, og.base.y) - SINK, z))
			og.tube_len.append(3.4 - r * 1.2 + (k % 3) * 0.4)
		organs.append(og)


func step(world: EcoWorld, dt: float) -> void:
	var s := world.ship.pos
	var best := INF
	for og in organs:
		og.hum_cd -= dt
		og.mask_cd -= dt
		var d := s.distance_to(og.base)
		best = minf(best, d)
		if d < HUM_R and og.hum_cd <= 0.0:
			og.hum_cd = HUM_CD
			world.emit(ID, "hum", og.top, _text(world, "%s гудит в течении, как орган"))
	loudness = maxf(0.0, 1.0 - best / LOUD_R)


## Губка, в гуле которой корабль (ближе MASK_R); null — корабль не в гуле.
func masking(world: EcoWorld) -> Organ:
	var s := world.ship.pos
	for og in organs:
		if s.distance_to(og.base) < MASK_R:
			return og
	return null


## Гул спрятал корабль от серпохвоста: watching — тот патрулирует или проверяет звук (иначе не замечаем).
## Наблюдение «mask» — раз в MASK_CD у губки.
func masked(world: EcoWorld, og: Organ, watching: bool) -> void:
	if watching and og.mask_cd <= 0.0:
		og.mask_cd = MASK_CD
		world.emit(ID, "mask", og.top, _mask_text(world))


## Каждая губка видна сонару и сканеру — по верху.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for og in organs:
		out.append(EcoWorld.target(ID, og.top, 1.6))


## Свечение губки в момент t (emissive в браузере: 0,1 + 0,05 sin 1,7t, 0,06, 0,03).
static func glow(t: float) -> Color:
	return Color(0.1 + 0.05 * sin(t * 1.7), 0.06, 0.03)


static func _floor(world: EcoWorld, x: float, z: float, fallback: float) -> float:
	return float(world.ground.call(x, z)) if world.ground.is_valid() else fallback


## Текст собирается в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой (событие лежит в шине мира).
static func _text(world: EcoWorld, fmt: String) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		return fmt % Species.cap(w.nm(ID) if w else Species.called(ID))


static func _mask_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var organ := w.nm(ID, Species.Case.GEN) if w else Species.called(ID, Species.Case.GEN)
		var pred := w.nm(EcoPred.ID) if w else Species.called(EcoPred.ID)
		return "Гул %s заглушает двигатели — %s не слышит корабль" % [organ, pred]
