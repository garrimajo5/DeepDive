extends TestCase
## Звуки корабля SND-002 (#656): импульс сонара, удары по корпусу и скрежет (`HullSound`, `ShipSounds`).


func test_files_imported() -> void:
	for path in [HullSound.PING, HullSound.SCRAPE] + HullSound.HITS:
		var s := load(path) as AudioStream
		ok(s != null, "звук загружается: %s" % path)
		if s:
			ok(s.get_length() > 1.0 and s.get_length() < 4.0, "разовый 1–4 с: %s %.2f" % [path, s.get_length()])
			ok(not ("loop_mode" in s) or s.loop_mode == AudioStreamWAV.LOOP_DISABLED, "не петля: %s" % path)


func test_hit_volume_grows_with_damage() -> void:
	near(HullSound.hit_db(1), HullSound.HIT_SOFT_DB, 0.01, "слабый удар тише")
	near(HullSound.hit_db(HullSound.HIT_FULL), HullSound.HIT_DB, 0.01, "сильный — в полную")
	near(HullSound.hit_db(60), HullSound.HIT_DB, 0.01, "выше полной не громче")
	ok(HullSound.hit_db(5) < HullSound.hit_db(10), "громче с уроном")


func test_hits_alternate_scrape_separate() -> void:
	var seen := {}
	var prev := -1
	for n in 6:
		var i := HullSound.hit_index("Хватун", n)
		ok(i != prev, "подряд разные удары")
		prev = i
		seen[i] = true
	eq(seen.size(), HullSound.HITS.size(), "звучат все три удара")
	eq(HullSound.hit_index("scrape", 0), HullSound.Side.BELOW, "о дно — удар снизу (#656)")
	var d := HullSound.for_hit(10, "scrape", 0)
	eq(d["path"], HullSound.HITS[HullSound.Side.BELOW], "о дно — звук удара, не один скрежет")
	eq(d["tail"], HullSound.SCRAPE, "под ударом о дно — скрежет хвостом")
	ok(d["tail_db"] < d["db"], "скрежет тише удара")
	eq(HullSound.for_hit(10, "Хватун", 0)["tail"], "", "удар существа — без скрежета")


func test_side_of_hit() -> void:
	eq(HullSound.side(Vector3(0, 0, -8)), HullSound.Side.FRONT, "в нос — прямой")
	eq(HullSound.side(Vector3(2, 0.5, -8)), HullSound.Side.FRONT, "чуть сбоку от носа — прямой")
	eq(HullSound.side(Vector3(6, 0, -1)), HullSound.Side.SIDE, "в борт — косой")
	eq(HullSound.side(Vector3(-3, 1, 9)), HullSound.Side.SIDE, "в корму — косой")
	eq(HullSound.side(Vector3(0, -3, -8)), HullSound.Side.BELOW, "из-под днища — снизу")
	eq(HullSound.hit_index("Хватун", 5, Vector3(0, -3, 0)), HullSound.Side.BELOW, "точка удара важнее счётчика")
	eq(HullSound.hit_index("Хватун", 1, null), 1, "без точки — по счётчику")


func test_ice_knock_volume() -> void:
	ok(is_nan(HullSound.ice_db(0.5)), "медленный упор в лёд — молча")
	near(HullSound.ice_db(HullSound.ICE_KNOCK), HullSound.ICE_SOFT_DB, 0.01, "на пороге — тихо")
	near(HullSound.ice_db(Helm.Ship.CLIMB), HullSound.ICE_DB, 0.01, "на полном подъёме — громче")
	near(HullSound.ice_db(9.0), HullSound.ICE_DB, 0.01, "выше полного не громче")


