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

const RADIUS := 0.06
const LENGTH := 0.2
const COLOR := Color("ffa040")

var ognevka: EcoOgnevka
var mesh: MultiMeshInstance3D
## Последние места рачков (для тестов — сервер отрисовки без экрана экземпляры не хранит).
var placed: Array[Transform3D] = []
var _buffer := PackedFloat32Array()

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
	mat.albedo_color = COLOR
	m.material = mat
	return m


## Капсула вдоль хода рачка: ось капсулы (Y меша) — по направлению dir.
static func place(s: EcoOgnevka.Shrimp) -> Transform3D:
	var y := s.dir
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = x.normalized()
	return Transform3D(Basis(x, y, x.cross(y)), s.p)


## Переписывает только рачков, шагнувших в этом шаге мира (EcoOgnevka шагает их половинами); all — всех.
## На «Экономно» скрытые рачки не пересчитываются.
func sync(all := false) -> void:
	var mm := mesh.multimesh
	var n := mini(ognevka.shrimp.size(), mm.instance_count)
	if placed.size() != n or _buffer.size() != mm.instance_count * 12:
		placed.resize(n)
		_buffer.resize(mm.instance_count * 12)
		_buffer.fill(0.0)
		all = true
	var from := 0 if all else ognevka.moved_half()
	var stride := 1 if all else 2
	var stations := ognevka.leeches.stations.size()
	for i in range(from, n, stride):
		if lite and not lite_shown(i % EcoOgnevka.PER_STATION):
			continue
		var x := place(ognevka.shrimp[i])
		placed[i] = x
		var b := x.basis
		var o := slot(i, stations, lite) * 12
		_buffer[o] = b.x.x; _buffer[o + 1] = b.y.x; _buffer[o + 2] = b.z.x; _buffer[o + 3] = x.origin.x
		_buffer[o + 4] = b.x.y; _buffer[o + 5] = b.y.y; _buffer[o + 6] = b.z.y; _buffer[o + 7] = x.origin.y
		_buffer[o + 8] = b.x.z; _buffer[o + 9] = b.y.z; _buffer[o + 10] = b.z.z; _buffer[o + 11] = x.origin.z
	mm.buffer = _buffer


## Облачка у веерников в момент t (время мира); flow — течение (сносит облачка).
func sync_dust(t: float, ship: EcoLink.ShipState, flow := Vector3.ZERO) -> void:
	dust.update(ognevka, t, ship.pos if ship != null else Vector3.ZERO)
	_dust.pack(dust.dust, t, flow, ship, EcoOgnevkaDust.COLOR, EcoOgnevkaDust.LIT)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)
