class_name StepClock
extends RefCounted
## Разбор шага игры по частям для лога тестера (issue #627): «код 112 мс» в худшем кадре не говорит, что тормозит —
## корабль, живой мир или виды. `Main.step` отмечает границы частей (`lap`), `QaRunner` пишет самые долгие части
## худшего кадра: «код 112 мс: мир 80, виды 20». Время берётся снаружи (мкс), чтобы тест был детерминированным.

const SHOW := 3            ## сколько частей в подписи
const MIN_MS := 1.0        ## части короче — не пишем
const SUB_MS := 10.0       ## часть дольше — с её долгими подчастями: «интерфейс 45 [связь 40]» (issue #745)
const SUB_SHOW := 2        ## сколько подчастей в скобках

var parts := {}            ## часть → мс этого шага (части с одним именем складываются)
var subs := {}             ## часть → {подчасть → мс}: отметки «часть/подчасть» (issue #745)
var last_subs := {}        ## подчасти прошлого шага
var dt := 0.0              ## шаг времени этого кадра, с — большой шаг дробит живой мир на подшаги
var last := {}             ## части прошлого, законченного шага — их читает лог тестера (issue #662)
var last_dt := 0.0         ## шаг времени прошлого шага, с
var _from := 0


## Новый шаг игры с момента now_us.
## Прошлый шаг уходит в `last`: замер кадра (`QaRunner._measure`) идёт уже внутри нового шага, после `start`,
## и меряет время прошлого — его части и нужны (issue #662).
func start(now_us: int, step_dt: float = 0.0) -> void:
	last = parts
	last_subs = subs
	last_dt = dt
	parts = {}
	subs = {}
	dt = step_dt
	_from = now_us


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
	return _top(parts, n, min_ms, subs)


static func _top(of: Dictionary, n: int, min_ms: float, sub_of: Dictionary = {}) -> String:
	var keys: Array = of.keys().filter(func(k): return float(of[k]) >= min_ms)
	keys.sort_custom(func(a, b): return float(of[a]) > float(of[b]) or (is_equal_approx(of[a], of[b]) and str(a) < str(b)))
	var out := PackedStringArray()
	for k in keys.slice(0, n):
		var t := "%s %d" % [k, roundi(float(of[k]))]
		if float(of[k]) >= SUB_MS and sub_of.has(k):
			var inner := _top(sub_of[k], SUB_SHOW, min_ms)
			if not inner.is_empty():
				t += " [%s]" % inner
		out.append(t)
	return ", ".join(out)


## Подпись для лога: части и шаг времени, если он больше обычного (1/30 с): «мир 80, виды 20; шаг 120 мс».
func note() -> String:
	return _note(parts, dt, subs)


## То же для прошлого, законченного шага — его время `Main.step_ms` и меряет худший кадр (issue #662).
func last_note() -> String:
	return _note(last, last_dt, last_subs)


static func _note(of: Dictionary, step_dt: float, sub_of: Dictionary = {}) -> String:
	var t := _top(of, SHOW, MIN_MS, sub_of)
	if step_dt > 0.05:
		t += ("; " if not t.is_empty() else "") + "шаг %d мс" % roundi(step_dt * 1000.0)
	return t
