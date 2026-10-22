extends TestCase
## Плашка строки состояния по своему тексту: после длинного сообщения она снова ужимается до коротких строк
## (отчёт тестера 2026-10-22-1430, п. 2: под тремя строками пустая полоса ещё на три).

var main: Main


func before() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)


func after() -> void:
	main.queue_free()
	await frames(1)


func test_plate_shrinks_after_long_message() -> void:
	var was := tree.root.size
	tree.root.size = Vector2i(1600, 720)
	main.step(1.0 / 30.0)
	var short_h := main.hint.get_combined_minimum_size().y
	main.say("Штурвал занят: Марина · стеклоуст на корпусе тянет энергию · перегрев реактора — сброс у кормового люка · " +
			"ил у носа — сонар вязнет · пробоина в трюме — варить у правого борта · заряд на исходе")
	main.step(1.0 / 30.0)
	await frames(1)
	var long_h := main.hint.size.y
	ok(long_h > short_h + 20.0, "длинное сообщение — плашка выше (%.0f > %.0f)" % [long_h, short_h])
	for i in 150:   # 5 с — сообщение (4,2 с) сошло
		main.step(1.0 / 30.0)
	await frames(1)
	var min_h := main.hint.get_combined_minimum_size().y
	ok(min_h < long_h - 20.0, "строк снова меньше (%.0f)" % min_h)
	near(main.hint.size.y, min_h, 0.5, "плашка ужалась по тексту, без пустой полосы")
	near(main.status_rect().size.y, main.hint.size.y, 0.5, "status_rect — та плашка, что на экране")
	tree.root.size = was
