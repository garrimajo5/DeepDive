extends TestCase
## Один постановочный эпизод угрозы у корабля за раз (#834): пока стеклоуст плывёт к стеклу или висит на нём,
## серпохвост не бросается; пока бросается серпохвост — стеклоуст сидит в логове. Эпизод — `EcoWorld.hold_threat`.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)
const SPOT := Vector3(0, FLAT, 0)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Ровное дно, логово стеклоуста в SPOT и серпохвосты; корабль носом к логову (как в test_eco_eel).
func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	w.add(EcoEel.new(null, null, [SPOT] as Array[Vector3]))
	w.add(EcoPred.new())
	return w


func _eels(w: EcoWorld) -> EcoEel:
	for s in w.systems:
		if s is EcoEel:
			return s
	return null


func _preds(w: EcoWorld) -> EcoPred:
	for s in w.systems:
		if s is EcoPred:
			return s
	return null


func _ship_near_lair(w: EcoWorld) -> void:
	var e := _eels(w).eels[0]
	w.ship.yaw = PI
	w.ship.pos = e.lair + Vector3(0, 6, -15) - EcoEel.FRONT.rotated(Vector3.UP, PI)


## Первый хищник голоден, готов к броску и в 25 м от корабля; остальные — далеко и сыты.
func _ready_pred(w: EcoWorld) -> EcoPred.Pred:
	var preds := _preds(w)
	for p in preds.all:
		p.hunger = 0.0
		p.cooldown = 999.0
		p.agent.p = FAR + Vector3(0, 0, 200)
	var pr := preds.all[0]
	pr.hunger = 0.5
	pr.cooldown = 0.0
	pr.agent.p = w.ship.pos + Vector3(25, 0, 0)
	return pr


func test_hold_and_free() -> void:
	var w := EcoWorld.new()
	var a := RefCounted.new()
	var b := RefCounted.new()
	ok(w.threat_free(a) and w.threat_free(b), "в начале эпизода нет")
	w.hold_threat(a)
	ok(w.threat_free(a), "свой эпизод не мешает себе")
	ok(not w.threat_free(b), "чужой ждёт")
	eq(w.threat_holder(), a.get_instance_id())
	w.step(EcoWorld.THREAT_HOLD + 0.2)
	ok(w.threat_free(b), "эпизод кончился — через THREAT_HOLD с свободно")
	eq(w.threat_holder(), 0)
	w.hold_threat(a)
	w.reset()
	ok(w.threat_free(b), "сброс мира — эпизода нет")


func test_pred_waits_while_eel_on_glass() -> void:
	var w := _world()
	_ship_near_lair(w)
	var e := _eels(w).eels[0]
	e.mode = EcoEel.Mode.TO_SHIP
	e.timer = 30.0
	w.step(0.1)
	eq(w.threat_holder(), e.get_instance_id(), "стеклоуст плывёт к стеклу — эпизод его")
	var pr := _ready_pred(w)
	w.ship.light_on = true
	var charged := false
	for i in 100:
		w.step(0.1)
		charged = charged or pr.mode == EcoPred.Mode.CHARGE
		pr.cooldown = 0.0
		pr.hunger = 0.5
	ok(_eels(w).latched != null, "стеклоуст на стекле")
	ok(not charged, "пока стеклоуст у стекла, серпохвост не бросается на свет")
	# разряд сбрасывает стеклоуста — эпизод кончился, теперь бросок
	w.ship.zap = true
	w.step(0.1)
	w.ship.zap = false
	ok(_eels(w).latched == null, "разряд сбросил стеклоуста")
	w.step(EcoWorld.THREAT_HOLD + 0.5)
	pr = _ready_pred(w)
	EcoPred._set_mode(pr, EcoPred.Mode.PATROL, 0.0)   # разряд спугнул и хищника — снова патруль, голоден
	for i in 40:
		w.step(0.1)
		if pr.mode == EcoPred.Mode.CHARGE:
			charged = true
			break
		pr.cooldown = 0.0
	ok(charged, "стеклоуст ушёл — серпохвост бросается")


func test_eel_waits_while_pred_charges() -> void:
	var w := _world()
	_ship_near_lair(w)
	_ready_pred(w)
	var e := _eels(w).eels[0]
	var held := RefCounted.new()   # бросок хищника — держит эпизод весь прогон
	var went := false
	for i in 400:
		w.hold_threat(held)
		w.step(0.1)
		went = went or e.mode == EcoEel.Mode.TO_SHIP
	ok(not went, "40 с у логова, пока идёт бросок, — стеклоуст сидит в логове")
	for i in 600:
		w.step(0.1)
		if e.mode == EcoEel.Mode.TO_SHIP:
			went = true
			break
	ok(went, "эпизод кончился — стеклоуст плывёт к стеклу")


func test_charge_holds_episode() -> void:
	var w := _world()
	var pr := _ready_pred(w)
	w.ship.light_on = true
	w.step(0.1)
	eq(pr.mode, EcoPred.Mode.CHARGE, "свет ближе 32 м — бросок")
	eq(w.threat_holder(), pr.get_instance_id(), "бросок держит эпизод")
