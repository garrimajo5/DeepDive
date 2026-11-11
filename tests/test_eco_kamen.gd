extends TestCase
## Каменщики (#1337, бестиарий): ряды трубок у кустов огнецвета, венчики прячутся от вибрации — плывущего крупного
## или шумного корабля — с того края, откуда идут, и раскрываются в тишине. Наблюдения «hide»/«warn», цели сканера.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world() -> Array:
	var w := EcoWorld.new()
	w.ground = _flat
	var k := w.add(EcoKamen.new([Vector2(0, 0), Vector2(200, 0)])) as EcoKamen
	w.reset()
	w.ship.pos = FAR
	w.ship.speed = 0.0
	return [w, k]


func _notes(w: EcoWorld, note: String) -> int:
	var n := 0
	for ev in w.bus.pending:
		if ev.species == EcoKamen.ID and ev.note == note:
			n += 1
	return n


func test_rows_at_bushes_on_floor() -> void:
	var a := _world()
	var k: EcoKamen = a[1]
	eq(k.rows.size(), 2)
	for r in k.rows:
		eq(r.worms.size(), EcoKamen.PER_ROW)
		near(r.center.y, FLAT, 1e-4, "ряд на дне")
		var d := Vector2(r.center.x, r.center.z).distance_to(Vector2(200 * r.index, 0))
		near(d, EcoKamen.OFFSET, 0.01, "в OFFSET от куста")
		for w in r.worms:
			eq(w.tube_base.size(), EcoKamen.TUBES)
			near(w.open, 1.0, 1e-6, "раскрыты")
	# ряд на дальней от старта стороне куста
	var c := Vector2(k.rows[0].center.x, k.rows[0].center.z)
	ok(c.distance_to(EcoKamen.FROM) > Vector2.ZERO.distance_to(EcoKamen.FROM) + 5.0, "дальше от старта, чем куст")
	var ev := EcoView.new()
	eq(ev.kamen.rows.size(), EcoCoral.BASES.size(), "в сцене — ряд у каждого куста огнецвета")
	eq(ev.kamen_view.count(), EcoCoral.BASES.size() * EcoKamen.PER_ROW * EcoKamen.TUBES)
	ev.free()


## Крупный проходит вдоль ряда с одного края: гнёзда прячутся по очереди от ближнего края, после ухода — раскрываются.
func test_big_passing_hides_from_its_side() -> void:
	var a := _world()
	var w: EcoWorld = a[0]
	var k: EcoKamen = a[1]
	var r := k.rows[0]
	w.ship.pos = r.center + Vector3(0, 12, 30)
	var pred := w.spawn("pred", FAR)
	ok(pred.big, "серпохвост — крупный")
	var first := r.worms[0].base
	var last := r.worms[EcoKamen.PER_ROW - 1].base
	# подходит со стороны первого гнезда, 1,5 м/с
	var dir := (first - last).normalized()
	var start := first + dir * (EcoKamen.HIDE_R + 3.0) + Vector3(0, 2, 0)
	pred.v = -dir * 1.5
	var order: Array[int] = []
	for i in 80:
		pred.p = start - dir * (i * 0.075)
		w.step(0.05)
		for j in r.worms.size():
			if r.worms[j].open < EcoKamen.HIDDEN and not order.has(j):
				order.append(j)
	ok(order.size() >= 2 and order.size() < EcoKamen.PER_ROW, "спряталась часть ряда: %s" % [order])
	eq(order[0], 0, "первым — ближний край")
	ok(r.worms[EcoKamen.PER_ROW - 1].open > EcoKamen.HIDDEN, "дальний край ещё открыт")
	eq(r.worms[0].cause, EcoKamen.Cause.BIG)
	eq(_notes(w, "warn"), 1, "warn — корабль видит ряд")
	eq(_notes(w, "hide"), 0, "шум корабля ни при чём")
	ok(k.rows[1].worms.all(func(x): return x.open >= 1.0), "дальний ряд не тронут")
	# ушёл
	pred.p = FAR
	w.run(EcoKamen.QUIET + 1.0 / EcoKamen.OPEN_RATE + 0.5)
	ok(r.worms.all(func(x): return x.open >= 1.0), "раскрылись снова")
	eq(k.hidden_in(r), 0)


