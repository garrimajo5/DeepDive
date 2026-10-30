class_name StepClock
extends RefCounted
## Разбор шага игры по частям для лога тестера (issue #627): «код 112 мс» в худшем кадре не говорит, что тормозит —
## корабль, живой мир или виды. `Main.step` отмечает границы частей (`lap`), `QaRunner` пишет самые долгие части
## худшего кадра: «код 112 мс: мир 80, виды 20». Время берётся снаружи (мкс), чтобы тест был детерминированным.

const SHOW := 3            ## сколько частей в подписи
const MIN_MS := 1.0        ## части короче — не пишем
const SUB_MS := 10.0       ## часть дольше — с её долгими подчастями: «интерфейс 45 [связь 40]» (issue #745)
const SUB_SHOW := 3        ## сколько подчастей в скобках
## Остаток долгой части за показанными подчастями (issue #1020: «мир 91 [EcoFringe 15, EcoFish 13]» — где ещё 63 мс):
## прочие подчасти одной суммой «ещё 12: 40» и время части вне подчастей «без отметки 13».
const REST := "ещё %d: %d"
const BARE := "без отметки %d"
## Обычное время частей — среднее прошлых шагов (issue #1020: в худшем кадре «мир 113 [… ещё 43: 61]» — модуль-виновник
## или весь шаг медленнее разом). Долгая часть пишет «обычно N», подчасти — во сколько раз дольше обычного: «EcoFish 20 ×7».
## Все подчасти «×6» — машина замерла на кадр (эмулятор, система), одна «×30» среди «×1» — виновник.
const USUAL_K := 0.05      ## доля нового шага в среднем
const USUAL_FROM := 10     ## столько шагов до первого «обычно»
const USUAL_MIN := 0.1     ## обычное короче, мс — отношение не пишем (подчасть по событию)
const SLOW := 2.0          ## во сколько раз дольше обычного — пишем «×N»

var parts := {}            ## часть → мс этого шага (части с одним именем складываются)
var subs := {}             ## часть → {подчасть → мс}: отметки «часть/подчасть» (issue #745)
var last_subs := {}        ## подчасти прошлого шага
var dt := 0.0              ## шаг времени этого кадра, с — большой шаг дробит живой мир на подшаги
var last := {}             ## части прошлого, законченного шага — их читает лог тестера (issue #662)
var last_dt := 0.0         ## шаг времени прошлого шага, с
var _from := 0
var usual := {}            ## часть → обычное время, мс (среднее шагов до `last`)
var usual_subs := {}       ## часть → {подчасть → обычное время, мс}
var usual_n := 0           ## сколько шагов в среднем
var _starts := 0           ## сколько было `start`: `last` — законченный шаг со второго

## Часы шага, который идёт сейчас (последний `start`): живой мир отмечает в них свои подчасти `mark`, не зная `Main`
## (issue #1020: «мир 78» в худшем кадре не говорит, какой модуль или вид мира дал всплеск).
static var active: StepClock = null


## Новый шаг игры с момента now_us.
## Прошлый шаг уходит в `last`: замер кадра (`QaRunner._measure`) идёт уже внутри нового шага, после `start`,
## и меряет время прошлого — его части и нужны (issue #662).
func start(now_us: int, step_dt: float = 0.0) -> void:
	if _starts >= 2:
		_fold(last, last_subs)   # в среднее — шаг до `last`: худший кадр сравнивается не с самим собой
	_starts += 1
	last = parts
	last_subs = subs
	last_dt = dt
	parts = {}
	subs = {}
	dt = step_dt
	_from = now_us
	active = self


## Шаг с частями of и подчастями sub_of — в обычное время (отсутствующая часть — 0 мс этого шага).
func _fold(of: Dictionary, sub_of: Dictionary) -> void:
	var k := 1.0 if usual_n == 0 else USUAL_K
	usual_n += 1
	_mix(usual, of, k)
	for p in sub_of.keys():
		if not usual_subs.has(p):
			usual_subs[p] = {}
	for p in usual_subs.keys():
		_mix(usual_subs[p], sub_of.get(p, {}), k)


static func _mix(into: Dictionary, of: Dictionary, k: float) -> void:
	for key in of.keys():
		if not into.has(key):
			into[key] = 0.0 if k < 1.0 else float(of[key])
	for key in into.keys():
		into[key] = lerpf(float(into[key]), float(of.get(key, 0.0)), k)


## Обычное время готово к сравнению.
func usual_ready() -> bool:
	return usual_n >= USUAL_FROM


## Подчасть идущего шага закончилась сейчас: `active.lap(name, …)`; нет идущего шага — ничего (тесты мира без `Main`).
static func mark(name: String) -> void:
	if active != null:
		active.lap(name, Time.get_ticks_usec())


