extends TestCase
## Сканер биолога (js/game.js findScanTarget/completeScan): цели — NEAR с "scan": true, ближайшая неизученная первой,
## удержание 1,5 с изучает вид, сведения у изученного, сохранение видов, сонар не берёт цели только сканера (issue #85).

const SHIP := Vector3(0, -20, 0)


func _near(sp: String, d: float, sonar: bool = false) -> Dictionary:
	return EcoLink.near(sp, Species.called(sp), SHIP + Vector3(d, 0, 0), SHIP, 1.0, sonar, true)


func test_target_nearest_unscanned() -> void:
	var s := Scanner.new()
	s.take([])
	ok(s.target.is_empty(), "целей нет")
	eq(s.label(), "Сканер: целей нет", "подпись без целей")
	s.take([_near("pred", 40.0), _near("fish", 12.0), EcoLink.near("fish", "x", SHIP, SHIP, 1.0, true, false)])
	eq(s.targets.size(), 2, "только цели сканера")
	eq(s.target["species"], "fish", "ближняя")
	eq(s.label(), "Цель: Неизвестный вид · 12 м", "до сканирования — неизвестный вид")
	s.scanned["fish"] = true
	s.take([_near("pred", 40.0), _near("fish", 12.0)])
	eq(s.target["species"], "pred", "изученную пропускает — дальняя неизученная")
	s.scanned["pred"] = true
	s.take([_near("pred", 40.0), _near("fish", 12.0)])
	eq(s.target["species"], "fish", "все изучены — ближняя")
	eq(s.target_name(), "Светляк-полосник", "настоящее имя")


func test_hold_scans_and_decays() -> void:
	var s := Scanner.new()
	var said: Array[String] = []
	var changes := [0]
	s.message.connect(func(t: String) -> void: said.append(t))
	s.changed.connect(func() -> void: changes[0] += 1)
	s.take([_near("fish", 10.0)])
	for i in 10:
		s.hold(0.1)
		s.update(0.1)
	near(s.progress, 1.0 / Scanner.SCAN_TIME, 1e-6, "за 1 с — две трети")
	ok(s.label().begins_with("Сканирую 66"), s.label())
	s.update(0.1)
	near(s.progress, 1.0 / Scanner.SCAN_TIME - 0.2, 1e-6, "отпустил — спадает вдвое быстрее")
	for i in 20:
		s.hold(0.1)
		s.update(0.1)
	ok(s.is_scanned("fish"), "вид изучен")
	eq(said, ["Новый вид: Светляк-полосник"], "сообщение один раз")
	eq(changes[0], 1, "сохранить")
	s.press()
	ok(said[-1].begins_with("Светляк-полосник: Мелкая рыба"), "сведения: %s" % said[-1])
	eq(s.screen_lines()[-1], "Видов изучено: 1 из %d" % Species.count(), "экран: счёт видов")
	s.take([])
	s.press()
	eq(said[-1], "Сканер: рядом никого ближе 80 м", "никого")


func test_save_species() -> void:
	var smp := Samples.new(func(_x: float, _z: float) -> float: return -60.0)
	var s := Scanner.new()
	s.scanned["pred"] = true
	s.scanned["fish"] = true
	var snap := SaveGame.snapshot(smp, s)
	eq(snap["species"]["fish"], {"scanned": true, "seen": []}, "формат js/save.js")
	eq(snap["species"]["grazer"]["scanned"], false, "неизученный")
	var back := Scanner.new()
	var data: Variant = JSON.parse_string(JSON.stringify(snap))
	data["species"]["nope"] = {"scanned": true}
	ok(SaveGame.apply(data, smp, back), "читается")
	eq(back.list(), ["fish", "pred"] as Array[String], "виды вернулись, незнакомый пропущен")
	ok(SaveGame.apply({"v": 1, "cargo": []}, smp, back), "старый файл без видов читается")
	eq(back.scanned.size(), 0, "без видов — ничего не изучено")


func test_sonar_skips_scan_only() -> void:
	var so := Sonar.new()
	so.ping(0.0, 1.0)
	so.take_contacts([_near("fish", 10.0, false), _near("pred", 20.0, true)], SHIP)
	eq(so.blips.size(), 1, "цель только для сканера — не отметка")
	eq(so.blips[0]["species"], "pred", "отметка сонара осталась")


func test_lab_journal_counts_species() -> void:
	var smp := Samples.new(func(_x: float, _z: float) -> float: return -60.0)
	eq(Lab.journal_lines(smp, 3)[1], "Видов изучено: 3 из %d" % Species.count(), "журнал лаборатории")


func test_scene_scanner_post() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.walker.x = 3.85
	main.walker.z = -2.0
	main.step(1.0 / 30.0)
	eq(main.overlay.action_label, "Сканер", "кнопка «Сканер»")
	main.step(1.0 / 30.0)
	near(main.eco_ship.scan_range, Scanner.RANGE, 1e-6, "у поста мир шлёт цели")
	print("цели сканера: ", main.scanner.targets.size())
	ok(not main.scanner.target.is_empty(), "у старта рядом есть кого сканировать")
	var r := main.overlay.router
	r.begin(5, r.layout.action.c)
	for i in 50:
		main.step(1.0 / 30.0)
	r.end(5)
	main.step(1.0 / 30.0)
	eq(main.scanner.scanned.size(), 1, "держали 1,7 с — вид изучен")
	ok(main.message.text.begins_with("Новый вид: "), main.message.text)
	ok(main.bridge.scanner_text.text.contains("Видов изучено: 1"), "экран сканера")
	ok(main.eco.world.scanned.call(main.scanner.list()[0]), "мир знает изученный вид")
	main.walker.x = 0.0
	main.walker.z = -3.0
	main.step(1.0 / 30.0)
	near(main.eco_ship.scan_range, 0.0, 1e-6, "отошёл — сканер выключен")
	ok(main.scanner.target.is_empty(), "целей нет")
	main.queue_free()
	await frames(1)
