extends TestCase
## Модели художника в models/: каждая загружается в Godot, есть меш, файл не больше 5 МБ.


func test_every_glb_loads() -> void:
	var n := 0
	for f in DirAccess.get_files_at("res://models"):
		if not f.ends_with(".glb"):
			continue
		n += 1
		var path := "res://models/" + f
		ok(FileAccess.get_file_as_bytes(path).size() <= 5 * 1024 * 1024, "%s не больше 5 МБ" % f)
		var scene: PackedScene = load(path)
		if not ok(scene != null, "%s загружается" % f):
			continue
		var node := scene.instantiate()
		ok(not node.find_children("*", "MeshInstance3D", true, false).is_empty(), "%s: есть меш" % f)
		node.free()
	ok(n >= 12, "моделей не меньше 12 (MOD-001…007)")
