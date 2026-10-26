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
	eq(HullSound.hit_index("scrape", 0), -1, "о дно — не удар")
	eq(HullSound.for_hit(10, "scrape", 0)["path"], HullSound.SCRAPE, "о дно — скрежет")


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
	eq(s.last, HullSound.SCRAPE, "удар о дно — скрежет")
	main.queue_free()
	await frames(1)
