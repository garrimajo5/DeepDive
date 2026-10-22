extends TestCase
## Плашка версии на экране (отладка): Main.version_text и узел «Версия» в интерфейсе.


func test_version_text_and_tag() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var t := main.version_text()
	ok(t.begins_with("v"), "строка версии начинается с v: %s" % t)
	ok(t.contains("dev") or t.contains("#"), "есть сборка — dev или #номер")
	ok(main.find_child("Версия", true, false) != null, "плашка версии есть в интерфейсе")
	main.queue_free()
	await frames(1)


## issue #399: CI пишет version.txt перед экспортом, но пресет «Android» берёт только ресурсы — без include_filter
## файл не попадал в APK и на телефоне было «v0.1 · dev».
func test_version_file_goes_into_apk() -> void:
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK, "пресеты экспорта читаются")
	var found := false
	for sec in cfg.get_sections():
		if cfg.get_value(sec, "name", "") == "Android":
			found = true
			var inc := str(cfg.get_value(sec, "include_filter", ""))
			var names: Array[String] = []
			for f in inc.split(",", false):
				names.append(f.strip_edges())
			ok("version.txt" in names, "version.txt в include_filter пресета Android (%s)" % inc)
			ok(not str(cfg.get_value(sec, "exclude_filter", "")).contains("version"), "и не исключён")
	ok(found, "пресет Android есть")
	var wf := FileAccess.get_file_as_string("res://.github/workflows/godot.yml")
	ok(wf.contains("> version.txt"), "CI пишет version.txt в корень проекта")
