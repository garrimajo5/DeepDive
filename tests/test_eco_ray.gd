extends TestCase
## Ледокрылы (initRays/rayUpdate в js/creatures.js, Snd.song в js/soundscape.js): два ската на кругах подо льдом,
## над кораблём проходят поверху, водят стаи светляков, поют; цели сонара; один MultiMesh в сцене.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world(with_fish := false) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f: EcoFish = null
	if with_fish:
		f = w.add(EcoFish.new()) as EcoFish
	w.add(EcoRay.new(f))
	return w


func _rays(w: EcoWorld) -> EcoRay:
	for s in w.systems:
		if s is EcoRay:
			return s
	return null


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


# ---------- Круги и глубина ----------

func test_two_rays_on_their_circles() -> void:
	var w := _world()
	var r := _rays(w)
	eq(r.rays.size(), 2, "два ската")
	w.run(20.0)
	for ry in r.rays:
		var c: Vector3 = EcoRay.PATHS[ry.index]["c"]
		var R: float = EcoRay.PATHS[ry.index]["r"]
		near(Vector2(ry.p.x - c.x, ry.p.z - c.z).length(), R, 1e-3, "на своём круге")
		ok(ry.p.y <= EcoRay.TOP_Y + 1e-4, "не выше −5,5 м — подо льдом")
		ok(ry.p.y >= FLAT + EcoRay.ABOVE_FLOOR - 1e-3, "не ниже 7 м над дном")
		near(ry.dir.length(), 1.0, 1e-5, "курс — единичный")
		var tangent := Vector3(-(ry.p.z - c.z), 0, ry.p.x - c.x).normalized()
		near(ry.dir.dot(tangent), 1.0, 1e-4, "плывёт по касательной")


func test_speed_along_circle() -> void:
	var w := _world()
	var r := _rays(w)
	var a0 := r.rays[0].ang
	w.run(10.0)
	near((r.rays[0].ang - a0) * EcoRay.PATHS[0]["r"], EcoRay.PATHS[0]["sp"] * 10.0, 1e-3, "4,2 м/с по кругу")


func test_high_floor_lifts_ray() -> void:
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float: return -14.0
	w.ship.pos = FAR
	var r := w.add(EcoRay.new()) as EcoRay
	w.run(3.0)
	for ry in r.rays:
		ok(ry.p.y > -14.0 + EcoRay.ABOVE_FLOOR - 0.3, "над мелким дном держится на 7 м")
		ok(ry.p.y <= EcoRay.TOP_Y + 1e-4)


func test_reset_same_seed_same_path() -> void:
	var a := _world()
	var b := _world()
	a.run(7.0)
	b.run(7.0)
	eq(_rays(a).rays[1].p, _rays(b).rays[1].p, "детерминированно")
	a.reset()
	b.reset()
	eq(_rays(a).rays[0].ang, _rays(b).rays[0].ang)


# ---------- Корабль на пути ----------

func test_passes_over_ship_without_touching_hull() -> void:
	var w := _world()
	var r := _rays(w)
	var ry := r.rays[0]
	# корабль ставим на круг ската чуть впереди него, на глубине его пути
	var ahead := ry.ang + 6.0 / ry.radius
	w.ship.pos = Vector3(ry.center.x + cos(ahead) * ry.radius, -16.0, ry.center.z + sin(ahead) * ry.radius)
	w.ship.yaw = 0.7
	var was_over := false
	for i in 200:
		w.step(0.05)
		was_over = was_over or ry.over
		ok(not EcoHull.touches(ry.p, w.ship.pos, w.ship.yaw, 0.5), "тело не в корпусе (шаг %d)" % i)
	ok(was_over, "скат шёл над кораблём")


func test_over_ship_rises_above() -> void:
	var w := _world()
	var ry := _rays(w).rays[0]
	var at := ry.ang + 0.5 * 3.0 / ry.radius
	w.ship.pos = Vector3(ry.center.x + cos(at) * ry.radius, -20.0, ry.center.z + sin(at) * ry.radius)
	w.run(3.0)
	ok(ry.over, "над кораблём")
	ok(ry.p.y > w.ship.pos.y + EcoRay.SHIP_TOP + EcoRay.OVER - 1.0, "поднялся над корпусом: %.2f" % ry.p.y)


