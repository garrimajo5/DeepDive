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
## Подчасть каждого шага с обычным короче USUAL_MIN (#1350, `EcoKamen` ~0,05 мс): «EcoKamen 42» без «×» читалась как
## событие, а не заминка. Точного отношения нет — пишем нижнюю границу «×>N» по USUAL_MIN, не больше «×>100». Подчасть
## по событию (бывает не в каждом шаге — доля шагов `usual_seen` ниже SEEN_MIN) по-прежнему без «×».
const SEEN_MIN := 0.5      ## доля шагов с подчастью — она «каждого шага»
const FLOOR_CAP := 100     ## «×>N» не больше
## Заминка машины (issue #1174, #1156: в провалах эмулятора «мир 230 [EcoVent 34 ×…, EcoCoins 33 ×129]» — раздуты все
## подчасти, даже EcoVent, у которого в шаге три строки, а тестер и разбор гадали, какой вид виноват). Медиана «×»
## подчастей с известным обычным — не меньше STALL_K, и таких подчастей не меньше STALL_N — после скобок пишем
## «— разом ×N, заминка»: виновника среди подчастей нет, время отняла машина (эмулятор, система). Долгий шаг работы не
## прибавляет: живой мир за кадр идёт одним подшагом ≤ `EcoWorld.SLOW_STEP`, остаток — в долг `EcoView.lag` (#1255),
## прочие части шаг не дробят. Раньше порог умножали на число подшагов долгого шага (шаг 117 мс — ×2, порог 10), и
## после #1255 настоящая заминка мира в `33a` («флора ×7, EcoPred ×6, EcoCoins ×15») не отмечалась (#1253).
const STALL_K := 5.0
const STALL_N := 3
const REST_SKIP := 2     ## заминка по сумме — без стольких самых долгих подчастей (#1253)
const STALL := " — разом ×%d, заминка"
## Три виновника разом (#1317, `32h-rakovina-osmotr`: «мир 51 (обычно 10) [EcoKelp 9 ×24, EcoCoins 9 ×44, EcoGrazer 9
## ×80, ещё 44: 24 ×3]» без пометки): машина отняла по куску времени у нескольких несвязанных модулей, остальные —
## ×3. За кадр мир идёт одним подшагом, и без импульса или разряда (`PING_MARK`) у трёх несвязанных модулей нет общей
## причины стать в SPIKE_K раз дольше разом (в облаке у Раковины 03 со сканером и импульсом ни один модуль за 840
## кадров не дольше 1,6 мс). Тогда «разом ×N» — во сколько раз дольше обычного весь замер, не меньше SPIKE_MIN.
const SPIKE_K := 10.0      ## во сколько раз дольше обычного — подчасть-«виновник»
const SPIKE_MS := 3.0      ## и не короче, мс
const SPIKE_MIN := 2       ## «разом ×N» не меньше
const PING_MARK := "импульс, разряд"   ## подчасть мира в кадре импульса или разряда (`EcoWorld.step`)
## Одна отметка (#1350, 12.11, отчёт `2026-11-12-0330`: «мир 72 [EcoFlower 42 ×>100, EcoFish 12, …]»): у подчасти
## обычное ~0 (`EcoFlower.step` — шесть сложений, за 1680 кадров замера макс 1 мс), она одна «×>N», а у всех подчастей
## с известным обычным — меньше SLOW раз. Работы в ней на 42 мс нет — время отняла машина (хост снял процесс с ЦП),
## пока шёл этот вызов. Пишем после скобок «— одна отметка, вероятно хост», чтобы разбор не искал в ней виновника.
## Подчасть с обычным ≥ USUAL_MIN, одна «×30» среди «×1», — по-прежнему виновник (у неё есть работа, которая может
## подорожать). В кадре импульса или разряда (`PING_MARK`) — не пишем.
const LONE := " — одна отметка, вероятно хост"

var parts := {}            ## часть → мс этого шага (части с одним именем складываются)
var subs := {}             ## часть → {подчасть → мс}: отметки «часть/подчасть» (issue #745)
var last_subs := {}        ## подчасти прошлого шага
var dt := 0.0              ## шаг времени этого кадра, с — большой шаг дробит живой мир на подшаги
var last := {}             ## части прошлого, законченного шага — их читает лог тестера (issue #662)
var last_dt := 0.0         ## шаг времени прошлого шага, с
var _from := 0
var usual := {}            ## часть → обычное время, мс (среднее шагов до `last`)
var usual_subs := {}       ## часть → {подчасть → обычное время, мс}
var usual_seen := {}       ## часть → {подчасть → доля шагов, где она была} (SEEN_MIN)
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
		var here := {}
		for key in sub_of.get(p, {}).keys():
			here[key] = 1.0
		if not usual_seen.has(p):
			usual_seen[p] = {}
		_mix(usual_seen[p], here, k)


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
	return {"": usual, "/": usual_subs, "seen": usual_seen} if usual_ready() else {}


