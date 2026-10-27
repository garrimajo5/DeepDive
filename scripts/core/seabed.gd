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


## Высота сетки дна (build_arrays, клетка SIZE / SEGMENTS) под (x, z): та, что видно, — между вершинами линейно по
## треугольникам клетки (диагональ от (x0 + шаг, z0) к (x0, z0 + шаг)). Вне карты — по ближней клетке.
static func mesh_height(x: float, z: float) -> float:
	var step := SIZE / SEGMENTS
	var half := SIZE / 2.0
	var i := clampf(floor((x + half) / step), 0.0, SEGMENTS - 1.0)
	var j := clampf(floor((z + half) / step), 0.0, SEGMENTS - 1.0)
	var x0 := -half + i * step
	var z0 := -half + j * step
	var a := (x - x0) / step
	var b := (z - z0) / step
	var h10 := height(x0 + step, z0)
	var h01 := height(x0, z0 + step)
	if a + b <= 1.0:
		var h00 := height(x0, z0)
		return h00 + (h10 - h00) * a + (h01 - h00) * b
	var h11 := height(x0 + step, z0 + step)
	return h11 + (h01 - h11) * (1.0 - a) + (h10 - h11) * (1.0 - b)


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
		return HashNoise.key_at(KEYS, depth)

	static func _num(depth: float, col: int) -> float:
		return HashNoise.keyed(KEYS, depth, col)

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


## Декали дна по ART-066 (`docs/concept-art/dekali-dna.md`): атлас 4×4 (следы, вмятины, ил, ракушечник, мох; разряды —
## ячейки 13–15, в фон не идут) проекцией world.xz в материал дна (`shaders/seabed.gdshader`, без новых вызовов).
## Два слоя клеток 4 × 4 м (второй сдвинут на полклетки): в клетке слоя — не больше одного штампа. Шейдер считает то же
## целочисленным хешем `HashNoise.hash2` — места штампов здесь и там совпадают.
class Marks:
	const ATLAS := "res://textures/dno/dekali.png"
	const CELL := 4.0                     ## клетка, м
	const LAYERS := 2                     ## слоёв клеток (ART-066 — один; плотность поднята при встройке)
	const ACCEPT := 0.72                  ## доля клеток со штампом
	const SIZE := Vector2(1.55, 2.4)      ## сторона квадрата штампа, м
	const JITTER := 0.2                   ## сдвиг центра, ± м
	const STRENGTH := 0.85                ## сила множителя
	const FADE := Vector2(10.0, 45.0)     ## гаснут, м от камеры
	const SLOPE := Vector2(0.30, 0.48)    ## уклон (1 − ny), на котором гаснут
	const TRACK_NY := Vector2(0.82, 0.96) ## следы — только на ровном
	const MOSS_EDGE := Vector2(0.48, 0.68)
	const EDGE := 0.07                    ## края квадрата гаснут в пустом поле ячейки (20 px из 256 ≈ 0,078)
	## «Экономно» (ART-044): один слой, реже и ближе.
	const LITE_ACCEPT := 0.36
	const LITE_FADE := Vector2(6.0, 25.0)
	## Категории фона: верхняя граница доли, первая ячейка, сколько ячеек.
	const CATS := [[0.27, 0, 4], [0.40, 4, 2], [0.67, 6, 3], [0.85, 9, 2], [1.0, 11, 2]]
	enum Cat { TRACK, DENT, SILT, SHELL, MOSS }
	const SCORCH := [13, 14, 15]          ## разряды — только по событию, не в фоне

	## Хеш клетки (как dhash в шейдере): k — номер числа, у слоя свои 8.
	static func h(ix: int, iz: int, k: int) -> float:
		return HashNoise.hash2(ix + 9973 * k, iz - 7919 * k)

	## Сдвиг сетки слоя, м.
	static func offset(layer: int) -> float:
		return CELL * 0.5 if layer == 1 else 0.0

	## Кандидат клетки слоя, в которую попала точка: {cell, accept, centre, rot, size, cat, index}.
	static func candidate(x: float, z: float, layer: int, accept: float = ACCEPT) -> Dictionary:
		var o := offset(layer)
		var ix := int(floorf((x - o) / CELL))
		var iz := int(floorf((z - o) / CELL))
		var b := layer * 8
		var pick := h(ix, iz, b + 5)
		var cat := 0
		while pick >= CATS[cat][0] and cat < CATS.size() - 1:
			cat += 1
		var index: int = CATS[cat][1] + mini(int(floorf(h(ix, iz, b + 6) * CATS[cat][2])), CATS[cat][2] - 1)
		return {
			"cell": Vector2i(ix, iz),
			"accept": h(ix, iz, b) < accept,
			"centre": Vector2((ix + 0.5) * CELL + o + (h(ix, iz, b + 1) - 0.5) * 2.0 * JITTER,
					(iz + 0.5) * CELL + o + (h(ix, iz, b + 2) - 0.5) * 2.0 * JITTER),
			"rot": h(ix, iz, b + 3) * TAU,
			"size": lerpf(SIZE.x, SIZE.y, h(ix, iz, b + 4)),
			"cat": cat,
			"index": index,
		}

	## Координаты точки в квадрате штампа 0…1 (вне квадрата — за пределами 0…1).
	static func stamp_uv(x: float, z: float, c: Dictionary) -> Vector2:
		var q: Vector2 = Vector2(x, z) - c.centre
		var cs: float = cos(c.rot)
		var sn: float = sin(c.rot)
		return Vector2(cs * q.x + sn * q.y, -sn * q.x + cs * q.y) / c.size + Vector2(0.5, 0.5)

	## UV в атласе: ячейка index (слева направо, сверху вниз), точка st в ней.
	static func atlas_uv(index: int, st: Vector2) -> Vector2:
		return (Vector2(index % 4, floorf(index / 4.0)) + st) / 4.0

	## Где лежит категория: веса грунта [песок, ил, галька], y нормали, точка (мох — по маске мха).
	static func habitat(cat: int, w: Array, ny: float, x: float, z: float) -> float:
		match cat:
			Cat.TRACK:
				return (w[0] + w[1]) * HashNoise.smooth(TRACK_NY.x, TRACK_NY.y, ny)
			Cat.DENT:
				return w[0] + w[1]
			Cat.SILT:
				return minf(0.3 * w[0] + w[1], 1.0)
			Cat.SHELL:
				return minf(0.35 * w[0] + w[2], 1.0)
		return HashNoise.smooth(MOSS_EDGE.x, MOSS_EDGE.y, HashNoise.value(x * 0.03 + 7.0, z * 0.03))

	## Затухание: вдали и на уклоне.
	static func fade(dist: float, ny: float, lite: bool = false) -> float:
		var f: Vector2 = LITE_FADE if lite else FADE
		return (1.0 - HashNoise.smooth(f.x, f.y, dist)) * (1.0 - HashNoise.smooth(SLOPE.x, SLOPE.y, 1.0 - ny))

	## Штампы, которые накрывают точку: [{index, st, cat}] по слоям (обычно 0–1).
	static func at(x: float, z: float, lite: bool = false) -> Array:
		var out := []
		for layer in (1 if lite else LAYERS):
			var c := candidate(x, z, layer, LITE_ACCEPT if lite else ACCEPT)
			if not c.accept:
				continue
			var st := stamp_uv(x, z, c)
			if st.x > 0.0 and st.y > 0.0 and st.x < 1.0 and st.y < 1.0:
				out.append({"index": c.index, "st": st, "cat": c.cat, "layer": layer})
		return out


