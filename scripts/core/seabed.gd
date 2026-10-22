class_name Seabed
## Отмель «Подлёдный сад»: рельеф как W.height в js/world.js — плато вокруг рифа, гряды,
## склон в глубину на востоке (+X) и скальные стены по краям карты. Лёд — на y = 0.

const SIZE := 700.0      ## сторона карты, м
const SEGMENTS := 140    ## клеток на сторону (141×141 вершин, ~39 тыс. треугольников)
const TOP := -7.0        ## выше дно не поднимается
const ICE_Y := 0.0


## Высота дна под точкой (x, z).
static func height(x: float, z: float) -> float:
	var n := HashNoise.fbm(x * 0.006, z * 0.006, 4)
	var h := -64.0 + (n - 0.5) * 34.0
	var r := sqrt((x + 10.0) * (x + 10.0) + (z + 10.0) * (z + 10.0))
	var plat := HashNoise.smooth(250.0, 110.0, r)
	h += plat * 25.0
	var rn := HashNoise.value(x * 0.028 + 3.1, z * 0.028 - 1.7)
	var ridge := 1.0 - absf(rn * 2.0 - 1.0)
	h += ridge * ridge * ridge * 9.0 * plat
	h -= HashNoise.smooth(150.0, 240.0, x) * 55.0
	var e := maxf(absf(x), absf(z))
	h += HashNoise.smooth(285.0, 345.0, e) * 80.0
	h += (HashNoise.value(x * 0.13, z * 0.13) - 0.5) * 1.4
	return minf(h, TOP)


## Цвет дна (js/world.js): песок, на крутых склонах скала, пятнами мох, в глубине темнеет. ny — y нормали.
static func color_at(x: float, y: float, z: float, ny: float) -> Color:
	var k := clampf((1.0 - ny) * 3.2, 0.0, 1.0)
	var c := Color(lerpf(0.80, 0.42, k), lerpf(0.74, 0.28, k), lerpf(0.60, 0.48, k))
	var m := HashNoise.smooth(0.55, 0.8, HashNoise.value(x * 0.03 + 7.0, z * 0.03)) * 0.7
	c = c.lerp(Color(0.20, 0.48, 0.44), m)
	var d := HashNoise.smooth(-55.0, -110.0, y)
	c = c.lerp(Color(0.08, 0.13, 0.22), d)
	var v := 0.82 + HashNoise.value(x * 0.4, z * 0.4) * 0.3
	return Color(c.r * v, c.g * v, c.b * v)


## Сетка дна: массивы для ArrayMesh (вершины, нормали, цвета, индексы), лицевая сторона вверх.
static func build_arrays(segments: int = SEGMENTS, size: float = SIZE) -> Array:
	var n := segments + 1
	var step := size / segments
	var half := size / 2.0
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			hs[j * n + i] = height(-half + i * step, -half + j * step)
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	pos.resize(n * n)
	nor.resize(n * n)
	col.resize(n * n)
	for j in n:
		for i in n:
			var v := j * n + i
			var x := -half + i * step
			var z := -half + j * step
			var y := hs[v]
			var il := maxi(i - 1, 0)
			var ir := mini(i + 1, n - 1)
			var jd := maxi(j - 1, 0)
			var ju := mini(j + 1, n - 1)
			var dx := (hs[j * n + ir] - hs[j * n + il]) / ((ir - il) * step)
			var dz := (hs[ju * n + i] - hs[jd * n + i]) / ((ju - jd) * step)
			var nn := Vector3(-dx, 1.0, -dz).normalized()
			pos[v] = Vector3(x, y, z)
			nor[v] = nn
			col[v] = color_at(x, y, z, nn.y)
	var idx := PackedInt32Array()
	idx.resize(segments * segments * 6)
	var t := 0
	for j in segments:
		for i in segments:
			var v := j * n + i
			# Godot: лицевая сторона — обход по часовой стрелке, если смотреть на неё (сверху)
			idx[t] = v; idx[t + 1] = v + 1; idx[t + 2] = v + n
			idx[t + 3] = v + 1; idx[t + 4] = v + n + 1; idx[t + 5] = v + n
			t += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nor
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