## «×N» к обычному времени ms (usual — обычное, мс): пусто, если не дольше SLOW раз или обычное неизвестно.
## seen — доля шагов с этой подчастью: подчасть каждого шага (≥ SEEN_MIN) с обычным короче USUAL_MIN — «×>N» (#1350).
static func slower(ms: float, usual_ms: float, seen: float = 0.0) -> String:
	if usual_ms < USUAL_MIN:
		var low := floori(ms / USUAL_MIN)
		if seen < SEEN_MIN or low < roundi(SLOW):
			return ""
		return " ×>%d" % mini(low, FLOOR_CAP)
	if ms < usual_ms * SLOW:
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
			var inner := _inner(float(of[k]), sub_of[k], min_ms, us.get("/", {}).get(k, {}),
					us.get("seen", {}).get(k, {}))
			if not inner.is_empty():
				t += " [%s]" % inner
				var x := stall(sub_of[k], us.get("/", {}).get(k, {}))
				if x > 0:
					t += STALL % x
				elif lone(sub_of[k], us.get("/", {}).get(k, {}), us.get("seen", {}).get(k, {})):
					t += LONE
		out.append(t)
	return ", ".join(out)


## Во сколько раз разом медленнее обычного все подчасти sub (us — их обычное время, мс): медиана «×» подчастей с
## известным обычным, если она не меньше STALL_K и таких подчастей не меньше STALL_N; иначе 0 — есть виновник или мало
## данных. Долгий шаг кадра порог не меняет: мир идёт одним подшагом (#1255), прочие части шаг не дробят (#1253).
static func stall(sub: Dictionary, us: Dictionary) -> int:
	var ratios: Array[float] = []
	for key in sub.keys():
		var u := float(us.get(key, 0.0))
		if u >= USUAL_MIN:
			ratios.append(float(sub[key]) / u)
	if ratios.size() < STALL_N:
		return 0
	ratios.sort()
	var mid := ratios.size() / 2
	var med := ratios[mid] if ratios.size() % 2 == 1 else (ratios[mid - 1] + ratios[mid]) * 0.5
	if med >= STALL_K:
		return roundi(med)
	var r := rest_stall(sub, us)
	return r if r > 0 else spike_stall(sub, us)


## Одна отметка (`LONE`): ровно одна подчасть sub не короче MIN_MS с обычным короче USUAL_MIN, которая каждого шага
## (seen ≥ SEEN_MIN) и пишется «×>N», а все подчасти с известным обычным (хотя бы одна) — меньше SLOW раз; кадр без
## импульса и разряда. us — обычное время подчастей, мс; seen — доля шагов с подчастью.
static func lone(sub: Dictionary, us: Dictionary, seen: Dictionary) -> bool:
	if sub.has(PING_MARK):
		return false
	var floors := 0
	var known := 0
	for key in sub.keys():
		var m := float(sub[key])
		var u := float(us.get(key, 0.0))
		if u >= USUAL_MIN:
			if m >= u * SLOW:
				return false
			known += 1
		elif m >= MIN_MS and not slower(m, u, float(seen.get(key, 0.0))).is_empty():
			floors += 1
	return floors == 1 and known > 0


## Заминка по трём «виновникам» сразу (#1317): не меньше STALL_N подчастей с известным обычным — каждая не короче
## SPIKE_MS и в SPIKE_K раз дольше обычного, в кадре без импульса и разряда. Итог — весь замер к обычному, не меньше
## SPIKE_MIN; иначе 0. Два таких — ещё виновники (`test_stall_by_rest_sum`).
static func spike_stall(sub: Dictionary, us: Dictionary) -> int:
	if sub.has(PING_MARK):
		return 0
	var spikes := 0
	var ms := 0.0
	var usual_ms := 0.0
	for key in sub.keys():
		var u := float(us.get(key, 0.0))
		if u < USUAL_MIN:
			continue
		var m := float(sub[key])
		ms += m
		usual_ms += u
		if m >= SPIKE_MS and m >= SPIKE_K * u:
			spikes += 1
	if spikes < STALL_N:
		return 0
	return maxi(SPIKE_MIN, roundi(ms / usual_ms))


## Заминка по сумме (#1253, `32o-mol-steklo`: «мир 230 (обычно 16) [EcoFish 79 ×40, рыбы 21 ×11, EcoDome 19 ×41,
## ещё 43: 111 ×10]» без пометки): медиану тянут вниз мелкие подчасти ×1–×3 (вызов в пару строк машина почти не
## замедляет), а раздутое время сидит в подчастях покрупнее. Без двух самых долгих (возможных виновников, `REST_SKIP`)
## остальные вместе — не меньше STALL_K раз дольше обычного и их не меньше STALL_N: это «разом ×N», а не вид.
static func rest_stall(sub: Dictionary, us: Dictionary) -> int:
	var keys: Array = sub.keys().filter(func(k): return float(us.get(k, 0.0)) >= USUAL_MIN)
	keys.sort_custom(func(a, b): return float(sub[a]) > float(sub[b]) or (is_equal_approx(sub[a], sub[b]) and str(a) < str(b)))
	var rest := keys.slice(REST_SKIP)
	if rest.size() < STALL_N:
		return 0
	var ms := 0.0
	var usual_ms := 0.0
	for k in rest:
		ms += float(sub[k])
		usual_ms += float(us[k])
	var x := ms / usual_ms
	return roundi(x) if x >= STALL_K else 0


## Подчасти долгой части total: SUB_SHOW самых долгих, затем остаток — прочие подчасти одной суммой (`REST`) и время
## вне подчастей (`BARE`), если они не короче min_ms (issue #1020).
static func _inner(total: float, sub: Dictionary, min_ms: float, us: Dictionary = {}, seen: Dictionary = {}) -> String:
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
			named.append("%s %d%s" % [k, roundi(float(sub[k])),
					slower(float(sub[k]), float(us.get(k, 0.0)), float(seen.get(k, 0.0)))])
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
