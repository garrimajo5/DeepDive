class_name NetSmooth
extends RefCounted
## Плавность у клиента сетевого забега: хост шлёт кадры 20 раз в секунду (`NetSnap.SEND_DT`), а экран рисует 60.
## Клиент показывает корабль и фигуры с небольшим отставанием `DELAY` по времени хоста: между двумя кадрами,
## пришедшими раньше, — плавно, даже когда пакеты приходят пачкой или с паузой. Вперёд не угадывает (без экстраполяции).
## Без узлов: `push` — принятый кадр, `step(dt)` — часы показа, `ship`/`member` — что рисовать.
## Живой мир — с тем же отставанием: пакет существ рядом («eco», `EcoLink.pack_world`) ждёт в очереди, пока часы
## показа не дойдут до его кадра (`take_eco`), — существа, мох и время мира у гостя на тех же часах, что корабль.

const DELAY := 0.1   ## отставание показа от свежего кадра, с: два кадра хоста — пара для перехода почти всегда есть
const KEEP := 8      ## сколько последних кадров держим
const SNAP := 2.0    ## м: фигура или корабль перескочили дальше — ставим сразу, не плывём через стены
const CATCH := 2.0   ## доля в секунду, с которой часы показа подтягиваются к «свежий кадр − DELAY»
const RESET := 0.3   ## часы ушли от цели дальше — ставим их на цель сразу (пауза связи, начало)

## Кадр показа: время хоста, корабль, экипаж — по члену [x, z, yaw, phase, swing, turn].
class Shot:
	extends RefCounted
	var t := 0.0
	var pos := Vector3.ZERO
	var yaw := 0.0
	var crew: Array[PackedFloat32Array] = []

var shots: Array[Shot] = []
var clock := 0.0   ## время показа (время хоста)
var eco: Array = []   ## пакеты живого мира, ещё не показанные: [время хоста, PackedFloat32Array], старые первыми
var _eco_fresh := false   ## очередь начата заново: первый пакет — сразу, как первый кадр корабля


## Принятый кадр хоста (после `NetSnap.apply_frame`): время хоста `t`, корабль, экипаж по порядку.
## Время не выросло (новый забег, другой хост) — начинаем заново с этого кадра. eco — существа рядом из этого
## кадра (пусто — не пришли): покажутся, когда часы показа дойдут до t (`take_eco`).
func push(t: float, pos: Vector3, yaw: float, crew: Array, eco_data := PackedFloat32Array()) -> void:
	if shots.is_empty() or t <= shots[-1].t:
		shots.clear()
		eco.clear()
		_eco_fresh = true
	if not eco_data.is_empty():
		eco.append([t, eco_data])
		while eco.size() > KEEP:
			eco.pop_front()
	var s := Shot.new()
	s.t = t
	s.pos = pos
	s.yaw = yaw
	for m: Crew.Member in crew:
		s.crew.append(PackedFloat32Array([m.x, m.z, m.yaw, m.phase, m.swing, m.wheel_turn]))
	shots.append(s)
	while shots.size() > KEEP:
		shots.pop_front()
	if shots.size() == 1 or absf(clock - (t - DELAY)) > RESET:
		clock = t - DELAY


## Часы показа идут своим dt и мягко подтягиваются к «свежий кадр − DELAY».
func step(dt: float) -> void:
	if shots.is_empty():
		return
	clock += dt
	var want := shots[-1].t - DELAY
	if absf(clock - want) > RESET:
		clock = want
	else:
		clock += (want - clock) * minf(1.0, dt * CATCH)


## Пара кадров вокруг часов и доля между ними: [a, b, k]. До первого — первый, после последнего — последний.
func _pair() -> Array:
	var n := shots.size()
	if clock <= shots[0].t or n == 1:
		return [shots[0], shots[0], 0.0]
	for i in range(1, n):
		var b := shots[i]
		if clock <= b.t:
			var a := shots[i - 1]
			return [a, b, clampf((clock - a.t) / maxf(b.t - a.t, 1e-6), 0.0, 1.0)]
	return [shots[-1], shots[-1], 0.0]


## Пакет живого мира на часах показа: самый свежий, чьё время уже настало (старше — пропускаем, пакеты полные);
## не настало ни одного — пусто. После сброса первый пакет — сразу (корабль тоже стоит на первом кадре).
func take_eco() -> PackedFloat32Array:
	var j := -1
	for i in eco.size():
		if float(eco[i][0]) <= clock + 1e-6:
			j = i
	if j < 0 and _eco_fresh and not eco.is_empty():
		j = 0
	if j < 0:
		return PackedFloat32Array()
	var out: PackedFloat32Array = eco[j][1]
	eco = eco.slice(j + 1)
	_eco_fresh = false
	return out


func ready() -> bool:
	return not shots.is_empty()


## Корабль на часах показа: [место, курс].
func ship() -> Array:
	var p := _pair()
	var a: Shot = p[0]
	var b: Shot = p[1]
	var k: float = p[2]
	if a.pos.distance_to(b.pos) > SNAP:
		return [b.pos, b.yaw]
	return [a.pos.lerp(b.pos, k), lerp_angle(a.yaw, b.yaw, k)]


## Член экипажа i на часах показа: [x, z, yaw, phase, swing, turn]; пусто — его нет в кадре показа.
func member(i: int) -> PackedFloat32Array:
	var p := _pair()
	var a: Shot = p[0]
	var b: Shot = p[1]
	var k: float = p[2]
	if i >= b.crew.size():
		return PackedFloat32Array()
	var mb := b.crew[i]
	if i >= a.crew.size():
		return mb
	var ma := a.crew[i]
	if Vector2(ma[0], ma[1]).distance_to(Vector2(mb[0], mb[1])) > SNAP:
		return mb
	return PackedFloat32Array([lerpf(ma[0], mb[0], k), lerpf(ma[1], mb[1], k), lerp_angle(ma[2], mb[2], k),
		wrapf(lerp_angle(ma[3], mb[3], k), 0.0, TAU), lerpf(ma[4], mb[4], k), lerpf(ma[5], mb[5], k)])


## Показать на часах: корабль в helm, фигуры в crew (место, курс, шаг, руль). Курс своего игрока `own`
## не трогаем — взгляд у него свой (`Main._client_frame`).
func apply(helm: Helm.Ship, crew: Array, own: Crew.Member) -> void:
	if shots.is_empty():
		return
	var s := ship()
	helm.pos = s[0]
	helm.yaw = s[1]
	for i in crew.size():
		var v := member(i)
		if v.is_empty():
			continue
		var m: Crew.Member = crew[i]
		m.x = v[0]
		m.z = v[1]
		m.walker.x = v[0]
		m.walker.z = v[1]
		if m != own:
			m.yaw = v[2]
			m.walker.yaw = v[2]
		m.phase = v[3]
		m.swing = v[4]
		m.wheel_turn = v[5]
