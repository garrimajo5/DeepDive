class_name OgnevkaView
extends Node3D
## Огнёвки в сцене (js/creatures.js initStations: капсулы 0,06 × 0,2 м, MeshBasicMaterial #FFA040 — светятся сами):
## один MultiMesh на всех рачков всех станций, капсула вытянута по ходу. Стоит на слое отмели (OceanView.LAYER_WORLD).
## Рачки обирают веерник пустой станции — у кружева облачка взвеси (EcoOgnevkaDust): дочерний MultiMesh «Муть»
## в мировых координатах на общем шейдере EcoShaders.MIST, +1 вызов.
## «Экономно» (Б6, `set_lite`): на каждой станции рисуется половина рачков (10 → 5, LITE_KEEP — и у вершины, и на
## веернике): видимые — в начале буфера (`slot`), `visible_instance_count` отрезает остальных, скрытые не
## пересчитываются. Мир (рой на хищнике, кормёжка на веернике, укрытие) не меняется; облачка мути — как были.
## Вызовов столько же.
## Рачок гребёт (Б3, `stroke`): капсула толчком короче и толще (на STROKE_SHORT длины за четверть гребка) и плавно
## распрямляется, STROKE_RATE гребков в секунду (у каждого чуть свой ритм и фаза); висящий у вершины гребёт на
## STROKE_STILL размаха, бросок к хищнику — во весь. По времени мира (у гостя то же), на CPU — шейдеров и вызовов
## не прибавилось, и на «Экономно».
## Рачки не клоны (Б4, «Вариативность в MultiMesh»): у каждого свой размер (±SIZE_SPREAD), яркость (±SHADE_SPREAD) и
## оттенок от красно-оранжевого до янтарного (±HUE_SPREAD) — хешем `EcoVary` от номера рачка, мир и его случай не
## меняются, у гостя тот же вид. Цвет — цвет экземпляра MultiMesh (sRGB, как прежний albedo): вызовов и шейдеров
## столько же, и на «Экономно».

const RADIUS := 0.06
const LENGTH := 0.2
const COLOR := Color("ffa040")
## Гребок: сколько в секунду, на какую долю короче и толще в толчке, доля гребка на толчок, размах у висящего.
const STROKE_RATE := 2.2
const STROKE_SHORT := 0.18
const STROKE_WIDE := 0.08
const STROKE_HIT := 0.25
const STROKE_STILL := 0.35
## Разброс по рачкам: размер, яркость, сдвиг тона (доля круга цветов).
const SIZE_SPREAD := 0.15
const SHADE_SPREAD := 0.2
const HUE_SPREAD := 0.035
## Чисел на рачка в буфере: матрица 3×4 и цвет.
const STRIDE := 16

var ognevka: EcoOgnevka
var mesh: MultiMeshInstance3D
## Последние места рачков (для тестов — сервер отрисовки без экрана экземпляры не хранит).
var placed: Array[Transform3D] = []
var _buffer := PackedFloat32Array()
## Время мира прошлого `sync` (гребок при пересборке на «Экономно»).
var _t := 0.0

## Облачка у веерника (EcoOgnevkaDust); буфер — для тестов.
var dust := EcoOgnevkaDust.new()
var dust_view: MultiMeshInstance3D
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()

## «Экономно»: у станции рисуются рачки с номерами k < LITE_KEEP.
const LITE_KEEP := EcoOgnevka.PER_STATION / 2
var lite := false


func _init(system: EcoOgnevka, on_lite := false) -> void:
	ognevka = system
	name = "Огнёвки"
	mesh = MultiMeshInstance3D.new()
	mesh.name = "Рачки"
	mesh.layers = OceanView.LAYER_WORLD
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = build()
	mm.instance_count = maxi(1, ognevka.leeches.stations.size() * EcoOgnevka.PER_STATION)
	mesh.multimesh = mm
	mesh.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	add_child(mesh)
	dust_view = GrazerView.build_dust(EcoOgnevkaDust.POOL)
	add_child(dust_view)
	if on_lite:
		set_lite(true)
	else:
		sync(true)


## «Экономно» — половина рачков каждой станции; буфер переписывается целиком сразу.
func set_lite(on: bool) -> void:
	if lite == on:
		return
	lite = on
	var n := ognevka.leeches.stations.size()
	mesh.multimesh.visible_instance_count = lite_count(n) if on else -1
	sync(true)


## Рисуется ли на «Экономно» рачок номер k своей станции: первые LITE_KEEP — в них и чётные (кружат у вершины), и
## нечётные (кормятся на веернике пустой станции), так что на «Экономно» рачки остаются в обоих местах.
static func lite_shown(k: int) -> bool:
	return k < LITE_KEEP


## Сколько рачков рисуется на «Экономно» у n станций.
static func lite_count(n: int) -> int:
	return n * LITE_KEEP


## Место рачка номер i (n станций) в буфере: на «Экономно» видимые — в начале, по станциям.
static func slot(i: int, n: int, on_lite: bool) -> int:
	if not on_lite:
		return i
	var st := i / EcoOgnevka.PER_STATION
	var k := i % EcoOgnevka.PER_STATION
	if lite_shown(k):
		return st * LITE_KEEP + k
	return n * LITE_KEEP + st * (EcoOgnevka.PER_STATION - LITE_KEEP) + k - LITE_KEEP


