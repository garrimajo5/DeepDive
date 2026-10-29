extends TestCase
## Чёрный курильщик (ART-012, kurilshchik.md; js/world.js): место с карты отмели, трубы по размерам концепта стоят
## на дне, пузыри идут от жерл до льда, меш породы — один вызов отрисовки, грани лицом наружу.

const FLAT := -40.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Наклонное дно: 0,25 м на метр по z (как склон у курильщика).
static func _slope(_x: float, z: float) -> float:
	return -40.0 - (z - 45.0) * 0.25


func _vent(ground: Callable) -> EcoVent:
	var w := EcoWorld.new()
	w.ground = ground
	return w.add(EcoVent.new()) as EcoVent


func test_place_from_map_and_reactor() -> void:
	var f := FileAccess.open("res://docs/concept-art/karta-otmeli-mesta.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var spot: Dictionary = {}
	for l in data["locations"]:
		if l["name"] == "Чёрный курильщик":
			spot = l
	near(EcoVent.CENTER.x, float(spot["x"]), 1e-6, "x с карты отмели")
	near(EcoVent.CENTER.y, float(spot["z"]), 1e-6, "z с карты отмели")
	eq(EcoVent.CENTER, Reactor.VENT_POS, "тёплая вода корабля — у этого же источника")
	eq(EcoVent.ID, "geyser", "ключ места как в Run.PLACES")
	eq(Run.PLACES[EcoVent.ID][1], EcoVent.CENTER, "точка маршрута — у источника")


func test_tubes_by_concept_on_ground() -> void:
	var v := _vent(Seabed.height)
	eq(v.tubes.size(), 3, "главная и две малые трубы")
	var y0 := Seabed.height(EcoVent.CENTER.x, EcoVent.CENTER.y)
	var main := v.tubes[0]
	near(main.floor_c.y, y0, 1e-4, "на дне")
	near(main.mouth.y - y0, 9.0 - EcoVent.SINK, 1e-4, "жерло около 9 м над дном, основание заглублено")
	near(main.base_r * 2.0, 8.0, 1e-6, "основание Ø 8 м")
	near(main.top_r * 2.0, 3.0, 1e-6, "верх Ø 3 м")
	near(main.bore_r * 2.0, 2.5, 1e-6, "просвет Ø 2,5 м")
	near(main.top_r - main.bore_r, 0.25, 1e-6, "стенка 0,25 м")
	eq(v.tubes[1].at, Vector2(-5, -1), "малая 4 м в (−5; −1)")
	near(v.tubes[1].height, 4.0, 1e-6)
	eq(v.tubes[2].at, Vector2(4, 3), "малая 3 м в (4; 3)")
	near(v.tubes[2].height, 3.0, 1e-6)
	for tb in v.tubes:
		near(tb.floor_c.y, Seabed.height(tb.floor_c.x, tb.floor_c.z), 1e-4, "каждая труба — на дне")
		ok(tb.bore_r < tb.top_r, "просвет уже кромки")
	ok(v.solid(main.floor_c + Vector3(0, 4, 0)), "середина главной трубы — твёрдая")
	ok(not v.solid(main.floor_c + Vector3(0, 12, 0)), "над жерлом — вода")
	ok(not v.solid(main.floor_c + Vector3(6, 2, 0)), "в 6 м сбоку — вода")
	ok(not v.solid(v.center() + Vector3(0, 0, -40)), "корабль у места не упирается в трубы")


func test_bubbles_rise_to_ice_from_mouths() -> void:
	var v := _vent(_flat)
	eq(v.b_origin.size(), EcoVent.BUBBLES, "180 пузырей, как в браузере")
	var per := [0, 0, 0]
	for i in EcoVent.BUBBLES:
		per[EcoVent.emitter(i)] += 1
		var tb := v.tubes[EcoVent.emitter(i)]
		ok(Vector2(v.b_origin[i].x - tb.mouth.x, v.b_origin[i].z - tb.mouth.z).length() < tb.bore_r, "выходит из просвета")
		ok(v.b_speed[i] > 1.0 and v.b_speed[i] <= 5.0, "скорость %f" % v.b_speed[i])
		near(v.b_origin[i].y + v.b_height[i], EcoVent.ICE_Y, 1e-4, "столб до льда")
	eq(per, [150, 15, 15], "малые жерла — реже")
	# пузырь поднимается, у льда сносит вбок и, дойдя, начинает снова от жерла
	var i := 7
	var t0 := (1.0 - v.b_phase[i]) * v.b_height[i] / v.b_speed[i]   # момент выхода из жерла
	near(v.bubble_f(i, t0), 0.0, 1e-3, "в жерле")
	var lo := v.bubble_pos(i, t0 + 0.01)
	var hi := v.bubble_pos(i, t0 + v.b_height[i] / v.b_speed[i] * 0.95)
	ok(hi.y > lo.y + 20.0, "поднялся к льду: %f → %f" % [lo.y, hi.y])
	ok(hi.y < EcoVent.ICE_Y, "не выше льда")
	ok(Vector2(hi.x - v.b_origin[i].x, hi.z - v.b_origin[i].z).length() <= EcoVent.DRIFT * 1.42, "снос не больше DRIFT")
	near(Vector2(lo.x - v.b_origin[i].x, lo.z - v.b_origin[i].z).length(), 0.0, 0.01, "у жерла не сносит")
	ok(EcoVent.bubble_size(0.9) > EcoVent.bubble_size(0.1), "у льда крупнее")
	ok(EcoVent.bubble_alpha(0.8) < EcoVent.bubble_alpha(0.2), "у льда прозрачнее")
	near(EcoVent.bubble_alpha(1.0), 0.0, 1e-6, "у льда гаснет")
	near(EcoVent.bubble_alpha(0.0), 0.0, 1e-6, "появляется в жерле")
	# пузыри не берут случай мира: тот же мир — те же пузыри
	var v2 := _vent(_flat)
	eq(v2.b_phase, v.b_phase, "детерминированно")


func test_flicker_small_and_irregular() -> void:
	var lo := 9.0
	var hi := 0.0
	for k in 600:
		var f := EcoVent.flicker(k * 0.05)
		lo = minf(lo, f)
		hi = maxf(hi, f)
	ok(lo > 0.55 and hi <= 1.0, "мерцание без вспышек и без погасания: %f…%f" % [lo, hi])
	ok(hi - lo > 0.2, "заметно мерцает")


func test_view_rock_one_mesh_faces_out() -> void:
	var v := _vent(_slope)
	var view := VentView.new(v)
	tree.root.add_child(view)
	await frames(1)
	eq(view.rock.mesh.get_surface_count(), 1, "порода — один вызов отрисовки")
	eq(view.rock.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(view.bubbles.layers, OceanView.LAYER_WORLD)
	eq(view.haze.layers, OceanView.LAYER_WORLD)
	var meshes := 0
	for c in view.get_children():
		if c is GeometryInstance3D:
			meshes += 1
	eq(meshes, 3, "три вызова отрисовки: порода, пузыри, марево")
	ok(view.tris > 400 and view.tris < 3000, "треугольников: %d" % view.tris)
	eq(view.bubbles.multimesh.instance_count, EcoVent.BUBBLES)
	# лицевая сторона: (b − a) × (c − a) смотрит внутрь, т. е. против нормали грани
	var bad := 0
	for t in view.tris:
		var a := view.verts[t * 3]
		var cr := (view.verts[t * 3 + 1] - a).cross(view.verts[t * 3 + 2] - a)
		if cr.dot(view.normals[t * 3]) >= 0.0:
			bad += 1
	eq(bad, 0, "все грани обходом по часовой стрелке")
	# стенка главной трубы снаружи смотрит от оси, низ стенки — по наклонному дну
	var main := v.tubes[0]
	var out_ok := 0
	var low := 0
	for k in view.verts.size():
		var p := view.verts[k]
		var r := Vector2(p.x - main.floor_c.x, p.z - main.floor_c.z)
		if r.length() > 3.0 and r.length() < 4.6 and p.y > main.floor_c.y + 1.5 and p.y < main.mouth.y - 1.0:
			if view.normals[k].dot(Vector3(r.x, 0, r.y).normalized()) > 0.3:
				out_ok += 1
		if absf(p.y - (_slope(p.x, p.z) - EcoVent.SINK)) < 1e-3:
			low += 1
	ok(out_ok > 50, "стенка лицом наружу: %d" % out_ok)
	ok(low > 30, "низ стенки идёт по склону: %d" % low)
	# кромка светится (альфа цвета), порода — нет
	var arrays := view.rock.mesh.surface_get_arrays(0)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var lit := 0
	var dark := 0
	for c in cols:
		if c.a > 0.99:
			lit += 1
		elif c.a < 0.01:
			dark += 1
	ok(lit > 0 and dark > lit, "светится только кромка: %d из %d" % [lit, cols.size()])
	view.queue_free()
	await frames(1)


func test_view_bubbles_buffer_matches_world() -> void:
	var v := _vent(_flat)
	var view := VentView.new(v)
	tree.root.add_child(view)
	await frames(1)
	var b := view.bubble_buffer
	eq(b.size(), EcoVent.BUBBLES * VentView.STRIDE)
	for i in [0, 77, 179]:
		var k: int = i * VentView.STRIDE
		near(b[k + 3], v.b_origin[i].x, 1e-4, "точка выхода в экземпляре")
		near(b[k + 7], v.b_origin[i].y, 1e-4)
		near(b[k + 12], v.b_speed[i], 1e-5, "скорость — в своих числах")
		near(b[k + 14], v.b_height[i], 1e-4, "высота столба")
	ok(view.bubbles.custom_aabb.has_point(Vector3(v.tubes[0].mouth.x, -1.0, v.tubes[0].mouth.z)), "рамка — до льда")
	view.queue_free()
	await frames(1)


func test_eco_view_has_vent() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	ok(view.vent != null and view.vent_view != null and view.vent_view.get_parent() == view, "курильщик — в живом мире")
	near(view.vent.tubes[0].floor_c.y, Seabed.height(EcoVent.CENTER.x, EcoVent.CENTER.y), 1e-4, "встал на дно сцены")
	ok(view.vent_view.rock != null, "порода собрана по дну")
	view.queue_free()
	await frames(1)


## Строки MESSAGE мира для корабля.
static func _messages(w: EcoWorld) -> Array[String]:
	var out: Array[String] = []
	for e in w.take_link():
		if e.get("type", "") == EcoLink.MESSAGE:
			out.append(str(e["text"]))
	return out


## #835, часть 2а: знак шлейфа приходит раньше перегрева реактора — корабль идёт к жерлу с востока на 5 м/с.
func test_plume_sign_before_heat() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.add(EcoVent.new())
	var at := -1.0
	var heat := -1.0
	for i in 300:
		var d := 150.0 - i * 0.5
		w.ship.pos = Vector3(EcoVent.CENTER.x + d, FLAT + 12.0, EcoVent.CENTER.y)
		w.step(0.1)
		if at < 0.0 and _messages(w).has(EcoVent.WARN_TEXT):
			at = d
		if heat < 0.0 and Reactor.near_vent(w.ship.pos.x, w.ship.pos.z):
			heat = d
	ok(at > 0.0, "знак шлейфа пришёл")
	ok(heat > 0.0, "корабль дошёл до тёплой воды")
	ok(at - heat >= 25.0, "знак на %.0f м раньше перегрева (≥ 25 м, на 5 м/с — 5 с)" % (at - heat))
	ok(EcoVent.WARN_R > Reactor.VENT_R, "круг знака шире круга перегрева")


## Знак — один раз за заход: стоять в круге — тишина; выйти и сразу вернуться — тишина до WARN_CD; потом снова.
func test_plume_sign_once_per_visit() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	var v := w.add(EcoVent.new()) as EcoVent
	var inside := Vector3(EcoVent.CENTER.x + 60.0, FLAT + 12.0, EcoVent.CENTER.y)
	var outside := Vector3(EcoVent.CENTER.x + 100.0, FLAT + 12.0, EcoVent.CENTER.y)
	var got: Array[String] = []
	w.ship.pos = inside
	for i in 50:
		w.step(0.1)
		got.append_array(_messages(w))
	eq(got.size(), 1, "в круге — одна строка")
	w.ship.pos = outside
	w.step(0.1)
	w.ship.pos = inside
	for i in 10:
		w.step(0.1)
		got.append_array(_messages(w))
	eq(got.size(), 1, "вернулся раньше WARN_CD — без повтора")
	w.ship.pos = outside
	for i in int(EcoVent.WARN_CD * 10.0):
		w.step(0.1)
		got.append_array(_messages(w))
	w.ship.pos = inside
	w.step(0.1)
	got.append_array(_messages(w))
	eq(got.size(), 2, "после WARN_CD новый заход — снова знак")
	w.reset()
	ok(v.warn_cd == 0.0, "новый забег — знак заново")


# ---------- Веерники у курильщика (#835, часть 2б) ----------

func _fan_world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var cur := w.add(EcoCurrent.new()) as EcoCurrent
	w.add(EcoCoral.new())
	w.add(EcoFan.new(cur))
	w.reset()
	return w


func _fans(w: EcoWorld) -> EcoFan:
	for s in w.systems:
		if s is EcoFan:
			return s
	return null


## Плоскость веера смотрит на жерло (без знака: плоскость двусторонняя).
func _faces_vent(f: EcoFan.Fan) -> float:
	var to := EcoVent.CENTER - Vector2(f.pos.x, f.pos.z)
	var n := EcoFan.facing(f)
	return absf(Vector2(n.x, n.z).dot(to.normalized()))


func test_vent_fans_point_flow_to_vent() -> void:
	for p in EcoVent.FANS:
		ok(EcoFan.default_spots().has(p), "веерник курильщика — в местах EcoFan")
		var d := p.distance_to(EcoVent.CENTER)
		ok(d > 12.0 and d < EcoVent.PULL_IN, "в %.1f м от трубы — не в цоколе и в полной тяге" % d)
		near(EcoFan.vent_pull(p), 1.0, 1e-6, "тяга к жерлу полная")
	near(EcoFan.vent_pull(EcoFan.START), 0.0, 1e-6, "у старта тяги нет")
	var w := _fan_world()
	var fans := _fans(w)
	var cur: EcoCurrent
	for s in w.systems:
		if s is EcoCurrent:
			cur = s
	var vent_fans: Array[EcoFan.Fan] = []
	for f in fans.fans:
		if f.pull > 0.0:
			vent_fans.append(f)
	eq(vent_fans.size(), EcoVent.FANS.size(), "тянет только веера курильщика")
	for f in vent_fans:
		ok(_faces_vent(f) > 0.999, "с начала плоскостью к жерлу: %f" % _faces_vent(f))
	w.run(310.0)   # течение сменилось (180 с) и веера доворачиваются
	ok(cur.turns >= 1, "течение сменилось")
	for f in vent_fans:
		ok(_faces_vent(f) > 0.999, "у курильщика течение мира веер не разворачивает: %f" % _faces_vent(f))
	var far := fans.fans[0]
	ok(EcoFan.facing(far).distance_to(cur.vel().normalized()) < 0.05, "веерник у огнецвета — поперёк течения, как раньше")


func test_vent_fan_message() -> void:
	var w := _fan_world()
	var fans := _fans(w)
	var vf: EcoFan.Fan
	for f in fans.fans:
		if f.pull > 0.5:
			vf = f
	w.ship.pos = vf.top + Vector3(0, 8, 6)
	w.step(0.05)
	var texts: Array[String] = []
	for e in w.take_link():
		if e["type"] == EcoLink.MESSAGE and e["text"] != "":
			texts.append(e["text"])
	ok(texts.any(func(t: String) -> bool: return t.contains("повёрнут к жерлу")), "рядом — строка про поток к жерлу: %s" % str(texts))
	ok(not texts.any(func(t: String) -> bool: return t.contains("поперёк течения")), "не «поперёк течения»")