## Вода по глубине по ART-059 (`docs/concept-art/voda-glubina.md`, ключи `voda-glubina.json`): конечные значения
## тумана, рассеянного света, солнца сквозь лёд и экспозиции ACES — `OceanView.apply_water` ставит их как есть.
## Между ключами — линейно (цвет — в линейном свете), ниже 120 м — как на 120 м.
class Water:
	## [глубина, цвет тумана, плотность, рассеянный, солнце, экспозиция]
	const KEYS := [
		[0.0, Color8(0x3A, 0x81, 0x90), 0.008, 0.70, 0.65, 0.84],
		[5.0, Color8(0x2E, 0x76, 0x87), 0.009, 0.64, 0.60, 0.85],
		[8.0, Color8(0x28, 0x6B, 0x80), 0.010, 0.58, 0.52, 0.86],
		[15.0, Color8(0x20, 0x53, 0x6F), 0.0115, 0.43, 0.39, 0.885],
		[20.0, Color8(0x1A, 0x46, 0x67), 0.013, 0.36, 0.31, 0.90],
		[30.0, Color8(0x14, 0x37, 0x53), 0.0155, 0.25, 0.18, 0.92],
		[45.0, Color8(0x0D, 0x29, 0x43), 0.018, 0.16, 0.085, 0.94],
		[60.0, Color8(0x09, 0x1E, 0x34), 0.0195, 0.10, 0.04, 0.955],
		[90.0, Color8(0x05, 0x13, 0x1F), 0.022, 0.045, 0.012, 0.98],
		[120.0, Color8(0x04, 0x0D, 0x17), 0.0235, 0.025, 0.005, 0.98],
	]

	## 0 у льда (до 8 м), 1 на глубине 95 м и ниже (каустики дна, прежняя кривая).
	static func k(depth: float) -> float:
		return HashNoise.smooth(8.0, 95.0, depth)

	## Ключ и доля до следующего: [i, t].
	static func _at(depth: float) -> Array:
		var d := clampf(depth, KEYS[0][0], KEYS[KEYS.size() - 1][0])
		for i in KEYS.size() - 1:
			if d <= KEYS[i + 1][0]:
				return [i, (d - KEYS[i][0]) / (KEYS[i + 1][0] - KEYS[i][0])]
		return [KEYS.size() - 2, 1.0]

	static func _num(depth: float, col: int) -> float:
		var a := _at(depth)
		return lerpf(KEYS[a[0]][col], KEYS[a[0] + 1][col], a[1])

	static func fog_density(depth: float) -> float:
		return _num(depth, 2)

	static func ambient(depth: float) -> float:
		return _num(depth, 3)

	static func sun(depth: float) -> float:
		return _num(depth, 4)

	static func exposure(depth: float) -> float:
		return _num(depth, 5)

	static func fog_color(depth: float) -> Color:
		var a := _at(depth)
		var c0: Color = KEYS[a[0]][1]
		var c1: Color = KEYS[a[0] + 1][1]
		return c0.srgb_to_linear().lerp(c1.srgb_to_linear(), a[1]).linear_to_srgb()

	## Свет каустик на дне — прежняя кривая (ART-059: лучи и каустики не усиливать и не ослаблять заново).
	static func caustic(depth: float) -> float:
		return 0.55 - 0.4 * k(depth)


