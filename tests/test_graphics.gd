extends TestCase
## Графика Forward Mobile: свет сквозь лёд отбрасывает тени, окружение — свечение биолюма и SSAO.
## Держим включёнными — тест ловит случайное отключение (на Mobile видно вживую, в облачном снимке SSAO/теней нет).


func test_world_graphics_on() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(main.ocean.sun.shadow_enabled, "свет сквозь лёд отбрасывает тени")
	ok(main.env.glow_enabled, "свечение биолюма включено")
	ok(main.env.ssao_enabled, "SSAO включено")
	ok(main.env.ssil_enabled, "SSIL (отражённый свет) включено")
	main.queue_free()
	await frames(1)
