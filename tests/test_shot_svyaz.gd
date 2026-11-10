extends TestCase
## Ключ снимка svyaz_text= (#1350): своя реплика на плашке связи ART-040 — длину новых строк проверять без правки
## tools/shot.gd. Без ключа — прежние образцы своего и подделки.

const ShotSetup := preload("res://tools/shot_setup.gd")
const LONG := "Слышу удары по корпусу у кормы, проверьте трюм и шлюз, пока не поздно"

var main: Main


func after() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_line_defaults_and_own() -> void:
	eq(ShotSetup.svyaz_line({"svyaz": "1"}), "Сбросьте ход, перегрев", "свой — прежний образец")
	eq(ShotSetup.svyaz_line({"svyaz": "fake"}), "Дайте импульс сонара", "подделка — прежний образец")
	eq(ShotSetup.svyaz_line({"svyaz": "wrong", "svyaz_text": " " + LONG + " "}), LONG, "своя строка, без краевых пробелов")
	eq(ShotSetup.svyaz_line({"svyaz": "1", "svyaz_text": "  "}), "Сбросьте ход, перегрев", "пустая — образец")
	ok(ShotSetup.svyaz_fake({"svyaz": "silent"}) and not ShotSetup.svyaz_fake({"svyaz": "match"}), "кто подделка")


func test_scene_own_text_on_plate() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ShotSetup.svyaz(main, {"svyaz": "wrong", "svyaz_text": LONG})
	ok(main.comms_panel.visible, "плашка на экране")
	eq(main.comms.cur.text, LONG, "на плашке своя реплика")
	ok(main.comms.cur.fake, "wrong — подделка")
	eq(main.comms.state, Comms.Ask.WRONG, "состояние из svyaz=")