## Грунты дна по ART-060 (`docs/concept-art/dno-grunty.md`): песок, ил и галька — карты 2 × 2 м поверх `color_at`
## в материале дна (`shaders/seabed.gdshader`, один вызов). Веса грунтов, затухания и базис нормалей — здесь;
## шейдер считает то же тем же хешем, что `HashNoise` (до точности float).
class Ground:
	const TEX := "res://textures/dno/%s-%s.png"   ## грунт (pesok, il, galka), карта (tsvet, normali, orm)
	const KINDS := ["pesok", "il", "galka"]
	const MAPS := ["tsvet", "normali", "orm"]
	const TILE := 2.0                              ## плитка, м: uv = world.xz / TILE
	const OFFSET := [Vector2(0.0, 0.0), Vector2(0.37, 0.71), Vector2(0.63, 0.19)]   ## свой сдвиг UV у грунта
	const NORMAL_K := [0.42, 0.25, 0.55]           ## сила нормалей: песок, ил, галька
	const NORMAL_FADE := Vector2(8.0, 35.0)        ## нормали гаснут, м от камеры
	const COLOR_FADE := Vector2(12.0, 55.0)        ## цвет деталей гаснет, м
	const BUMP := 0.12                             ## прежний процедурный микрорельеф — слабее
	const SILT_SCALE := 0.075                      ## ил — карманы по шуму, 1/м
	const SILT_EDGE := Vector2(0.48, 0.62)
	const PEBBLE_SCALE := 0.11                     ## галька — пятна шума, 1/м
	const PEBBLE_EDGE := Vector2(0.45, 0.62)
	const STEEP := Vector2(0.42, 0.65)             ## уклон (1 − ny), на котором детали уходят в скалу

	## Веса [песок, ил, галька] ≥ 0, сумма 1. ny — y нормали, depth — глубина дна под льдом, м.
	static func weights(x: float, z: float, ny: float, depth: float) -> Array:
		var s := 1.0 - ny
		var n_silt := HashNoise.fbm(x * SILT_SCALE + 7.0, z * SILT_SCALE + 7.0, 2)
		var band := HashNoise.smooth(10.0, 18.0, depth) * (1.0 - HashNoise.smooth(55.0, 75.0, depth))
		var silt := HashNoise.smooth(SILT_EDGE.x, SILT_EDGE.y, n_silt) * (0.35 + 0.65 * band) \
				* HashNoise.smooth(0.80, 0.98, ny)
		var spot := HashNoise.value(x * PEBBLE_SCALE + 31.0, z * PEBBLE_SCALE - 5.0)
		var slope_band := HashNoise.smooth(0.08, 0.16, s) * (1.0 - HashNoise.smooth(0.36, 0.46, s))
		var pebble := maxf(slope_band * HashNoise.smooth(0.25, 0.45, spot),
				0.7 * HashNoise.smooth(PEBBLE_EDGE.x, PEBBLE_EDGE.y, spot))
		silt *= 1.0 - pebble
		return [1.0 - silt - pebble, silt, pebble]

	## Сила деталей на склоне: на крутом остаётся скальный цвет.
	static func detail_k(ny: float) -> float:
		return 1.0 - HashNoise.smooth(STEEP.x, STEEP.y, 1.0 - ny)

	static func normal_fade(dist: float) -> float:
		return 1.0 - HashNoise.smooth(NORMAL_FADE.x, NORMAL_FADE.y, dist)

	static func color_fade(dist: float) -> float:
		return 1.0 - HashNoise.smooth(COLOR_FADE.x, COLOR_FADE.y, dist)

	## Цвет: vertex_color · mix(1, 2·tsvet, k) — карта даёт отклонение от 50 % серого.
	static func tint(base: Color, tsvet: Color, k: float) -> Color:
		return Color(base.r * lerpf(1.0, 2.0 * tsvet.r, k), base.g * lerpf(1.0, 2.0 * tsvet.g, k),
				base.b * lerpf(1.0, 2.0 * tsvet.b, k))

	## Мировой базис нормалей: T — +X на поверхность, B = N × T (на ровном дне к −Z), +Y карты — к −Z мира.
	static func basis(n: Vector3) -> Basis:
		var t := (Vector3.RIGHT - n * n.dot(Vector3.RIGHT)).normalized()
		return Basis(t, n.cross(t), n)

	## UV грунта kind в точке мира.
	static func uv(x: float, z: float, kind: int) -> Vector2:
		return Vector2(x, z) / TILE + OFFSET[kind]

	static func path(kind: int, map: int) -> String:
		return TEX % [KINDS[kind], MAPS[map]]
