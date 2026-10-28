class_name EcoLod
## LOD шага мира для одиночек и стаек вдали (issue #850, как у стай рыб — EcoFish.MID/FAR): дальше MID от корабля
## существо шагает раз в MID_EVERY шагов мира, дальше FAR — раз в FAR_EVERY, набирая пропущенное время. Очередь —
## по счётчику шагов модуля и номеру существа (фазы разнесены — дальние не считаются в одном кадре, issue #803).
## Шаг не длиннее LAG_MAX: если ещё одно ожидание сделало бы его длиннее, существо шагает раньше своей очереди.
## Подошло ближе MID — шагает каждый раз и сразу догоняет набранное.
##
##     if EcoLod.wait(d, _tick, g.index, g.lag, dt):
##         g.lag += dt
##         continue
##     var h := dt + g.lag
##     g.lag = 0.0

const MID := EcoFish.MID
const FAR := EcoFish.FAR
const MID_EVERY := EcoFish.MID_EVERY
const FAR_EVERY := EcoFish.FAR_EVERY
const LAG_MAX := EcoFish.LAG_MAX


## Пропустить ли шаг существа в d м от корабля: tick — шаги модуля, index — номер существа, lag — уже набрано (с).
static func wait(d: float, tick: int, index: int, lag: float, dt: float) -> bool:
	if d <= MID:
		return false
	var every := FAR_EVERY if d > FAR else MID_EVERY
	return (tick + index) % every != 0 and lag + 2.0 * dt <= LAG_MAX + 1e-6
