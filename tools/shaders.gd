extends SceneTree
## Разные шейдеры сцены (ShaderKey, issue #159): сколько у корабля и у живого мира, кто их делит.
## godot --headless --path . -s tools/shaders.gd


func _initialize() -> void:
	SaveGame.default_path = ""
	Main.intro = false
	Main.menu = false
	_go.call_deferred()


func _go() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.open_silt()      # облака ила и пробоина — их материалы создаются заранее, но так видно всё
	main.open_breach(0)
	main.step(0.1)
	var ship := ShaderKey.collect(main, main.eco)
	var eco := ShaderKey.collect(main.eco)
	var both := 0
	for k in ship:
		if eco.has(k):
			both += 1
	print("Шейдеров: корабль %d, живой мир %d, общих %d, всего %d" % [ship.size(), eco.size(), both,
		ship.size() + eco.size() - both])
	for part in [["корабль", ship], ["живой мир", eco]]:
		print("— ", part[0])
		for k in part[1]:
			print("  ", ", ".join(PackedStringArray(part[1][k])), "   ", k.get_slice("|", 0))
	quit(0)
