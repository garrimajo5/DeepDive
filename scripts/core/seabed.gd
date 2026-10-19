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


## Вода по глубине (updateEnv в js/game.js): у льда бирюзовая, к 95 м тёмная, туман гуще.
class Water:
	const SHALLOW := Color8(0x1a, 0x66, 0x76)
	const DEEP := Color8(0x04, 0x1a, 0x22)

	## 0 у льда (до 8 м), 1 на глубине 95 м и ниже.
	static func k(depth: float) -> float:
		return HashNoise.smooth(8.0, 95.0, depth)

	static func fog_density(depth: float) -> float:
		return 0.015 + 0.01 * k(depth)

	static func ambient(depth: float) -> float:
		return 0.95 - 0.55 * k(depth)

	static func sun(depth: float) -> float:
		return 0.55 - 0.4 * k(depth)

	static func fog_color(depth: float) -> Color:
		return SHALLOW.lerp(DEEP, k(depth))
