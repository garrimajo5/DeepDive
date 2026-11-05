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
	var flash := RaduzhView.color_at(rv.body_buffer, n0)
	flash.a = 1.0   # в альфе тела — фаза биения ресничек (Б3), не цвет
	ok(flash.is_equal_approx(EcoRaduzh.member_color(sw, 0, 3.0)), "вспышка — без разброса")
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
		if not near(tr.basis.z.length(), k, 1e-4, "размер монетника %d в буфере" % cn.index):
			return
		ok(tr.basis.is_equal_approx(EcoCoins.coin_basis(cn, 2.0, CoinsView.coin_rate(cn))
				.scaled_local(CoinsView.coin_breath(cn, 2.0) * k)),
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


## Глазуны (Б4): у каждого свой размер ±12 % и краска песка (светлее-темнее ±12 %) — в буфере вида; альфа экземпляра
## — по-прежнему свет глаз. Без исправления все глазуны одного размера и белого цвета экземпляра.
func test_glazuns_differ_in_size_and_paint() -> void:
	var sizes := []
	var lums := []
	for n in 24:
		sizes.append(CoinsView.glazun_scale(n))
		var tn := CoinsView.glazun_tint(n)
		lums.append(tn.g)
		ok(tn.r >= tn.g * 0.96 - 1e-5 and tn.r <= tn.g * 1.04 + 1e-5, "теплее-холоднее ±4 %%: %s" % tn)
		eq(CoinsView.glazun_tint(n), CoinsView.glazun_tint(n), "один и тот же глазун — одна краска")
	var s := _span(sizes)
	ok(s.x >= 0.88 - 1e-5 and s.y <= 1.12 + 1e-5 and s.y - s.x > 0.12, "размер ±12 %%: %s" % s)
	var l := _span(lums)
	ok(l.x >= 0.88 - 1e-5 and l.y <= 1.12 + 1e-5 and l.y - l.x > 0.12, "светлее-темнее ±12 %%: %s" % l)
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var m := w.add(EcoMoss.new()) as EcoMoss
	var c := w.add(EcoCoins.new(m)) as EcoCoins
	if not ok(c.glazuns.size() > 1, "глазуны есть: %d" % c.glazuns.size()):
		return
	var v := CoinsView.new(c)
	v.sync(2.0)
	ok(v.bodies.multimesh.use_colors, "у глазуна цвет экземпляра")
	for gz in c.glazuns:
		var tr := KelpView.transform_at(v.body_buffer, gz.index, CoinsView.STRIDE_C)
		near(tr.basis.z.length(), CoinsView.glazun_scale(gz.index), 1e-4, "размер глазуна %d в буфере" % gz.index)
		var i := gz.index * CoinsView.STRIDE_C + 12
		ok(Color(v.body_buffer[i], v.body_buffer[i + 1], v.body_buffer[i + 2]).is_equal_approx(
				CoinsView.glazun_tint(gz.index)), "краска — цвет экземпляра")
		near(v.body_buffer[i + 3], CoinsView.eye_alpha(gz, 2.0, v.eye_lit[gz.index]), 1e-6, "альфа — свет глаз")
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


## Огнёвки (Б4): у рачка свой размер, яркость и тон — от красно-оранжевого до янтарного; цвет — экземпляра в буфере,
## на «Экономно» — у видимых тоже свой.
func test_ognevka_differ_and_carry_tint() -> void:
	var sizes := []
	var hues := []
	var lums := []
	for n in 20:
		sizes.append(OgnevkaView.shrimp_scale(n))
		var c := OgnevkaView.shrimp_color(n)
		hues.append(c.h)
		lums.append(c.get_luminance())
	var s := _span(sizes)
	ok(s.x >= 0.85 - 1e-5 and s.y <= 1.15 + 1e-5 and s.y - s.x > 0.12, "размер ±15 %%: %s" % s)
	var h := _span(hues)
	var base := OgnevkaView.COLOR.h
	ok(h.x >= base - OgnevkaView.HUE_SPREAD - 1e-4 and h.y <= base + OgnevkaView.HUE_SPREAD + 1e-4, "тон рядом с оранжевым: %s" % h)
	ok(h.y - h.x > 0.03, "тона разные: %s" % h)
	var l := _span(lums)
	ok(l.y - l.x > 0.1, "яркость разная: %s" % l)
	eq(OgnevkaView.shrimp_color(7), OgnevkaView.shrimp_color(7), "один и тот же рачок — один цвет")
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var ps := w.add(EcoPred.new()) as EcoPred
	var tops: Array[Vector3] = [Vector3(0, -36, 0), Vector3(80, -36, 0)]
	var lc := w.add(EcoLeech.new(ps, null, tops)) as EcoLeech
	var og := w.add(EcoOgnevka.new(lc)) as EcoOgnevka
	w.step(0.1)
	var v := OgnevkaView.new(og)
	ok(v.mesh.multimesh.use_colors, "у рачка цвет экземпляра")
	var mat := (v.mesh.multimesh.mesh as CapsuleMesh).material as StandardMaterial3D
	ok(mat.vertex_color_use_as_albedo and not mat.vertex_color_is_srgb, "цвет экземпляра — флаги как у огоньков гротовика, без нового шейдера")
	v.sync(true, 1.0)
	for i in [0, 3, 14]:
		near(v.placed[i].basis.z.length() / OgnevkaView.shrimp_scale(i), v.placed[i].basis.x.length() / OgnevkaView.shrimp_scale(i), 1e-4, "толщина по размеру (%d)" % i)
		var got := v.color_at(i)
		var want := OgnevkaView.shrimp_color(i)
		near(Vector3(got.r, got.g, got.b).distance_to(Vector3(want.r, want.g, want.b)), 0.0, 1e-3, "цвет рачка %d в буфере" % i)
	near(v.placed[3].basis.y.length(), (1.0 - OgnevkaView.STROKE_SHORT * OgnevkaView.stroke(1.0, og.shrimp[3].phase, og.shrimp[3].v.length())) * OgnevkaView.shrimp_scale(3), 1e-4, "длина — своя")
	v.set_lite(true)
	var n := lc.stations.size()
	var c1 := v.color_at(OgnevkaView.slot(1, n, true))
	var w1 := OgnevkaView.shrimp_color(1)
	near(Vector3(c1.r, c1.g, c1.b).distance_to(Vector3(w1.r, w1.g, w1.b)), 0.0, 1e-3, "на «Экономно» цвет у своего рачка")
	v.free()


## Шипоежи у ленточника (Б4): у ежа свой размер ±10 % — во весь рост буфер несёт его, мир не меняется.
func test_urchins_differ_in_size() -> void:
	var sizes := []
	for n in 12:
		sizes.append(KelpView.urchin_scale(n))
	var s := _span(sizes)
	ok(s.x >= 0.9 - 1e-5 and s.y <= 1.1 + 1e-5 and s.y - s.x > 0.08, "размер ±10 %%: %s" % s)
	var w := EcoWorld.new()
	w.ship.pos = Vector3(500, -30, 500)
	var k := w.add(EcoKelp.new(null, [Vector3(0, -40, 0)] as Array[Vector3])) as EcoKelp
	w.reset()
	var v := KelpView.new(k)
	v.sync(1.0)
	v.sync(1.0 + KelpView.URCHIN_RISE + 0.1)
	var t := 1.0 + KelpView.URCHIN_RISE + 0.1
	for u in k.urchins:
		var tr := KelpView.transform_at(v.urchin_buffer, u.index, KelpView.STRIDE)
		var want := EcoKelp.urchin_basis(u, t).x.length() * KelpView.urchin_scale(u.index)
		near(tr.basis.x.length(), want, 1e-4, "ёж %d — своего размера" % u.index)
	v.free()


func test_fern_leaves_differ_and_carry_tint() -> void:
	var lens := []
	var turns := []
	var lums := []
	var base := Basis.IDENTITY
	for n in 24:
		var b := FernView.leaf_shape(n, base)
		lens.append(b.y.length())
		turns.append(atan2(b.x.z, b.x.x))
		lums.append(FernView.leaf_tint(n).get_luminance())
	var s := _span(lens)
	ok(s.x >= 0.85 - 1e-5 and s.y <= 1.15 + 1e-5 and s.y - s.x > 0.12, "длина листа ±15 %%: %s" % s)
	var tr := _span(turns)
	ok(tr.x >= -FernView.LEAF_TURN - 1e-4 and tr.y <= FernView.LEAF_TURN + 1e-4 and tr.y - tr.x > 0.2,
		"поворот вокруг стебля ±0,2 рад: %s" % tr)
	ok(_span(lums).y - _span(lums).x > 0.1, "листья разной яркости")
	eq(FernView.leaf_tint(5), FernView.leaf_tint(5), "тот же лист — тот же цвет")
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var fr := w.add(EcoFern.new()) as EcoFern
	w.reset()
	var v := FernView.new(fr)
	ok(v.leaves.multimesh.use_colors, "у листа цвет экземпляра")
	v.sync(2.0)
	var fe := fr.ferns[2]
	for j in EcoFern.LEAVES:
		var n := fe.index * EcoFern.LEAVES + j
		var got := FernView.transform_at(v.buffer, n, FernView.STRIDE_C)
		var want := FernView.leaf_shape(n, EcoFern.leaf_basis(fe, j, 2.0))
		ok(got.basis.is_equal_approx(want), "лист %d — своей формы" % j)
		ok(got.origin.is_equal_approx(fe.pos), "из подножия куста")
		var i := n * FernView.STRIDE_C
		var c := FernView.leaf_tint(n)
		near(v.buffer[i + 12], c.r, 1e-5, "оттенок листа %d в буфере" % j)
		near(v.buffer[i + 14], c.b, 1e-5)
	ok(EcoShaders.PLANT.contains("* mix(0.55, 1.0, 1.0 - UV.y * 0.6) * COLOR.rgb"), "ветка листа берёт цвет экземпляра")
	v.free()


## Ледяная моль (Б4): у рачка свой размер ±15 % и яркость панциря ±20 % — в буфере по номеру рачка, сидящий на
## стекле — по своему месту; без исправления все карточки одного размера и яркости.
func test_moths_differ_in_size_and_shade() -> void:
	var sizes := []
	var shades := []
	for n in 30:
		sizes.append(MothView.moth_scale(n))
		shades.append(MothView.moth_shade(n))
	var s := _span(sizes)
	ok(s.x >= 0.85 - 1e-5 and s.y <= 1.15 + 1e-5 and s.y - s.x > 0.15, "размер ±15 %%: %s" % s)
	var l := _span(shades)
	ok(l.x >= 0.8 - 1e-5 and l.y <= 1.2 + 1e-5 and l.y - l.x > 0.2, "яркость ±20 %%: %s" % l)
	ok(MothView.CODE.contains("INSTANCE_CUSTOM.z"), "яркость — из своих данных экземпляра, шейдер тот же")
	var m := EcoMoth.new()
	m.reset(null)
	var v := MothView.new(m)
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(EcoMoth.WELL.x, -6.0, EcoMoth.WELL.y)
	v.sync(ship, 1.0)
	ok(v.visible, "у колодца виден")
	for i in [0, 5, 17]:
		near(v.scale_at(i), MothView.moth_scale(i), 1e-6, "размер рачка %d" % i)
		near(v.shade_at(i), MothView.moth_shade(i), 1e-6, "яркость рачка %d" % i)
	ok(absf(v.scale_at(0) - v.scale_at(5)) + absf(v.scale_at(5) - v.scale_at(17)) > 0.01, "карточки не одного размера")
	v.free()
## Иглы кольчужника (Б4): у иглы своя длина ±20 % и толщина ±12 % — в месте иглы на панцире, буфер несёт её
## размер; без исправления все десять игл одной длины.
func test_krab_spines_differ() -> void:
	var lens := []
	var ths := []
	for k in EcoKrab.SPINE_MAX:
		var b := KrabView.spine_transform(k).basis
		lens.append(b.y.length())
		ths.append(b.x.length())
		near(b.x.length(), b.z.length(), 1e-5, "игла круглая (%d)" % k)
		eq(KrabView.spine_transform(k), KrabView.spine_transform(k), "одна и та же игла — один размер")
	var l := _span(lens)
	ok(l.x >= 0.8 - 1e-5 and l.y <= 1.2 + 1e-5 and l.y - l.x > 0.15, "длина ±20 %%: %s" % l)
	var t := _span(ths)
	ok(t.x >= 0.88 - 1e-5 and t.y <= 1.12 + 1e-5 and t.y - t.x > 0.08, "толщина ±12 %%: %s" % t)
	near(KrabView.spine_at(4, 1.0).basis.y.length(), lens[4], 1e-5, "выросшая игла — своей длины")
## Пузырчатка (Б4): у луковицы свой размер ±15 % и яркость сока ±12 %, у стебля — толщина ±15 % по номеру луковицы;
## буфер несёт их поверх спелости куста. Без исправления семь луковиц куста — одного размера и цвета.
func test_bladder_bulbs_differ() -> void:
	var sizes := []
	var thick := []
	for n in 21:
		sizes.append(BladderView.bulb_scale(n))
		thick.append(BladderView.stem_thick(n))
	var s := _span(sizes)
	ok(s.x >= 0.85 - 1e-5 and s.y <= 1.15 + 1e-5 and s.y - s.x > 0.15, "размер ±15 %%: %s" % s)
	var w := _span(thick)
	ok(w.x >= 0.85 - 1e-5 and w.y <= 1.15 + 1e-5 and w.y - w.x > 0.15, "толщина ±15 %%: %s" % w)
	var c := Color(0.5, 0.8, 0.4)
	var lum := []
	for n in 21:
		var t := BladderView.bulb_tint(c, n)
		near(t.g / t.r, c.g / c.r, 1e-5, "тон сока тот же (%d)" % n)
		lum.append(t.g / c.g)
	var l := _span(lum)
	ok(l.x >= 0.88 - 1e-5 and l.y <= 1.12 + 1e-5 and l.y - l.x > 0.1, "яркость ±12 %%: %s" % l)
	var w2 := EcoWorld.new()
	w2.ground = Seabed.height
	w2.ship.pos = Vector3(500, 0, 500)
	var sys: EcoBladder = w2.add(EcoBladder.new(null)) as EcoBladder
	var v := BladderView.new(sys)
	v.sync(1.0)
	var bl: EcoBladder.Bush = sys.bushes[0]
	var r := EcoBladder.bulb_size(bl)
	var radii := []
	for k in EcoBladder.STEMS:
		var n := bl.index * EcoBladder.STEMS + k
		var b := BladderView.transform_at(v.bulb_buffer, n).basis
		var pw := 1.0 + BladderView.PULSE_W * BladderView.pulse(n, 1.0) * BladderView.pulse_k(r)
		near(b.x.length(), r * BladderView.bulb_scale(n) * pw, 1e-4, "луковица %d — своего размера" % k)
		radii.append(b.x.length())
		var st := BladderView.transform_at(v.stems.multimesh.buffer, n, BladderView.STRIDE).basis
		near(st.x.length(), BladderView.stem_thick(n), 1e-4, "стебель %d — своей толщины" % k)
		near(st.z.length(), st.x.length(), 1e-4, "стебель круглый (%d)" % k)
	var rs := _span(radii)
	ok(rs.y - rs.x > 0.01 * r, "луковицы куста не одного размера: %s" % rs)
	v.free()

## Хватни и пестрянки (Б4): у хватня своя ширина тела ±12 % (основания щупалец на диске — с ней), у пестрянки —
## размер ±15 % и яркость свечения ±20 % (тон тот же); буферы несут их. Без исправления четыре хватня и двенадцать
## пестрянок — одного размера и одной яркости.
func test_hvaten_and_pestr_differ() -> void:
	var widths := []
	var sizes := []
	for i in 24:
		widths.append(HvatenView.body_width(i))
		sizes.append(HvatenView.pestr_size(i))
	var w := _span(widths)
	ok(w.x >= 0.88 - 1e-5 and w.y <= 1.12 + 1e-5 and w.y - w.x > 0.1, "ширина тела ±12 %%: %s" % w)
	var s := _span(sizes)
	ok(s.x >= 0.85 - 1e-5 and s.y <= 1.15 + 1e-5 and s.y - s.x > 0.15, "размер пестрянки ±15 %%: %s" % s)
	var c := Color(1.0, 0.48, 0.16)
	var lum := []
	for n in 24:
		var g := HvatenView.pestr_glow(c, n)
		near(g.g / g.r, c.g / c.r, 1e-5, "тон тот же (%d)" % n)
		lum.append(g.r / c.r)
	var l := _span(lum)
	ok(l.x >= 0.8 - 1e-5 and l.y <= 1.2 + 1e-5 and l.y - l.x > 0.2, "яркость ±20 %%: %s" % l)
	var w2 := EcoWorld.new()
	w2.ground = func(_x: float, _z: float) -> float: return -40.0
	w2.ship.pos = Vector3(500, -30, 500)
	var f := w2.add(EcoFish.new()) as EcoFish
	var homes: Array[Vector3] = []
	for j in 4:
		homes.append(Vector3(EcoFish.HOMES[j].x + 3.0, -40.0, EcoFish.HOMES[j].z))
	var h := w2.add(EcoHvaten.new(f, homes)) as EcoHvaten
	var v := HvatenView.new(h)
	var t := 3.0
	v.sync(t)
	var n := h.anemones.size()
	var bw := []
	for hv in h.anemones:
		var b := HvatenView.transform_at(v.body_buffer, hv.index).basis
		var raw := EcoHvaten.body(hv, t).basis
		near(b.x.length() / raw.x.length(), HvatenView.body_width(hv.index), 1e-5, "тело %d — своей ширины" % hv.index)
		near(b.y.length(), raw.y.length(), 1e-5, "высота та же — диск на месте (%d)" % hv.index)
		bw.append(b.x.length() / raw.x.length())
		var tr := HvatenView.transform_at(v.tent_buffer, hv.index * EcoHvaten.TENT + 5)
		near(Vector2(tr.origin.x - hv.top.x, tr.origin.z - hv.top.z).length(),
			EcoHvaten.TENT_R * EcoHvaten.breath(hv, t) * HvatenView.body_width(hv.index), 1e-4,
			"щупальце растёт из диска своей ширины (%d)" % hv.index)
		for k in EcoHvaten.PESTR_N:
			var m := hv.index * EcoHvaten.PESTR_N + k
			var pe := HvatenView.transform_at(v.pestr_buffer, m, HvatenView.STRIDE_P)
			near(pe.basis.z.length(), EcoPestrLook.SCALE * HvatenView.pestr_size(m), 1e-5, "пестрянка %d — своего размера (длина — дыхание её не меняет)" % m)
	ok(_span(bw).y - _span(bw).x > 0.01, "хватни не одной ширины: %s" % [bw])
	ok(n > 0)
	v.free()


## Фонарные вуали: у каждой своя яркость куполов, ядра и колокольчиков (альфа цвета экземпляра) и свой ритм пульса.
func test_veils_differ_in_glow_and_rate() -> void:
	var g0 := VeilView.veil_glow(0)
	var g1 := VeilView.veil_glow(1)
	ok(absf(g0 - g1) > 0.03, "яркость разная: %.3f и %.3f" % [g0, g1])
	for g in [g0, g1]:
		ok(absf(g - 1.0) <= VeilView.GLOW_SPREAD + 1e-6, "в пределах ± GLOW_SPREAD")
	near(VeilView.glow(VeilView.CORE, g1).a, VeilView.CORE.a * g1, 1e-6, "ядро — с яркостью вуали")
	eq(VeilView.glow(VeilView.CORE, g1).r, VeilView.CORE.r, "тон тот же")
	near(VeilView.veil_glow(1), g1, 0.0, "каждый раз то же")
	ok(absf(EcoVeil.pulse_rate(0) - EcoVeil.pulse_rate(1)) > 0.03, "ритм пульса разный")


## Трубные органы (Б4): у трубы своя краска (светлее-темнее ±12 %, теплее-холоднее ±4 %), толщина ±10 % и обод тусклее
## до 15 % по номеру трубы; в меше устье — своей толщины. Без исправления все светлые трубы одного цвета и радиуса.
static func _flat_organ(_x: float, _z: float) -> float:
	return 0.0


func test_organ_tubes_differ() -> void:
	var widths := []
	var shades := []
	var rims := []
	for j in 40:
		widths.append(OrganView.tube_width(j))
		var c := OrganView.tube_color(j, 1)
		shades.append(c.g / OrganView.LIGHT.g)
		ok(c.r <= 1.0 and c.g <= 1.0 and c.b <= 1.0, "краска не ярче 1 (%d)" % j)
		rims.append(OrganView.rim_color(j).g / OrganView.RIM.g)
		eq(OrganView.tube_color(j, 1), OrganView.tube_color(j, 1), "одна и та же труба — одна краска")
	var w := _span(widths)
	ok(w.x >= 0.9 - 1e-5 and w.y <= 1.1 + 1e-5 and w.y - w.x > 0.1, "толщина ±10 %%: %s" % w)
	var s := _span(shades)
	ok(s.x >= 0.88 - 1e-5 and s.y <= 1.12 + 1e-5 and s.y - s.x > 0.12, "краска ±12 %%: %s" % s)
	var r := _span(rims)
	ok(r.x >= 0.85 - 1e-5 and r.y <= 1.0 + 1e-5 and r.y - r.x > 0.08, "обод тусклее до 15 %%: %s" % r)
	ok(OrganView.tube_color(3, 0).g < OrganView.tube_color(3, 1).g, "тёмная и светлая через одну остаются")
	var world := EcoWorld.new()
	world.ground = _flat_organ
	var organs := world.add(EcoOrgan.new()) as EcoOrgan
	var ov := OrganView.new(organs)
	var og := organs.organs[0]
	for k in 2:
		var j := EcoOrganDust.tube_id(og, k)
		var top := og.tube_base[k] + Vector3(0, og.tube_len[k], 0)
		var want := top + Vector3(EcoOrgan.TUBE_TOP_R * OrganView.tube_width(j), 0, 0)
		var best := INF
		for v in ov.verts:
			best = minf(best, v.distance_to(want))
		ok(best < 1e-4, "устье трубы %d — своей толщины (%.4f)" % [k, best])
	ov.free()


## Бахрома колодца 05: у нити своя ширина ±15 % и тон тела ±12 % по номеру — и в буфере MultiMesh они у каждой свои.
func test_fringe_strands_differ() -> void:
	var widths := []
	var shades := []
	for i in EcoFringe.COUNT:
		widths.append(FringeView.strand_width(i) / FringeView.WIDTH)
		shades.append(FringeView.strand_shade(i))
		eq(FringeView.strand_width(i), FringeView.strand_width(i), "одна и та же нить — одна ширина")
	var w := _span(widths)
	ok(w.x >= 0.85 - 1e-5 and w.y <= 1.15 + 1e-5 and w.y - w.x > 0.15, "ширина ±15 %%: %s" % w)
	var s := _span(shades)
	ok(s.x >= 0.88 - 1e-5 and s.y <= 1.12 + 1e-5 and s.y - s.x > 0.12, "тон ±12 %%: %s" % s)
	var f := EcoFringe.new()
	f.reset(null)
	var v := FringeView.new(f)
	tree.root.add_child(v)
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(EcoFringe.WELL.x, -20.0, EcoFringe.WELL.y)
	v.sync(ship, 0.0)
	ok(v.visible, "у колодца — виден")
	var sizes := {}
	for i in f.curtain.active:
		var b := i * FringeView.STRIDE
		near(v.buffer[b], FringeView.strand_width(i), 1e-6, "ширина нити %d — в базисе экземпляра" % i)
		near(v.buffer[b + 4], FringeView.strand_shade(i), 1e-6, "тон нити %d — там же" % i)
		sizes[snappedf(v.buffer[b], 0.001)] = true
	ok(sizes.size() > 10, "нити разной ширины: %d" % sizes.size())
	var code := v.material.shader.code
	ok(code.contains("shade = MODEL_MATRIX[0].y"), "шейдер берёт тон нити из экземпляра")
	ok(code.contains("* shade;"), "и красит им тело")
	v.queue_free()
	await frames(1)


## Огнецвет: у куста своя краска ветвей — светлее-темнее ±14 %, теплее-холоднее ±5 % по номеру; в меше она у куста своя.
func test_coral_bushes_differ_in_paint() -> void:
	var base := EcoCoralLook.BODY
	var shades := []
	for j in 40:
		var c := CoralView.bush_paint(j, base)
		shades.append(c.g / base.g)
		ok(c.r <= 1.0 and c.g <= 1.0 and c.b <= 1.0, "краска не ярче 1 (%d)" % j)
		eq(CoralView.bush_paint(j, base), CoralView.bush_paint(j, base), "один куст — одна краска")
	var s := _span(shades)
	ok(s.x >= 0.86 - 1e-5 and s.y <= 1.14 + 1e-5 and s.y - s.x > 0.14, "краска ±14 %%: %s" % s)
	var w := EcoWorld.new()
	w.ground = _flat_organ
	var coral := w.add(EcoCoral.new([Vector2(0, 0), Vector2(20, 0), Vector2(40, 0)] as Array[Vector2])) as EcoCoral
	var view := CoralView.new(coral)
	var cols: PackedColorArray = view.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var n := view.form.verts.size()
	var firsts := {}
	for k in coral.bushes.size():
		var b := coral.bushes[k]
		var got := cols[k * n]
		var want := CoralView.bush_paint(b.index, view.form.colors[0])
		var d := Vector3(got.r - want.r, got.g - want.g, got.b - want.b).length()
		ok(d < 0.01, "куст %d — своей краски (%.4f)" % [k, d])
		firsts[got.to_html()] = true
	ok(firsts.size() == coral.bushes.size(), "кусты не одной краски: %d" % firsts.size())
	view.free()


func test_moss_patches_differ_in_paint() -> void:
	var shades := []
	var hues := []
	for j in 40:
		var t := MossView.patch_tint(j)
		shades.append(t.g)
		hues.append(t.r / t.g - 1.0)
		eq(MossView.patch_tint(j), MossView.patch_tint(j), "одно пятно — одна краска")
		ok(t.r * 0.5 <= 1.0 and t.g * 0.5 <= 1.0 and t.b * 0.5 <= 1.0, "краска ÷ 2 влезает в цвет вершины (%d)" % j)
	var s := _span(shades)
	ok(s.x >= 0.85 - 1e-5 and s.y <= 1.15 + 1e-5 and s.y - s.x > 0.15, "светлее-темнее ±15 %%: %s" % s)
	var h := _span(hues)
	ok(h.x >= -0.06 - 1e-5 and h.y <= 0.06 + 1e-5 and h.y - h.x > 0.06, "желтее-голубее ±6 %%: %s" % h)
	var w := EcoWorld.new()
	w.ground = _flat_organ
	var spots: Array[Vector3] = [Vector3(0, 0, 0), Vector3(20, 0, 0), Vector3(40, 0, 0), Vector3(60, 0, 0)]
	var moss := w.add(EcoMoss.new(spots)) as EcoMoss
	for lite in [false, true]:
		var view := MossView.new(moss, _flat_organ, lite)
		var cols: PackedColorArray = view.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var per := view.look.verts.size() / moss.patches.size()
		var seen := {}
		for k in moss.patches.size():
			var want := MossView.patch_tint(moss.patches[k].index)
			for v in [k * per, k * per + per - 1]:
				var got := cols[v]
				var d := Vector3(got.g * 2.0 - want.r, got.b * 2.0 - want.g, got.a * 2.0 - want.b).length()
				ok(d < 0.02, "пятно %d — своей краски (%.4f, lite %s)" % [k, d, lite])
				near(got.r, view.look.base[v], 0.01, "яркость вершины — в красном, как была")
			seen[cols[k * per].to_html()] = true
		ok(seen.size() == moss.patches.size(), "пятна не одной краски: %d" % seen.size())
		eq(view.mesh.get_surface_count(), 1, "мох — по-прежнему один меш")
		view.free()
	ok(EcoShaders.MOSS.contains("moss_color * tint"), "шейдер красит пятно")


static func _flat_sk(_x: float, _z: float) -> float:
	return -40.0


## Скальник (Б4): у каждого из восьми щупалец своя длина ±15 %, толщина звеньев ±12 % и ритм колыхания ±20 % по
## номеру щупальца. Без исправления концы всех щупалец — на одном расстоянии от мантии, шары одной толщины.
func test_skalnik_arms_differ() -> void:
	var reach := []
	var thick := []
	var rate := []
	for a in SkalnikView.ARMS:
		reach.append(SkalnikView.arm_reach(a))
		thick.append(SkalnikView.arm_thick(a))
		rate.append(SkalnikView.arm_rate(a))
		eq(SkalnikView.arm_reach(a), SkalnikView.arm_reach(a), "одно щупальце — одна длина")
	var r := _span(reach)
	ok(r.x >= 0.85 - 1e-5 and r.y <= 1.15 + 1e-5 and r.y - r.x > 0.1, "длина ±15 %%: %s" % r)
	var th := _span(thick)
	ok(th.x >= 0.88 - 1e-5 and th.y <= 1.12 + 1e-5 and th.y - th.x > 0.06, "толщина ±12 %%: %s" % th)
	var ra := _span(rate)
	ok(ra.x >= 0.8 - 1e-5 and ra.y <= 1.2 + 1e-5 and ra.y - ra.x > 0.1, "ритм ±20 %%: %s" % ra)
	var w := EcoWorld.new()
	w.ground = _flat_sk
	w.ship.pos = Vector3(500, -30, 500)
	var spots: Array[Vector3] = [Vector3(-60, -40, 0), Vector3(0, -40, 0)]
	var k := w.add(EcoKelp.new(null, spots)) as EcoKelp
	var kr := w.add(EcoKrab.new(k)) as EcoKrab
	var s := w.add(EcoSkalnik.new(kr)) as EcoSkalnik
	var v := SkalnikView.new(s)
	s.octo.camo = 0.0
	s.octo.state = EcoSkalnik.State.STALK   # раскрытый: щупальца во всю длину
	v.spread_k = 1.0
	v.sync(1.0, s.octo.pos + Vector3(0, 0, 10), true)
	var tips := []
	var sizes := []
	var mm := v.arms.multimesh
	for a in SkalnikView.ARMS:
		var tip := _sk_at(v, a * SkalnikView.SEG + SkalnikView.SEG - 1)
		var base := _sk_at(v, a * SkalnikView.SEG)
		var ang := float(a) / SkalnikView.ARMS * TAU + 0.2
		var j := SkalnikView.SEG - 1
		var rr := 0.35 + j * 0.24 * SkalnikView.arm_reach(a)
		var ww := sin(1.0 * 2.5 * SkalnikView.arm_rate(a) + a + j * 0.7) * 0.06 * j
		near(tip.origin.x - s.octo.pos.x, cos(ang) * rr + ww, 1e-3, "конец щупальца %d — своей длины и ритма (x)" % a)
		near(tip.origin.z - s.octo.pos.z, sin(ang) * rr - ww, 1e-3, "конец щупальца %d — своей длины и ритма (z)" % a)
		tips.append(rr)
		sizes.append(base.basis.x.length())
		near(base.basis.x.length(), 0.2 * SkalnikView.arm_thick(a), 1e-4, "звено — толщины своего щупальца (%d)" % a)
	var tp := _span(tips)
	ok(tp.y - tp.x > 0.1, "концы щупалец на разном расстоянии: %s" % tp)
	eq(mm.instance_count, SkalnikView.ARMS * SkalnikView.SEG, "звеньев столько же — один MultiMesh")
	v.free()


## Звено щупальца скальника из буфера вида (в headless MultiMesh своих трансформов не возвращает).
func _sk_at(v: SkalnikView, i: int) -> Transform3D:
	var b := v._buf
	var o := i * SkalnikView.STRIDE
	return Transform3D(Basis(Vector3(b[o], b[o + 4], b[o + 8]), Vector3(b[o + 1], b[o + 5], b[o + 9]),
		Vector3(b[o + 2], b[o + 6], b[o + 10])), Vector3(b[o + 3], b[o + 7], b[o + 11]))


## Планктон: у клетки свой размер (±25 %) и яркость (±20 %) по номеру — в масштабе базиса и INSTANCE_CUSTOM.w буфера.
func test_plankton_cells_differ() -> void:
	var sizes := []
	var glows := []
	for id in 200:
		sizes.append(PlanktonView.cell_scale(id))
		glows.append(PlanktonView.cell_glow(id))
	eq(PlanktonView.cell_scale(7), PlanktonView.cell_scale(7), "одна клетка — один размер")
	var s := _span(sizes)
	ok(s.x >= 0.75 - 1e-5 and s.y <= 1.25 + 1e-5 and s.y - s.x > 0.3, "размер ±25 %%: %s" % s)
	var g := _span(glows)
	ok(g.x >= 0.8 - 1e-5 and g.y <= 1.2 + 1e-5 and g.y - g.x > 0.25, "яркость ±20 %%: %s" % g)
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float: return -50.0
	w.ship.pos = Vector3(1e5, -30, 1e5)
	var spots: Array[Vector2] = [Vector2(0, 0), Vector2(80, 0)]
	var pl := w.add(EcoPlankton.new(null, null, spots)) as EcoPlankton
	var v := PlanktonView.new(pl)
	var seen := []
	for c in pl.clouds.size():
		for k in [0, 5, EcoPlankton.PER_CLOUD - 1]:
			var id := PlanktonView.cell_id(c, k)
			near(v.scale_at(c, k), PlanktonView.cell_scale(id), 1e-6, "размер клетки %d/%d — в базисе" % [c, k])
			near(v.glow_at(c, k), PlanktonView.cell_glow(id), 1e-6, "яркость клетки %d/%d — в буфере" % [c, k])
			seen.append(v.scale_at(c, k))
	ok(_span(seen).y - _span(seen).x > 0.05, "клетки разного размера: %s" % _span(seen))
	var cl := pl.clouds[1]
	near(v.origin_at(1, 3).distance_to(cl.home + cl.offsets[3]), 0.0, 1e-4, "дом клетки на месте")
	eq(v.cells.multimesh.instance_count, pl.clouds.size() * EcoPlankton.PER_CLOUD, "клеток столько же — один MultiMesh")
	ok(EcoShaders.SPOT.contains("* INSTANCE_CUSTOM.w"), "шейдер облака умножает свечение на яркость клетки")
	v.free()
