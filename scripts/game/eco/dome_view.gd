class_name DomeView
extends Node3D
## Купольник в сцене (#837): модель MOD-022 на скелете ANIM-004 (`models/kupolnik-anim.glb`, одна сетка, один
## материал, 7 419 треугольников — 1 вызов отрисовки) пока в позе покоя — плывёт и разворачивается код `EcoDome`;
## клипы `Swim`/`Idle`/`OpenPetal` подключит следующая задача (#837, #840). Pivot модели — центр низа, перед — −Z,
## как курс купольника и корабля: `rotation.y = yaw`, низ модели — в `EcoDome.pos` (над дном на AT_NEST, ниже
## AT_NEST/2 мир не опускает — модель дна не касается). Ушёл в нишу (`shown()` — нет) — узел скрыт. Фотофоры (маска emissive в GLB) — по `EcoDome.glow`:
## в покое как в модели, импульс команды Хранителя ярче в PULSE_GAIN раз. Дальше HIDE_FAR модель не рисуется
## (`visibility_range_end`: в мути её всё равно не видно). Стоит на слое отмели (OceanView.LAYER_WORLD), тень
## отбрасывает. У гостя мир свой (`EcoView.step_client`) — вид тот же.

const GLB := "res://models/kupolnik-anim.glb"
## Импульс фотофоров на пике (glow = EcoDome.PULSE) — во столько раз ярче покоя (GLOW_REST).
const PULSE_GAIN := 3.0
## Дальше — не рисуется, м.
const HIDE_FAR := 90.0

var dome: EcoDome
var body: Node3D
var mesh: MeshInstance3D
## Свой материал (копия из GLB): свечение меняется только у купольника.
var mat: StandardMaterial3D
## Свечение модели в покое.
var base_energy := 1.0


func _init(system: EcoDome) -> void:
	dome = system
	name = "Купольник"
	var scene: PackedScene = load(GLB)
	body = scene.instantiate()
	body.name = "Модель"
	add_child(body)
	mesh = body.find_children("*", "MeshInstance3D", true, false)[0]
	mesh.layers = OceanView.LAYER_WORLD
	mesh.visibility_range_end = HIDE_FAR
	EcoShadows.cast(mesh)
	mat = (mesh.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	base_energy = mat.emission_energy_multiplier
	mesh.set_surface_override_material(0, mat)
	sync()


## Свечение фотофоров по доле glow купольника: покой — как в модели, пик импульса — × PULSE_GAIN.
static func energy(glow: float, base: float) -> float:
	var k := clampf((glow - EcoDome.GLOW_REST) / (EcoDome.PULSE - EcoDome.GLOW_REST), 0.0, 1.0)
	return base * lerpf(1.0, PULSE_GAIN, k)


## Место, курс и свечение — из мира.
func sync() -> void:
	visible = dome.shown()
	if not visible:
		return
	body.position = dome.pos
	body.rotation = Vector3(0.0, dome.yaw, 0.0)
	mat.emission_energy_multiplier = energy(dome.glow, base_energy)