func test_helm_knock_on_ice() -> void:
	var h := Helm.Ship.new()
	h.pos = Vector3(0, Helm.Ship.CEILING - 0.05, 0)
	h.in_vert = 1.0
	var best := 0.0
	var count := 0
	for i in 120:
		h.update(1.0 / 30.0)
		if h.knock > 0.0:
			best = maxf(best, h.knock)
			if h.knock >= HullSound.ICE_KNOCK:
				count += 1
	ok(best < HullSound.ICE_KNOCK, "из-подо льда медленно — удара нет (%.2f)" % best)
	h.pos = Vector3(0, -12.0, 0)
	h.vy = Helm.Ship.CLIMB
	count = 0
	for i in 200:
		h.update(1.0 / 30.0)
		if h.knock >= HullSound.ICE_KNOCK:
			count += 1
	eq(count, 1, "с разгона в лёд — один удар, упор дальше молчит")
	eq(h.pos.y, Helm.Ship.CEILING, "стоит подо льдом")


func test_scene_ping_and_hit_play_on_ship_bus() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var s := main.ship_sounds
	ok(s != null, "звуки корабля в сцене")
	eq(String(s.ping.bus), SoundMix.SHIP, "импульс — на шине «Корабль»")
	eq(String(s.hit.bus), SoundMix.SHIP, "удары — на шине «Корабль»")
	main.vitals.energy = 100.0
	main.ping_sonar()
	eq(s.last, HullSound.PING, "импульс сонара прозвучал")
	ok(s.ping.playing, "плеер импульса играет")
	near(s.ping.volume_db, HullSound.PING_DB, 0.01, "чистый импульс — своей громкостью")
	main.vitals.hit(8, "Хватун")
	ok(s.last in HullSound.HITS, "удар существа — звук удара")
	ok(s.hit.playing, "плеер ударов играет")
	main.vitals.hit_cd = 0.0
	main.vitals.scrape(10.0, 3.0)
	eq(s.last, HullSound.HITS[HullSound.Side.BELOW], "удар о дно — удар снизу")
	eq(s.last_tail, HullSound.SCRAPE, "и скрежет хвостом")
	ok(s.scrape.playing, "плеер скрежета играет")
	eq(String(s.scrape.bus), SoundMix.SHIP, "скрежет — на шине «Корабль»")
	main.vitals.hit_cd = 0.0
	main.on_eco_event(EcoLink.hit("Хватун", 0.05, main.helm.pos + Vector3(0, -4, 0)))
	eq(s.last, HullSound.HITS[HullSound.Side.BELOW], "существо из-под днища — удар снизу")
	eq(main.hit_local, null, "точка удара не залипает")
	main.helm.yaw = PI / 2.0   # нос смотрит в −X
	main.on_eco_event(EcoLink.hit("Хватун", 0.05, main.helm.pos + Vector3(-8, 0, 0)))
	eq(s.last, HullSound.HITS[HullSound.Side.FRONT], "в нос при повороте — прямой")
	main.vitals.hit(3, "Хватун")
	eq(s.last_tail, "", "удар существа без скрежета")
	s.play_ice(Helm.Ship.CLIMB)
	eq(s.last, HullSound.HITS[HullSound.Side.FRONT], "упор в лёд — прямой удар")
	near(s.hit.volume_db, HullSound.ICE_DB, 0.01, "громкость удара о лёд")
	main.queue_free()
	await frames(1)


## SND-003 (#657): петли струи и тревоги из файлов, разряд — один раз.
func test_snd003_files() -> void:
	for path in [HullSound.JET, HullSound.SIREN]:
		var s := load(path) as AudioStreamWAV
		ok(s != null, "петля загружается: %s" % path)
		if s:
			eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "петля вперёд: %s" % path)
			ok(s.get_length() > 2.0 and s.get_length() < 10.0, "петля 2–10 с: %s %.2f" % [path, s.get_length()])
	var z := load(HullSound.ZAP) as AudioStreamWAV
	ok(z != null and z.loop_mode != AudioStreamWAV.LOOP_FORWARD, "разряд — один раз")


func test_snd003_scene() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var bv := main.breach_view
	eq(bv.siren.stream, load(HullSound.SIREN), "тревога — из файла, не Synth")
	eq(bv.jet_sound.stream, load(HullSound.JET), "струя — из файла, не Synth")
	var s := main.ship_sounds
	eq(String(s.zap.bus), SoundMix.SHIP, "разряд — на шине «Корабль»")
	main.vitals.energy = 100.0
	main.fire_zap()
	eq(s.last, HullSound.ZAP, "разряд прозвучал")
	ok(s.zap.playing, "плеер разряда играет")
	s.last = ""
	main.step(0.5)
	main.fire_zap()   # копится (Zap.COOLDOWN) — разряда нет
	eq(s.last, "", "несостоявшийся разряд молчит")
	main.queue_free()
	await frames(1)


