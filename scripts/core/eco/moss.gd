class_name EcoMoss
extends EcoSystem
## Пятна светящегося мха — еда скребунов (W.patches в js/world.js, Unity `Core/EcoMoss.cs`). 22 пятна на дне на тех же
## местах, что в браузере. У пятна есть еда Patch.food от 0 до 1: она всё время отрастает на 0,012 в секунду (от нуля
## до полного — 83 с), скребун на пятне съедает 0,05 в секунду. Яркость пятна glow() — 0,15 у объеденного, 1 у нетронутого.
## Модуль подключают в мир раньше скребунов.

## Сколько еды отрастает за секунду.
const REGROW := 0.012
## Яркость объеденного пятна.
const MIN_GLOW := 0.15
## Размер пятна (м): квадрат 7 × 7, светится круг радиусом до 3,4 м.
const SIZE := 7.0
const RADIUS := 3.4

## Места пятен: placeMany(22, −10, 30, 170, −56, −12, 18) из js/world.js — числа браузерной версии (в Unity x со знаком
## минус), y — дно в этой точке. Первые восемь — те же пятна, у которых лежат образцы мха (задача потока А про образцы).
const SPOTS: Array[Vector3] = [
	Vector3(30.8309, -37.6724, 94.4369),
	Vector3(-25.4157, -35.7588, -79.7119),
	Vector3(-112.4688, -41.8346, 74.6209),
	Vector3(-43.2558, -43.8208, 34.7669),
	Vector3(-24.8791, -51.2604, 173.5895),
	Vector3(109.8195, -34.7911, -20.3002),
	Vector3(18.7095, -44.7823, 22.6775),
	Vector3(116.9517, -39.6591, -47.6367),
	Vector3(-165.5336, -40.6051, -25.1137),
	Vector3(-140.0866, -49.3867, 108.3999),
	Vector3(-20.0083, -41.8121, -46.8639),
	Vector3(-97.8924, -34.3003, 37.5374),
	Vector3(6.2860, -43.1480, -23.6787),
	Vector3(-118.4317, -45.1394, 95.0969),
	Vector3(-37.5094, -43.0731, -11.6377),
	Vector3(-64.0230, -41.8639, -119.1368),
	Vector3(-100.9378, -37.6128, -93.3913),
	Vector3(78.8336, -38.8845, -57.8510),
	Vector3(-39.3468, -43.5194, -52.0988),
	Vector3(0.0778, -37.9034, -127.1762),
	Vector3(71.2277, -34.6013, 78.1338),
	Vector3(-119.3342, -31.9155, 16.7775),
]


## Пятно мха.
class Patch:
	extends RefCounted
	var index := 0
	## Середина пятна на дне.
	var pos := Vector3.ZERO
	## Еда: 0 — объедено, 1 — нетронуто.
	var food := 1.0

	## Яркость пятна (mossAlpha).
	func glow() -> float:
		return EcoMoss.glow_of(food)


var patches: Array[Patch] = []

var _spots: Array[Vector3]
var _rnd: EcoRandom


## spots — свои места пятен (для тестов); пусто — места из браузера.
func _init(spots: Array[Vector3] = []) -> void:
	_spots = spots if not spots.is_empty() else SPOTS


## Своё зерно мха: от зерна мира, остальные виды не сдвигаются.
static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 7002) & 0xFFFFFFFF


## Яркость пятна по еде: 0,15 у объеденного, 1 у нетронутого.
static func glow_of(food: float) -> float:
	return MIN_GLOW + (1.0 - MIN_GLOW) * clampf(food, 0.0, 1.0)


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	patches.clear()
	for i in _spots.size():
		var p := Patch.new()
		p.index = i
		p.pos = _spots[i]
		p.food = _rnd.range_f(0.6, 1.0)
		patches.append(p)


func step(_world: EcoWorld, dt: float) -> void:
	for p in patches:
		p.food = minf(1.0, p.food + dt * REGROW)


## Съесть с пятна amount еды (не ниже нуля).
static func eat(p: Patch, amount: float) -> void:
	p.food = maxf(0.0, p.food - amount)


## Ближайшее пятно по горизонтали не дальше radius (null — нет).
func nearest(pos: Vector3, radius: float = INF) -> Patch:
	var best: Patch = null
	var bd := radius
	for p in patches:
		var d := Vector2(p.pos.x - pos.x, p.pos.z - pos.z).length()
		if d <= bd:
			bd = d
			best = p
	return best
