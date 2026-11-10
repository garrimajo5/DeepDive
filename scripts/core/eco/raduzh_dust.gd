class_name EcoRaduzhDust
extends RefCounted
## Слизь радужников (docs/grafika-plan-eco.md, Б3 «Мелочь жизни», «облачка и пузырьки от существ»): гребневики
## пугаются света и толчков и выпускают облачка слизи. Луч прожектора зажёг стаю (EcoRaduzh.Swarm.glow перешёл
## EcoRaduzh.FLARE_ON вверх — та же вспышка, что выдаёт корабль хищнику) — у FLASH_N гребневиков стаи (номера —
## хешем EcoVary от стаи и вспышки) встаёт по облачку. Корпус корабля упёрся в стаю (гребневик внутри обшивки —
## EcoHull.touches; его расталкивает EcoRaduzh.member_pos_outside) — раз в BUMP_EVERY с (± 25 %) облачко у того
## гребневика, что задет. Облачка те же, что у скребунов (EcoGrazerDust: стоят, где выпущены, растут, поднимаются,
## уплывают по течению, тают; светлее в луче прожектора) — свой пул на POOL мест, цвет — бледная голубоватая слизь
## в тон тела. Мир и его случай не меняются: что делает стая — по вспышке между шагами и месту корабля; вспышка едет
## гостю в кадре радужников (EcoLink.apply_raduzh), стая дрейфует по времени мира — у гостя облачка те же. Рисует
## RaduzhView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки, шейдеров не
## прибавилось. «Экономно» — общий выключатель мелочи жизни EcoGrazerDust.lite.

## Мест в пуле: 3 стаи × (вспышка 3 + толчки корпуса раз в 0,6 с за жизнь облачка 3,6 с у одной стаи) — с запасом.
const POOL := 16
## Вспышка в луче: облачков на стаю, непрозрачность, доля размера (у скребуна 0,5 → 1,6 м).
const FLASH_N := 3
const FLASH_ALPHA := 0.4
const FLASH_SCALE := 0.4
## Толчок корпуса: пауза (с) × (1 ± BUMP_SPREAD), непрозрачность, доля размера; проверяем каждого BUMP_STEP-го
## гребневика (как луч в EcoRaduzh._lit) и только стаю ближе BUMP_NEAR к кораблю.
const BUMP_EVERY := 0.6
const BUMP_SPREAD := 0.25
const BUMP_ALPHA := 0.3
const BUMP_SCALE := 0.3
const BUMP_STEP := 3
const BUMP_NEAR := EcoRaduzh.R + EcoHull.BOUND
## Разброс места облачка у гребневика (м).
const SCATTER := 0.2
const SALT := 433
## Цвет: бледная голубоватая слизь (в тон силуэта гребневика без света); в луче — светлая, почти белая.
const COLOR := Color(0.34, 0.40, 0.48)
const LIT := Color(0.78, 0.84, 0.94)

var dust := EcoGrazerDust.new(POOL)
## У каждой стаи: вспышка прошлого шага, сколько было вспышек и когда можно следующий толчок.
var _glow := PackedFloat32Array()
var _flashes := PackedInt32Array()
var _bump_at := PackedFloat32Array()
var _made := 0
var _last := -1e9


## Шаг в момент t (время мира). ship_pos, ship_yaw — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoRaduzh, t: float, ship_pos: Vector3, ship_yaw: float) -> void:
	if system == null:
		return
	var n := system.swarms.size()
	if t < _last or _last < -1e8 or _glow.size() != n:   # первый шаг или время пошло назад — запомнить, без облачков
		_glow.resize(n)
		_flashes.resize(n)
		_bump_at.resize(n)
		for sw in system.swarms:
			_glow[sw.index] = sw.glow
			_bump_at[sw.index] = t
		_last = t
		return
	_last = t
	for sw in system.swarms:
		var i := sw.index
		var was := _glow[i]
		_glow[i] = sw.glow
		var d := sw.c.distance_to(ship_pos)
		if EcoGrazerDust.lite or d > EcoGrazerDust.NEAR:
			continue
		if was <= EcoRaduzh.FLARE_ON and sw.glow > EcoRaduzh.FLARE_ON:
			_flashes[i] += 1
			for k in FLASH_N:
				var key := flash_key(i, _flashes[i], k)
				var m := flash_member(key)
				_puff(EcoRaduzh.member_pos_outside(sw, m, t, ship_pos, ship_yaw), t, key, FLASH_ALPHA, FLASH_SCALE)
		if d < BUMP_NEAR and t >= _bump_at[i]:
			var hit := bumped(sw, t, ship_pos, ship_yaw)
			if hit >= 0:
				var key := ((_made + 1) * 8 + i) * 2 + 1   # нечётный — толчок, у вспышки чётный
				_bump_at[i] = t + BUMP_EVERY * EcoVary.spread(key, SALT + 1, BUMP_SPREAD)
				_puff(EcoRaduzh.member_pos_outside(sw, hit, t, ship_pos, ship_yaw), t, key, BUMP_ALPHA, BUMP_SCALE)


## Ключ разброса облачка k вспышки f стаи i.
static func flash_key(i: int, f: int, k: int) -> int:
	return ((f * 8 + i) * 4 + k) * 2


## Какой гребневик стаи выпускает облачко вспышки с ключом key.
static func flash_member(key: int) -> int:
	return mini(int(EcoVary.unit(key, SALT + 2) * EcoRaduzh.PER_SWARM), EcoRaduzh.PER_SWARM - 1)


## Номер гребневика стаи sw, что сейчас внутри обшивки корабля (−1 — никого).
static func bumped(sw: EcoRaduzh.Swarm, t: float, ship_pos: Vector3, ship_yaw: float) -> int:
	for k in range(0, EcoRaduzh.PER_SWARM, BUMP_STEP):
		if EcoHull.touches(EcoRaduzh.member_pos(sw, k, t), ship_pos, ship_yaw, EcoRaduzh.HULL_GAP):
			return k
	return -1


func _puff(at: Vector3, t: float, key: int, alpha: float, scale: float) -> void:
	_made += 1
	var off := Vector3(EcoVary.unit(key, SALT + 3) - 0.5, EcoVary.unit(key, SALT + 4) - 0.5,
			EcoVary.unit(key, SALT + 5) - 0.5) * (2.0 * SCATTER)
	dust.add(at + off, t, alpha * EcoVary.spread(key, SALT + 6, 0.2), key, scale * EcoVary.spread(key, SALT + 7, 0.15))
