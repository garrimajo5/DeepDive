class_name EcoOgnevkaDust
extends RefCounted
## Облачка у веерника, где кормятся огнёвки (docs/grafika-plan-eco.md, Б3 «Мелочь жизни», «облачка и пузырьки от
## существ»): станция чистки пустует (EcoLeech.Station.busy < 0), у неё есть веерник (EcoOgnevka.fan_at) — половина
## рачков обирает кружево: раз в PICK_EVERY с (× 1 ± 0,25) у одного из мест кружева встаёт маленькое облачко
## сорванной взвеси. Серпохвост пришёл на чистку (busy стал ≥ 0) — рачки разом снимаются с веера, и с кружева
## стряхивается клуб из LEAVE_N облачков; хищник ушёл и рачки вернулись — LAND_N слабее. Места — на плоскости веера
## (поперёк течения, EcoFan.Fan.yaw), ниже вершины. Облачка те же, что у скребунов (EcoGrazerDust: стоят, где подняты,
## растут, поднимаются, уплывают по течению, тают; светлее в луче прожектора) — свой пул на POOL мест, цвет — бледная
## зелёно-серая взвесь на бирюзовом кружеве. Мир и его случай не меняются: что делают рачки — по станции между
## шагами, разброс — хешем EcoVary; у гостя сети хищники и станции идут в его мире — облачка те же по виду.
## Рисует OgnevkaView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки,
## шейдеров не прибавилось. «Экономно» — общий выключатель мелочи жизни EcoGrazerDust.lite.

## Мест в пуле: 3 станции × ~3 облачка кормёжки (жизнь 3,6 с, раз в 1,2 с) + клуб взлёта.
const POOL := 16
## Пауза между облачками кормёжки на станции (с), у каждого × (1 ± 0,25).
const PICK_EVERY := 1.2
const PICK_SPREAD := 0.25
## Непрозрачность и доля размера (облачко скребуна 0,5 → 1,6 м): кормёжка — слабое и мелкое.
const PICK_ALPHA := 0.3
const PICK_SCALE := 0.3
## Рачки снялись с веера (хищник на чистке) — клуб; вернулись — слабее.
const LEAVE_N := 3
const LEAVE_ALPHA := 0.55
const LEAVE_SCALE := 0.5
const LAND_N := 2
const LAND_ALPHA := 0.35
const LAND_SCALE := 0.35
## Где на кружеве: вдоль веера ± LACE_W/2 от середины, от вершины вниз до LACE_DROP м.
const LACE_W := EcoFan.WIDTH * 0.8
const LACE_DROP := 1.4
const SALT := 307
## Цвет: бледная зелёно-серая взвесь (на бирюзовом кружеве #1f8796 видна); в луче — светлая.
const COLOR := Color(0.26, 0.31, 0.29)
const LIT := Color(0.64, 0.74, 0.70)

enum Kind { NONE, PICK, LEAVE, LAND }

var dust := EcoGrazerDust.new(POOL)
## У каждой станции: время следующего облачка кормёжки и кормились ли рачки прошлым шагом.
var _next := PackedFloat32Array()
var _fed := PackedByteArray()
var _made := 0
var _last := -1e9


## Рачки станции st кормятся на веернике: станция пустует и веерник рядом есть.
static func feeding(system: EcoOgnevka, st: EcoLeech.Station) -> bool:
	return st.busy < 0 and system.fan_at(st) != null


## Что сделали рачки: кормились was, кормятся now, у станции есть веерник (fan).
static func kind(was: bool, now: bool, has_fan: bool) -> Kind:
	if not has_fan:
		return Kind.NONE
	if was and not now:
		return Kind.LEAVE
	if now and not was:
		return Kind.LAND
	return Kind.PICK if now else Kind.NONE


## Место облачка с ключом key на кружеве веерника f: вдоль плоскости веера, ниже вершины.
static func lace_spot(f: EcoFan.Fan, key: int) -> Vector3:
	var along := Vector3(cos(f.yaw), 0.0, -sin(f.yaw))   # плоскость смотрит в (sin yaw, 0, cos yaw)
	var u := EcoVary.unit(key, SALT) - 0.5
	var v := EcoVary.unit(key, SALT + 1)
	return f.top + along * (u * LACE_W) + Vector3(0, -v * LACE_DROP, 0)


## Шаг в момент t (время мира). ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoOgnevka, t: float, ship: Vector3) -> void:
	if system == null or system.leeches == null:
		return
	var sts := system.leeches.stations
	var n := sts.size()
	if _next.size() != n or t < _last:   # первый шаг или время мира пошло назад — запомнить, без облачков
		_next.resize(n)
		_fed.resize(n)
		for st in sts:
			_next[st.index] = t
			_fed[st.index] = 1 if feeding(system, st) else 0
		_last = t
		return
	_last = t
	for st in sts:
		var i := st.index
		var f := system.fan_at(st)
		var now := feeding(system, st)
		var k := kind(_fed[i] != 0, now, f != null)
		_fed[i] = 1 if now else 0
		if k == Kind.NONE:
			continue
		var quiet := EcoGrazerDust.lite or f.top.distance_to(ship) > EcoGrazerDust.NEAR
		match k:
			Kind.LEAVE:
				if not quiet:
					for c in LEAVE_N:
						_puff(f, i, t, LEAVE_ALPHA, LEAVE_SCALE)
				continue
			Kind.LAND:
				if not quiet:
					for c in LAND_N:
						_puff(f, i, t, LAND_ALPHA, LAND_SCALE)
				_next[i] = t + PICK_EVERY
				continue
		if t < _next[i]:
			continue
		var key := (_made + 1) * 4 + i
		_next[i] = t + PICK_EVERY * EcoVary.spread(key, SALT + 2, PICK_SPREAD)
		if not quiet:
			_puff(f, i, t, PICK_ALPHA, PICK_SCALE)


func _puff(f: EcoFan.Fan, station: int, t: float, alpha: float, scale: float) -> void:
	_made += 1
	var key := _made * 4 + station
	dust.add(lace_spot(f, key), t, alpha * EcoVary.spread(key, SALT + 3, 0.2), key,
			scale * EcoVary.spread(key, SALT + 4, 0.15))
