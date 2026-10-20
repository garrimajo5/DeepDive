class_name Synth
## Процедурный звук без файлов (как js/audio.js на WebAudio): петли PCM 16 бит моно, собранные в коде.
## Звуков-ассетов в игре нет: всё, что звучит, — отсюда. Числа тонов и громкостей — из js/audio.js.
## Сэмплы детерминированные (свой генератор), чтобы тесты и снимки не зависели от случая.

const RATE := 22050

## Сирена пробоины (A.siren): «квадрат» 620/780 Гц, тон меняется по sin(3t), громко/тихо — по sin(6t)
## (0,05 и 0,012 при общей 0,7 → доли 1 и 0,24). Петля — один период sin(3t), 2π/3 с.
const SIREN_LO := 620.0
const SIREN_HI := 780.0
const SIREN_QUIET := 0.24
const SIREN_LEN := TAU / 3.0
## Струя: шум, без самых низких и самых высоких (полоса ~250…1800 Гц, верх — два звена фильтра), петля 2 с со сшитыми краями.
const JET_LEN := 2.0
const JET_LP := 1800.0
const JET_HP := 250.0
## Тревога «присоска на корпусе» (A.alarmCue('latch') раз в 1,6 с из js/soundscape.js): шипение 0,25 с — белый шум
## через верхний фильтр (Q 2), срез скользит 4000 → 2500 Гц, нарастание 0,02 с и экспоненциальный спад.
## Звук без петли длиной LATCH_LEN; раз в LATCH_PERIOD его перезапускает корабль (Vitals.hiss), пока тревога горит.
## Прежняя петля 1,6 с с тишиной роняла игру на Android в потоке звука (issue #163).
const LATCH_PERIOD := 1.6
const LATCH_LEN := 0.25
const LATCH_F0 := 4000.0
const LATCH_F1 := 2500.0
const LATCH_Q := 2.0
const PEAK := 0.8   ## доля от полной шкалы 16 бит


## «Квадрат» из первых нечётных гармоник (1, 3, 5, 7): без хруста на 22 кГц.
static func soft_square(phase: float) -> float:
	return (sin(phase) + sin(phase * 3.0) / 3.0 + sin(phase * 5.0) / 5.0 + sin(phase * 7.0) / 7.0) * 4.0 / PI


## Сирена: сэмплы −1…1 (пик 1) на петлю SIREN_LEN. Фаза тона непрерывна при смене частоты, громкость сглажена ~5 мс.
static func siren_samples(rate: int = RATE) -> PackedFloat32Array:
	var n := int(round(SIREN_LEN * rate))
	var out := PackedFloat32Array()
	out.resize(n)
	var cycles := 0.0   # частоты чуть подогнаны, чтобы на петлю пришлось целое число периодов — без щелчка на стыке
	for i in n:
		cycles += (SIREN_HI if sin(float(i) / rate * 3.0) > 0.0 else SIREN_LO) / rate
	var fk: float = roundf(cycles) / cycles
	var ph := 0.0
	var g := SIREN_QUIET
	var follow := 1.0 - exp(-1.0 / (0.005 * rate))
	for i in n:
		var t := float(i) / rate
		var f: float = (SIREN_HI if sin(t * 3.0) > 0.0 else SIREN_LO) * fk
		ph = fmod(ph + TAU * f / rate, TAU)
		var want := 1.0 if sin(t * 6.0) > 0.0 else SIREN_QUIET
		g += (want - g) * follow
		out[i] = soft_square(ph) * g
	return normalized(out)


## Готовые петли (собираются один раз на запуск).
static var _cache := {}


static func siren() -> AudioStreamWAV:
	if not _cache.has("siren"):
		_cache["siren"] = loop(siren_samples())
	return _cache["siren"]


static func jet() -> AudioStreamWAV:
	if not _cache.has("jet"):
		_cache["jet"] = loop(jet_samples())
	return _cache["jet"]


static func latch() -> AudioStreamWAV:
	if not _cache.has("latch"):
		_cache["latch"] = once(latch_samples())
	return _cache["latch"]


## Шипение присоски: LATCH_LEN с (биквад верхних частот RBJ со скользящим срезом), без тишины после.
static func latch_samples(rate: int = RATE, seed: int = 11) -> PackedFloat32Array:
	var m := int(LATCH_LEN * rate)
	var n := m
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var lo := 0.0001
	for i in m:
		var t := float(i) / rate
		var f := LATCH_F0 * pow(LATCH_F1 / LATCH_F0, t / LATCH_LEN)
		var w := TAU * f / rate
		var al := sin(w) / (2.0 * LATCH_Q)
		var cw := cos(w)
		var a0 := 1.0 + al
		var x := rng.randf_range(-1.0, 1.0)
		var y := ((1.0 + cw) / 2.0 * x - (1.0 + cw) * x1 + (1.0 + cw) / 2.0 * x2 + 2.0 * cw * y1 - (1.0 - al) * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		# громкость: 0,0001 → 1 за 0,02 с, затем → 0,0001 к концу (экспоненты, как exponentialRampToValueAtTime)
		var g: float = lo * pow(1.0 / lo, t / 0.02) if t < 0.02 else pow(lo, (t - 0.02) / (LATCH_LEN - 0.02))
		out[i] = y * g
	return normalized(out)


## Струя: полосовой шум на JET_LEN, края петли сшиты перекрёстным затуханием 0,1 с.
static func jet_samples(rate: int = RATE, seed: int = 7) -> PackedFloat32Array:
	var n := int(JET_LEN * rate)
	var fade := int(0.1 * rate)
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var a_lp := 1.0 - exp(-TAU * JET_LP / rate)
	var a_hp := 1.0 - exp(-TAU * JET_HP / rate)
	var lp1 := 0.0
	var lp := 0.0
	var low := 0.0
	for i in raw.size():
		lp1 += (rng.randf_range(-1.0, 1.0) - lp1) * a_lp
		lp += (lp1 - lp) * a_lp
		low += (lp - low) * a_hp
		raw[i] = lp - low
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	for i in fade:   # хвост за концом петли плавно переходит в её начало
		var k := float(i) / fade
		out[i] = raw[n + i] * (1.0 - k) + raw[i] * k
	return normalized(out)


## Звук на один раз (без петли): 16 бит, моно, пик — PEAK от полной шкалы.
static func once(samples: PackedFloat32Array, rate: int = RATE) -> AudioStreamWAV:
	var w := loop(samples, rate)
	w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	w.loop_end = 0
	return w


## Привести пик к 1.
static func normalized(s: PackedFloat32Array) -> PackedFloat32Array:
	var peak := 0.0
	for v in s:
		peak = maxf(peak, absf(v))
	if peak > 0.0:
		for i in s.size():
			s[i] /= peak
	return s


## Петля для AudioStreamPlayer: 16 бит, моно, пик — PEAK от полной шкалы.
static func loop(samples: PackedFloat32Array, rate: int = RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * PEAK, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = samples.size()
	return w
