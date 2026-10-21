class_name OceanView
extends Node3D
## Отмель за бортом: дно (один меш с цветом вершин), лёд над головой, свет сквозь лёд, морской снег
## и вода по глубине (туман и рассеянный свет, как updateEnv в js/game.js). Мир неподвижен, движется корабль.

const LAYER_WORLD := 1   ## слой отмели: её освещает свет сквозь лёд
const LAYER_SHIP := 2    ## слой корабля изнутри: только свои лампы

var seabed: MeshInstance3D
var ice: MeshInstance3D
var sun: DirectionalLight3D
var snow: CPUParticles3D


func _ready() -> void:
	seabed = MeshInstance3D.new()
	seabed.name = "Дно"
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Seabed.build_arrays())
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	mesh.surface_set_material(0, m)
	seabed.mesh = mesh
	seabed.layers = LAYER_WORLD
	add_child(seabed)

	# лёд: плоскость на y = 0 лицом вниз, светится рассеянным светом сверху
	ice = MeshInstance3D.new()
	ice.name = "Лёд"
	var q := PlaneMesh.new()
	q.size = Vector2(Seabed.SIZE, Seabed.SIZE)
	q.flip_faces = true
	ice.mesh = q
	var im := StandardMaterial3D.new()
	im.albedo_color = Color("86BCCB")
	im.emission_enabled = true
	im.emission = Color("9AD9E8")
	im.emission_energy_multiplier = 0.35
	im.roughness = 0.4
	ice.material_override = im
	ice.position.y = Seabed.ICE_Y
	ice.layers = LAYER_WORLD
	add_child(ice)

	sun = DirectionalLight3D.new()
	sun.name = "Свет сквозь лёд"
	sun.rotation_degrees = Vector3(-70, 20, 0)
	sun.light_color = Color("9AD9E8")
	sun.light_cull_mask = LAYER_WORLD
	add_child(sun)

	snow = _make_snow()
	add_child(snow)


## Морской снег: медленные светлые точки вокруг корабля; частицы в мировых координатах,
## поэтому при ходе корабль проплывает сквозь них — так видно движение.
func _make_snow() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Морской снег"
	p.amount = 420
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(28, 14, 28)
	p.direction = Vector3(0, -1, 0)
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.06, 0.06)
	mesh.material = ShaderKey.flakes(Color(0.85, 0.95, 1.0, 0.55))   # шейдер общий с илом (issue #159)
	p.mesh = mesh
	p.layers = LAYER_WORLD
	return p


## Вода по глубине: цвет и плотность тумана, рассеянный свет, свет сквозь лёд. around — где корабль.
## silt — корабль в облаке ила 0…1 (Silt.k): вода бурая и мутная.
func apply_water(env: Environment, depth: float, around: Vector3, silt: float = 0.0) -> void:
	var fog := Seabed.Water.fog_color(depth).lerp(Silt.COLOR, 0.6 * silt)
	env.background_color = fog
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = fog
	env.fog_light_energy = 1.0
	env.fog_density = Seabed.Water.fog_density(depth) * 0.9 + 0.03 * silt
	env.fog_sky_affect = 0.0
	env.ambient_light_color = Color(0.55, 0.75, 0.8)
	env.ambient_light_energy = Seabed.Water.ambient(depth) * 0.7
	sun.light_energy = Seabed.Water.sun(depth) * 1.2
	snow.position = around
