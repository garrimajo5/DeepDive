extends TestCase
## Ключи по глубине одной функцией (#764): `HashNoise.keyed`/`key_at` вместо трёх копий в `IceSheet.row`,
## `Seabed.Water._num`/`_at` и `WaterGlints.strength`. Числа — те же, что у прежних копий (они ниже как образец).

const T := [[0.0, 1.0, 10.0], [10.0, 3.0, 20.0], [30.0, 0.0, 40.0]]


func test_keyed_inside_and_edges() -> void:
	eq(HashNoise.keyed(T, -5.0), 1.0, "до первого ключа — первое значение")
	eq(HashNoise.keyed(T, 0.0), 1.0, "на первом ключе")
	eq(HashNoise.keyed(T, 5.0), 2.0, "между ключами — линейно")
	eq(HashNoise.keyed(T, 10.0), 3.0, "на среднем ключе")
	eq(HashNoise.keyed(T, 20.0), 1.5, "второй отрезок")
	eq(HashNoise.keyed(T, 30.0), 0.0, "на последнем ключе")
	eq(HashNoise.keyed(T, 99.0), 0.0, "за последним — последнее")
	eq(HashNoise.keyed(T, 20.0, 2), 30.0, "другой столбец")
	eq(HashNoise.keyed(T, 99.0, 2), 40.0, "другой столбец за краем")
	eq(HashNoise.keyed(T, 99.0, 1, 7.0), 7.0, "за последним — `after`")
	eq(HashNoise.keyed(T, 30.0, 1, 7.0), 0.0, "на последнем ключе `after` не действует")
	eq(HashNoise.keyed(T, -5.0, 1, 7.0), 1.0, "до первого `after` не действует")
	eq(HashNoise.key_at(T, -1.0), [0, 0.0], "ключ до таблицы")
	eq(HashNoise.key_at(T, 20.0), [1, 0.5], "ключ внутри")
	eq(HashNoise.key_at(T, 50.0), [1, 1.0], "ключ за таблицей")


## Прежние три копии — числа должны совпасть точно на всём диапазоне глубин.
static func _old_row(depth: float) -> float:
	var d := clampf(depth, 0.0, 90.0)
	for i in range(1, IceSheet.ROW_KEYS.size()):
		var a: Array = IceSheet.ROW_KEYS[i - 1]
		var b: Array = IceSheet.ROW_KEYS[i]
		if d <= b[0]:
			return lerpf(a[1], b[1], (d - a[0]) / (b[0] - a[0]))
	return 15.0


static func _old_water(depth: float, col: int) -> float:
	var K: Array = Seabed.Water.KEYS
	var d := clampf(depth, K[0][0], K[K.size() - 1][0])
	for i in K.size() - 1:
		if d <= K[i + 1][0]:
			return lerpf(K[i][col], K[i + 1][col], (d - K[i][0]) / (K[i + 1][0] - K[i][0]))
	return lerpf(K[K.size() - 2][col], K[K.size() - 1][col], 1.0)


static func _old_glints(depth: float) -> float:
	var K: Array = WaterGlints.KEYS
	if depth <= K[0][0]:
		return K[0][1]
	for i in K.size() - 1:
		if depth <= K[i + 1][0]:
			return lerpf(K[i][1], K[i + 1][1], (depth - K[i][0]) / (K[i + 1][0] - K[i][0]))
	return 0.0


func test_same_numbers_as_before() -> void:
	var bad := 0
	for n in range(-40, 1700):
		var d := n * 0.1
		if IceSheet.row(d) != _old_row(d):
			bad += 1
		if WaterGlints.strength(d) != _old_glints(d):
			bad += 1
		for col in range(2, 6):
			if Seabed.Water._num(d, col) != _old_water(d, col):
				bad += 1
	eq(bad, 0, "лёд, вода и блики — те же числа от −4 до 170 м")
	eq(IceSheet.row(200.0), 15.0, "лёд глубже 90 м — строка 15")
	eq(WaterGlints.strength(200.0), 0.0, "блики глубже — нет")
	eq(Seabed.Water.fog_density(500.0), 0.0235, "вода глубже 120 м — как на 120")
