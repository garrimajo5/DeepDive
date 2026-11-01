class_name SeabedStones
extends RefCounted
## Камни на дне — мелочь одним MultiMesh (`docs/grafika-plan.md`, этап 4 «MultiMesh для мелочи»): россыпь галек и
## булыжников вокруг корабля, у дна в луче прожектора видно объём, а не только карты грунта. Где лежат — хеш клетки
## CELL × CELL м (`HashNoise.hash2`, детерминированно, у гостя сети те же), гуще на гальке грунтов ART-060
## (`Seabed.Ground.weights`), редко на песке, тонут в иле, нет на крутом склоне и у образцов (`Samples` — светящиеся
## камешки не спутать с фоном). Клетки считаются не больше CELLS_STEP за шаг, ближние первыми, и кэшируются —
## ход корабля не даёт провала кадра. Список — камни в радиусе от центра (корабль), у края радиуса мельчают до нуля
## (не выскакивают). «Экономно» — радиус LITE_RADIUS (`lite`). Рисует `scripts/game/stones_view.gd` (`OceanView.stones`).

const CELL := 3.0              ## клетка, м
const PER_CELL := 3            ## кандидатов в клетке
const RADIUS := 40.0           ## радиус россыпи от центра, м
const LITE_RADIUS := 22.0      ## «Экономно»
const EDGE := 8.0              ## у края радиуса камни мельчают, м
const MOVE := 4.0              ## центр сдвинулся на столько — пересобрать список, м
const CELLS_STEP := 12         ## клеток за шаг, не больше
const JUMP := 15.0             ## центр перескочил дальше (старт, загрузка, возвращение к 10 под шторкой) — радиус сразу
const MAX := 1400              ## камней в списке, не больше (ёмкость MultiMesh)
const SIZE := Vector2(0.25, 1.1)    ## поперечник, м (видно с мостика в 5–15 м)
const SAND := 0.05             ## доля кандидатов на песке
const PEBBLE := 0.95           ## на гальке
const SILT := 0.25             ## на иле (сверху только крупные)
const STEEP_NY := 0.8          ## круче — нет камней (y нормали)
const SAMPLE_GAP := 1.6        ## до образца не ближе, м
const SINK := 0.2              ## доля высоты в грунте
const DARK := 0.45             ## камень темнее дна под ним
const TOP_Y := Seabed.TOP      ## дно не выше


class Stone:
	var pos := Vector3.ZERO
	var basis := Basis.IDENTITY   ## поворот и размер (без затухания у края)
	var size := 0.0
	var color := Color.WHITE


var lite := false
var avoid: Array[Vector3] = []   ## образцы на дне — камни вокруг не кладём
var list: Array[Stone] = []      ## камни в радиусе (для MultiMesh)
var scales: PackedFloat32Array = PackedFloat32Array()   ## доля размера у края радиуса, по list
var rev := 0                     ## растёт, когда list поменялся
var cells_done := 0              ## клеток посчитано всего (тесты)
var _cache := {}                 ## Vector2i → Array[Stone]
var _center := Vector3(INF, INF, INF)
var _dirty := true
var _full_at := Vector2i(1 << 30, 0)   ## клетка центра, у которой все клетки радиуса уже посчитаны
var _ahead := Vector2i(1 << 30, 0)     ## клетка будущего центра (`prefetch`): её клетки кэш не забывает


func radius() -> float:
	return LITE_RADIUS if lite else RADIUS


func set_lite(on: bool) -> void:
	if on != lite:
		lite = on
		_dirty = true
		_full_at = Vector2i(1 << 30, 0)


## Хеш клетки: k — номер числа.
static func h(ix: int, iz: int, k: int) -> float:
	return HashNoise.hash2(ix * 31 + 7717 * k + 13, iz * 17 - 3121 * k + 5)


static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(floorf(x / CELL)), int(floorf(z / CELL)))


## Доля кандидатов, что остаются камнем, по весам грунта [песок, ил, галька].
static func density(w: Array) -> float:
	return SAND * w[0] + SILT * w[1] + PEBBLE * w[2]


## y нормали дна около (x, z) — по высотам ±1 м.
static func ny_at(x: float, z: float) -> float:
	var dx := Seabed.height(x + 1.0, z) - Seabed.height(x - 1.0, z)
	var dz := Seabed.height(x, z + 1.0) - Seabed.height(x, z - 1.0)
	return Vector3(-dx, 2.0, -dz).normalized().y


