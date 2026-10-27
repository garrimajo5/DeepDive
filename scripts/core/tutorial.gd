class_name Tutorial
extends RefCounted
## Подсказки первого забега по ART-038 (`docs/concept-art/podskazki.md`): плашка сверху, шесть шагов — штурвал, ход,
## свет, энергия, сонар, маршрут. Шаг засчитывает `note(событие)` из `Main` (свой игрок сел, дал ход за штурвалом,
## переключил прожектор, сменил долю, импульс прошёл, маршрут выбран); чужое событие или событие другого шага не
## считается. Выполнено — галочка и «Выполнено» `DONE_TIME`, затем следующий шаг; по таймеру не листаем.
## Тревога, голосование, итог, пауза, меню, облёт — плашка скрыта (`update(dt, hidden)`), шаг сохраняется.
## Пройденное помнят настройки (`Settings.tutorial`). Здесь — шаги, тексты, подсветка и место плашки (макет 2400×1080,
## масштаб H/1080, по центру); рисует `scripts/game/tutorial_panel.gd` (`main.tutorial_panel`), события — `Main`.

enum Ev { SAT, THRUST, LIGHT, SHARE, PING, ROUTE }

const REF_H := 1080.0
const BOX := Vector2(1360, 174)   ## плашка, по центру по x
const TOP := 32.0                 ## верх плашки
const GAP := 12.0                 ## под строкой приборов, если плашка на неё легла бы
const STEP_AT := Vector2(40, 48)  ## «Первый забег · n / 6»: от левого верхнего угла плашки до базовой линии
const STEP_PX := 28.0
const TEXT_AT := Vector2(40, 116) ## действие
const TEXT_PX := 40.0
const RING := 8.0                 ## обводка нужного управления, px при H = 1080
const FADE := 0.15                ## появление и исчезновение, с
const DONE_TIME := 0.5            ## «Выполнено» столько секунд
const DONE := "Выполнено"
## Кнопка «Схема» на плашке, пока игрок ищет пост (ART-042): справа, по центру по высоте; открывает схему корабля,
## «Назад» схемы возвращает к подсказке (`Main.open_hint_map`).
const MAP_BTN := Vector2(360, 112)
const MAP_RIGHT := 24.0           ## от правого края плашки
const MAP_TEXT := "Схема"
const MAP_PX := 36.0

## Шаги: текст плашки, событие, пост-цель (указатель `HintPointer`).
const STEPS := [
	["Подойдите к штурвалу — кнопка справа", Ev.SAT, "helm"],
	["За штурвалом: крестовина вверх — ход", Ev.THRUST, "helm"],
	["За штурвалом нажмите «Свет»", Ev.LIGHT, "helm"],
	["Пульт энергии: крестовиной меняйте доли", Ev.SHARE, "energy"],
	["У голостола нажмите «Сонар» — импульс", Ev.PING, "sonar"],
	["У голостола нажмите «Маршрут»", Ev.ROUTE, "route"],
]
const STAND_UP := "Нажмите «Встать» — идите к энергии"   ## шаг 4, пока сидит за штурвалом
const AT_POWER := "Пульт энергии — кнопка справа"        ## шаг 4, у пульта до открытия

var step := 0          ## текущий шаг 0…5; STEPS.size() — пройдено
var done_t := -1.0     ## ≥ 0 — показывается «Выполнено» этого шага столько секунд
var a := 0.0           ## прозрачность плашки 0…1
var on := true         ## обучение не выключено


func finished() -> bool:
	return step >= STEPS.size()


## Шаг ждёт события или показывает «Выполнено».
func active() -> bool:
	return on and not finished()


## Событие своего игрока. true — шаг засчитан (началось «Выполнено»).
func note(ev: Ev) -> bool:
	if not active() or done_t >= 0.0 or STEPS[step][1] != ev:
		return false
	done_t = 0.0
	return true


