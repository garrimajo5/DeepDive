class_name StepClock
extends RefCounted
## Разбор шага игры по частям для лога тестера (issue #627): «код 112 мс» в худшем кадре не говорит, что тормозит —
## корабль, живой мир или виды. `Main.step` отмечает границы частей (`lap`), `QaRunner` пишет самые долгие части
## худшего кадра: «код 112 мс: мир 80, виды 20». Время берётся снаружи (мкс), чтобы тест был детерминированным.

const SHOW := 3            ## сколько частей в подписи
const MIN_MS := 1.0        ## части короче — не пишем

var parts := {}            ## часть → мс этого шага (части с одним именем складываются)
var dt := 0.0              ## шаг времени этого кадра, с — большой шаг дробит живой мир на подшаги
var last := {}             ## части прошлого, законченного шага — их читает лог тестера (issue #662)
var last_dt := 0.0         ## шаг времени прошлого шага, с
var _from := 0


## Новый шаг игры с момента now_us.
## Прошлый шаг уходит в `last`: замер кадра (`QaRunner._measure`) идёт уже внутри нового шага, после `start`,
## и меряет время прошлого — его части и нужны (issue #662).
func start(now_us: int, step_dt: float = 0.0) -> void:
	last = parts
	last_dt = dt
	parts = {}
	dt = step_dt
	_from = now_us


## Часть name закончилась в now_us: время с прошлой отметки — ей.
func lap(name: String, now_us: int) -> void:
	parts[name] = float(parts.get(name, 0.0)) + maxf(0.0, (now_us - _from) / 1000.0)
	_from = now_us


## Самые долгие части по убыванию: «мир 80, виды 20, корабль 5»; пусто — нечего показать.
func top(n: int = SHOW, min_ms: float = MIN_MS) -> String:
	return _top(parts, n, min_ms)


static func _top(of: Dictionary, n: int, min_ms: float) -> String:
	var keys: Array = of.keys().filter(func(k): return float(of[k]) >= min_ms)
	keys.sort_custom(func(a, b): return float(of[a]) > float(of[b]) or (is_equal_approx(of[a], of[b]) and str(a) < str(b)))
	var out := PackedStringArray()
	for k in keys.slice(0, n):
		out.append("%s %d" % [k, roundi(float(of[k]))])
	return ", ".join(out)


## Подпись для лога: части и шаг времени, если он больше обычного (1/30 с): «мир 80, виды 20; шаг 120 мс».
func note() -> String:
	return _note(parts, dt)


## То же для прошлого, законченного шага — его время `Main.step_ms` и меряет худший кадр (issue #662).
func last_note() -> String:
	return _note(last, last_dt)


static func _note(of: Dictionary, step_dt: float) -> String:
	var t := _top(of, SHOW, MIN_MS)
	if step_dt > 0.05:
		t += ("; " if not t.is_empty() else "") + "шаг %d мс" % roundi(step_dt * 1000.0)
	return t
