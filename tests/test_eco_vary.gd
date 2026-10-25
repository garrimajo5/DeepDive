extends TestCase
## Разброс особей в MultiMesh (Б4, `docs/grafika-plan-eco.md`): у светляков, скребунов, радужников, монетников,
## веерников, пиявников и прилипал свой размер, оттенок
## и ритм — стая не клоны. Числа — хешем от номера особи (EcoVary): мир и его случай не меняются, вид один и тот же
## при каждом запуске, вызовов отрисовки и шейдеров не прибавилось.


func _fish_world() -> EcoWorld:
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	w.add(EcoFish.new())
	return w


func _grazer_world() -> EcoWorld:
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var m := w.add(EcoMoss.new()) as EcoMoss
	w.add(EcoGrazer.new(m))
	return w


func _span(xs: Array) -> Vector2:
	var lo := INF
	var hi := -INF
	for x: float in xs:
		lo = minf(lo, x)
		hi = maxf(hi, x)
	return Vector2(lo, hi)


func _mean(xs: Array) -> float:
	var s := 0.0
	for x: float in xs:
		s += x
	return s / xs.size()


func test_hash_stable_and_in_range() -> void:
	var seen := {}
	for i in 500:
		var u := EcoVary.unit(i, EcoVary.SIZE)
		if not ok(u >= 0.0 and u < 1.0, "в [0, 1): %f" % u):
			return
		eq(u, EcoVary.unit(i, EcoVary.SIZE), "тот же номер — то же число")
		seen[snappedf(u, 0.1)] = true
		var s := EcoVary.spread(i, EcoVary.SHADE, 0.2)
		if not ok(s >= 0.8 and s <= 1.2, "1 ± 0,2: %f" % s):
			return
	ok(seen.size() >= 10, "покрывает весь отрезок: %d десятых" % seen.size())
	var same := 0
	for i in 200:
		if absf(EcoVary.unit(i, EcoVary.SIZE) - EcoVary.unit(i, EcoVary.SHADE)) < 0.02:
			same += 1
	ok(same < 12, "свойства одной особи не связаны: совпало %d из 200" % same)
	var close := 0
	for i in 199:
		if absf(EcoVary.unit(i, EcoVary.SIZE) - EcoVary.unit(i + 1, EcoVary.SIZE)) < 0.02:
			close += 1
	ok(close < 12, "соседи по номеру не похожи: %d из 199" % close)


func test_fish_differ_in_size_shade_and_rhythm() -> void:
	var fish := _fish_world().systems[0] as EcoFish
	var sizes := []
	var shades := []
	var rates := []
	for f: EcoFish.Fish in fish.all:
		if f.shoal.cage:
			continue  # молодь — своим размером, ниже
		sizes.append(EcoFishLook.scale(f))
		shades.append(EcoFishLook.shade(f))
		rates.append(EcoFishLook.wiggle_rate(f))
	var s := _span(sizes)
	ok(s.x >= 1.0 - EcoFishLook.SIZE_SPREAD - 1e-5 and s.y <= 1.0 + EcoFishLook.SIZE_SPREAD + 1e-5,
		"размер взрослых в пределах ±12 %%: %s" % s)
	ok(s.y - s.x > 0.18, "и заметно разный: %s" % s)
	near(_mean(sizes), 1.0, 0.03, "в среднем — прежняя рыбка")
	var d := _span(shades)
	ok(d.y - d.x > 0.3 and d.x >= 0.8 - 1e-5 and d.y <= 1.2 + 1e-5, "тело светлее-темнее: %s" % d)
	var r := _span(rates)
	ok(r.y - r.x > 3.0, "хвостами машут не в лад: %s рад/с" % r)
	near(_mean(rates), EcoFishLook.WIGGLE_RATE, 0.6, "средняя частота прежняя")
	# у каждой рыбки своё, вид не зависит от зерна мира (тот же номер — та же рыбка)
	var other := EcoWorld.new(77)
	other.ground = Seabed.height
	other.ship.pos = Vector3(500, 0, 500)
	var fish2 := other.add(EcoFish.new()) as EcoFish
	for i in 20:
		eq(EcoFishLook.scale(fish2.all[i]), EcoFishLook.scale(fish.all[i]), "размер — по номеру особи")


