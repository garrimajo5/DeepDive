extends TestCase
## Облачка слизи у огнецвета (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): куст рывком гасит кончики — разряд даёт
## густой клуб, импульс сонара — меньше, шумный ход рядом — два слабых облачка, один раз за угасание; погасший куст,
## разгорание, дальний корабль и «Экономно» облачков не дают; облачка — у кончиков; в сцене — свой MultiMesh на
## общем шейдере мира.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
const BASE := Vector2(10.0, 10.0)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	w.add(EcoCoral.new([BASE] as Array[Vector2]))
	return w


func _coral(w: EcoWorld) -> EcoCoral:
	return w.systems[0] as EcoCoral


## Корабль стоит в 25 м от куста (не шумит: ближе 18 м не подходит).
func _near(w: EcoWorld) -> void:
	w.ship.pos = _coral(w).bushes[0].top + Vector3(0, 5, 24)
	w.ship.speed = 0.0


func _run(w: EcoWorld, d: EcoCoralDust, secs: float) -> void:
	var t := 0.0
	while t < secs - 1e-6:
		w.step(1.0 / 30.0)
		w.ship.sonar_ping = false
		w.ship.zap = false
		d.update(_coral(w), w.time, w.ship.pos)
		t += 1.0 / 30.0


func _start(w: EcoWorld) -> EcoCoralDust:
	EcoGrazerDust.lite = false
	_near(w)
	var d := EcoCoralDust.new()
	d.update(_coral(w), w.time, w.ship.pos)
	_run(w, d, 0.5)
	return d


func test_kind_by_drop() -> void:
	eq(EcoCoralDust.kind(1.0, 0.08, 0.033, false), EcoCoralDust.Kind.ZAP, "разом в ноль — разряд")
	eq(EcoCoralDust.kind(1.0, 0.5, 0.033, false), EcoCoralDust.Kind.PING, "разом на половину — импульс")
	eq(EcoCoralDust.kind(1.0, 0.973, 0.033, false), EcoCoralDust.Kind.NOISE, "плавно гаснет — шум")
	eq(EcoCoralDust.kind(0.9, 0.873, 0.033, true), EcoCoralDust.Kind.NONE, "уже гаснет — второй раз нет")
	eq(EcoCoralDust.kind(0.4, 0.08, 0.033, false), EcoCoralDust.Kind.NONE, "погасший куст не втягивает")
	eq(EcoCoralDust.kind(0.5, 0.501, 0.033, false), EcoCoralDust.Kind.NONE, "разгорается — нет")


func test_zap_makes_thick_puffs_at_tips() -> void:
	var w := _world()
	var d := _start(w)
	eq(d._made, 0, "куст горит, корабль тихий — облачков нет")
	var b := _coral(w).bushes[0]
	w.ship.zap = true
	w.ship.zap_radius = 30.0
	_run(w, d, 1.0)
	ok(b.glow < EcoCoral.DARK, "разряд погасил куст")
	eq(d._made, EcoCoralDust.ZAP_N, "разряд — клуб из %d облачков" % EcoCoralDust.ZAP_N)
	var spots := {}
	for p in d.dust.puffs:
		if p.born < 0.0:
			continue
		near(p.scale, EcoCoralDust.SCALE, 1e-6, "доля размера кончиков")
		ok(p.alpha > EcoCoralDust.ZAP_ALPHA * 0.7, "клуб густой (%.2f)" % p.alpha)
		ok(p.born <= w.time, "облачко уже встало")
		var hb := Vector2(p.at.x - b.base.x, p.at.z - b.base.z).length()
		ok(p.at.y > b.base.y + EcoCoral.HEIGHT * b.scale * 0.5, "у кроны, а не у дна (%.2f м)" % (p.at.y - b.base.y))
		ok(hb < 3.5, "в кроне куста (%.2f м от оси)" % hb)
		spots[str(p.at.snapped(Vector3.ONE * 0.01))] = true
	ok(spots.size() >= 3, "у разных кончиков (%d мест)" % spots.size())