## Б3, плавность: над кораблём скат взмывает носом вверх и плавно выравнивается, а не всплывает «лифтом».
func test_climbs_nose_up_over_ship_smoothly() -> void:
	var w := _world()
	var ry := _rays(w).rays[0]
	var at := ry.ang + 6.0 / ry.radius
	w.ship.pos = Vector3(ry.center.x + cos(at) * ry.radius, -10.0, ry.center.z + sin(at) * ry.radius)
	var top := 0.0
	var prev := ry.pitch
	var dt := 0.05
	for i in 80:
		w.step(dt)
		top = maxf(top, ry.pitch)
		ok(absf(ry.pitch - prev) <= EcoRay.PITCH_MAX * 2.0 * EcoRay.PITCH_FOLLOW * dt + 1e-5,
			"тангаж меняется плавно (шаг %d)" % i)
		ok(absf(ry.pitch) <= EcoRay.PITCH_MAX + 1e-5, "не круче 20°")
		prev = ry.pitch
	ok(top > deg_to_rad(10.0), "взмыл над кораблём носом вверх: %.1f°" % rad_to_deg(top))
	var nose := EcoRay.xform(ry).basis.z.normalized()
	near(nose.y, sin(ry.pitch), 1e-4, "нос меша — по тангажу")
	near(Vector2(nose.x, nose.z).normalized().dot(Vector2(ry.dir.x, ry.dir.z)), 1.0, 1e-4, "и по курсу")


func test_level_far_from_ship() -> void:
	var w := _world()
	var r := _rays(w)
	for ry in r.rays:
		eq(ry.pitch, 0.0, "в начале — ровно")
	w.run(30.0)
	for ry in r.rays:
		ok(absf(ry.pitch) < deg_to_rad(6.0), "на своей глубине почти ровно: %.1f°" % rad_to_deg(ry.pitch))
	near(EcoRay.pitch_for(1.0, 4.0), atan2(1.0, 4.0), 1e-6, "наклон пути")
	near(EcoRay.pitch_for(-50.0, 4.0), -EcoRay.PITCH_MAX, 1e-6, "вниз — не круче предела")


func test_far_ship_does_not_lift() -> void:
	var w := _world()
	w.run(5.0)
	for ry in _rays(w).rays:
		ok(not ry.over, "корабль далеко — скат на своей глубине")


# ---------- Ведёт стаю ----------

func test_leads_nearest_reef_shoal() -> void:
	var w := _world(true)
	var r := _rays(w)
	var fish := w.systems[0] as EcoFish
	var ry := r.rays[0]
	# скат — у стаи 4 (дом (56, 6)), зов сейчас
	var sh := fish.shoals[4]
	w.ship.pos = sh.home + Vector3(0, 0, 40)  # ближе MID: стая шагает каждый шаг мира, не по очереди дальних (issue #803)
	ry.center = Vector3(sh.center.x - 20.0, ry.center.y, sh.center.z)
	ry.radius = 20.0
	ry.ang = 0.0
	ry.lead_cd = 0.0
	w.step(0.05)
	ok(sh.leader() == ry, "стая пошла за скатом")
	near(sh.lead_t, EcoRay.LEAD_T, 1e-6, "на 18 с")
	eq(_notes(w, EcoRay.ID, "follow").size(), 1, "наблюдение «follow»")
	eq(_notes(w, EcoFish.ID, "follow").size(), 1, "и заметка светляков")
	# светляки шагают раньше скатов: цель — по месту ската до его шага
	var want := ry.p - ry.dir * EcoFish.LEAD_BEHIND + Vector3(0, -EcoFish.LEAD_BELOW, 0)
	w.step(0.05)
	near(sh.goal.distance_to(want), 0.0, 1e-3, "цель — в 12 м за скатом и на 3 м ниже")
	w.run(EcoRay.LEAD_T)
	ok(sh.leader() == null or sh.lead_t > 0.0, "через 18 с отпускает (или позвал снова)")


func test_shoal_follows_ray() -> void:
	var w := _world(true)
	var r := _rays(w)
	var fish := w.systems[0] as EcoFish
	var ry := r.rays[0]
	var sh := fish.shoals[4]
	ry.center = Vector3(sh.center.x - ry.radius, ry.center.y, sh.center.z)
	ry.ang = 0.0
	ry.lead_cd = 0.0
	w.step(0.05)
	ok(sh.leader() == ry)
	var home := sh.home
	w.run(15.0)
	var want := ry.p - ry.dir * EcoFish.LEAD_BEHIND
	ok(sh.center.distance_to(home) > 15.0, "стая ушла от дома: %.1f м" % sh.center.distance_to(home))
	var way := (sh.center - home).normalized().dot((want - home).normalized())
	ok(way > 0.7, "и уходит туда, куда скат: %.2f" % way)


