class_name DomeView
extends Node3D
## Купольник в сцене (#837): модель MOD-022 на скелете ANIM-004 (`models/kupolnik-anim.glb`, одна сетка, один
## материал, 7 419 треугольников — 1 вызов отрисовки): плывёт и разворачивается код `EcoDome`, клип — по его
## состоянию (`EcoDome.clip`): `Idle` в нише и стоя, `Swim` на ходу (темп — по скорости, `swim_rate`), `OpenPetal` у
## гнезда — позиция клипа = время состояния OPEN (`EcoDome.t`), подъём створки в клипе и в мире (`LIFT`) совпадают.
## Смена клипа — плавно за BLEND с. AnimationPlayer идёт вручную от времени мира (`sync(now, from)`): дальше
## HIDE_FAR от корабля поза не считается. Pivot модели — центр низа, перед — −Z,
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
## Смена клипа, с.
const BLEND := 0.4
## Темп Swim: на полном ходу к гнезду (EcoDome.SWIM) — 1; не медленнее RATE_MIN и не быстрее RATE_MAX.
const RATE_MIN := 0.4
const RATE_MAX := 1.6
## Клип OpenPetal ушёл от времени состояния дальше этого (с) — встаёт по нему.
const DRIFT := 0.05

var dome: EcoDome
var body: Node3D
var mesh: MeshInstance3D
## Свой материал (копия из GLB): свечение меняется только у купольника.
var mat: StandardMaterial3D
## Свечение модели в покое.
var base_energy := 1.0
## Клипы модели (вручную, `sync`) и какой играет.
var player: AnimationPlayer
var playing := ""
var _last := NAN


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
	player = body.find_children("*", "AnimationPlayer", true, false)[0]
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	sync()


## Темп клипа Swim на ходу speed (м/с).
static func swim_rate(speed: float) -> float:
	return clampf(speed / EcoDome.SWIM, RATE_MIN, RATE_MAX)


## Свечение фотофоров по доле glow купольника: покой — как в модели, пик импульса — × PULSE_GAIN.
static func energy(glow: float, base: float) -> float:
	var k := clampf((glow - EcoDome.GLOW_REST) / (EcoDome.PULSE - EcoDome.GLOW_REST), 0.0, 1.0)
	return base * lerpf(1.0, PULSE_GAIN, k)


## Место, курс, свечение и клип — из мира. now — время мира (NAN — клип не трогать), from — где корабль.
func sync(now := NAN, from := Vector3.INF) -> void:
	var dt := clampf(now - _last, 0.0, 0.5) if not is_nan(now) and not is_nan(_last) else 0.0
	_last = now
	visible = dome.shown()
	if not visible:
		return
	body.position = dome.pos
	body.rotation = Vector3(0.0, dome.yaw, 0.0)
	mat.emission_energy_multiplier = energy(dome.glow, base_energy)
	if not is_nan(now) and dome.pos.distance_to(from) <= HIDE_FAR:
		animate(dt)


## Шаг клипа на dt с по состоянию купольника.
func animate(dt: float) -> void:
	var want := dome.clip()
	if want != playing:
		player.play(want, BLEND if playing != "" else 0.0)
		playing = want
		if want == "OpenPetal":
			player.seek(dome.t, false)
	player.speed_scale = swim_rate(dome.speed) if want == "Swim" else 1.0
	player.advance(dt)
	if want == "OpenPetal" and player.is_playing() and absf(player.current_animation_position - dome.t) > DRIFT:
		player.seek(minf(dome.t, EcoDome.OPEN_TIME), true)