## Сколько рачков рисуется сейчас.
func drawn() -> int:
	var v := mesh.multimesh.visible_instance_count
	return mesh.multimesh.instance_count if v < 0 else v


static func build() -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = RADIUS
	m.height = LENGTH + RADIUS * 2.0
	m.radial_segments = 5
	m.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true   # цвет — у каждого рачка свой (shrimp_color)
	mat.vertex_color_is_srgb = true
	m.material = mat
	return m


## Сжатие рачка в гребке (0 — распрямлён, 1 — толчок во весь размах) в момент t: фаза phase, ход speed, м/с.
## Толчок — за STROKE_HIT гребка, распрямление — плавно остаток; ритм — STROKE_RATE ±15 % по фазе.
static func stroke(t: float, phase: float, speed: float) -> float:
	var rate := STROKE_RATE * (0.85 + 0.3 * fposmod(phase * 3.7, 1.0))
	var k := fposmod(t * rate + phase / TAU, 1.0)
	var c := sin(k / STROKE_HIT * PI * 0.5) if k < STROKE_HIT \
			else 0.5 + 0.5 * cos(PI * (k - STROKE_HIT) / (1.0 - STROKE_HIT))
	var amp := clampf(STROKE_STILL + (1.0 - STROKE_STILL) * speed / EcoOgnevka.DART, 0.0, 1.0)
	return c * amp


## Размер рачка номер i (множитель капсулы).
static func shrimp_scale(i: int) -> float:
	return EcoVary.spread(i, EcoVary.SIZE, SIZE_SPREAD)


## Цвет рачка номер i: COLOR со сдвигом тона и яркости (sRGB, цвет экземпляра).
static func shrimp_color(i: int) -> Color:
	var c := COLOR
	c.h = fposmod(c.h + (EcoVary.unit(i, EcoVary.HUE) * 2.0 - 1.0) * HUE_SPREAD, 1.0)
	var k := EcoVary.spread(i, EcoVary.SHADE, SHADE_SPREAD)
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


## Цвет рачка в буфере на месте slot (для тестов).
func color_at(slot: int) -> Color:
	var o := slot * STRIDE + 12
	return Color(_buffer[o], _buffer[o + 1], _buffer[o + 2], _buffer[o + 3])


## Капсула вдоль хода рачка: ось капсулы (Y меша) — по направлению dir; в гребке (момент t) короче и толще;
## size — размер рачка (shrimp_scale).
static func place(s: EcoOgnevka.Shrimp, t := 0.0, size := 1.0) -> Transform3D:
	var y := s.dir
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = x.normalized()
	var c := stroke(t, s.phase, s.v.length())
	var w := (1.0 + STROKE_WIDE * c) * size
	return Transform3D(Basis(x * w, y * (1.0 - STROKE_SHORT * c) * size, x.cross(y) * w), s.p)


## Переписывает только рачков, шагнувших в этом шаге мира (EcoOgnevka шагает их половинами); all — всех;
## t — время мира (гребок; меньше нуля — прошлое). На «Экономно» скрытые рачки не пересчитываются.
func sync(all := false, t := -1.0) -> void:
	if t < 0.0:
		t = _t
	_t = t
	var mm := mesh.multimesh
	var n := mini(ognevka.shrimp.size(), mm.instance_count)
	if placed.size() != n or _buffer.size() != mm.instance_count * STRIDE:
		placed.resize(n)
		_buffer.resize(mm.instance_count * STRIDE)
		_buffer.fill(0.0)
		all = true
	var from := 0 if all else ognevka.moved_half()
	var stride := 1 if all else 2
	var stations := ognevka.leeches.stations.size()
	for i in range(from, n, stride):
		if lite and not lite_shown(i % EcoOgnevka.PER_STATION):
			continue
		var x := place(ognevka.shrimp[i], t, shrimp_scale(i))
		placed[i] = x
		var b := x.basis
		var o := slot(i, stations, lite) * STRIDE
		var col := shrimp_color(i)
		_buffer[o + 12] = col.r; _buffer[o + 13] = col.g; _buffer[o + 14] = col.b; _buffer[o + 15] = 1.0
		_buffer[o] = b.x.x; _buffer[o + 1] = b.y.x; _buffer[o + 2] = b.z.x; _buffer[o + 3] = x.origin.x
		_buffer[o + 4] = b.x.y; _buffer[o + 5] = b.y.y; _buffer[o + 6] = b.z.y; _buffer[o + 7] = x.origin.y
		_buffer[o + 8] = b.x.z; _buffer[o + 9] = b.y.z; _buffer[o + 10] = b.z.z; _buffer[o + 11] = x.origin.z
	mm.buffer = _buffer


## Облачка у веерников в момент t (время мира); flow — течение (сносит облачка).
func sync_dust(t: float, ship: EcoLink.ShipState, flow := Vector3.ZERO) -> void:
	dust.update(ognevka, t, ship.pos if ship != null else Vector3.ZERO)
	_dust.pack(dust.dust, t, flow, ship, EcoOgnevkaDust.COLOR, EcoOgnevkaDust.LIT)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)
