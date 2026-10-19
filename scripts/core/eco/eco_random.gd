class_name EcoRandom
extends RefCounted
## Случай по зерну — mulberry32 из js/util.js, число в число: при одном зерне те же значения, что G.rng() в браузере
## (Unity `Core/EcoRandom.cs`). Зерно мира — 20261018; новый вид берёт своё зерно (как G.seed(7031) в js/creatures.js),
## чтобы не перетасовывать остальной мир. Целые в GDScript 64-битные: держим 32 бита маской, умножаем по половинкам.

const WORLD_SEED := 20261018
const _M := 0xFFFFFFFF

## Внутреннее состояние: по нему можно продолжить ту же последовательность.
var state: int = WORLD_SEED


func _init(seed_value: int = WORLD_SEED) -> void:
	state = seed_value & _M


## Произведение по модулю 2^32 (Math.imul без знака): без переполнения 64-битного целого.
static func _mul32(a: int, b: int) -> int:
	var lo := a * (b & 0xFFFF)
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & _M


## Число от 0 (включительно) до 1 (G.rng).
func next() -> float:
	state = (state + 0x6D2B79F5) & _M
	var t := _mul32(state ^ (state >> 15), 1 | state)
	t = ((t + _mul32(t ^ (t >> 7), 61 | t)) & _M) ^ t
	return float(t ^ (t >> 14)) / 4294967296.0


## Число от lo до hi (G.rr).
func range_f(lo: float, hi: float) -> float:
	return lo + (hi - lo) * next()


## Целое от 0 до n − 1.
func index(n: int) -> int:
	if n <= 0:
		return 0
	return mini(n - 1, int(floor(next() * n)))


## Случайный элемент (G.pick).
func pick(items: Array) -> Variant:
	return items[index(items.size())]


## Истина с вероятностью p.
func chance(p: float) -> bool:
	return next() < p