func test_fish_buffer_carries_variation() -> void:
	var fish := _fish_world().systems[0] as EcoFish
	var buf := FishView.pack(fish, 2.0)
	var shades := {}
	for f: EcoFish.Fish in fish.all:
		var tr := FishView.transform_at(buf, f.index)
		if not near(tr.basis.x.length(), EcoFishLook.scale(f), 1e-4, "размер в буфере — EcoFishLook.scale"):
			return
		if not ok(tr.basis.z.distance_to(EcoFishLook.basis(f, 2.0).z) < 1e-4, "курс с вилянием особи"):
			return
		near(FishView.shade_at(buf, f.index), EcoFishLook.shade(f), 1e-5, "оттенок тела в INSTANCE_CUSTOM.a")
		shades[snappedf(FishView.shade_at(buf, f.index), 0.05)] = true
	ok(shades.size() >= 6, "тела разного оттенка: %d" % shades.size())
	ok(FishView.SHADER.contains("body_color * shade"), "шейдер берёт оттенок особи")


func test_grazers_differ_and_stand_on_ground() -> void:
	var w := _grazer_world()
	var grazers: EcoGrazer = null
	for sys in w.systems:
		if sys is EcoGrazer:
			grazers = sys
	var sizes := []
	var tints := {}
	for g: EcoGrazer.Grazer in grazers.all:
		var k := EcoGrazerLook.scale(g)
		sizes.append(k)
		ok(k >= 0.9 - 1e-5 and k <= 1.1 + 1e-5, "размер ±10 %%: %f" % k)
		var tn := EcoGrazerLook.tint(g)
		tints[Vector3i(roundi(tn.r * 40), roundi(tn.g * 40), roundi(tn.b * 40))] = true
		ok(tn.g >= 0.88 - 1e-5 and tn.g <= 1.12 + 1e-5 and absf(tn.r - tn.b) <= 2.0 * 0.06 * 1.12 + 1e-4,
			"оттенок в пределах: %s" % tn)
		# стопы остаются на дне при любом размере
		var low := INF
		for i in EcoGrazerLook.verts_per_grazer():
			low = minf(low, EcoGrazerLook.place(g, 0.0, i).y)
		near(low, g.agent.p.y - EcoGrazer.LIFT, 1e-3, "стопы скребуна %d на дне" % g.index)
	var s := _span(sizes)
	ok(s.y - s.x > 0.08, "скребуны разного размера: %s" % s)
	ok(tints.size() >= grazers.all.size() * 0.7, "почти все разного оттенка: %d из %d" % [tints.size(), grazers.all.size()])
	var buf := GrazerView.pack(grazers, 1.0)
	for g: EcoGrazer.Grazer in grazers.all:
		ok(GrazerView.tint_at(buf, g.index).is_equal_approx(EcoGrazerLook.tint(g)), "оттенок — цвет экземпляра")


## Разброс не трогает случай мира: стаи плывут так же, как без него (поведение берёт f.size, не scale()).
func test_world_unchanged() -> void:
	var a := _fish_world()
	var b := _fish_world()
	a.run(5.0)
	b.run(5.0)
	var fa := a.systems[0] as EcoFish
	var fb := b.systems[0] as EcoFish
	for i in fa.all.size():
		if not ok(fa.all[i].agent.p.distance_to(fb.all[i].agent.p) < 1e-6, "рыбка %d там же" % i):
			return
	for f: EcoFish.Fish in fa.all:
		if not near(f.agent.clearance, 0.4 * f.size, 1e-6, "зазор — по размеру возраста"):
			return


func _raduzh_view() -> RaduzhView:
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	return RaduzhView.new(w.add(EcoRaduzh.new()) as EcoRaduzh)


