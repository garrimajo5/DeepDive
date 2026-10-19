class_name HullView
extends Node3D
## «Ковчег-7» снаружи (HullPlan по ART-001, меши — HullMesh): неподвижные детали одним мешем, по поверхности на краску;
## роторы и рули глубины — свои узлы, их ставит apply() по HullMesh.Motion. Окна, линза прожектора светятся сами.
## Слой отмели (1): корпус освещают лёд и прожектор. Изнутри корпус не виден — лицевые стороны смотрят наружу.

var body: MeshInstance3D
var rotors: Array[MeshInstance3D] = []
var rudders: Array[MeshInstance3D] = []
var _rotor_parts: Array = []
var _rudder_parts: Array = []
var _mats := {}


func _ready() -> void:
	body = MeshInstance3D.new()
	body.name = "Корпус снаружи"
	var mesh := ArrayMesh.new()
	for paint in HullMesh.paints():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, HullMesh.paint_builder(paint).arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(paint))
	body.mesh = mesh
	_setup(body)
	add_child(body)
	for part in HullPlan.parts():
		if not HullMesh.drawn(part) or not HullMesh.moving(part):
			continue
		var mi := MeshInstance3D.new()
		mi.name = part.name
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, HullMesh.part_builder(part).arrays())
		m.surface_set_material(0, material(part.paint))
		mi.mesh = m
		mi.position = part.pos
		_setup(mi)
		add_child(mi)
		if part.piece == HullPlan.Piece.ROTOR:
			rotors.append(mi)
			_rotor_parts.append(part)
		else:
			rudders.append(mi)
			_rudder_parts.append(part)


func _setup(mi: MeshInstance3D) -> void:
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func material(paint: int) -> StandardMaterial3D:
	if _mats.has(paint):
		return _mats[paint]
	var c: Color = HullPlan.COLORS[paint]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75 if paint == HullPlan.Paint.METAL else 0.6
	m.metallic = 0.3 if paint == HullPlan.Paint.METAL or paint == HullPlan.Paint.SEAM else 0.0
	if HullPlan.glows(paint):
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = HullMesh.glow(paint)
	_mats[paint] = m
	return m


## Роторы крутятся вокруг своей оси (вдоль корабля), рули глубины — вокруг поперечной оси: при всплытии
## задняя кромка поднята.
func apply(motion: HullMesh.Motion) -> void:
	for i in rotors.size():
		var part: HullPlan.Part = _rotor_parts[i]
		var axis := part.rotate(Vector3.UP).normalized()
		rotors[i].basis = Basis(axis, deg_to_rad(motion.rotor_angle_of(signf(part.pos.x))))
	for r in rudders:
		r.basis = Basis(Vector3.RIGHT, -deg_to_rad(motion.pitch))
