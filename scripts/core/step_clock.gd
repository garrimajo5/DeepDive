class_name StepClock
extends RefCounted
## Разбор шага игры по частям для лога тестера (issue #627): «код 112 мс» в худшем кадре не говорит, что тормозит —
## корабль, живой мир или виды. `Main.step` отмечает границы частей (`lap`), `QaRunner` пишет самые долгие части
## худшего кадра: «код 112 мс: мир 80, виды 20». Время берётся снаружи (мкс), чтобы тест был детерминированным.

const SHOW := 3            ## сколько частей в подписи
const MIN_MS := 1.0        ## части короче — не пишем

var parts := {}            ## часть → мс этого шага (части с одним именем складываются)
var dt := 0.0              ## шаг времени этого кадра, с — большой шаг дробит живой мир на подшаги
var _from := 0


## Новый шаг игры с момента now_us.
func start(now_us: int, step_dt: float = 0.0) -> void:
	parts.clear()
	dt = step_dt
	_from = now_us


## Часть name закончилась в now_us: время с прошлой отметки — ей.
func lap(name: String, now_us: int) -> void:
	parts[name] = float(parts.get(name, 0.0)) + maxf(0.0, (now_us - _from) / 1000.0)
	_from = now_us


## Самые долгие части по убыванию: «мир 80, виды 20, корабль 5»; пусто — нечего показать.
func top(n: int = SHOW, min_ms: float = MIN_MS) -> String:
	var keys: Array = parts.keys().filter(func(k): return float(parts[k]) >= min_ms)
	keys.sort_custom(func(a, b): return float(parts[a]) > float(parts[b]) or (is_equal_approx(parts[a], parts[b]) and str(a) < str(b)))
	var out := PackedStringArray()
	for k in keys.slice(0, n):
		out.append("%s %d" % [k, roundi(float(parts[k]))])
	return ", ".join(out)


## Подпись для лога: части и шаг времени, если он больше обычного (1/30 с): «мир 80, виды 20; шаг 120 мс».
func note() -> String:
	var t := top()
	if dt > 0.05:
		t += ("; " if not t.is_empty() else "") + "шаг %d мс" % roundi(dt * 1000.0)
	return t