func test_raduzh_differ_in_size_rhythm_and_shade() -> void:
	var rv := _raduzh_view()
	var r := rv.raduzh
	var sizes := []
	var shades := []
	var rates := []
	for sw in r.swarms:
		for k in EcoRaduzh.PER_SWARM:
			var n := sw.index * EcoRaduzh.PER_SWARM + k
			sizes.append(RaduzhView.member_scale(n))
			rates.append(RaduzhView.member_rate(n))
			shades.append(RaduzhView.member_shade(n))
	var s := _span(sizes)
	ok(s.x >= 0.85 - 1e-5 and s.y <= 1.15 + 1e-5 and s.y - s.x > 0.2, "размер ±15 %%: %s" % s)
	near(_mean(sizes), 1.0, 0.04, "в среднем — прежний гребневик")
	var rt := _span(rates)
	ok(rt.y - rt.x > 0.7, "дышат не в лад: %s рад/с" % rt)
	near(_mean(rates), RaduzhView.BREATH_RATE, 0.15, "средняя частота прежняя")
	var d := _span(shades)
	ok(d.y - d.x > 0.35, "силуэты светлее-темнее: %s" % d)
	# в буфере: размер в basis (в момент без дыхания — sin = 0 при t = −phase/rate, проще сравнить отношение осей)
	rv.sync(3.0, Vector3(1e6, 0, 1e6), 0.0, true)
	var sw := r.swarms[1]
	for k in EcoRaduzh.PER_SWARM:
		var n := sw.index * EcoRaduzh.PER_SWARM + k
		var j := n * RaduzhView.STRIDE_C
		var bx := Vector3(rv.body_buffer[j], rv.body_buffer[j + 4], rv.body_buffer[j + 8]).length()
		var m := sw.members[k]
		var want := RaduzhView.BODY.x * RaduzhView.member_scale(n) \
			* (1.0 + sin(3.0 * RaduzhView.member_rate(n) + m.phase) * 0.08)
		if not near(bx, want, 1e-4, "размер гребневика %d в буфере" % n):
			return
		var c := RaduzhView.color_at(rv.body_buffer, n)
		var base := EcoRaduzh.member_color(sw, k, 3.0)
		if not near(c.b, base.b * RaduzhView.member_shade(n), 1e-5, "силуэт без света — свой оттенок"):
			return
	# во вспышке радуга одна на всех: оттенок особи не гасит её
	sw.glow = 1.0
	rv.sync(3.0, Vector3(1e6, 0, 1e6), 0.0, true)
	var n0 := sw.index * EcoRaduzh.PER_SWARM
	ok(RaduzhView.color_at(rv.body_buffer, n0).is_equal_approx(EcoRaduzh.member_color(sw, 0, 3.0)), "вспышка — без разброса")
	eq(rv.bodies.multimesh.instance_count, r.swarms.size() * EcoRaduzh.PER_SWARM, "те же экземпляры")
	rv.free()


func test_coins_differ_and_carry_tint() -> void:
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var m := w.add(EcoMoss.new()) as EcoMoss
	var c := w.add(EcoCoins.new(m)) as EcoCoins
	if not ok(c.coins.size() > 10, "монетники есть: %d" % c.coins.size()):
		return
	var v := CoinsView.new(c)
	v.sync(2.0)
	ok(v.fish.multimesh.use_colors, "у монетника цвет экземпляра")
	var sizes := []
	var rates := []
	var tints := {}
	for cn in c.coins:
		var k := CoinsView.coin_scale(cn)
		sizes.append(k)
		rates.append(CoinsView.coin_rate(cn))
		var tn := CoinsView.coin_tint(cn)
		tints[Vector3i(roundi(tn.r * 40), roundi(tn.g * 40), roundi(tn.b * 40))] = true
		ok(tn.g >= 0.85 - 1e-5 and tn.g <= 1.15 + 1e-5, "светлее-темнее ±15 %%: %s" % tn)
		var tr := KelpView.transform_at(v.coin_buffer, cn.index, CoinsView.STRIDE_C)
		if not near(tr.basis.x.length(), k, 1e-4, "размер монетника %d в буфере" % cn.index):
			return
		ok(tr.basis.is_equal_approx(EcoCoins.coin_basis(cn, 2.0, CoinsView.coin_rate(cn)).scaled_local(Vector3.ONE * k)),
			"покачивание — в своём ритме")
		var i := cn.index * CoinsView.STRIDE_C + 12
		ok(Color(v.coin_buffer[i], v.coin_buffer[i + 1], v.coin_buffer[i + 2]).is_equal_approx(tn), "оттенок — цвет экземпляра")
	var s := _span(sizes)
	ok(s.x >= 0.88 - 1e-5 and s.y <= 1.12 + 1e-5 and s.y - s.x > 0.15, "размер ±12 %%: %s" % s)
	var r := _span(rates)
	ok(r.y - r.x > 0.6, "качаются не в лад: %s рад/с" % r)
	ok(tints.size() >= c.coins.size() * 0.7, "почти все разного оттенка: %d из %d" % [tints.size(), c.coins.size()])
	eq(EcoCoins.coin_basis(c.coins[0], 1.0), EcoCoins.coin_basis(c.coins[0], 1.0, CoinsView.ROCK_RATE),
		"без своего ритма — прежнее покачивание")
	v.free()


