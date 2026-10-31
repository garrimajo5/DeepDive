class_name StonesView
extends MultiMeshInstance3D
## Камни на дне (`SeabedStones`): один MultiMesh (+1 вызов отрисовки), неровный низкий многогранник со светом —
## ловит свет сквозь лёд и прожектор, тени не отбрасывает. Список камней пишет буфером MultiMesh целиком, только
## когда он поменялся (`SeabedStones.rev`). Слой отмели `OceanView.LAYER_WORLD`.

var stones := SeabedStones.new()
var writes := 0   ## сколько раз буфер записан (тесты)
var _rev := -1


func _init() -> void:
	name = "Камни на дне"
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = true
	m.mesh = rock_mesh()
	m.instance_count = SeabedStones.MAX
	m.visible_instance_count = 0
	multimesh = m
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	material_override = mat
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# границы — на всю отмель со склоном: камни идут за кораблём, отсечение по кадру их не прячет
	custom_aabb = AABB(Vector3(-Seabed.SIZE / 2.0, -320.0, -Seabed.SIZE / 2.0),
			Vector3(Seabed.SIZE + Seabed.EAST.size.x, 320.0, Seabed.SIZE))


## Шаг: камни вокруг точки at (корабль).
func follow(at: Vector3) -> void:
	stones.update(at)
	if stones.rev != _rev:
		_write()


func set_lite(on: bool) -> void:
	stones.set_lite(on)


func _write() -> void:
	_rev = stones.rev
	writes += 1
	var n := stones.list.size()
	var buf := PackedFloat32Array()
	buf.resize(SeabedStones.MAX * 16)
	for i in n:
		var s: SeabedStones.Stone = stones.list[i]
		var b := s.basis.scaled(Vector3.ONE * stones.scales[i]) if stones.scales[i] < 1.0 else s.basis
		# у Basis.scaled масштаб глобальный — у края мельчает весь камень, поворот тот же
		var o := i * 16
		buf[o] = b.x.x
		buf[o + 1] = b.y.x
		buf[o + 2] = b.z.x
		buf[o + 3] = s.pos.x
		buf[o + 4] = b.x.y
		buf[o + 5] = b.y.y
		buf[o + 6] = b.z.y
		buf[o + 7] = s.pos.y
		buf[o + 8] = b.x.z
		buf[o + 9] = b.y.z
		buf[o + 10] = b.z.z
		buf[o + 11] = s.pos.z
		buf[o + 12] = s.color.r
		buf[o + 13] = s.color.g
		buf[o + 14] = s.color.b
		buf[o + 15] = 1.0
	multimesh.buffer = buf
	multimesh.visible_instance_count = n


## Неровный икосаэдр радиуса 0,5 (поперечник 1 м — размер задаёт экземпляр): вершины сдвинуты хешем, грани плоские
## (видно сколы), 20 треугольников. Лицевая сторона — по часовой стрелке снаружи.
static func rock_mesh() -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in v.size():
		var k := 0.78 + 0.34 * HashNoise.hash2(i * 7 + 3, i * 13 + 1)
		v[i] = v[i].normalized() * 0.5 * k
		if v[i].y < 0.0:
			v[i].y *= 0.6   # низ плоский — камень лежит, а не стоит на острие
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var a: Vector3 = v[f[0]]
		var b: Vector3 = v[f[1]]
		var c: Vector3 = v[f[2]]
		if (b - a).cross(c - a).dot(a + b + c) > 0.0:   # (b − a) × (c − a) должно смотреть внутрь
			var tmp := b
			b = c
			c = tmp
		var n := (c - a).cross(b - a).normalized()
		for p in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(p)
	return st.commit()
