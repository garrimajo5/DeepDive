class_name PlanktonView
extends Node3D
## Мерцающий планктон в сцене (initClouds/cloudUpdate в js/creatures.js): все клетки четырёх облаков — один MultiMesh
## мягких пятен лицом к камере (0,8 м, сложение цвета, общий шейдер EcoShaders.SPOT в режиме cloud). Место клетки
## (дрейф облака и покачивание) и её свечение шейдер считает сам по времени мира: в буфере — дом клетки и
## INSTANCE_CUSTOM = (фаза облака, номер клетки, время вспышки). Буфер переписывается, только когда в облаке
## вспыхнули новые клетки (EcoPlankton.Cloud.version). Клетки выталкиваются из коробки корпуса корабля. Слой отмели.
## Клетки в буфере — вперемешку по облакам (место клетки k облака c — `slot(c, k)` = k × облаков + c), поэтому первая
## половина буфера — половина каждого облака. «Экономно» — рисуется только она (`set_lite`, `LITE_SHARE`):
## вдвое меньше пятен со сложением цвета, мир (вспышки, след корабля, у гостя сети) считает все клетки как раньше.
## Б4 «Вариативность в MultiMesh»: у клетки свой размер (± SIZE_SPREAD, масштаб базиса — шейдер берёт его) и яркость
## (± GLOW_SPREAD, INSTANCE_CUSTOM.w — множитель цвета в ветке cloud) по её номеру хешем `EcoVary` — облако не из
## одинаковых точек. Мир не меняется, у гостя то же. Вызовов и шейдеров столько же, и на «Экономно».

const SIZE := 0.8
## Дальше этого клетки не видны (м от камеры).
const FADE_FAR := 60.0
## Чисел на экземпляр: transform 3 × 4 и свои данные (4).
const STRIDE := 16
const CUSTOM := 12
## Доля клеток, что рисуется на «Экономно».
const LITE_SHARE := 0.5
## Разброс размера и яркости клеток.
const SIZE_SPREAD := 0.25
const GLOW_SPREAD := 0.2

var plankton: EcoPlankton
var cells: MultiMeshInstance3D
var material: ShaderMaterial
## Последний буфер (для тестов) и сколько раз его переписывали.
var buffer := PackedFloat32Array()
var writes := 0
## «Экономно»: рисуется доля LITE_SHARE клеток каждого облака.
var lite := false

var _versions: Array[int] = []


func _init(system: EcoPlankton, lite_on := false) -> void:
	plankton = system
	name = "Мерцающий планктон"
	cells = MultiMeshInstance3D.new()
	cells.name = "Клетки планктона"
	cells.layers = OceanView.LAYER_WORLD
	cells.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = build_mesh()
	material = mm.mesh.material as ShaderMaterial
	mm.instance_count = plankton.clouds.size() * EcoPlankton.PER_CLOUD
	cells.multimesh = mm
	# облака дрейфуют в шейдере — рамка на всю отмель
	cells.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	add_child(cells)
	_fill()
	set_lite(lite_on)
	sync(0.0, Vector3(1e6, 0, 1e6), 0.0)


## «Экономно» — рисуется только первая доля буфера (в ней — каждое облако поровну).
func set_lite(on: bool) -> void:
	lite = on
	var n := cells.multimesh.instance_count
	cells.multimesh.visible_instance_count = int(n * LITE_SHARE) if on else -1


## Сколько клеток рисуется.
func drawn() -> int:
	var v := cells.multimesh.visible_instance_count
	return cells.multimesh.instance_count if v < 0 else v


## Место в буфере клетки k облака c.
func slot(c: int, k: int) -> int:
	return k * plankton.clouds.size() + c


static func build_mesh() -> QuadMesh:
	var m := QuadMesh.new()
	m.size = Vector2.ONE * SIZE
	var mat := ShaderMaterial.new()
	mat.shader = EcoShaders.shader(EcoShaders.SPOT)
	mat.set_shader_parameter("fade_far", FADE_FAR)
	mat.set_shader_parameter("cloud", true)
	mat.set_shader_parameter("box_min", EcoPlankton.BOX_MIN)
	mat.set_shader_parameter("box_max", EcoPlankton.BOX_MAX)
	m.material = mat
	return m


## Номер клетки k облака c во всём планктоне (для разброса).
static func cell_id(c: int, k: int) -> int:
	return c * EcoPlankton.PER_CLOUD + k


## Множитель размера клетки с номером id: 1 ± SIZE_SPREAD.
static func cell_scale(id: int) -> float:
	return EcoVary.spread(id, EcoVary.SIZE, SIZE_SPREAD)


## Множитель яркости клетки с номером id: 1 ± GLOW_SPREAD.
static func cell_glow(id: int) -> float:
	return EcoVary.spread(id, EcoVary.SHADE, GLOW_SPREAD)


## Дома клеток, фазы облаков, номера клеток, размер и яркость — один раз.
func _fill() -> void:
	var n := cells.multimesh.instance_count
	buffer.resize(n * STRIDE)
	_versions.clear()
	for cl in plankton.clouds:
		_versions.append(-1)
		for k in EcoPlankton.PER_CLOUD:
			var i := slot(cl.index, k) * STRIDE
			var o := cl.home + cl.offsets[k]
			var id := cell_id(cl.index, k)
			var sc := cell_scale(id)
			buffer[i] = sc; buffer[i + 1] = 0.0; buffer[i + 2] = 0.0; buffer[i + 3] = o.x
			buffer[i + 4] = 0.0; buffer[i + 5] = sc; buffer[i + 6] = 0.0; buffer[i + 7] = o.y
			buffer[i + 8] = 0.0; buffer[i + 9] = 0.0; buffer[i + 10] = sc; buffer[i + 11] = o.z
			buffer[i + CUSTOM] = cl.phase
			buffer[i + CUSTOM + 1] = float(k)
			buffer[i + CUSTOM + 2] = cl.lit_at[k]
			buffer[i + CUSTOM + 3] = cell_glow(id)


## Время мира и корпус корабля — в шейдер; облако с новыми вспышками — в буфер.
func sync(t: float, ship_pos: Vector3, ship_yaw: float) -> void:
	material.set_shader_parameter("now", t)
	material.set_shader_parameter("ship_pos", ship_pos)
	material.set_shader_parameter("ship_yaw", ship_yaw)
	var dirty := false
	for cl in plankton.clouds:
		if _versions[cl.index] == cl.version:
			continue
		_versions[cl.index] = cl.version
		dirty = true
		for k in EcoPlankton.PER_CLOUD:
			buffer[slot(cl.index, k) * STRIDE + CUSTOM + 2] = cl.lit_at[k]
	if dirty:
		cells.multimesh.buffer = buffer
		writes += 1


## Время вспышки клетки k облака c из буфера.
func lit_at(c: int, k: int) -> float:
	return buffer[slot(c, k) * STRIDE + CUSTOM + 2]


## Дом клетки k облака c из буфера.
func origin_at(c: int, k: int) -> Vector3:
	var i := slot(c, k) * STRIDE
	return Vector3(buffer[i + 3], buffer[i + 7], buffer[i + 11])


## Размер клетки k облака c из буфера (масштаб базиса — шейдер берёт его как размер пятна).
func scale_at(c: int, k: int) -> float:
	return buffer[slot(c, k) * STRIDE]


## Множитель яркости клетки k облака c из буфера.
func glow_at(c: int, k: int) -> float:
	return buffer[slot(c, k) * STRIDE + CUSTOM + 3]
