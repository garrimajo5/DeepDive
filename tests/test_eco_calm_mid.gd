extends TestCase
## Спокойная середина 00 → 01 (#1400, решение гейм-дизайнера 08.11 в `docs/urovni/sloj-1.md`): цепочку «прожектор →
## волнолист → моллюски» не совмещать с песчаной засадой, засадчиками и логовом. Путь и стоянка — как в
## `tools/mid_calm.gd` (PATH, FLOOR, STOP): корабль идёт от выхода из 00 к середине (20; 22,5) и стоит там. Засады
## мира стоят на местах из констант, поэтому проверка — геометрией луча, без шагов мира.

const STEP := 0.5   # м между пробами пути
const LOOK := 16    # курсов на стоянке: экипаж оглядывается


func _tool() -> GDScript:
	return load("res://tools/mid_calm.gd")


## Пробы корабля середины: путь PATH[0] → PATH[1] курсом по ходу и стоянка у PATH[1] со всеми курсами.
func _ships() -> Array[EcoLink.ShipState]:
	var tool := _tool()
	var a: Vector2 = tool.PATH[0]
	var b: Vector2 = tool.PATH[1]
	var out: Array[EcoLink.ShipState] = []
	var n := int(a.distance_to(b) / STEP)
	var d := b - a
	for i in n + 1:
		out.append(_ship(tool, a.lerp(b, float(i) / n), atan2(-d.x, -d.y)))
	for k in LOOK:
		out.append(_ship(tool, b, TAU * k / LOOK))
	return out


func _ship(tool: GDScript, xz: Vector2, yaw: float) -> EcoLink.ShipState:
	var s := EcoLink.ShipState.new()
	s.pos = tool.ship_at(xz)
	s.yaw = yaw
	s.light_on = true
	s.light_range = Searchlight.BASE_RANGE
	return s


## Где могут быть глаза глазуна у пятна стайки p: на круге GZ_OFFSET (угол — от зерна), над видимым дном.
func _glazun_eyes(p: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in 12:
		var a := TAU * k / 12.0
		var x := p.x + cos(a) * EcoCoins.GZ_OFFSET
		var z := p.z + sin(a) * EcoCoins.GZ_OFFSET
		out.append(Vector3(x, Seabed.mesh_height(x, z) + EcoCoins.EYE.y, z))
	return out


func test_glazun_eyes_never_in_beam() -> void:
	var ships := _ships()
	var eyes: Array[Vector3] = []
	for p in EcoCoins.default_spots():
		eyes.append_array(_glazun_eyes(p))
	eq(eyes.size(), EcoCoins.SCHOOLS * 12, "все глазуны")
	var nearest := INF
	var lit: Array[String] = []
	for s in ships:
		for e in eyes:
			if EcoWorld.beam_hits(s, e):
				lit.append("%s из %s" % [e, s.pos])
			nearest = minf(nearest, Vector2(e.x - s.pos.x, e.z - s.pos.z).length())
	eq(lit.size(), 0, "глаза глазуна не в луче середины: %s" % ", ".join(lit.slice(0, 3)))
	ok(nearest > EcoWorld.BEAM_R * 0.5, "глазун не у пути середины: %.1f м" % nearest)
	# Проверка не пустая: глаз прямо по курсу середины луч видит.
	var hits := 0
	for s in ships:
		var fwd := Basis(Vector3.UP, s.yaw) * Vector3(0, 0, -20)
		var p := s.pos + fwd
		p.y = Seabed.mesh_height(p.x, p.z) + EcoCoins.EYE.y
		if EcoWorld.beam_hits(s, p):
			hits += 1
	ok(hits > ships.size() / 2, "глаз в 20 м по курсу — в луче: %d из %d" % [hits, ships.size()])


func test_eel_lair_beyond_warning() -> void:
	var nearest := INF
	for s in _ships():
		for l in EcoEel.LAIRS:
			nearest = minf(nearest, Vector2(s.pos.x, s.pos.z).distance_to(l))
	ok(nearest > EcoEel.WARN_R, "логово стеклоуста дальше знака WARN_R: %.1f м" % nearest)


func test_echo_does_not_listen() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.mesh_height
	var bones := w.add(EcoBones.new()) as EcoBones
	var echo := w.add(EcoEcho.new(bones, null)) as EcoEcho
	w.reset(1)
	var at := echo.echo.p
	var nearest := INF
	for s in _ships():
		nearest = minf(nearest, Vector2(s.pos.x, s.pos.z).distance_to(Vector2(at.x, at.z)))
	ok(nearest > EcoEcho.LISTEN_R, "эхоловец не слушает корабль середины: %.1f м" % nearest)
	ok(nearest > EcoEcho.STRIKE_R, "и не бьёт на импульс")
