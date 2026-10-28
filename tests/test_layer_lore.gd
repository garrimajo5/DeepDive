extends TestCase
## Знания слоя 1 (#825): факты ставит только своё событие, гибель и загрузка их не сбрасывают, сохранение — ключ
## "lore", в коопе — маска в кадре «k»; уход вниз у 10 не требует диагностики.

const TEST_PATH := "user://test_lore.json"


func _flat(_x: float, _z: float) -> float:
	return -40.0


func after() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func test_learn_once() -> void:
	var l := LayerLore.new()
	var n := [0]
	l.changed.connect(func() -> void: n[0] += 1)
	ok(not l.knows(LayerLore.K2), "в начале ничего не известно")
	ok(l.learn(LayerLore.K2), "запись К-2 — новое")
	ok(not l.learn(LayerLore.K2), "второй раз — не новое")
	ok(not l.learn("remont"), "чужой ключ не ставится")
	ok(l.knows(LayerLore.K2), "знает")
	eq(n[0], 1, "одно изменение — один сигнал")
	for k in LayerLore.KEYS:
		if k != LayerLore.K2:
			ok(not l.knows(k), "%s сам не ставится" % k)


func test_diagnostics_separate_and_not_required() -> void:
	var l := LayerLore.new()
	eq(l.unread_diagnostics().size(), 3, "три факта диагностики отдельно")
	l.learn(LayerLore.D07_RELAY)
	eq(l.unread_diagnostics(), [LayerLore.D07_RETURN, LayerLore.D07_AUTH], "прочитан один — два остались")
	ok(not l.knows(LayerLore.AUTH07), "авторизация не приходит с диагностикой")
	ok(l.may_descend(), "уход вниз без диагностики разрешён")
	for k in LayerLore.DIAGNOSTICS:
		l.learn(k)
	ok(l.unread_diagnostics().is_empty() and l.may_descend(), "всё прочитано")


func test_snapshot_round_trip() -> void:
	var l := LayerLore.new()
	l.learn(LayerLore.FIELD08)
	l.learn(LayerLore.INTRO)
	var m := LayerLore.new()
	m.apply(JSON.parse_string(JSON.stringify(l.snapshot())))
	eq(m.facts, [LayerLore.FIELD08, LayerLore.INTRO], "через JSON — те же, в том же порядке")
	m.apply(null)
	ok(m.facts.is_empty(), "старое сохранение — знаний нет")
	m.apply(["k2", "k2", "remont", 5])
	eq(m.facts, [LayerLore.K2], "повтор и чужие ключи пропущены")


func test_pack_for_net() -> void:
	var host := LayerLore.new()
	host.learn(LayerLore.D07_AUTH)
	host.learn(LayerLore.BACK)
	var guest := LayerLore.new()
	ok(guest.apply_net(host.pack()), "гость принял знания хоста")
	eq(guest.pack(), host.pack(), "те же")
	ok(guest.knows(LayerLore.BACK) and guest.knows(LayerLore.D07_AUTH), "оба факта")
	ok(not guest.apply_net(host.pack()), "то же — без изменений")
	ok(not guest.apply_net(null), "кадр без «k» — знания остаются")
	ok(guest.knows(LayerLore.BACK), "остались")
	var rev := guest.rev
	ok(guest.apply_net(0), "хост начал новую экспедицию")
	ok(guest.facts.is_empty() and guest.rev > rev, "у гостя тоже пусто")


func test_save_file_and_reset() -> void:
	var l := LayerLore.new()
	l.learn(LayerLore.SHELL03)
	var save := SaveGame.new()
	save.path = TEST_PATH
	save.lore = l
	ok(save.save(Samples.new(_flat)), "записано")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	eq(raw["lore"], ["shell03"], "ключ lore в файле")
	var m := LayerLore.new()
	var load := SaveGame.new()
	load.path = TEST_PATH
	load.lore = m
	ok(load.load_into(Samples.new(_flat)), "прочитано")
	ok(m.knows(LayerLore.SHELL03), "знание из файла")
	load.reset(Samples.new(_flat))
	ok(m.facts.is_empty(), "«Сбросить сохранение» — знания с нуля")


func test_old_file_without_lore() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string('{"v":1,"cargo":[],"got":[]}')
	f.close()
	var m := LayerLore.new()
	m.learn(LayerLore.K2)
	var load := SaveGame.new()
	load.path = TEST_PATH
	load.lore = m
	ok(load.load_into(Samples.new(_flat)), "старый файл принят")
	ok(m.facts.is_empty(), "знаний в нём нет")


func test_scene_wreck_keeps_lore_and_saves() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	ok(main.lore is LayerLore and main.save.lore == main.lore, "знания — main.lore, сохраняются")
	main.lore.learn(LayerLore.K2)
	ok(main.save.dirty, "новое знание отмечает запись")
	main._restart()   # гибель и новый забег (как после «Корпус разрушен»)
	ok(main.lore.knows(LayerLore.K2), "гибель не сбрасывает знания")
	main.queue_free()
	await frames(1)
