extends TestCase
## Свет внутри корабля по ART-064 (CabinLight, `docs/concept-art/svet-vnutri.md`): семь огней по таблице, аварийная
## огибающая при пробоине, свет реактора от реактора, мигание поверх.


func test_table_matches_json() -> void:
	var data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/concept-art/svet-vnutri.json"))
	var all := CabinLight.lamps()
	eq(all.size(), 7, "семь огней")
	eq(data.size(), 7, "в таблице художника — семь")
	for i in data.size():
		var d: Dictionary = data[i]
		var l := all[i]
		eq(l.id, d.id, "порядок")
		ok(l.pos.is_equal_approx(Vector3(d.pos[0], d.pos[1], d.pos[2])), "%s: место" % l.id)
		ok(l.color.is_equal_approx(Color(d.color)), "%s: цвет" % l.id)
		near(l.energy, d.energy, 1e-6, "%s: энергия" % l.id)
		near(l.range, d.range, 1e-6, "%s: дальность" % l.id)
		near(l.attenuation, d.attenuation, 1e-6, "%s: затухание" % l.id)
		eq(ShipLayout.room_at(l.pos.z), l.room, "%s: в своём отсеке" % l.id)
	eq(CabinLight.of(true).size() + CabinLight.of(false).size() + 1, 7, "мостик + отсеки + реактор")


func test_alarm_envelope() -> void:
	var b1 := CabinLight.lamps()[0]   # опора мостика
	var b2 := CabinLight.lamps()[1]   # рабочий мостика
	var c1 := CabinLight.lamps()[2]
	near(CabinLight.pulse(0.0), 0.0, 1e-6, "ритм начинается внизу")
	near(CabinLight.pulse(0.6), 1.0, 1e-6, "вершина через полпериода")
	near(CabinLight.pulse(1.2), 0.0, 1e-6, "период 1,2 с")
	near(CabinLight.energy(b2, -1, 0.3, 1.0), 1.65, 1e-6, "без пробоины — по таблице")
	eq(CabinLight.color(b2, -1), b2.color, "без пробоины — свой цвет")
	var bridge := ShipLayout.Room.BRIDGE
	eq(CabinLight.color(b1, bridge), CabinLight.SAFE_ALARM, "опора — холодная")
	near(CabinLight.energy(b1, bridge, 0.0, 1.0), 1.8 * 0.48, 1e-6, "опора ровная")
	near(CabinLight.energy(b1, bridge, 0.6, 1.0), 1.8 * 0.48, 1e-6, "опора не пульсирует")
	eq(CabinLight.color(b2, bridge), CabinLight.AMBER, "тревога — янтарь")
	near(CabinLight.energy(b2, bridge, 0.0, 1.0), 1.65 * 0.35, 1e-6, "в отсеке пробоины — внизу 0,35")
	near(CabinLight.energy(b2, bridge, 0.6, 1.0), 1.65, 1e-6, "вверху — полная")
	near(CabinLight.energy(c1, bridge, 0.0, 1.0), 1.05 * 0.40, 1e-6, "в других отсеках — 0,40")
	near(CabinLight.energy(c1, bridge, 0.6, 1.0), 1.05 * 0.60, 1e-6, "…до 0,60")
	near(CabinLight.energy(c1, bridge, 0.6, 0.5), 1.05 * 0.30, 1e-6, "мигание умножает итог")
	for l in CabinLight.lamps():
		var c := CabinLight.color(l, bridge)
		ok(c.r - c.g < 0.35, "%s: без красного (#129)" % l.id)


func test_reactor_light() -> void:
	var r := Reactor.new()
	var r1 := CabinLight.reactor()
	near(CabinLight.reactor_energy(r), 0.55, 1e-6, "реактор светит по таблице")
	eq(CabinLight.reactor_color(r), r1.color, "голубой")
	r.hot = true
	r.heat = 100.0
	ok(CabinLight.reactor_color(r).is_equal_approx(CabinLight.HOT), "перегрев — к #FF8A3C")
	r.scram = 1.0
	eq(CabinLight.reactor_energy(r), 0.0, "SCRAM гасит")