## Шаг времени. hidden — тревога, голосование, пауза и прочее: плашка тает, шаг стоит. true — обучение только что
## пройдено целиком (сохранить).
func update(dt: float, hidden: bool) -> bool:
	var was := finished()
	if done_t >= 0.0:
		done_t += dt
		if done_t >= DONE_TIME:
			done_t = -1.0
			step += 1
	var want := active() and not hidden
	a = move_toward(a, 1.0 if want else 0.0, dt / FADE)
	return finished() and not was


func shown() -> bool:
	return a > 0.0 and on and step < STEPS.size()


## «Первый забег · 2 / 6» (у гостя сети — те же шесть: импульс сонара гостя идёт хосту, `CrewFlow.mate_action`).
func step_line() -> String:
	return "Первый забег · %d / %d" % [mini(step + 1, STEPS.size()), STEPS.size()]


## Текст плашки: «Выполнено» или действие шага; на шаге энергии — промежуточные фразы (сидит за штурвалом, у пульта).
func text(seated: bool, near: String) -> String:
	if finished():
		return ""
	if done_t >= 0.0:
		return DONE
	if STEPS[step][1] == Ev.SHARE:
		if seated:
			return STAND_UP
		if near == "energy":
			return AT_POWER
	return STEPS[step][0]


## Какое управление обвести: "action", "up" (верх крестовины), "light", "pad", "" — ничего. Кнопка действия — когда
## на ней нужная подпись (игрок у поста-цели или пора встать).
func highlight(seated: bool, at_power: bool, near: String) -> String:
	if not active() or done_t >= 0.0:
		return ""
	match STEPS[step][1]:
		Ev.SAT:
			return "action" if near == "helm" and not seated else ""
		Ev.THRUST:
			return "up" if seated else ""
		Ev.LIGHT:
			return "light" if seated else ""
		Ev.SHARE:
			if at_power:
				return "pad"
			return "action" if seated or near == "energy" else ""
		Ev.PING:
			return "action" if near == "sonar" else ""
		Ev.ROUTE:
			return "action" if near == "route" else ""
	return ""


## Пост-цель шага.
func target() -> String:
	return "" if finished() else STEPS[step][2]


## Куда показывает указатель (`HintPointer`): пост-цель шага; "" — в «Выполнено», когда обучение не идёт и когда
## игрок уже сидит за штурвалом, а цель — штурвал (указатель был бы над его же креслом). Шаг энергии из кресла —
## указатель на пульт.
func pointer_target(seated: bool) -> String:
	if not active() or done_t >= 0.0:
		return ""
	var id: String = STEPS[step][2]
	return "" if seated and id == "helm" else id


## Кнопка «Схема» нужна: шаг ждёт поста-цели target (`pointer_target`), а игрок не у него (near — пост рядом,
## at_power — пульт открыт). У нужного поста, в «Выполнено» и без цели кнопки нет.
func map_wanted(target: String, near: String, at_power: bool) -> bool:
	if not shown() or not active() or done_t >= 0.0 or target == "":
		return false
	return target != near and not (at_power and target == "energy")


## Кнопка «Схема» на плашке b (экран высотой size.y).
static func map_rect(b: Rect2, size: Vector2) -> Rect2:
	var s := size.y / REF_H
	var w := MAP_BTN * s
	return Rect2(b.end.x - (MAP_RIGHT * s) - w.x, b.position.y + (b.size.y - w.y) * 0.5, w.x, w.y)


## Плашка на экране size: по центру, верх TOP. Легла бы на строку приборов status — опускается под неё; на открытую
## панель avoid (пульт энергии справа) — сдвигается влево от неё, не помещается — опускается под панель.
static func box(size: Vector2, status: Rect2 = Rect2(), avoid: Rect2 = Rect2()) -> Rect2:
	var s := size.y / REF_H
	var w := minf(BOX.x * s, size.x - 32.0)
	var r := Rect2((size.x - w) * 0.5, TOP * s, w, BOX.y * s)
	if status.has_area() and r.intersects(status):
		r.position.y = status.end.y + GAP * s
	if avoid.has_area() and r.intersects(avoid):
		r.position.x = maxf(16.0, avoid.position.x - GAP * s - w)
		if r.intersects(avoid):
			r.position.y = avoid.end.y + GAP * s
	return r


