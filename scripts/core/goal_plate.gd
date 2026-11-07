class_name GoalPlate
extends RefCounted
## Плашка цели маршрута за штурвалом (#1344, разбор #1335): пилот видит не только «сколько» до точки, но и «куда» —
## стрелку и угол поворота от курса корабля на пеленг следующей точки (`Run.next_key`), название и метры. Видна, пока
## свой игрок сидит за штурвалом (`OverlayFlow.goal_step`); строка маршрута из `Run.status` за штурвалом в строку
## приборов не идёт (`Main.status_parts`). Текст пересобирается только при смене целого угла или метров.
## Рисует `scripts/game/goal_plate_view.gd` (`main.goal_plate_view`). Размеры — при высоте экрана REF_H.

const REF_H := 1080.0
const TOP := 32.0         ## верх плашки
const HEIGHT := 88.0
const PAD := 30.0         ## поля слева и справа
const GAP := 16.0         ## зазор до строки приборов и кнопки noclip
const TEXT_PX := 40
const ARROW_PX := 44      ## значок-стрелка
const ICON_GAP := 24.0    ## от значка до текста
const RADIUS := 12.0
const FILL_A := 0.85      ## непрозрачность подложки `UiStyle.DARK`
const AHEAD := 10.0       ## |Δ| ≤ — «прямо», без угла
const BEHIND := 120.0     ## |Δ| > — «развернитесь»
const ARRIVED_TIME := 2.0 ## «… — на месте», затем следующая цель
const MIN_K := 0.8        ## мельче кегль текста не делаем — тогда плашка уходит под строку приборов
const AMBER := Color("FFB259")   ## янтарь табло ART-025 — точка пройдена, решение у стола

enum Kind { AHEAD, LEFT, RIGHT, BEHIND, ARRIVED, NONE, VOTE }

const NONE_TEXT := "Маршрут не выбран — голостол, «Маршрут»"
const VOTE_TEXT := "Решение — у голостола"

var kind := Kind.NONE
var angle := 0            ## угол поворота, целые градусы без знака (только LEFT/RIGHT)
var text := NONE_TEXT     ## строка без значка
var rev := 0              ## растёт, когда меняется вид плашки (перерисовать)
var _route := -1
var _key := ""
var _arrived := ""        ## название пройденной точки, пока показываем «на месте»
var _arrived_t := 0.0


## Угол от курса корабля yaw (рад; 0 — нос в −Z, растёт — поворот влево) до пеленга из from на to (x, z), градусы
## в (−180, 180]: плюс — цель левее, минус — правее.
static func delta(yaw: float, from: Vector2, to: Vector2) -> float:
	var d := to - from
	if d.length_squared() < 1e-6:
		return 0.0
	var bearing := atan2(-d.x, -d.y)   # yaw, при котором нос смотрит на цель
	var a := rad_to_deg(wrapf(bearing - yaw, -PI, PI))
	return 180.0 if a <= -180.0 else a


## Вид по углу Δ (градусы, `delta`).
static func kind_of(dlt: float) -> Kind:
	var a := absf(dlt)
	if a <= AHEAD:
		return Kind.AHEAD
	if a > BEHIND:
		return Kind.BEHIND
	return Kind.LEFT if dlt > 0.0 else Kind.RIGHT


## Шаг: маршрут run, корабль в pos (x, z) с курсом yaw. true — вид плашки сменился.
func update(dt: float, run: Run, yaw: float, pos: Vector2) -> bool:
	var key := run.next_key() if run.route >= 0 and not run.done else ""
	if run.route == _route and _key != "" and key != _key and run.visited.has(_key):
		_arrived = Run.place_name(_key)   # точка пройдена — 2 с «на месте», затем следующая цель
		_arrived_t = ARRIVED_TIME
	elif run.route != _route:
		_arrived_t = 0.0
	_route = run.route
	_key = key
	_arrived_t = maxf(0.0, _arrived_t - dt)
	var k := Kind.NONE
	var a := 0
	var t := NONE_TEXT
	if run.voting:
		k = Kind.VOTE
		t = VOTE_TEXT
	elif _arrived_t > 0.0:
		k = Kind.ARRIVED
		t = "%s — на месте" % _arrived
	elif key != "":
		var to := Run.place_xz(key)
		var dlt := delta(yaw, pos, to)
		k = kind_of(dlt)
		var where := "%s · %d м" % [Run.place_name(key), roundi(pos.distance_to(to))]
		match k:
			Kind.AHEAD:
				t = where
			Kind.BEHIND:
				t = "Развернитесь · " + where
			_:
				a = roundi(absf(dlt))
				t = "%d°   %s" % [a, where]
	if k == kind and a == angle and t == text:
		return false
	kind = k
	angle = a
	text = t
	rev += 1
	return true


## Есть ли значок слева от текста (стрелка или разворот).
func has_icon() -> bool:
	return kind in [Kind.AHEAD, Kind.LEFT, Kind.RIGHT, Kind.BEHIND]


## Цвет рамки: голубой акцент, янтарь — точка пройдена и решение у стола, погашенный — маршрута нет.
func edge() -> Color:
	match kind:
		Kind.ARRIVED, Kind.VOTE:
			return AMBER
		Kind.NONE:
			return UiStyle.OFF
	return UiStyle.ACCENT


func text_color() -> Color:
	return UiStyle.OFF if kind == Kind.NONE else UiStyle.TEXT


## Ширина плашки на экране высотой h по ширине текста text_w (px, уже в кегле экрана); k — доля кегля текста и значка
## (поля — без изменений).
func width(text_w: float, h: float, k := 1.0) -> float:
	var s := h / REF_H
	return (text_w + ((ARROW_PX + ICON_GAP) * s if has_icon() else 0.0)) * k + 2.0 * PAD * s


## Место плашки на экране size по ширине текста text_w (в полном кегле): [Rect2, доля кегля k]. Верх TOP, по x —
## центр свободной полосы между строкой приборов status и кнопкой noclip (пустые — край экрана). Не помещается —
## текст и значок мельче, до MIN_K («Развернитесь · …» при 1600×720); и так нет — полный кегль, прижата к noclip и
## опущена под строку приборов.
func fit(text_w: float, size: Vector2, status: Rect2, noclip: Rect2) -> Array:
	var s := size.y / REF_H
	var gap := GAP * s
	var left := (status.end.x if status.has_area() else 0.0) + gap
	var right := (noclip.position.x if noclip.has_area() else size.x) - gap
	var strip := right - left
	var y := TOP * s
	var w := width(text_w, size.y)
	var k := 1.0
	if w > strip:
		k = (strip - 2.0 * PAD * s) / maxf(1.0, w - 2.0 * PAD * s)
		if k >= MIN_K:
			w = width(text_w, size.y, k)
		else:
			k = 1.0
			if status.has_area():
				y = maxf(y, status.end.y + gap)
			return [Rect2(maxf(gap, right - w), y, w, HEIGHT * s), k]
	return [Rect2((left + right - w) * 0.5, y, w, HEIGHT * s), k]