## Камни клетки (ix, iz): всегда те же для тех же клетки и образцов.
func cell(ix: int, iz: int) -> Array[Stone]:
	var out: Array[Stone] = []
	var cx := (ix + 0.5) * CELL
	var cz := (iz + 0.5) * CELL
	var ny := ny_at(cx, cz)
	if ny < STEEP_NY:
		return out
	var cy := Seabed.height(cx, cz)
	var w := Seabed.Ground.weights(cx, cz, ny, -cy)
	var keep := density(w) * Seabed.Ground.detail_k(ny)
	for k in PER_CELL:
		var b := k * 8
		if h(ix, iz, b) >= keep:
			continue
		var x := (ix + h(ix, iz, b + 1)) * CELL
		var z := (iz + h(ix, iz, b + 2)) * CELL
		if _near_sample(x, z):
			continue
		var big := h(ix, iz, b + 3)
		# на иле остаются только крупные: мелкие ушли в муть
		if w[1] > 0.5 and big < 0.6:
			continue
		var s := Stone.new()
		s.size = lerpf(SIZE.x, SIZE.y, big * big)
		var flat := lerpf(0.55, 0.9, h(ix, iz, b + 4))
		var long := lerpf(0.8, 1.35, h(ix, iz, b + 5))
		var turn := Basis(Vector3.UP, h(ix, iz, b + 6) * TAU) * Basis(Vector3.RIGHT, (h(ix, iz, b + 7) - 0.5) * 0.5)
		s.basis = turn * Basis.from_scale(Vector3(long, flat, 1.0) * s.size)
		var y := Seabed.mesh_height(x, z)
		s.pos = Vector3(x, y - SINK * flat * s.size, z)
		var g := Seabed.color_at(x, y, z, ny)
		var v := DARK * lerpf(0.8, 1.2, h(ix, iz, b + 3) * 0.5 + h(ix, iz, b + 5) * 0.5)
		s.color = Color(g.r * v, g.g * v * 0.97, g.b * v * 0.95)
		out.append(s)
	return out


func _near_sample(x: float, z: float) -> bool:
	for p in avoid:
		if Vector2(p.x - x, p.z - z).length() < SAMPLE_GAP:
			return true
	return false


## Доля размера у края радиуса r на расстоянии d по горизонтали.
static func edge_k(d: float, r: float) -> float:
	return 1.0 - HashNoise.smooth(r - EDGE, r, d)


## Шаг: досчитать клетки у центра at (ближние первыми, не больше CELLS_STEP) и пересобрать список, если центр
## ушёл на MOVE или клетки добавились. true — list поменялся.
func update(at: Vector3) -> bool:
	var r := radius()
	var gap := Vector2(at.x - _center.x, at.z - _center.z).length()
	var moved := gap >= MOVE
	var budget := CELLS_STEP if gap < JUMP else 1 << 20
	var c := cell_of(at.x, at.z)
	if c == _full_at and not moved and not _dirty:
		return false   # стоим в той же клетке, всё посчитано — шаг почти даром
	var n := int(ceilf(r / CELL)) + 1
	var todo := _fill(at, budget)
	_full_at = c if todo.size() <= budget else Vector2i(1 << 30, 0)
	if not (moved or _dirty or not todo.is_empty()):
		return false
	_center = at
	_dirty = false
	_rebuild(c, n, r)
	return true


## Заранее досчитать клетки у будущего центра at, не больше budget за шаг (ближние первыми), список не трогать.
## Перескок под шторкой (возвращение к 10, #1090): клетки в кэше к прыжку — `update` тогда только пересобирает
## список, а не считает весь радиус в одном кадре. Клетки у этого места кэш не забывает (`_rebuild`). true — все
## клетки радиуса у at уже в кэше.
func prefetch(at: Vector3, budget := CELLS_STEP) -> bool:
	_ahead = cell_of(at.x, at.z)
	return _fill(at, budget).size() <= budget


## Клетки радиуса у at, которых нет в кэше ([расстояние, ключ], ближние первыми); первые budget посчитать.
func _fill(at: Vector3, budget: int) -> Array:
	var r := radius()
	var c := cell_of(at.x, at.z)
	var n := int(ceilf(r / CELL)) + 1
	var todo: Array = []
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var key := Vector2i(c.x + dx, c.y + dz)
			if _cache.has(key):
				continue
			var d := Vector2((key.x + 0.5) * CELL - at.x, (key.y + 0.5) * CELL - at.z).length()
			if d <= r + CELL:
				todo.append([d, key])
	if not todo.is_empty():
		todo.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(todo.size(), budget):
			var key: Vector2i = todo[i][1]
			_cache[key] = cell(key.x, key.y)
			cells_done += 1
	return todo


## Все ли клетки радиуса у центра посчитаны.
func complete(at: Vector3) -> bool:
	var r := radius()
	var c := cell_of(at.x, at.z)
	var n := int(ceilf(r / CELL)) + 1
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var key := Vector2i(c.x + dx, c.y + dz)
			var d := Vector2((key.x + 0.5) * CELL - at.x, (key.y + 0.5) * CELL - at.z).length()
			if d <= r + CELL and not _cache.has(key):
				return false
	return true


func _rebuild(c: Vector2i, n: int, r: float) -> void:
	list.clear()
	scales.resize(0)
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not _cache.has(key):
				continue
			for s: Stone in _cache[key]:
				var d := Vector2(s.pos.x - _center.x, s.pos.z - _center.z).length()
				var k := edge_k(d, r)
				if k <= 0.0 or list.size() >= MAX:
					continue
				list.append(s)
				scales.append(k)
	# дальние клетки забываем: кэш не растёт за кораблём
	if _cache.size() > 4 * (2 * n + 1) * (2 * n + 1):
		for key: Vector2i in _cache.keys():
			if absi(key.x - c.x) > 2 * n or absi(key.y - c.y) > 2 * n:
				if absi(key.x - _ahead.x) > n or absi(key.y - _ahead.y) > n:   # заготовка под прыжок (prefetch)
					_cache.erase(key)
	rev += 1


## Поставить образцы, у которых камней не будет (кэш сбрасывается).
func set_avoid(points: Array[Vector3]) -> void:
	avoid = points
	_cache.clear()
	_dirty = true
	_full_at = Vector2i(1 << 30, 0)
