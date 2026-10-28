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
