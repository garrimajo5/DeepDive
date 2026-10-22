extends TestCase
## Графика Forward Mobile: свет сквозь лёд отбрасывает тени, свечение биолюма, тонмаппинг ACES и цветокоррекция
## глубины. Держим включёнными — тест ловит случайное отключение (на Mobile видно вживую; SSAO/SSIL на Mobile нет,
## поэтому их не включаем — «вес» дают тени и шейдеры «героев»).


func test_world_graphics_on() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(main.ocean.sun.shadow_enabled, "свет сквозь лёд отбрасывает тени")
	ok(main.env.glow_enabled, "свечение биолюма включено")
	eq(main.env.tonemap_mode, Environment.TONE_MAPPER_ACES, "тонмаппинг ACES")
	ok(main.env.adjustment_enabled, "цветокоррекция глубины включена")
	# SSAO/SSIL на Forward Mobile не работают — их не включаем, чтобы не вводить в заблуждение и не спамить варнингами
	ok(not main.env.ssil_enabled, "SSIL выключен (на Mobile не поддерживается)")
	main.queue_free()
	await frames(1)
