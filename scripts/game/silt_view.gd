class_name SiltView
extends MultiMeshInstance3D
## Облака ила (Silt, js/silt.js): по 300 бурых хлопьев на облако, до трёх облаков — один MultiMesh, один вызов
## отрисовки. Хлопья — квадраты 1,6 м лицом к камере; облако разрастается, дрейфует, хлопья чуть колышутся.
## Живёт в осях мира, слой отмели (OceanView.LAYER_WORLD).

const PER_CLOUD := 300
const FLAKE := 1.6
const OPACITY := 0.55

var offsets: Array[Vector3] = []  ## точки в единичном шаре (детерминированно, как Si.off в js)
var shown := 0  ## сколько хлопьев видно (для тестов)
var _mat: StandardMaterial3D
var _hull: Array = []  ## части корпуса (HullPlan): хлопья внутри корабля и у самых стен не рисуем


func _init() -> void:
	name = "Ил"
	layers = OceanView.LAYER_WORLD
	for i in PER_CLOUD:
		var u := sin(i * 12.9898) * 43758.5453
		var r := u - floorf(u)
		var a := i * 2.39996
		var y := fmod(i * 0.618, 1.0) * 2.0 - 1.0
		var rr := sqrt(maxf(0.0, 1.0 - y * y))
		offsets.append(Vector3(cos(a) * rr, y * 0.45, sin(a) * rr) * pow(r, 1.0 / 3.0))
	var q := QuadMesh.new()
	q.size = Vector2(FLAKE, FLAKE)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.billboard_keep_scale = true
	_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mat.albedo_color = Color(Silt.COLOR.darkened(0.35), OPACITY)
	q.material = _mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = Silt.MAX_CLOUDS * PER_CLOUD
	mm.visible_instance_count = 0
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for part in HullPlan.parts():
		if part.piece == HullPlan.Piece.BODY or part.piece == HullPlan.Piece.NOSE or part.piece == HullPlan.Piece.STERN:
			_hull.append(part)


## Хлопок в точке корабля p (оси корабля) заходит внутрь корпуса: сама точка или точка на полхлопка ближе к оси.
func in_hull(p: Vector3) -> bool:
	if absf(p.x) > 8.0 or p.y < -4.0 or p.y > 7.0 or p.z < -14.0 or p.z > 32.0:
		return false
	var axis := Vector3(0.0, 1.6, p.z)
	var q := p + (axis - p).limit_length(FLAKE * 0.6)
	for part in _hull:
		if part.contains(p) or part.contains(q):
			return true
	return false


## Облака s в момент t; корабль в ship_pos с курсом yaw — внутри него хлопьев нет.
func apply(s: Silt, t: float, ship_pos: Vector3, yaw: float) -> void:
	var n := 0
	for cl in s.clouds:
		var sp := cl.spread()
		var near_ship := cl.c.distance_to(ship_pos) < sp + 30.0
		for j in PER_CLOUD:
			var o := offsets[j]
			var p := cl.c + o * sp + Vector3(sin(t * 0.3 + j) * 0.6, 0.0, cos(t * 0.25 + j) * 0.6)
			if near_ship and in_hull((p - ship_pos).rotated(Vector3.UP, -yaw)):
				continue
			multimesh.set_instance_transform(n, Transform3D(Basis(), p))
			n += 1
	multimesh.visible_instance_count = n
	shown = n
	visible = n > 0
	_mat.albedo_color.a = OPACITY * minf(1.0, s.max_density() + 0.1)