## Стоящий (чистка) и мёртвый крупный не вибрируют; некрупный не пугает; далеко от корабля — без строки.
func test_still_dead_small_and_far_ship() -> void:
	var a := _world()
	var w: EcoWorld = a[0]
	var k: EcoKamen = a[1]
	var r := k.rows[0]
	var pred := w.spawn("pred", r.center + Vector3(0, 3, 0))
	pred.v = Vector3.ZERO
	w.run(2.0)
	eq(k.hidden_in(r), 0, "стоит — открыты")
	pred.v = Vector3(2, 0, 0)
	pred.alive = false
	w.run(2.0)
	eq(k.hidden_in(r), 0, "мёртвый — открыты")
	var fish := w.spawn("fish", r.center + Vector3(0, 1, 0))
	fish.v = Vector3(3, 0, 0)
	ok(not fish.big)
	w.run(2.0)
	eq(k.hidden_in(r), 0, "светляк не крупный")
	pred.alive = true
	w.run(1.0)
	eq(k.hidden_in(r), EcoKamen.PER_ROW, "живой плывущий у середины — прячется весь ряд")
	eq(_notes(w, "warn"), 0, "корабль далеко — строки нет")


## Шумный ход корабля прячет ряд — «hide» про корабль, без «warn»; хищник рядом причину не перебивает.
func test_ship_noise_is_own_cause() -> void:
	var a := _world()
	var w: EcoWorld = a[0]
	var k: EcoKamen = a[1]
	var r := k.rows[0]
	w.ship.pos = r.center + Vector3(0, 6, 0)
	w.ship.speed = 5.0
	var pred := w.spawn("pred", r.center + Vector3(3, 2, 0))
	pred.v = Vector3(2, 0, 0)
	w.run(1.0)
	eq(k.hidden_in(r), EcoKamen.PER_ROW)
	eq(r.worms[0].cause, EcoKamen.Cause.SHIP)
	eq(_notes(w, "hide"), 1)
	eq(_notes(w, "warn"), 0, "свой шум — не довод «кто-то крупный»")
	var texts: Array[String] = []
	for ev in w.take_link():
		texts.append(String(ev.get("text", "")))
	eq(texts, ["Ряд трубчатых червей прячет венчики в трубки — корабль шумит рядом"] as Array[String])
	# медленно — тихо
	w.ship.speed = 1.0
	pred.alive = false
	w.run(EcoKamen.QUIET + 4.5)
	eq(k.hidden_in(r), 0, "тихий ход — раскрылись")


func test_hide_text_and_observation() -> void:
	ok(Species.is_observation(EcoKamen.ID, "hide"))
	ok(Species.is_observation(EcoKamen.ID, "warn"))


func test_targets_one_per_row() -> void:
	var a := _world()
	var w: EcoWorld = a[0]
	var out: Array[Dictionary] = []
	(a[1] as EcoKamen).targets(w, out)
	eq(out.size(), 2)
	eq(out[0]["species"], EcoKamen.ID)


## Вид: венчик спрятанного гнезда мал и утоплен в устье; трубок и венчиков по числу гнёзд.
func test_view_crowns_follow_open() -> void:
	var a := _world()
	var w: EcoWorld = a[0]
	var k: EcoKamen = a[1]
	var v := KamenView.new(k)
	eq(v.count(), 2 * EcoKamen.PER_ROW * EcoKamen.TUBES)
	eq(v.tubes.multimesh.instance_count, v.count())
	var wm := k.rows[0].worms[0]
	var top := wm.tube_base[0] + Vector3(0, wm.tube_len[0], 0)
	near(v.crown_at[0].basis.get_scale().x, 1.0, 1e-4, "раскрыт — во весь размер")
	ok(v.crown_at[0].origin.y > top.y, "над устьем")
	var pred := w.spawn("pred", wm.base + Vector3(0, 1, 0))
	pred.v = Vector3(2, 0, 0)
	w.run(1.0)
	v.sync()
	near(v.crown_at[0].basis.get_scale().x, KamenView.CLOSED, 1e-4, "спрятан — мал")
	ok(v.crown_at[0].origin.y < top.y, "в трубке")
	v.free()
