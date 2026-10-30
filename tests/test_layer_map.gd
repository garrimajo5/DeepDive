extends TestCase
## Карта слоя 1 (#821): один источник мест — `LayerMap`, совпадает с принятой картой #818 и ART-005.


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_matches_layer_json() -> void:
	var j := _json("res://docs/concept-art/karta-sloj1-mesta.json")
	eq(j["locations"].size(), LayerMap.POINTS.size(), "11 мест")
	for l: Dictionary in j["locations"]:
		var p: Dictionary = LayerMap.POINTS[l["id"]]
		eq(p["name"], l["name"], "название " + str(l["id"]))
		if LayerMap.MOVED.has(l["id"]):
			eq(LayerMap.MOVED[l["id"]], Vector2(l["x"], l["z"]), "сдвинутое место %s — с карты #818" % l["id"])
			eq(p["depth"], float(l["depth"]), "глубина сдвинутого места " + str(l["id"]))
		else:
			ok(LayerMap.at(l["id"]).is_equal_approx(Vector3(l["x"], -float(l["depth"]), l["z"])), "место " + str(l["id"]))
		eq(p["accepted"], l["status"] == "существующая", "статус " + str(l["id"]))
	eq(Array(LayerMap.MAIN_ROUTE), j["main_route"], "основной маршрут")
	eq(LayerMap.LINKS, j["optional_links"], "петли и ответвления")
	eq(LayerMap.BOUNDS, Vector2(j["bounds_xz"][0], j["bounds_xz"][1]), "границы")


func test_old_landmarks_stay() -> void:
	var j := _json("res://docs/concept-art/karta-otmeli-mesta.json")
	for l: Dictionary in j["locations"]:
		var id := "%02d" % int(l["id"])
		ok(LayerMap.xz(id).is_equal_approx(Vector2(l["x"], l["z"])), "ориентир ART-005 на месте: " + id)
		eq(LayerMap.POINTS[id]["depth"], float(l["depth"]), "глубина ориентира " + id)
	eq(LayerMap.xz("00"), Vector2(Helm.Ship.START.x, Helm.Ship.START.z), "старт корабля — точка 00")


func test_run_places_from_map() -> void:
	eq(Run.PLACES.size(), LayerMap.POINTS.size(), "все 11 мест слоя — в Run.PLACES (#829)")
	eq(Array(Run.PLACES.keys()).slice(0, 6), ["flower", "geyser", "shell", "bones", "well", "drop"],
		"шесть мест ART-005 — первыми: номера в сети не сдвинулись")
	for id: String in LayerMap.POINTS:
		ok(LayerMap.POINTS[id]["key"] != "", "у места %s есть ключ" % id)
	for key: String in Run.PLACES:
		var id := LayerMap.id_of(key)
		ok(id != "", "у места забега есть точка карты: " + key)
		eq(Run.place_xz(key), LayerMap.xz(id), "координаты из LayerMap: " + key)
		eq(Run.place_name(key), LayerMap.POINTS[id]["name"], "название из LayerMap: " + key)
	eq(LayerMap.id_of("нет"), "", "чужой ключ")


func test_segments() -> void:
	var s := LayerMap.segments()
	eq(s.size(), 5 + 5 + 1 + 1, "отрезки основного маршрута, петли и ответвлений без повторов")
	ok(s.has(["07", "08"]) and s.has(["01", "03"]) and s.has(["00", "01"]), "есть все виды отрезков")
	for seg: Array in s:
		ok(LayerMap.POINTS.has(seg[0]) and LayerMap.POINTS.has(seg[1]), "концы отрезка — места карты")


## #822: спуск к лесу 10 — на дне склона за восточным краем: корабль туда заходит, дно ниже 290 м с запасом,
## на голостоле место прижато к восточному краю карты, в журнале — у правого края карты.
func test_descent_on_slope() -> void:
	var p := LayerMap.at("10")
	ok(p.x > Helm.Ship.EDGE, "10 за краем отмели (x %.0f)" % p.x)
	ok(-p.y >= 290.0, "ориентир 10 не выше 290 м")
	ok(Helm.Ship.east_ok(p.x, p.z), "корабль заходит к 10 — котловина склона")
	ok(p.y >= Helm.Ship.DEEP, "10 не ниже предела хода")
	var h := Seabed.height(p.x, p.z)
	ok(h <= p.y - Helm.Ship.CLEARANCE - 3.0, "под 10 дно %.1f — ниже корабля с запасом" % h)
	ok(h <= -300.0, "дно у 10 глубже 300 м: %.1f" % h)
	var t := Briefing.on_table(LayerMap.xz("10"))
	near(t.x, Briefing.SIDE * 0.5 - Briefing.EDGE_IN, 1e-6, "на столе — у восточного края карты")
	ok(t.y > Briefing.on_table(LayerMap.xz("06")).y, "и южнее Края отмели, как в мире")
	var size := Vector2(1600, 720)
	var c := Journal.place_center("descent", size)
	ok(c.x > Journal.place_center("drop", size).x, "в журнале 10 правее Края отмели")


func test_start_depth_is_point_00() -> void:
	# корабль начинает слой у места 00 на 30 м (#827): та же точка, что на карте, и дно под ней с запасом
	near(Helm.Ship.START.distance_to(LayerMap.at("00")), 0.0, 1e-6, "старт — место 00")
	var h := Seabed.height(Helm.Ship.START.x, Helm.Ship.START.z)
	ok(h <= Helm.Ship.START.y - Helm.Ship.CLEARANCE - 3.0, "дно под стартом %.1f — ниже корабля с запасом" % h)
