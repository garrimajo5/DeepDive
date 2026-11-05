extends TestCase
## Светляки у дна (план Б3, docs/grafika-plan-eco.md): дно впереди — по наклону из двух последних выборок
## (`EcoAgent.ground_ahead`), рыбка не встаёт на дне за кадр и не подскакивает на зажиме clearance.


## Склон 1:1 вдоль −Z (идти к −Z — в гору) с мелкой рябью, чтобы наклон не был ровным.
static func _slope(x: float, z: float) -> float:
	return -60.0 - z + 0.6 * sin(x * 0.7) + 0.4 * sin(z * 1.3)


## Первые шаги не меряются: рыбки поставлены на склон руками, наклон дна у каждой ещё не набран (две выборки).
const WARM := 20


## Стая 0 на склоне, хищник у стаи — тревога, стая несётся к дому: dir — куда дом от стаи (в гору или под гору).
## Возвращает [худшее вертикальное ускорение места рыбки, м/с²; самый глубокий заход под дно, м; быстрейшая рыбка].
func _run(dir: Vector3) -> Array[float]:
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = _slope
	w.ship.pos = Vector3(500, 0, 500)
	var fish := EcoFish.new()
	w.add(fish)
	var sh: EcoFish.Shoal = fish.shoals[0]
	var c := sh.home
	c.y = _slope(c.x, c.z) + 1.5
	sh.home = c + dir * 30.0
	sh.home.y = _slope(sh.home.x, sh.home.z) + 1.0
	for f: EcoFish.Fish in sh.members:
		f.agent.p = c + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		f.agent.p.y = _slope(f.agent.p.x, f.agent.p.z) + randf_range(0.6, 2.5)
		f.agent.v = Vector3.ZERO
	sh.center = c
	w.ship.pos = c + Vector3(40, 0, 0)
	var dt := 1.0 / 30.0
	var pred := w.spawn("pred", c - dir * 5.0)
	var prev := {}
	var last := {}
	var worst := 0.0
	var under := 0.0
	var fast := 0.0
	for i in int(5.0 / dt):
		pred.p = sh.center - dir * 5.0
		w.ship.pos = sh.center + Vector3(40, 0, 0)  # ближе MID: стая шагает каждый шаг мира
		w.step(dt)
		for f: EcoFish.Fish in sh.members:
			if not f.agent.alive:
				continue
			var p := f.agent.p
			under = maxf(under, _slope(p.x, p.z) - p.y)
			fast = maxf(fast, f.agent.v.length())
			if i >= WARM and last.has(f) and prev.has(f):
				var a: float = ((p.y - last[f]) - (last[f] - prev[f])) / (dt * dt)
				worst = maxf(worst, absf(a))
			if last.has(f):
				prev[f] = last[f]
			last[f] = p.y
	return [worst, under, fast]


func test_no_bounce_uphill_or_dive_downhill() -> void:
	seed(7)
	var up := _run(Vector3(0, 0, -1))
	var down := _run(Vector3(0, 0, 1))
	ok(up[2] > 4.0 and down[2] > 4.0, "стая неслась к дому: %.1f / %.1f м/с" % [up[2], down[2]])
	ok(up[1] < 0.05 and down[1] < 0.05, "под дно не уходит: %.2f / %.2f м" % [up[1], down[1]])
	ok(up[0] < 60.0, "в гору — без подскоков на зажиме: %.0f м/с²" % up[0])
	ok(down[0] < 60.0, "под гору — не встаёт на дне за кадр: %.0f м/с²" % down[0])


## На настоящем дне (Seabed.height): каждая стая рифа в тревоге несётся домой из 25 м в сторону — вертикальное
## ускорение рыбки у дна не больше, чем гасит FLOOR_BRAKE с запасом на неровность дна.
func test_real_floor_alarm_run_home() -> void:
	seed(11)
	var worst := 0.0
	var under := 0.0
	var dt := 1.0 / 30.0
	for k in 6:
		var w := EcoWorld.new(EcoRandom.WORLD_SEED)
		w.ground = Seabed.height
		w.ship.pos = Vector3(500, 0, 500)
		var fish := EcoFish.new()
		w.add(fish)
		var sh: EcoFish.Shoal = fish.shoals[k]
		var dir := Vector3(cos(k * 1.1), 0, sin(k * 1.1))
		var c := sh.home - dir * 25.0
		c.y = Seabed.height(c.x, c.z) + 1.0
		for f: EcoFish.Fish in sh.members:
			f.agent.p = c + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
			f.agent.p.y = Seabed.height(f.agent.p.x, f.agent.p.z) + randf_range(0.6, 2.5)
			f.agent.v = Vector3.ZERO
		sh.center = c
		var pred := w.spawn("pred", c - dir * 5.0)
		var prev := {}
		var last := {}
		for i in int(5.0 / dt):
			pred.p = sh.center - dir * 5.0
			w.ship.pos = sh.center + Vector3(0, 30, 0)
			w.step(dt)
			for f: EcoFish.Fish in sh.members:
				if not f.agent.alive:
					continue
				var p := f.agent.p
				under = maxf(under, Seabed.height(p.x, p.z) - p.y)
				if i >= WARM and last.has(f) and prev.has(f):
					worst = maxf(worst, absf(((p.y - last[f]) - (last[f] - prev[f])) / (dt * dt)))
				if last.has(f):
					prev[f] = last[f]
				last[f] = p.y
	print("настоящее дно: ", worst, " под дном ", under)
	ok(under < 0.05, "под дно не уходит: %.2f м" % under)
	ok(worst < 60.0, "у дна без подскоков: %.0f м/с²" % worst)
