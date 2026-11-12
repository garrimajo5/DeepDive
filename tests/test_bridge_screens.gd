extends TestCase
## Стёкла экранов пульта пилота садятся в рамки корпуса MOD-004 (#1388): каждый угол и середина экрана лежат над
## тёмным полем экрана в текстуре корпуса и чуть впереди поверхности — не утоплены и не висят над ней.

const DARK := 0.12   ## яркость поля экрана в текстуре корпуса ниже этой; рамка и корпус светлее


class Console:
	var v: PackedVector3Array
	var uv: PackedVector2Array
	var idx: PackedInt32Array
	var img: Image

	func _init() -> void:
		var n: Node3D = (load("res://models/%s.glb" % BridgeProps.CONSOLE) as PackedScene).instantiate()
		var m: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
		var a := m.mesh.surface_get_arrays(0)
		v = a[Mesh.ARRAY_VERTEX]
		uv = a[Mesh.ARRAY_TEX_UV]
		idx = a[Mesh.ARRAY_INDEX]
		img = (m.get_active_material(0) as BaseMaterial3D).albedo_texture.get_image()
		if img.is_compressed():
			img.decompress()
		n.free()

	## Ближайшее к пилоту попадание луча из точки p против `dir`: [точка, яркость текстуры] или [].
	func surface(p: Vector3, dir: Vector3) -> Array:
		var o := p + dir * 0.3
		var best := []
		var bd := INF
		for t in range(0, idx.size(), 3):
			var a := v[idx[t]]
			var b := v[idx[t + 1]]
			var c := v[idx[t + 2]]
			var h = Geometry3D.ray_intersects_triangle(o, -dir, a, b, c)
			if h == null:
				continue
			var d := (h as Vector3).distance_to(o)
			if d >= bd:
				continue
			bd = d
			var bc := Geometry3D.get_triangle_barycentric_coords(h, a, b, c)
			var u: Vector2 = uv[idx[t]] * bc.x + uv[idx[t + 1]] * bc.y + uv[idx[t + 2]] * bc.z
			var px := Vector2i(clampi(int(u.x * img.get_width()), 0, img.get_width() - 1),
				clampi(int(u.y * img.get_height()), 0, img.get_height() - 1))
			best = [h, img.get_pixelv(px).get_luminance()]
		return best


func _check(c: Console, q: PackedVector3Array) -> String:
	var face := (q[1] - q[0]).cross(q[3] - q[0]).normalized()
	if face.z < 0.8:
		return "стекло не лицом к пилоту: %s" % face
	var pts: Array[Vector3] = [(q[0] + q[1] + q[2] + q[3]) / 4.0]
	pts.append_array(Array(q))
	for p in pts:
		var h := c.surface(p, face)
		if h.is_empty():
			return "под точкой %s нет корпуса" % p
		if h[1] >= DARK:
			return "точка %s над рамкой (яркость %.2f), а не над полем экрана" % [p, h[1]]
		var gap: float = (p - (h[0] as Vector3)).dot(face)
		if gap < 0.003 or gap > 0.015:
			return "точка %s на %.1f мм от поверхности (нужно 3…15)" % [p, gap * 1000.0]
	return ""


func test_screens_sit_in_frames() -> void:
	var c := Console.new()
	eq(BridgeProps.SCREEN_CORNERS.size(), BridgeProps.SCREEN_COUNT * 4, "три экрана по четыре угла")
	for i in BridgeProps.SCREEN_COUNT:
		eq(_check(c, BridgeProps.screen_quad(i)), "", "экран %d в своей рамке" % i)


## Прежние плоскости `pult-ekrany` выходили на рамку: средняя (y 1,02…1,32) — сверху и снизу, левая — у внутреннего
## края снизу, где рамка скошена.
func test_old_flat_quad_fails() -> void:
	var c := Console.new()
	var mid := PackedVector3Array([Vector3(-0.36, 1.02, 0.105), Vector3(0.36, 1.02, 0.105),
		Vector3(0.36, 1.32, 0.019), Vector3(-0.36, 1.32, 0.019)])
	var left := PackedVector3Array([Vector3(-1.03, 1.03, 0.0395), Vector3(-0.59, 1.03, 0.0799),
		Vector3(-0.59, 1.22, 0.0114), Vector3(-1.03, 1.22, -0.0284)])
	ok(_check(c, mid) != "", "старая средняя плоскость не проходит проверку")
	ok(_check(c, left) != "", "старая левая плоскость не проходит проверку")


func test_mesh_faces_pilot() -> void:
	var m := BridgeProps.screen_mesh()
	var a := m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	eq(idx.size(), 18, "шесть треугольников")
	for t in range(0, idx.size(), 3):
		var inward := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
		ok(inward.z < 0.0, "треугольник %d лицом к пилоту (+Z)" % (t / 3))
	# граница трёх экранов в шейдере — edge от центра модели
	var edge: float = 0.35
	for p in BridgeProps.screen_quad(1):
		ok(absf(p.x) < edge, "средний экран внутри |x| < edge")
	for i in [0, 2]:
		for p in BridgeProps.screen_quad(i):
			ok(absf(p.x) > edge, "боковой экран %d за |x| > edge" % i)
