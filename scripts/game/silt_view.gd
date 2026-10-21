class_name SiltView
extends MultiMeshInstance3D
## Облака ила (Silt, js/silt.js): по 300 карточек на облако, до трёх облаков — один MultiMesh, один вызов
## отрисовки. Карточка 1,6 м лицом к камере, на ней рваные серо-зелёные пятна 0,10–0,40 м (маска Silt.flake_image,
## ART-048); каждая девятая крупнее — редкие ближние хлопья до 0,7 м. Облако разрастается, дрейфует, хлопья колышутся.
## Живёт в осях мира, слой отмели (OceanView.LAYER_WORLD).

const PER_CLOUD := 300
const FLAKE := 1.6
const OPACITY := 0.55
const BIG_EVERY := 9    ## каждая такая карточка — крупные ближние хлопья
const BIG_SCALE := 1.75

## Рой у носа, пока корабль в облаке: окно (м) и насколько его центр впереди середины корабля.
const LOCAL_BOX := Vector3(24.0, 10.0, 24.0)
const LOCAL_AHEAD := 12.0

static var _mask: ImageTexture

var offsets: Array[Vector3] = []  ## точки в единичном шаре (детерминированно, как Si.off в js)
var shown := 0  ## сколько хлопьев видно (для тестов)
var near_bow := 0  ## сколько из них в окне перед мостиком (для тестов)
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
	if _mask == null:   # маска одна на все запуски сцены
		var img := Silt.flake_image()
		img.generate_mipmaps()
		_mask = ImageTexture.create_from_image(img)
	_mat = ShaderKey.flakes(Color(1, 1, 1, OPACITY), _mask)   # шейдер общий с морским снегом (issue #159)
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
## sc — масштаб карточки (card_scale): крупной нужен запас больше.
func in_hull(p: Vector3, sc: float = 1.0) -> bool:
	if absf(p.x) > 8.0 or p.y < -4.0 or p.y > 7.0 or p.z < -14.0 or p.z > 32.0:
		return false
	var axis := Vector3(0.0, 1.6, p.z)
	var q := p + (axis - p).limit_length(FLAKE * 0.6 * sc)
	for part in _hull:
		if part.contains(p) or part.contains(q):
			return true
	return false


## Масштаб j-й карточки: 0,8–1,15, каждая BIG_EVERY-я — BIG_SCALE (пятна до 0,7 м).
static func card_scale(j: int) -> float:
	if j % BIG_EVERY == BIG_EVERY - 1:
		return BIG_SCALE
	return 0.8 + 0.35 * fmod(j * 0.618034, 1.0)


## Облака s в момент t; корабль в ship_pos с курсом yaw — внутри него хлопьев нет.
## Облако, в котором корабль, отдаёт половину карточек (по доле Silt.k) рою у носа: окно LOCAL_BOX перед мостиком,
## точки стоят в мире и переносятся на другую сторону окна, когда корабль уходит (как морской снег). Иначе 300 карточек
## на шар 16 м — у окон их почти нет (ART-048: 60–100 пятен в центральном окне внутри, 20–30 на входе).
func apply(s: Silt, t: float, ship_pos: Vector3, yaw: float) -> void:
	var n := 0
	var near_n := 0
	var anchor := ship_pos + Vector3(0.0, 0.0, -LOCAL_AHEAD).rotated(Vector3.UP, yaw)
	for cl in s.clouds:
		var sp := cl.spread()
		var near_ship := cl.c.distance_to(ship_pos) < sp + 30.0
		var local_n := int(PER_CLOUD * 0.5 * clampf(s.k, 0.0, 1.0)) if cl == s.inside else 0
		for j in PER_CLOUD:
			var o := offsets[j]
			var sway := Vector3(sin(t * 0.3 + j) * 0.6, 0.0, cos(t * 0.25 + j) * 0.6)
			var p: Vector3
			if j % 2 == 0 and j / 2 < local_n:
				p = anchor + wrap_box(cl.c + o * LOCAL_BOX * 1.7 + sway - anchor)
			else:
				p = cl.c + o * sp + sway
			if near_ship and in_hull((p - ship_pos).rotated(Vector3.UP, -yaw), card_scale(j)):
				continue
			multimesh.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * card_scale(j)), p))
			n += 1
			if (p - anchor).abs().x < LOCAL_BOX.x * 0.5 and (p - anchor).abs().z < LOCAL_BOX.z * 0.5:
				near_n += 1
	multimesh.visible_instance_count = n
	shown = n
	near_bow = near_n
	visible = n > 0
	_mat.albedo_color.a = OPACITY * minf(1.0, s.max_density() + 0.1)


## Сдвиг v, перенесённый в окно LOCAL_BOX с центром в нуле.
static func wrap_box(v: Vector3) -> Vector3:
	return Vector3(fposmod(v.x + LOCAL_BOX.x * 0.5, LOCAL_BOX.x) - LOCAL_BOX.x * 0.5,
			fposmod(v.y + LOCAL_BOX.y * 0.5, LOCAL_BOX.y) - LOCAL_BOX.y * 0.5,
			fposmod(v.z + LOCAL_BOX.z * 0.5, LOCAL_BOX.z) - LOCAL_BOX.z * 0.5)