## Следы разрядов ART-066 (ячейки атласа 13–15): штамп на дне под кораблём после настоящего разряда у дна.
## Сила 0…1 на событие — по зазору под корпусом и доле «Разряд»; держатся последние MAX до нового забега, свежий
## («разряд А» или «Б») за OLD с темнеет в «старое пятно». Шейдер дна читает uniform-массивы `uniforms(t)`.
class Scorch:
	const MAX := 4                        ## сколько последних держит материал дна
	const REACH := Vector2(2.0, 10.0)     ## зазор под корпусом (над CLEARANCE), м: до x — полная сила, к y — нет следа
	const MIN_K := 0.1                    ## слабее — следа нет
	const SIZE := Vector2(2.4, 4.0)       ## сторона квадрата штампа, м (по силе)
	const OLD := Vector2(40.0, 120.0)     ## свежий → «старое пятно», с после разряда
	const OLD_K := 0.75                   ## старое пятно бледнее свежего
	const FRESH := [13, 14]               ## разряды А и Б — по очереди
	const STALE := 15                     ## старое пятно

	## [{at: Vector2 xz, rot, size, k, index, t}] — от старых к новым.
	var all: Array = []
	var count := 0                        ## разрядов у дна за забег (выбирает А/Б и поворот)

	## Сила следа: зазор от низа корпуса до дна gap (м, CLEARANCE уже вычтен), доля «Разряд» share 0…1.
	static func strength(gap: float, share: float) -> float:
		var k := (1.0 - HashNoise.smooth(REACH.x, REACH.y, gap)) * clampf(share, 0.0, 1.0)
		return k if k >= MIN_K else 0.0

	## Разряд в момент t: корабль в ship, дно под ним на floor_y, доля share. Возвращает, лёг ли след.
	func add(ship: Vector3, floor_y: float, share: float, t: float) -> bool:
		var k := strength(ship.y - floor_y - Helm.Ship.CLEARANCE, share)
		if k <= 0.0:
			return false
		all.append({"at": Vector2(ship.x, ship.z), "rot": HashNoise.hash2(count, 61) * TAU,
			"size": lerpf(SIZE.x, SIZE.y, k), "k": k, "index": FRESH[count % FRESH.size()], "t": t})
		count += 1
		if all.size() > MAX:
			all.pop_front()
		return true

	func clear() -> void:
		all.clear()
		count = 0

	## Доля «старого пятна» у следа s в момент t (0 — свежий, 1 — старый).
	static func old(s: Dictionary, t: float) -> float:
		return HashNoise.smooth(OLD.x, OLD.y, t - float(s.t))

	## Для шейдера: [где (x, z, поворот, размер), сила (k, ячейка, доля старого, 0)] по MAX; пустые — сила 0.
	func uniforms(t: float) -> Array:
		var at := PackedVector4Array()
		var kk := PackedVector4Array()
		for i in MAX:
			if i < all.size():
				var s: Dictionary = all[i]
				var o := old(s, t)
				at.append(Vector4(s.at.x, s.at.y, s.rot, s.size))
				kk.append(Vector4(s.k * lerpf(1.0, OLD_K, o), s.index, o, 0.0))
			else:
				at.append(Vector4(0.0, 0.0, 0.0, 1.0))
				kk.append(Vector4.ZERO)
		return [at, kk]

	## Следы, которые накрывают точку: [{index, st, k, old}] (двойник шейдера для тестов).
	func at_point(x: float, z: float, t: float) -> Array:
		var out := []
		for s: Dictionary in all:
			var st := Marks.stamp_uv(x, z, {"centre": s.at, "rot": s.rot, "size": s.size})
			if st.x > 0.0 and st.y > 0.0 and st.x < 1.0 and st.y < 1.0:
				out.append({"index": s.index, "st": st, "k": s.k, "old": old(s, t)})
		return out