func test_does_not_lead_far_crown_or_cage() -> void:
	var w := _world(true)
	var r := _rays(w)
	var fish := w.systems[0] as EcoFish
	for ry in r.rays:
		ry.center = Vector3(1000, -9, 1000)
		ry.lead_cd = 0.0
	w.step(0.05)
	for sh in fish.shoals:
		ok(sh.leader() == null, "стаи дальше 45 м не зовут")
	# скат у кроны цветка: стаи кроны не идут
	var crown := fish.shoals[EcoFish.HOMES.size()]
	var ry := r.rays[0]
	ry.center = crown.center + Vector3(-5, 0, 0)
	ry.radius = 5.0
	ry.ang = 0.0
	ry.lead_cd = 0.0
	w.step(0.05)
	ok(crown.leader() == null, "стая у кроны остаётся у кроны")


func test_lead_is_weak_and_overrides_goal() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var fish := w.add(EcoFish.new()) as EcoFish
	var sh := fish.shoals[0]
	var lead := EcoRay.Ray.new()
	lead.p = sh.center + Vector3(30, 0, 0)
	lead.dir = Vector3.RIGHT
	sh.follow(lead, 10.0)
	w.step(0.05)
	near(sh.goal.distance_to(lead.p - lead.dir * EcoFish.LEAD_BEHIND + Vector3(0, -EcoFish.LEAD_BELOW, 0)), 0.0, 1e-4,
		"за ведущим, а не к своей цели")
	lead = null
	w.step(0.05)
	ok(sh.leader() == null, "ведущего нет (слабая ссылка) — стая свободна")


# ---------- Песня ----------

func test_sings_to_near_ship_with_side() -> void:
	var w := _world()
	var r := _rays(w)
	var ry := r.rays[0]
	ry.speed = 0.0
	w.run(0.05)
	# корабль в 40 м от ската, нос на −Z (yaw 0): скат справа по +X
	w.ship.pos = ry.p - Vector3(40, 0, 0)
	w.ship.yaw = 0.0
	w.bus.pending.clear()
	w.run(EcoRay.SONG_FIRST)
	ok(not r.song.is_empty(), "спел")
	eq(r.phrase, 1)
	var notes: Array = r.song["notes"]
	ok(notes.size() >= 3 and notes.size() <= 5, "3–5 нот")
	ok(float(r.song["pan"]) > 0.3, "справа от корабля")
	var ev := _notes(w, EcoRay.ID, "song")
	eq(ev.size(), 1, "наблюдение «song»")
	ok(ev[0].text().contains("справа"), ev[0].text())
	ok(ev[0].pos.distance_to(w.ship.pos) < EcoBus.HEARING, "слышно с корабля")


func test_far_ship_hears_no_song() -> void:
	var w := _world()
	var r := _rays(w)
	w.run(30.0)
	ok(r.song.is_empty(), "дальше 160 м песни нет")
	eq(_notes(w, EcoRay.ID, "song").size(), 0)


func test_song_note_only_closer_110() -> void:
	var w := _world()
	var r := _rays(w)
	var ry := r.rays[1]
	ry.speed = 0.0
	w.run(0.05)
	w.ship.pos = ry.p + Vector3(0, 0, 130)
	r.rays[0].center = Vector3(2000, -9, 2000)
	w.bus.pending.clear()
	w.run(EcoRay.SONG_FIRST)
	ok(not r.song.is_empty(), "песню слышно за 130 м")
	eq(_notes(w, EcoRay.ID, "song").size(), 0, "но наблюдения нет — дальше 110 м")


# ---------- Цели ----------

func test_rays_are_scan_targets() -> void:
	var w := _world()
	var t := w.scan_targets()
	eq(t.size(), 2)
	for x in t:
		eq(x["species"], EcoRay.ID)
		near(float(x["r"]), EcoRay.TARGET_R, 1e-6)