func test_ping_weaker_than_zap() -> void:
	var w := _world()
	var d := _start(w)
	w.ship.sonar_ping = true
	_run(w, d, 1.0)
	eq(d._made, EcoCoralDust.PING_N, "импульс — %d облачка" % EcoCoralDust.PING_N)
	for p in d.dust.puffs:
		if p.born >= 0.0:
			ok(p.alpha <= EcoCoralDust.PING_ALPHA * 1.21, "слабее разряда")
	# второй импульс: куст горит вполсилы — облачка бледнее; третий сразу: погас — облачков нет
	w.ship.sonar_ping = true
	_run(w, d, 0.5)
	eq(d._made, EcoCoralDust.PING_N * 2, "вполсилы — снова втягивает")
	w.ship.sonar_ping = true
	_run(w, d, 0.5)
	eq(d._made, EcoCoralDust.PING_N * 2, "погасший куст не втягивает")


func test_noise_once_per_dimming() -> void:
	var w := _world()
	var d := _start(w)
	var b := _coral(w).bushes[0]
	w.ship.pos = b.top + Vector3(0, 2, 8)
	w.ship.speed = 5.0
	_run(w, d, 2.0)
	ok(b.glow < EcoCoral.DARK, "шумный ход погасил куст")
	eq(d._made, EcoCoralDust.NOISE_N, "шум — одна пара слабых облачков за угасание")
	for p in d.dust.puffs:
		if p.born >= 0.0:
			ok(p.alpha <= EcoCoralDust.NOISE_ALPHA * 1.21, "слабые")
	# корабль ушёл — куст медленно разгорается, облачков нет
	w.ship.speed = 0.0
	w.ship.pos = FAR
	_run(w, d, 3.0)
	eq(d._made, EcoCoralDust.NOISE_N, "разгорание облачков не даёт")


func test_far_and_lite_make_no_dust() -> void:
	var w := _world()
	var d := _start(w)
	w.ship.pos = FAR
	w.ship.zap = true
	w.ship.zap_radius = 1000.0
	_run(w, d, 0.5)
	eq(d._made, 0, "дальше 80 м облачков нет")
	var b := _coral(w).bushes[0]
	b.glow = 1.0
	_near(w)
	EcoGrazerDust.lite = true
	_run(w, d, 0.2)
	w.ship.sonar_ping = true
	_run(w, d, 0.5)
	eq(d._made, 0, "«Экономно» — облачков нет")
	EcoGrazerDust.lite = false
	b.glow = 1.0
	_run(w, d, 0.2)
	w.ship.sonar_ping = true
	_run(w, d, 0.5)
	eq(d._made, EcoCoralDust.PING_N, "выключатель вернули — облачка есть")


func test_same_world_same_dust() -> void:
	var runs: Array = []
	for k in 2:
		var w := _world()
		var d := _start(w)
		w.ship.sonar_ping = true
		_run(w, d, 1.0)
		w.ship.zap = true
		_coral(w).bushes[0].glow = 1.0
		_run(w, d, 1.0)
		eq(d.dust.puffs.size(), EcoCoralDust.POOL, "пул не растёт")
		var row := []
		for p in d.dust.puffs:
			row.append([p.at, p.born, p.alpha])
		runs.append(row)
	eq(str(runs[0]), str(runs[1]), "те же облачка при том же мире")


func test_scene_multimesh() -> void:
	EcoGrazerDust.lite = false
	var w := _world()
	var c := _coral(w)
	var view := CoralView.new(c)
	tree.root.add_child(view)
	await frames(1)
	var dust := view.find_child("Муть", false, false) as MultiMeshInstance3D
	if not ok(dust != null, "облачка огнецвета в сцене"):
		view.queue_free()
		return
	eq(dust.multimesh.instance_count, EcoCoralDust.POOL, "один MultiMesh на пул")
	eq(dust.layers, OceanView.LAYER_WORLD, "на слое отмели")
	eq(dust.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	var mat := (dust.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	var info := EcoLink.ShipState.new()
	info.pos = c.bushes[0].top + Vector3(0, 5, 24)
	view.sync_dust(0.0, info)
	view.sync_dust(0.1, info)
	c.bushes[0].glow = 0.5
	view.sync_dust(0.2, info)
	view.sync_dust(0.8, info)
	var seen := 0
	for n in EcoCoralDust.POOL:
		var i := n * GrazerView.DUST_STRIDE
		if view.dust_buffer[i + 15] > 0.0:
			seen += 1
			ok(view.dust_buffer[i] <= EcoGrazerDust.SIZE_END * EcoCoralDust.SCALE + 1e-5, "облачко — с размером")
			near(view.dust_buffer[i + 12], EcoCoralDust.COLOR.r, 1e-5, "слизь без луча")
	ok(seen > 0, "куст выдохнул слизь (%d)" % seen)
	view.queue_free()
	await frames(1)