func test_scene_lights_and_breach() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var all: Array[OmniLight3D] = []
	all.append_array(main.bridge.lamps)
	all.append_array(main.rooms.lamps)
	all.append(main.rooms.reactor_light)
	eq(all.size(), 7, "семь рабочих огней")
	for o in all:
		eq(o.light_cull_mask, OceanView.LAYER_SHIP, "%s: слой корабля" % o.name)
		ok(not o.shadow_enabled, "%s: без теней" % o.name)
	ok(main.rooms.reactor_light.global_position.is_equal_approx(main.ship.to_global(CabinLight.reactor().pos)),
		"свет реактора — в точке R1")
	main.step(0.1)
	near(main.bridge.lamps[1].light_energy, 1.65, 1e-5, "мостик ровный")
	main.on_eco_event({"type": EcoLink.HIT, "damage": 0.12, "by": "Серпохвост"})
	ok(main.breach.active.room == ShipLayout.Room.BRIDGE, "пробоина на мостике")
	var seen := {}
	for i in 12:
		main.step(0.1)
		var b2 := main.bridge.lamps[1]
		ok(b2.light_color.is_equal_approx(CabinLight.AMBER), "B2 — янтарь")
		near(b2.light_energy, CabinLight.energy(CabinLight.lamps()[1], ShipLayout.Room.BRIDGE, main.breach.time),
			1e-5, "B2 по огибающей")
		seen[snappedf(b2.light_energy, 0.1)] = true
		near(main.bridge.lamps[0].light_energy, 1.8 * 0.48, 1e-5, "B1 — ровная опора")
	ok(seen.size() >= 4, "B2 пульсирует: %s" % [seen.keys()])
	eq(main.breach_view.find_children("*", "OmniLight3D", true, false).filter(func(l: Light3D) -> bool: return l.visible).size(),
		0, "пустой лампы тревоги нет — аварию ведут огни корабля (#842)")
	main.breach.hold(10.0)
	main.step(0.1)
	ok(main.breach.active == null, "заварили")
	near(main.bridge.lamps[1].light_energy, 1.65, 1e-5, "свет снова обычный")
	ok(main.bridge.lamps[1].light_color.is_equal_approx(CabinLight.lamps()[1].color), "и цвет свой")
	main.queue_free()
	await frames(1)


func test_materials_envelope() -> void:
	near(CabinLight.plafond_energy(-1, 0.3, 1.0), 0.75, 1e-6, "плафоны — 0,75")
	near(CabinLight.plafond_energy(-1, 0.3, 0.5), 0.375, 1e-6, "× lamp_k")
	eq(CabinLight.plafond_tint(-1), Color.WHITE, "рисунок как есть")
	eq(CabinLight.plafond_tint(2), CabinLight.AMBER, "авария — янтарь")
	near(CabinLight.plafond_energy(2, 0.0, 1.0), 0.22, 1e-6, "внизу 0,22")
	near(CabinLight.plafond_energy(2, 0.6, 1.0), 0.70, 1e-6, "вверху 0,70")
	near(CabinLight.ring_energy(-1), 0.7, 1e-6, "кольцо 0,7")
	near(CabinLight.ring_energy(0, 0.5), 0.14, 1e-6, "в аварии 0,28 × k")
	eq(BridgeView.plafond_tiles(0.4, 0.28), Vector2(1, 1), "панель мостика — один рисунок")
	eq(BridgeView.plafond_tiles(0.15, 5.4), Vector2(1, 14), "полоса — модулем 0,4 м")
	var tex: Image = load("res://textures/svet/plafon.png").get_image()
	eq(tex.get_size(), Vector2i(256, 256), "текстура 256²")
	ok(tex.get_pixel(2, 2).get_luminance() < 0.02, "за альфой — тёмный носитель")
	var core := 0.0
	for x in range(100, 156, 4):
		core = maxf(core, tex.get_pixel(x, 120).get_luminance())
	ok(core > 0.5, "ядро светится: %.2f" % core)


func test_scene_materials() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var bm := main.bridge.plafond_mat
	var rm := main.rooms.plafond_mat
	ok(bm != null and rm != null and bm != rm, "у мостика и отсеков свои рассеиватели")
	ok(bm.emission_texture != null and bm.albedo_texture == bm.emission_texture, "текстура плафона — цвет и свечение")
	main.step(0.1)
	near(bm.emission_energy_multiplier, 0.75, 1e-5, "мостик светится 0,75")
	near(rm.emission_energy_multiplier, 0.75, 1e-5, "отсеки — тоже")
	near(main.rooms._ring_mats[0].emission_energy_multiplier, 0.7, 1e-5, "кольцо 0,7")
	near(main.rooms._rod_mat.emission_energy_multiplier, CabinLight.ROD_E, 1e-5, "стержень 0,45")
	var wheel := main.rooms.valve_wheel.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var wm := wheel.material_override as StandardMaterial3D
	ok(wm != null and wm.albedo_color.is_equal_approx(CabinLight.WHEEL) and wm.albedo_texture == null, "маховик — матовый металл")
	main.on_eco_event({"type": EcoLink.HIT, "damage": 0.12, "by": "Серпохвост"})
	for i in 5:
		main.step(0.1)
		ok(bm.emission.is_equal_approx(CabinLight.AMBER), "плафоны — янтарь")
		near(bm.emission_energy_multiplier, CabinLight.plafond_energy(0, main.breach.time), 1e-5, "по ритму")
		near(main.rooms._ring_mats[0].emission_energy_multiplier, 0.28, 1e-5, "кольцо — ровная опора")
	main.reactor.scram = 1.0
	main.step(0.1)
	eq(main.rooms._rod_mat.emission_energy_multiplier, 0.0, "SCRAM гасит стержень")
	main.queue_free()
	await frames(1)