func test_fans_differ_and_carry_tint() -> void:
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var cur := w.add(EcoCurrent.new()) as EcoCurrent
	w.add(EcoCoral.new())
	var f := w.add(EcoFan.new(cur)) as EcoFan
	var v := FanView.new(f)
	v.sync(1.5)
	ok(v.multimesh.use_colors, "у веера цвет экземпляра")
	var sizes := []
	var tints := {}
	for fan in f.fans:
		var k := FanView.fan_scale(fan.index)
		sizes.append(k)
		var tr := FanView.transform_at(v.buffer, fan.index)
		if not near(tr.basis.y.length(), k, 1e-4, "размер веера %d в буфере" % fan.index):
			return
		ok(tr.basis.is_equal_approx(EcoFan.basis(fan, 1.5) * k), "поворот к потоку прежний")
		var tn := FanView.fan_tint(fan.index)
		ok(tn.r >= 0.85 - 1e-5 and tn.r <= 1.15 + 1e-5, "светлее-темнее ±15 %%: %s" % tn)
		var i := fan.index * FanView.STRIDE + 12
		ok(Color(v.buffer[i], v.buffer[i + 1], v.buffer[i + 2]).is_equal_approx(tn), "оттенок — цвет экземпляра")
		tints[Vector3i(roundi(tn.r * 40), roundi(tn.g * 40), roundi(tn.b * 40))] = true
	var s := _span(sizes)
	ok(s.x >= 0.85 - 1e-5 and s.y <= 1.15 + 1e-5 and s.y - s.x > 0.08, "размер ±15 %%: %s" % s)
	eq(tints.size(), f.fans.size(), "все веера разного оттенка")
	ok(EcoShaders.PLANT.contains("smoothstep(1.6, 2.6, el)) * COLOR.rgb"), "кружево веера берёт цвет экземпляра")
	v.free()


func test_remoras_differ() -> void:
	var sizes := []
	var rates := []
	var shades := []
	for n in 12:
		sizes.append(RemoraView.remora_scale(n))
		rates.append(RemoraView.remora_rate(n))
		shades.append(RemoraView.remora_shade(n))
	var s := _span(sizes)
	ok(s.x >= 0.85 - 1e-5 and s.y <= 1.15 + 1e-5 and s.y - s.x > 0.15, "размер ±15 %%: %s" % s)
	var r := _span(rates)
	ok(r.x >= 14.0 * 0.8 - 1e-4 and r.y <= 14.0 * 1.2 + 1e-4 and r.y - r.x > 3.0, "виляют не в лад: %s рад/с" % r)
	var d := _span(shades)
	ok(d.y - d.x > 0.1, "светлее-темнее: %s" % d)
	# на плаву: поворот хвоста в своём ритме, масштаб — свой
	var rm := EcoRemora.Remora.new()
	rm.index = 3
	rm.dir = Vector3(1, 0, 0)
	rm.ph = 0.4
	rm.mode = EcoRemora.Mode.SWIM
	var x := RemoraView.place(rm, 0.7)
	near(x.basis.z.length(), RemoraView.SCALE * RemoraView.remora_scale(3), 1e-4, "масштаб рыбы 3")
	var want := Basis.looking_at(-rm.dir, Vector3.UP) * Basis(Vector3.UP, sin(0.7 * RemoraView.remora_rate(3) + 0.4) * RemoraView.WAG)
	ok(x.basis.orthonormalized().is_equal_approx(want), "виляние — своей частотой")
	var view := RemoraView.new(EcoRemora.new())
	ok(view.multimesh.use_colors, "у прилипалы цвет экземпляра")
	view.free()


func test_leeches_differ() -> void:
	var sizes := []
	var rates := []
	for n in 6:
		sizes.append(LeechView.leech_scale(n))
		rates.append(LeechView.leech_rate(n))
	var s := _span(sizes)
	ok(s.x >= 0.85 - 1e-5 and s.y <= 1.15 + 1e-5 and s.y - s.x > 0.08, "размер ±15 %%: %s" % s)
	var r := _span(rates)
	ok(r.y - r.x > 0.3, "изгибаются не в лад: %s рад/с" % r)
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var ps := w.add(EcoPred.new()) as EcoPred
	var lc := w.add(EcoLeech.new(ps)) as EcoLeech
	var pr := ps.all[0]
	pr.leech = true
	var v := LeechView.new(lc)
	ok(v.mesh.multimesh.use_colors, "у ленты цвет экземпляра")
	v.sync(1.0)
	var x := v.placed[0]
	near(x.basis.y.length(), LeechView.leech_scale(pr.index), 1e-4, "длина ленты — своя")
	var k := LeechView.leech_shade(pr.index)
	ok(v.color_at(0).is_equal_approx(Color(k, k, k, 1.0)), "оттенок — цвет экземпляра")
	v.free()