func test_ray_does_not_shift_fish_without_lead() -> void:
	var a := EcoWorld.new()
	a.ground = Seabed.height
	var fa := a.add(EcoFish.new()) as EcoFish
	var ra := a.add(EcoRay.new(fa)) as EcoRay
	for ry in ra.rays:
		ry.lead_cd = 1e9
	var b := EcoWorld.new()
	b.ground = Seabed.height
	var fb := b.add(EcoFish.new()) as EcoFish
	a.run(5.0)
	b.run(5.0)
	eq(fa.shoals[3].center, fb.shoals[3].center, "свои числа случая — стаи те же")


# ---------- В сцене ----------

func test_view_one_multimesh() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var rv := view.ray_view
	ok(rv != null and rv.get_parent() == view, "ледокрылы — в живом мире")
	eq(rv.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(rv.multimesh.instance_count, 2, "оба ската — один MultiMesh")
	eq(rv.multimesh.mesh.get_surface_count(), 1, "один вызов отрисовки")
	ok(rv.tris < 600, "треугольников на ската: %d" % rv.tris)
	var ship := EcoLink.ShipState.new()
	ship.pos = FAR
	view.step(0.05, ship)
	var ry := view.rays.rays[1]
	var x := rv.placed[1]
	near(x.origin.distance_to(ry.p), 0.0, 1e-4, "скат на месте")
	near((x.basis.z.normalized()).dot(ry.dir), 1.0, 0.05, "нос по курсу")
	var span := 0.0
	for v in rv.verts:
		span = maxf(span, absf(v.x))
	near(span * 2.0, RayView.SPAN, 0.8, "размах около 14 м")
	view.queue_free()
	await frames(1)


func test_tail_whips() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var rv := view.ray_view
	var mesh := rv.multimesh.mesh
	var arr := mesh.surface_get_arrays(0)
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	eq(uv.size(), v.size(), "доля длины хвоста — у каждой вершины")
	var z0 := RayView.TAIL_Z + RayView.TAIL_L * 0.5
	var tail := 0
	for i in v.size():
		if uv[i].x > 0.0:
			tail += 1
			near(v[i].z, z0 - RayView.TAIL_L * uv[i].x, 1e-4, "доля длины растёт к кончику")
			ok(absf(v[i].x) < 0.2, "это хвост, а не крыло")
	ok(tail >= (RayView.TAIL_RINGS - 1) * 6, "хвост из %d колец гнётся: %d вершин" % [RayView.TAIL_RINGS, tail])
	var mat := mesh.surface_get_material(0) as ShaderMaterial
	ok(mat.shader.code.contains(
		"VERTEX.x += sin(TIME * 2.4 + INSTANCE_CUSTOM.x * 2.1 - UV.x * 5.0) * 0.8 * UV.x * UV.x * sway_k"),
		"волна хвоста — в шейдере, числа как у двойника")
	near(RayView.TAIL_RATE, 2.4, 1e-6, "частота")
	near(RayView.TAIL_PHASE, 2.1, 1e-6, "сдвиг между скатами")
	near(RayView.TAIL_K, 5.0, 1e-6, "волн на длину")
	near(RayView.TAIL_AMP, 0.8, 1e-6, "размах")
	var most := 0.0
	var apart := 0.0
	var mid := 0.0
	for k in 300:
		var t := k * 0.1
		near(RayView.tail_wave(0.0, t, 0), 0.0, 1e-6, "у тела хвост стоит")
		var tip := RayView.tail_wave(1.0, t, 0)
		most = maxf(most, absf(tip))
		mid = maxf(mid, absf(RayView.tail_wave(0.5, t, 0)))
		apart = maxf(apart, absf(tip - RayView.tail_wave(1.0, t, 1)))
	ok(most > 0.5 and most <= RayView.TAIL_AMP + 1e-6, "кончик хлещет: %.2f м" % most)
	ok(mid < most * 0.5, "у середины размах меньше: %.2f" % mid)
	ok(apart > 0.3, "два ската — вразнобой: %.2f" % apart)
	EcoShaders.set_sway_lite(true)
	eq(float(mat.get_shader_parameter("sway_k")), 0.0, "«Экономно» — хвост не гнётся")
	near(RayView.tail_wave(1.0, 0.7, 0, 0.0), 0.0, 1e-9, "двойник тоже стоит")
	EcoShaders.set_sway_lite(false)
	eq(float(mat.get_shader_parameter("sway_k")), 1.0, "выключили — снова хлещет")
	view.queue_free()
	await frames(1)
