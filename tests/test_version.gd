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
