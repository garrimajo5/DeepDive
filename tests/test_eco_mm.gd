extends TestCase
## Общие куски видов (EcoMM, issue #767): MultiMesh на слое мира, запись трансформа в буфер, ArrayMesh.


## Порядок MultiMesh.TRANSFORM_3D: три строки «basis.x.?, basis.y.?, basis.z.?, origin.?» (в headless буфер
## MultiMesh не читается обратно — сверяем с раскладкой из документации).
func test_put_layout() -> void:
	var tr := Transform3D(Basis.from_euler(Vector3(0.3, 1.1, -0.4)).scaled(Vector3(1.5, 0.7, 2.0)), Vector3(3, -4, 5))
	var buf := PackedFloat32Array()
	buf.resize(2 * EcoMM.STRIDE)
	EcoMM.put(buf, EcoMM.STRIDE, tr)
	var i := EcoMM.STRIDE
	var back := Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
	ok(back.is_equal_approx(tr), "трансформ читается обратно")
	var zero := true
	for k in EcoMM.STRIDE:
		zero = zero and buf[k] == 0.0
	ok(zero, "первый экземпляр не тронут")
	ok(FernView.transform_at(buf, 1).is_equal_approx(tr), "как читает волнолист")
	var buf2 := PackedFloat32Array()
	buf2.resize(EcoMM.STRIDE)
	EcoMM.put_basis(buf2, 0, tr.basis, tr.origin)
	ok(buf2 == buf.slice(EcoMM.STRIDE), "put_basis = put")


func test_instance_on_world_layer() -> void:
	var root := Node3D.new()
	var mi := EcoMM.instance(root, "Проба", BoxMesh.new(), 7, true, true)
	eq(mi.get_parent(), root)
	eq(mi.name, &"Проба")
	eq(mi.layers, OceanView.LAYER_WORLD)
	eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	eq(mi.multimesh.instance_count, 7)
	ok(mi.multimesh.use_colors and mi.multimesh.use_custom_data, "цвета и свои данные")
	eq(mi.custom_aabb, EcoMM.SHOAL_AABB)
	var still := EcoMM.instance(root, "Неподвижное", BoxMesh.new(), 1, false, false, false)
	eq(still.custom_aabb, AABB())
	ok(not still.multimesh.use_colors, "без цветов")
	root.free()


func test_tris() -> void:
	var v := PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 1), Vector3(1, 0, 0)])
	var n := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var m := EcoMM.tris(v, n, PackedColorArray([Color.RED, Color.RED, Color.RED]))
	eq(m.get_surface_count(), 1)
	var arr := m.surface_get_arrays(0)
	eq((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 3)
	eq((arr[Mesh.ARRAY_COLOR] as PackedColorArray).size(), 3)
	ok(EcoMM.tris(v, n).surface_get_arrays(0)[Mesh.ARRAY_COLOR] == null, "без цветов")
