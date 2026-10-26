class_name EcoKrabDust
extends RefCounted
## Муть у дна от кольчужника (docs/grafika-plan-eco.md, Б3 «Мелочь жизни»): идущий краб поднимает из-под ног
## облачка ила позади себя, удирающий от скальника — чаще и гуще, а пока раскалывает шипоежа — клешни у дна
## выбивают плотные облачка впереди. Облачка те же, что у скребунов (EcoGrazerDust: стоят, где подняты, растут,
## поднимаются, уплывают по течению, тают; светлее в луче прожектора) — свой пул на POOL мест и свой бурый цвет. Мир и его случай не
## меняются: разброс — хешем EcoVary от номера облачка; у гостя краб идёт в его мире, муть та же по виду.
## Рисует KrabView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» — общий выключатель EcoGrazerDust.lite.

## Мест в пуле: жизнь облачка / самая частая пауза.
const POOL := 12
## Пауза между облачками (с): идёт, удирает, раскалывает ежа.
const WALK_EVERY := 0.55
const RUN_EVERY := 0.3
const CRACK_EVERY := 0.35
## Непрозрачность в пике: гуще, чем у скребунов — краб роет крупный ил, а светлый песок в луче прячет бледную муть.
const WALK_ALPHA := 0.5
const RUN_ALPHA := 0.65
const CRACK_ALPHA := 0.8
## Из-под ног — позади панциря, у клешней — впереди (м по курсу; KrabView: клешни ×1,25 до ~1 м).
const BEHIND := 0.5
const CLAW := 1.0
const SCATTER := 0.2
const BASE_LIFT := 0.25
const SALT := 23
## Цвет: краб роет крупный бурый ил из-под камней норы — темнее светлого песка в луче, иначе на нём облачко не видно.
const COLOR := Color(0.22, 0.20, 0.16)
const LIT := Color(0.50, 0.45, 0.36)

var dust := EcoGrazerDust.new(POOL)
var _next := 0.0
var _made := 0
var _last := -1e9
var _was := false


## Чем поднимает муть краб cr сейчас: 0 — ничем, 1 — идёт, 2 — удирает, 3 — раскалывает ежа.
static func mode(cr: EcoKrab.Crab) -> int:
	if cr == null:
		return 0
	if cr.state == EcoKrab.State.CRACK:
		return 3
	if not cr.moving:
		return 0
	return 2 if cr.scared > 0.0 else 1


static func every(m: int) -> float:
	return [0.0, WALK_EVERY, RUN_EVERY, CRACK_EVERY][m]


static func alpha(m: int) -> float:
	return [0.0, WALK_ALPHA, RUN_ALPHA, CRACK_ALPHA][m]


## Где поднять облачко номер n: у клешней впереди (m = 3) или позади из-под ног, с разбросом.
static func spot(cr: EcoKrab.Crab, m: int, n: int) -> Vector3:
	var fw := Vector3(cr.dir.x, 0.0, cr.dir.z)
	fw = fw.normalized() if fw.length_squared() > 1e-6 else Vector3.FORWARD
	var ahead := CLAW if m == 3 else -BEHIND
	var sx := (EcoVary.unit(n, SALT) * 2.0 - 1.0) * SCATTER
	var sz := (EcoVary.unit(n, SALT + 1) * 2.0 - 1.0) * SCATTER
	return cr.pos + fw * ahead + Vector3(sx, BASE_LIFT, sz)


## Шаг мути в момент t (время мира); ship — корабль: дальше EcoGrazerDust.NEAR — нет.
func update(system: EcoKrab, t: float, ship: Vector3) -> void:
	if t < _last:
		_next = t
	_last = t
	var cr := system.crab if system else null
	var m := mode(cr)
	if m == 0:
		_was = false
		return
	if not _was:
		_was = true
		_next = maxf(_next, t)
	if t < _next:
		return
	_next = t + every(m) * EcoVary.spread(_made, SALT + 2, 0.2)
	if EcoGrazerDust.lite or cr.pos.distance_to(ship) > EcoGrazerDust.NEAR:
		return
	_made += 1
	dust.add(spot(cr, m, _made), t, alpha(m) * EcoVary.spread(_made, SALT + 3, 0.2), _made)
