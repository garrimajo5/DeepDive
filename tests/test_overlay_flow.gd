extends TestCase
## Наложения поверх игры (#758): подсказки, карточка роли, связь и рация шагает `OverlayFlow` (`main.overlay_flow`),
## у `Main` — только пересылка `comms_area`. Пауза гасит все наложения сразу и обрывает передачу рации.

const DT := 1.0 / 30.0

var main: Main


func after() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_scene_overlay_flow() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	ok(main.overlay_flow is OverlayFlow and main.overlay_flow.main == main, "наложения — поле main.overlay_flow")
	for f in ["_tutorial_step", "_tutorial_hide", "_card_step", "_comms_step", "_overlay_hidden", "_radio_step",
			"_radio_sight"]:
		ok(not main.has_method(f), "%s больше не в Main" % f)
	eq(main.comms_area(), main.overlay_flow.comms_area(), "comms_area — пересылка")
	ok(not main.overlay_flow.hidden(), "в игре плашки не скрыты")
	main.on_eco_event(EcoLink.voice(Crew.Role.ENGINEER, "Сбросьте ход, перегрев"))
	for i in 10:
		main.step(DT)
	ok(main.comms.a > 0.0 and main.comms_panel.visible, "плашка связи показана шагом наложений")
	ok(not main.overlay.router.blocks.is_empty(), "кнопка связи не крутит взгляд")
	main.back_pressed()
	main.step(DT)
	ok(main.pause.open and main.overlay_flow.hidden(), "под паузой наложения скрыты")
	eq(main.comms.a, 0.0, "плашка связи погасла сразу")
	ok(not main.comms_panel.visible, "и панель")
	ok(main.overlay.router.blocks.is_empty(), "места кнопок сняты")
