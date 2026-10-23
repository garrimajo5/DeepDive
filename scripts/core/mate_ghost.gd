class_name MateGhost
extends RefCounted
## Фигура отключившегося гостя у хоста (ART-043, `svyaz-poteryana.md`): на последнем месте полупрозрачной (ALPHA)
## с табличкой ART-033 «Нет связи» HOLD секунд, затем тает за FADE. В экипаже (`main.crew`) её нет: поста не держит,
## гостям не едет, ни с чем не сталкивается. Гость вернулся — фигура убирается сразу, встаёт новая (`forget`).
## Рисуют `Main.ghost_view` (CrewView с `alpha`) и `Main.ghost_tags`.

const ALPHA := 0.35   ## непрозрачность фигуры
const HOLD := 10.0    ## столько секунд стоит
const FADE := 0.3     ## тает за столько секунд

var member: Crew.Member
var t := 0.0


func _init(m: Crew.Member) -> void:
	member = m
	m.lost = true
	m.press = INF   # кнопку больше не нажимает — табличка без «нажимает»


func update(dt: float) -> void:
	t += dt


## Непрозрачность сейчас: ALPHA, в последние FADE секунд — к 0.
func alpha() -> float:
	return ALPHA * clampf(1.0 - (t - HOLD) / FADE, 0.0, 1.0)


func done() -> bool:
	return t >= HOLD + FADE


## Шаг всех фигур: растаявшие убраны. true — список изменился.
static func step(list: Array[MateGhost], dt: float) -> bool:
	var n := list.size()
	for g in list:
		g.update(dt)
	var keep := list.filter(func(g: MateGhost) -> bool: return not g.done())
	list.assign(keep)
	return list.size() != n


## Гость с этим именем вошёл снова — его прежняя фигура убирается сразу. true — убрали.
static func forget(list: Array[MateGhost], name: String) -> bool:
	var n := list.size()
	list.assign(list.filter(func(g: MateGhost) -> bool: return g.member.name != name))
	return list.size() != n


static func members(list: Array[MateGhost]) -> Array:
	return list.map(func(g: MateGhost) -> Crew.Member: return g.member)
