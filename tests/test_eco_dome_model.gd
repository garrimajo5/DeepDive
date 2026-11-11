extends TestCase
## Модель купольника MOD-022 (приёмка PR #1574, заказ #920; концепт ART-081 — `docs/concept-art/kupolnik.md`), с ANIM-004
## — на скелете (`models/kupolnik-anim.glb`, скелет и клипы — `test_eco_dome_anim`): одна сетка и один материал,
## габарит 3 × 1,8 × 1,2 м ±10 %, перед в −Z, pivot — центр низа, ≤ 8 000 треугольников, матовая (metallic 0),
## фотофоры — маской emissive.

const PATH := "res://models/kupolnik-anim.glb"


func _model() -> Node3D:
	var scene: PackedScene = load(PATH)
	return scene.instantiate()


func _mesh(n: Node) -> MeshInstance3D:
	return n.find_children("*", "MeshInstance3D", true, false)[0]


func test_one_mesh() -> void:
	var n := _model()
	eq(n.find_children("*", "MeshInstance3D", true, false).size(), 1, "одна сетка")
	var mi := _mesh(n)
	eq(mi.mesh.get_surface_count(), 1, "один материал")
	var tris: int = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	ok(tris <= 8000, "треугольников %d ≤ 8000" % tris)
	n.free()


func test_size_and_pivot() -> void:
	var n := _model()
	var mi := _mesh(n)
	var box: AABB = mi.transform * mi.mesh.get_aabb()
	near(box.size.x, 1.8, 0.18, "ширина 1,8 м")
	near(box.size.y, 1.2, 0.12, "высота 1,2 м")
	near(box.size.z, 3.0, 0.3, "длина 3 м")
	near(box.position.y, 0.0, 0.01, "pivot — низ")
	near(box.get_center().x, 0.0, 0.05, "pivot — центр по ширине")
	n.free()


## Захваты — спереди (−Z), сифоны — сзади: нижняя треть высоты (захваты висят под куполом) — ближе к носу.
func test_graspers_front() -> void:
	var n := _model()
	var mi := _mesh(n)
	var pts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var low := 0.0
	var cnt := 0
	for p in pts:
		if p.y < 0.3:
			low += p.z
			cnt += 1
	ok(cnt > 0, "есть низ (захваты)")
	ok(low / maxf(cnt, 1) < -0.5, "низ модели — у носа (−Z): %.2f" % (low / maxf(cnt, 1)))
	n.free()


func test_matte_with_glow_mask() -> void:
	var n := _model()
	var mat := _mesh(n).mesh.surface_get_material(0) as StandardMaterial3D
	if not ok(mat != null, "материал StandardMaterial3D"):
		n.free()
		return
	near(mat.metallic, 0.0, 1e-3, "metallic 0")
	ok(mat.emission_enabled, "свечение включено")
	ok(mat.emission_texture != null, "фотофоры — маской emissive")
	n.free()


## По ANIM-004 (#1601): прежняя модель без скелета не лежит в проекте (лишние 3,5 МБ в APK), сцена грузит модель
## на скелете.
func test_no_static_model() -> void:
	for f in DirAccess.get_files_at("res://models"):
		if f.begins_with("kupolnik") and not f.begins_with("kupolnik-anim"):
			ok(false, "лишний файл купольника models/%s" % f)
	eq(DomeView.GLB, PATH, "сцена грузит модель на скелете")
