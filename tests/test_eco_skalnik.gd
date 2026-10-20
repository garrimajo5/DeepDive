extends TestCase
## Скальник (initSkalnik, skUpdate в js/creatures.js): живой камень у норы кольчужника — невидим сонару и сканеру,
## в луче меняет цвет, гоняет краба с бедным панцирем, отступает от брони, разглядывает тихий тёмный корабль.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
const SPOTS: Array[Vector3] = [Vector3(-60, FLAT, 0), Vector3(0, FLAT, 0)]


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _notes(w: EcoWorld, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == EcoSkalnik.ID and ev.note == note:
			out.append(ev)
	return out


## Ровное дно, корабль далеко, две рощи, кольчужник и скальник.
func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var k := w.add(EcoKelp.new(null, SPOTS)) as EcoKelp
	var kr := w.add(EcoKrab.new(k)) as EcoKrab
	w.add(EcoSkalnik.new(kr))
	return w


func _krab(w: EcoWorld) -> EcoKrab:
	return w.systems[1] as EcoKrab


func _sk(w: EcoWorld) -> EcoSkalnik:
	return w.systems[2] as EcoSkalnik


## Корабль стоит в dist м от дома скальника со стороны от норы, носом к дому.
func _ship_facing_home(w: EcoWorld, dist: float) -> void:
	var sk := _sk(w).octo
	var side := Vector3(sk.home.x - _krab(w).crab.den.x, 0, sk.home.z - _krab(w).crab.den.z).normalized()
	w.ship.pos = sk.home + side * dist + Vector3(0, 3, 0)
	w.ship.yaw = atan2(side.x, side.z)
	w.ship.speed = 0.0
	w.ship.light_on = false


# ---------- Место и маскировка ----------

func test_home_beside_crab_den() -> void:
	var w := _world()
	var sk := _sk(w).octo
	var cr := _krab(w).crab
	ok(sk != null)
	near(Vector2(sk.home.x - cr.den.x, sk.home.z - cr.den.z).length(), EcoSkalnik.SIDE, 1e-4, "в 7 м от норы")
	near(Vector3(sk.home.x - cr.den.x, 0, sk.home.z - cr.den.z).dot(cr.out), 0.0, 1e-4, "сбоку от выхода")
	near(sk.home.y, FLAT, 1e-5, "на дне")
	eq(sk.state, EcoSkalnik.State.ROCK)
	near(sk.camo, 1.0, 1e-6)


func test_no_crab_no_octo() -> void:
	var w := EcoWorld.new()
	var kr := w.add(EcoKrab.new(w.add(EcoKelp.new()) as EcoKelp)) as EcoKrab
	var s := w.add(EcoSkalnik.new(kr)) as EcoSkalnik
	ok(s.octo == null)
	w.run(1.0)
	var out: Array[Dictionary] = []
	s.targets(w, out)
	eq(out.size(), 0)


func test_rock_hidden_from_sonar_and_scanner() -> void:
	var w := _world()
	var sk := _sk(w).octo
	w.ship.pos = sk.home + Vector3(0, 20, 30)
	w.ship.speed = 3.0
	w.ship.sonar_ping = true
	w.ship.sonar_range = 200.0
	w.ship.scan_range = 80.0
	w.step(0.05)
	for ev in w.take_link():
		ok(ev.get("species", "") != EcoSkalnik.ID, "камень не виден: %s" % ev)
	sk.reveal = 5.0
	w.run(2.0)
	ok(sk.camo < 0.5, "кожа видна: %.2f" % sk.camo)
	w.step(0.05)
	var seen := false
	for ev in w.take_link():
		if ev.get("species", "") == EcoSkalnik.ID:
			seen = ev["sonar"] and ev["scan"]
	ok(seen, "без маскировки — и на сонаре, и в прицеле")


func test_beam_reveals_with_message_once() -> void:
	var w := _world()
	var s := _sk(w)
	var sk := s.octo
	var cr := _krab(w).crab
	# корабль над камнем со стороны от норы, прожектор включён — ищем место, где луч на камне
	var side := Vector3(sk.home.x - cr.den.x, 0, sk.home.z - cr.den.z).normalized()
	w.ship.yaw = atan2(side.x, side.z)
	w.ship.light_on = true
	w.ship.light_range = Searchlight.BASE_RANGE
	w.ship.speed = 3.0
	var found := false
	for d in range(12, 40):
		w.ship.pos = sk.home + side * d + Vector3(0, 6, 0)
		if w.in_beam(sk.pos + Vector3(0, 0.5, 0)):
			found = true
			break
	ok(found, "есть место, где луч на камне")
	w.step(0.05)
	eq(_notes(w, "mimic").size(), 1, "камень ожил")
	ok(sk.reveal > 5.0)
	eq(_notes(w, "mimic")[0].text(), "Камень в луче прожектора меняет цвет — это живое существо")
	w.scanned = func(id: String) -> bool: return id == EcoSkalnik.ID
	eq(_notes(w, "mimic")[0].text(), "Скальник в луче прожектора сбросил маскировку", "текст собирается при показе")
	w.run(1.0)
	ok(sk.camo < 0.1, "в луче — живая кожа: %.2f" % sk.camo)
	ok(not s.hidden())
	# погасить и снова включить свет до 40 с — без второго сообщения
	w.ship.light_on = false
	w.run(15.0)
	ok(sk.camo > 0.6, "без света снова камень: %.2f" % sk.camo)
	w.ship.light_on = true
	w.run(0.5)
	eq(_notes(w, "mimic").size(), 1, "сообщение не чаще 40 с")
	ok(sk.camo < 0.8, "но цвет всё равно меняет")


# ---------- Кольчужник ----------

func test_stalks_hunting_crab_and_drives_it_home() -> void:
	var w := _world()
	var kr := _krab(w)
	var sk := _sk(w).octo
	kr.crab.hunger = 1.2
	w.run(EcoSkalnik.COOLDOWN_START - 1.0)
	eq(sk.state, EcoSkalnik.State.ROCK, "первые 20 с сидит")
	var t := 0.0
	while t < 40.0 and _notes(w, "hunt").is_empty():
		w.step(0.05)
		t += 0.05
		if sk.state == EcoSkalnik.State.STALK:
			ok(kr.crab.pos.distance_to(kr.crab.den) > 0.0)
	eq(_notes(w, "hunt").size(), 1, "набросился на краба")
	eq(_notes(w, "hunt")[0].text(), "Живой камень набросился на донного краба — тот удирает в нору")
	eq(kr.crab.state, EcoKrab.State.HOME, "краб удирает")
	ok(kr.crab.scared > 5.0)
	eq(sk.state, EcoSkalnik.State.BACK)
	near(sk.cd, EcoSkalnik.COOLDOWN, 0.1)
	w.run(5.0)
	eq(kr.crab.state, EcoKrab.State.DEN, "краб в норе")
	w.run(10.0)
	eq(sk.state, EcoSkalnik.State.ROCK, "вернулся камнем")
	ok(sk.pos.is_equal_approx(sk.home))


func test_backs_off_armored_crab() -> void:
	var w := _world()
	var kr := _krab(w)
	var sk := _sk(w).octo
	kr.crab.spines = EcoSkalnik.ARMOR
	kr.crab.hunger = 1.2
	sk.cd = 0.0
	var t := 0.0
	while t < 40.0 and _notes(w, "armor").is_empty():
		w.step(0.05)
		t += 0.05
	eq(_notes(w, "armor").size(), 1, "отступил от брони")
	eq(_notes(w, "hunt").size(), 0)
	near(kr.crab.scared, 0.0, 1e-6, "краба не тронул")
	ok(kr.crab.state != EcoKrab.State.HOME or kr.crab.target < 0)
	eq(sk.state, EcoSkalnik.State.BACK)


func test_scare_breaks_crack() -> void:
	var w := _world()
	var kr := _krab(w)
	kr.crab.state = EcoKrab.State.CRACK
	kr.crab.target = 0
	kr.scare(6.0)
	eq(kr.crab.state, EcoKrab.State.HOME, "бросил ежа")
	eq(kr.crab.target, -1)


# ---------- Любопытство ----------

func test_curious_swims_to_glass_of_quiet_dark_ship() -> void:
	var w := _world()
	var sk := _sk(w).octo
	_ship_facing_home(w, 20.0)
	ok(EcoEel.front(w.ship).distance_to(sk.home) < EcoSkalnik.CURIOUS_R)
	w.step(0.05)
	eq(sk.state, EcoSkalnik.State.CURIOUS)
	var t := 0.0
	while t < EcoSkalnik.CURIOUS_TIME and _notes(w, "curious").is_empty():
		w.step(0.05)
		t += 0.05
	eq(_notes(w, "curious").size(), 1, "у стекла")
	ok(sk.pos.distance_to(EcoSkalnik.glass_goal(w.ship)) < 1.0)
	ok(not EcoHull.touches(sk.pos, w.ship.pos, w.ship.yaw), "не в корпусе")
	ok(sk.camo < 0.1, "любопытный — без маскировки")
	eq(_notes(w, "curious")[0].text(), "Живой камень подплыл к самому стеклу и разглядывает корабль")
	w.run(EcoSkalnik.CURIOUS_TIME)
	ok(sk.state != EcoSkalnik.State.CURIOUS, "насмотрелся")
	w.run(20.0)
	eq(sk.state, EcoSkalnik.State.ROCK, "снова камень")
	var rock := true
	while sk.cur_cd > 0.1:
		w.step(0.05)
		rock = rock and sk.state == EcoSkalnik.State.ROCK
	ok(rock, "любопытство — не чаще 60 с")
	eq(_notes(w, "curious").size(), 1)
	w.run(0.5)
	eq(sk.state, EcoSkalnik.State.CURIOUS, "через 60 с — снова")


func test_light_spooks_curious() -> void:
	var w := _world()
	var sk := _sk(w).octo
	_ship_facing_home(w, 20.0)
	w.run(2.0)
	eq(sk.state, EcoSkalnik.State.CURIOUS)
	w.ship.light_on = true
	w.step(0.05)
	eq(sk.state, EcoSkalnik.State.BACK, "свет спугнул")
	ok(sk.reveal > 3.0)


func test_moving_or_lit_ship_not_interesting() -> void:
	var w := _world()
	var sk := _sk(w).octo
	_ship_facing_home(w, 20.0)
	w.ship.speed = 1.0
	w.run(3.0)
	eq(sk.state, EcoSkalnik.State.ROCK, "корабль на ходу")
	w.ship.speed = 0.0
	w.ship.light_on = true
	w.run(3.0)
	ok(sk.state == EcoSkalnik.State.ROCK, "свет горит")
	_ship_facing_home(w, 45.0)
	w.run(3.0)
	eq(sk.state, EcoSkalnik.State.ROCK, "далеко")


func test_reset_back_to_rock() -> void:
	var w := _world()
	var sk := _sk(w).octo
	_ship_facing_home(w, 20.0)
	w.run(5.0)
	w.reset()
	var again := _sk(w).octo
	eq(again.state, EcoSkalnik.State.ROCK)
	ok(again.pos.is_equal_approx(sk.home))
	near(again.camo, 1.0, 1e-6)


# ---------- Сцена ----------

func test_view_two_draws_color_follows_camo() -> void:
	var w := _world()
	var s := _sk(w)
	var v := SkalnikView.new(s)
	tree.root.add_child(v)
	await frames(1)
	ok(v.visible)
	eq(v.body.layers, OceanView.LAYER_WORLD)
	eq(v.arms.layers, OceanView.LAYER_WORLD)
	eq(v.arms.multimesh.instance_count, SkalnikView.ARMS * SkalnikView.SEG)
	ok(v.material.albedo_color.is_equal_approx(SkalnikView.ROCK), "камень")
	ok(v.body.global_position.is_equal_approx(s.octo.pos))
	var writes := v.arm_writes
	v.sync(1.0, FAR)
	eq(v.arm_writes, writes, "далёкий камень не шевелится")
	var reads := v.ground_reads
	v.sync(1.0, s.octo.home + Vector3(0, 0, 10))
	eq(v.arm_writes, writes + 1, "рядом — колышется")
	eq(v.ground_reads, reads, "на месте дно под щупальцами не меряется заново")
	s.octo.pos += Vector3(1, 0, 0)
	v.sync(1.5, s.octo.home + Vector3(0, 0, 10))
	eq(v.ground_reads, reads + 1, "сдвинулся — мерит")
	s.octo.pos = s.octo.home
	s.octo.camo = 0.0
	v.sync(2.0, FAR)
	ok(v.material.albedo_color.is_equal_approx(SkalnikView.SKIN), "кожа")
	ok(v.material.emission.r > 0.1, "светится")
	# щупальца на дне, не ниже
	for i in v.arms.multimesh.instance_count:
		ok(v.arms.multimesh.get_instance_transform(i).origin.y >= FLAT + 0.05)
	v.queue_free()
	await frames(1)


func test_body_faces_outward() -> void:
	var m := SkalnikView.build_body()
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var bad := 0
	for i in range(0, v.size(), 3):
		if (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).dot(n[i]) > 0.0:
			bad += 1
	eq(bad, 0, "все грани наружу")


func test_eco_view_has_skalnik() -> void:
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	var sk := view.skalnik.octo
	ok(sk != null, "у норы кольчужника")
	ok(view.skalnik.krab == view.krab)
	near(sk.home.y, Seabed.height(sk.home.x, sk.home.z), 1e-3, "на дне")
	ok(view.skalnik_view != null and view.skalnik_view.get_parent() == view)
	var ship := EcoLink.ShipState.new()
	ship.pos = Helm.Ship.START
	view.step(0.1, ship)
	view.queue_free()
	await frames(1)
