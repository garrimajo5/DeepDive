class_name HashNoise
## Шум как в браузерной версии (js/util.js: G.noise, G.fbm): тот же хеш на целочисленной
## решётке и те же числа до знаков после запятой. Оси Godot совпадают с браузерными (three.js), x не меняет знак.

const MASK := 0xFFFFFFFF


## Хеш узла решётки (hash2 из util.js): 32-битная арифметика как Math.imul.
## Множитель меньше 2^31, а h — меньше 2^32: произведение меньше 2^63 и в 64-битном int не переполняется, поэтому
## `(h * MUL) & MASK` — то же, что Math.imul, без разбора на половины (шаг мира зовёт дно ~50 раз за кадр, `value` —
## 4 хеша, `fbm` — 4 `value`: прежнее умножение по 16 бит было половиной времени `Seabed.height`).
const MUL := 1274126177


static func hash2(ix: int, iz: int) -> float:
	var h: int = (ix * 374761393 + iz * 668265263) & MASK
	h = ((h ^ (h >> 13)) * MUL) & MASK
	h ^= h >> 16
	return float(h) / 4294967295.0


## Гладкий шум 0..1 (G.noise).
static func value(x: float, z: float) -> float:
	var fx0 := floorf(x)
	var fz0 := floorf(z)
	var ix := int(fx0)
	var iz := int(fz0)
	var fx := x - fx0
	var fz := z - fz0
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uz := fz * fz * (3.0 - 2.0 * fz)
	# четыре узла — hash2 без вызова функции (то же число): строки hash2 — на каждый узел
	var h0: int = (ix * 374761393 + iz * 668265263) & MASK
	var h1: int = (h0 + 374761393) & MASK
	var h2: int = (h0 + 668265263) & MASK
	var h3: int = (h1 + 668265263) & MASK
	h0 = ((h0 ^ (h0 >> 13)) * MUL) & MASK
	h1 = ((h1 ^ (h1 >> 13)) * MUL) & MASK
	h2 = ((h2 ^ (h2 >> 13)) * MUL) & MASK
	h3 = ((h3 ^ (h3 >> 13)) * MUL) & MASK
	var a := float(h0 ^ (h0 >> 16)) / 4294967295.0
	var b := float(h1 ^ (h1 >> 16)) / 4294967295.0
	var c := float(h2 ^ (h2 >> 16)) / 4294967295.0
	var d := float(h3 ^ (h3 >> 16)) / 4294967295.0
	return a + (b - a) * ux + (c - a) * uz + (a - b - c + d) * ux * uz


## Сумма октав (G.fbm).
static func fbm(x: float, z: float, oct: int) -> float:
	var s := 0.0
	var amp := 0.5
	var f := 1.0
	var n := 0.0
	for i in oct:
		s += amp * value(x * f + i * 17.3, z * f - i * 9.1)
		n += amp
		amp *= 0.5
		f *= 2.0
	return s / n


## G.smooth: плавный шаг от e0 к e1 (e1 может быть меньше e0).
static func smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Ключ таблицы `[[x, значение…], …]` (x по возрастанию) и доля до следующего: [i, t]; x зажат в края таблицы.
static func key_at(table: Array, x: float) -> Array:
	var d := clampf(x, table[0][0], table[table.size() - 1][0])
	for i in table.size() - 1:
		if d <= table[i + 1][0]:
			return [i, (d - table[i][0]) / (table[i + 1][0] - table[i][0])]
	return [table.size() - 2, 1.0]


## Кусочно-линейно по таблице ключей (столбец `col`): до первого ключа — его значение, за последним — значение
## последнего или `after`, если задано (не NAN). Таблицы по глубине (лёд, вода, блики, слои глубже) — через неё.
static func keyed(table: Array, x: float, col := 1, after := NAN) -> float:
	if not is_nan(after) and x > table[table.size() - 1][0]:
		return after
	var a := key_at(table, x)
	return lerpf(table[a[0]][col], table[a[0] + 1][col], a[1])
