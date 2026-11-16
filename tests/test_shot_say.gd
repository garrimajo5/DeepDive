extends TestCase
## Ключ снимка say= (#1350, UX 15.11): своя строка в приборах на время снимка — длину новых сообщений проверяют
## настоящим шрифтом до встройки. Строка держится все кадры ожидания снимка и не уступает строке мира: первый же
## облачный снимок показал вместо неё «Папоротник-спираль разворачивает листья…».

const ShotSetup := preload("res://tools/shot_setup.gd")
const LINE := "Гнездо прочитано: створка откроется, когда купольник поднимет её"

var main: Main


func after() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_scene_line_on_status_and_stays() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	still_world(main)
	main.message.say("строка мира", Status.MESSAGE_SECONDS, true)
	main.message.say("ждущая строка мира", Status.MESSAGE_SECONDS, true)
	ShotSetup.say(main, {"say": "  " + LINE + " "})
	eq(main.message.text, LINE, "в приборах своя строка, без краевых пробелов")
	eq(main.message.next, "", "ждущая строка мира снята — не сменит её до снимка")
	ok(main.status_parts().has(LINE), "строка в частях строки состояния")
	main.on_eco_event(EcoLink.message("Папоротник-спираль разворачивает листья"))
	main.step(0.1)
	eq(main.message.text, LINE, "строка мира её не сменяет")
	eq(ShotSetup.say_line(main, {"say": LINE}), "SAY на приборах: «%s», %d знаков" % [LINE, LINE.length()], "строка лога")
	main.message.say("Хищник рядом", Status.MESSAGE_SECONDS, true, true)
	ok(ShotSetup.say_line(main, {"say": LINE}).begins_with("SAY ВНИМАНИЕ"), "перебила угроза — лог предупреждает")
	ShotSetup.say(main, {"say": LINE})
	eq(main.message.text, LINE, "повтор каждый кадр ожидания возвращает строку")
	for i in 100:   # 10 с мира: обычное сообщение (4,2 с) давно бы погасло
		main.step(0.1)
	eq(main.message.text, LINE, "держится до снимка")
	ok(main.status_parts().has(LINE), "и через 10 с — на приборах")


func test_empty_keeps_current_line() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.say("Вы за штурвалом")
	ShotSetup.say(main, {"say": "  "})
	eq(main.message.text, "Вы за штурвалом", "пустой ключ строку не трогает")
	ShotSetup.say(main, {})
	eq(main.message.text, "Вы за штурвалом", "без ключа — тоже")