## Верх крестовины (стрелка «вперёд», `TouchOverlay` рисует её от 0,55 до 0,78 радиуса): круг обводки.
static func up_ring(pad: Touch.Circle) -> Touch.Circle:
	return Touch.Circle.new(pad.c + Vector2(0.0, -pad.r * 0.665), pad.r * 0.24)


## Круг обводки управления id по раскладке; null — нечего обводить.
static func ring_of(id: String, l: Touch.Layout) -> Touch.Circle:
	match id:
		"action":
			return l.action
		"light":
			return l.light
		"pad":
			return l.pad
		"up":
			return up_ring(l.pad)
	return null


## Гость сети: корабль считает хост, поэтому шаг засчитывает своё нажатие, подтверждённое кадром хоста за `WAIT`:
## «Свет» за штурвалом — свет в кадре сменился, крестовина у пульта — доли сменились, кнопка у поста «Маршрут» —
## маршрут сменился, кнопка у голостола («Сонар») — в кадре новый импульс хоста (`Sonar.count`). Сел — свой пост в кадре стал «за штурвалом» (пост у каждого свой), ход — своя крестовина вверх
## за штурвалом. Чужое изменение без своего нажатия не считается. `update` — каждый шаг клиента после кадра.
class Guest:
	const WAIT := 1.5   ## нажал — ждём кадр хоста с переменой столько секунд

	var wait := {}   ## Ev → секунды с нажатия
	var primed := false
	var seated := false
	var light := false
	var shares: Array = []
	var route := -1
	var pings := 0

	## События своего игрока за этот шаг. move, light_pressed, action_pressed — свой ввод (вне диалога и шторки);
	## seated, at_power, near — свой пост из кадра; lit, share, route_now, pings_now — свет, доли, маршрут и счёт
	## импульсов сонара из кадра хоста.
	func update(dt: float, seated_now: bool, at_power: bool, near: String, move: Vector2, light_pressed: bool,
			action_pressed: bool, lit: bool, share: Array, route_now: int, pings_now: int = 0) -> Array[Ev]:
		var out: Array[Ev] = []
		for k: int in wait.keys():
			wait[k] += dt
			if wait[k] > WAIT:
				wait.erase(k)
		if seated_now and light_pressed:
			wait[Ev.LIGHT] = 0.0
		if at_power and move != Vector2.ZERO:
			wait[Ev.SHARE] = 0.0
		if near == "route" and action_pressed and not seated_now and not at_power:
			wait[Ev.ROUTE] = 0.0
		if near == "sonar" and action_pressed and not seated_now and not at_power:
			wait[Ev.PING] = 0.0
		if primed:
			if seated_now and not seated:
				out.append(Ev.SAT)
			if lit != light and wait.has(Ev.LIGHT):
				out.append(Ev.LIGHT)
				wait.erase(Ev.LIGHT)
			if share != shares and wait.has(Ev.SHARE):
				out.append(Ev.SHARE)
				wait.erase(Ev.SHARE)
			if route_now != route and wait.has(Ev.ROUTE):
				out.append(Ev.ROUTE)
				wait.erase(Ev.ROUTE)
			if pings_now != pings and wait.has(Ev.PING):
				out.append(Ev.PING)
				wait.erase(Ev.PING)
		if seated_now and move.y > 0.0:
			out.append(Ev.THRUST)
		primed = true
		seated = seated_now
		light = lit
		shares = share.duplicate()
		route = route_now
		pings = pings_now
		return out


func reset() -> void:
	step = 0
	done_t = -1.0
	a = 0.0