## Часть name закончилась в now_us: время с прошлой отметки — ей.
## «интерфейс/связь» — подчасть: время идёт и части «интерфейс», и её подчасти «связь» (issue #745: «интерфейс 45»
## в худшем кадре не говорит, подсказки это, связь или рация).
func lap(name: String, now_us: int) -> void:
	var ms := maxf(0.0, (now_us - _from) / 1000.0)
	var cut := name.find("/")
	var part := name if cut < 0 else name.substr(0, cut)
	parts[part] = float(parts.get(part, 0.0)) + ms
	if cut >= 0:
		var child := name.substr(cut + 1)
		var of: Dictionary = subs.get(part, {})
		of[child] = float(of.get(child, 0.0)) + ms
		subs[part] = of
	_from = now_us


## Самые долгие части по убыванию: «мир 80, виды 20, корабль 5»; пусто — нечего показать.
## Долгая часть (≥ SUB_MS) — с подчастями в квадратных скобках: «интерфейс 45 [связь 40], мир 30».
func top(n: int = SHOW, min_ms: float = MIN_MS) -> String:
	return _top(parts, n, min_ms, subs, _usual_now())


## Обычное время для подписи: {} — пока шагов мало.
func _usual_now() -> Dictionary:
	return {"": usual, "/": usual_subs} if usual_ready() else {}


## «×N» к обычному времени ms (usual — обычное, мс): пусто, если не дольше SLOW раз или обычное неизвестно.
static func slower(ms: float, usual_ms: float) -> String:
	if usual_ms < USUAL_MIN or ms < usual_ms * SLOW:
		return ""
	return " ×%d" % roundi(ms / usual_ms)


static func _top(of: Dictionary, n: int, min_ms: float, sub_of: Dictionary = {}, us: Dictionary = {}) -> String:
	var keys: Array = of.keys().filter(func(k): return float(of[k]) >= min_ms)
	keys.sort_custom(func(a, b): return float(of[a]) > float(of[b]) or (is_equal_approx(of[a], of[b]) and str(a) < str(b)))
	var out := PackedStringArray()
	for k in keys.slice(0, n):
		var t := "%s %d" % [k, roundi(float(of[k]))]
		var mine: Dictionary = us.get("", {})
		if float(of[k]) >= SUB_MS and mine.has(k) and float(of[k]) >= float(mine[k]) * SLOW:
			t += " (обычно %d)" % roundi(float(mine[k]))
		if float(of[k]) >= SUB_MS and sub_of.has(k):
			var inner := _inner(float(of[k]), sub_of[k], min_ms, us.get("/", {}).get(k, {}))
			if not inner.is_empty():
				t += " [%s]" % inner
		out.append(t)
	return ", ".join(out)


## Подчасти долгой части total: SUB_SHOW самых долгих, затем остаток — прочие подчасти одной суммой (`REST`) и время
## вне подчастей (`BARE`), если они не короче min_ms (issue #1020).
static func _inner(total: float, sub: Dictionary, min_ms: float, us: Dictionary = {}) -> String:
	var t := _top(sub, SUB_SHOW, min_ms)
	if t.is_empty():
		return t
	var mark := not us.is_empty()
	var keys: Array = sub.keys()
	keys.sort_custom(func(a, b): return float(sub[a]) > float(sub[b]) or (is_equal_approx(sub[a], sub[b]) and str(a) < str(b)))
	var shown := keys.filter(func(k): return float(sub[k]) >= min_ms).slice(0, SUB_SHOW)
	if mark:   # подчасти заново — с «×N» к обычному
		var named := PackedStringArray()
		for k in shown:
			named.append("%s %d%s" % [k, roundi(float(sub[k])), slower(float(sub[k]), float(us.get(k, 0.0)))])
		t = ", ".join(named)
	var rest := 0.0
	var rest_usual := 0.0
	var marked := 0.0
	var n := 0
	for k in keys:
		marked += float(sub[k])
		if not shown.has(k):
			rest += float(sub[k])
			rest_usual += float(us.get(k, 0.0))
			n += 1
	if rest >= min_ms:
		t += ", " + REST % [n, roundi(rest)] + (slower(rest, rest_usual) if mark else "")
	var bare := total - marked
	if bare >= min_ms:
		t += ", " + BARE % roundi(bare)
	return t


## Подпись для лога: части и шаг времени, если он больше обычного (1/30 с): «мир 80, виды 20; шаг 120 мс».
func note() -> String:
	return _note(parts, dt, subs, _usual_now())


## То же для прошлого, законченного шага — его время `Main.step_ms` и меряет худший кадр (issue #662).
func last_note() -> String:
	return _note(last, last_dt, last_subs, _usual_now())


static func _note(of: Dictionary, step_dt: float, sub_of: Dictionary = {}, us: Dictionary = {}) -> String:
	var t := _top(of, SHOW, MIN_MS, sub_of, us)
	if step_dt > 0.05:
		t += ("; " if not t.is_empty() else "") + "шаг %d мс" % roundi(step_dt * 1000.0)
	return t