## Петля скрежета, пока корабль трётся о дно на ходу (#656, PR #700).
func test_rub_volume() -> void:
	ok(is_nan(HullSound.rub_db(0.0)), "стоим — молча")
	ok(is_nan(HullSound.rub_db(HullSound.RUB_SPEED - 0.05)), "ползком — молча")
	near(HullSound.rub_db(HullSound.RUB_SPEED), HullSound.RUB_SOFT_DB, 0.01, "на пороге — тихо")
	near(HullSound.rub_db(HullSound.RUB_FULL), HullSound.RUB_DB, 0.01, "на ходу — в полную")
	near(HullSound.rub_db(9.0), HullSound.RUB_DB, 0.01, "быстрее не громче")
	ok(HullSound.rub_db(1.5) < HullSound.rub_db(2.5), "громче с ходом")


func test_helm_rub_on_floor() -> void:
	var h := Helm.Ship.new()
	h.ground = func(_x: float, _z: float) -> float: return -60.0
	var floor_y := -60.0 + Helm.Ship.CLEARANCE
	h.pos = Vector3(0, floor_y, 0)
	h.in_thrust = 1.0
	for i in 90:
		h.update(1.0 / 30.0)
	ok(h.rub > HullSound.RUB_SPEED, "лежим на дне и идём — трёмся (%.2f)" % h.rub)
	near(h.rub, absf(h.speed), 0.001, "трение — по ходу")
	h.pos.y = floor_y + 2.0
	h.update(1.0 / 30.0)
	eq(h.rub, 0.0, "над дном — не трёмся")
	h.reset()
	eq(h.rub, 0.0, "сброс — не трёмся")


func test_scene_rub_loop() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var s := main.ship_sounds
	eq(String(s.rub.bus), SoundMix.SHIP, "петля скрежета — на шине «Корабль»")
	var w := s.rub.stream as AudioStreamWAV
	ok(w != null and w.loop_mode == AudioStreamWAV.LOOP_FORWARD, "скрежет о дно — по кругу")
	ok(w != null and w.loop_end > int(w.mix_rate), "петля — на всю запись")
	var tail := load(HullSound.SCRAPE) as AudioStreamWAV
	eq(tail.loop_mode, AudioStreamWAV.LOOP_DISABLED, "хвост удара о дно остаётся разовым")
	ok(not s.rub.playing, "над дном молчит")
	s.set_rub(HullSound.RUB_FULL, 0.05)
	ok(s.rub.playing, "трёмся — петля играет")
	ok(s.rub.volume_db < HullSound.RUB_DB - 1.0, "поднимается плавно")
	s.set_rub(HullSound.RUB_FULL, HullSound.RUB_FADE)
	near(s.rub.volume_db, HullSound.RUB_DB, 0.01, "на ходу — в полную")
	s.set_rub(0.0, HullSound.RUB_FADE / 2.0)
	ok(s.rub.playing, "оторвались — спадает, не обрывается")
	ok(s.rub.volume_db < HullSound.RUB_DB, "тише")
	s.set_rub(0.0, HullSound.RUB_FADE)
	ok(not s.rub.playing, "спала — петля стоит")
	main.helm.pos.y = Seabed.height(main.helm.pos.x, main.helm.pos.z) + Helm.Ship.CLEARANCE - 1.0
	main.helm.speed = 2.5
	main.step(1.0 / 30.0)
	ok(main.helm.rub > HullSound.RUB_SPEED, "в игре: на дне на ходу — трёмся (%.2f)" % main.helm.rub)
	main.step(HullSound.RUB_FADE)
	ok(s.rub.playing, "в игре: петля скрежета играет")
	main.queue_free()
	await frames(1)
