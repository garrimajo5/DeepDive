extends TestCase
## Процедурный звук (Synth, js/audio.js): сирена пробоины и шум струи — петли PCM без файлов.


## Частота по пересечениям нуля вверх на отрезке [a, b) сэмплов.
func _freq(s: PackedFloat32Array, a: int, b: int) -> float:
	var ups := 0
	for i in range(a + 1, b):
		if s[i - 1] < 0.0 and s[i] >= 0.0:
			ups += 1
	return ups * float(Synth.RATE) / (b - a)


func _rms(s: PackedFloat32Array, a: int, b: int) -> float:
	var e := 0.0
	for i in range(a, b):
		e += s[i] * s[i]
	return sqrt(e / (b - a))


func test_siren_two_tones_and_pulse() -> void:
	var s := Synth.siren_samples()
	eq(s.size(), int(round(Synth.SIREN_LEN * Synth.RATE)), "петля — период sin(3t), 2,09 с")
	var peak := 0.0
	for v in s:
		peak = maxf(peak, absf(v))
	near(peak, 1.0, 1e-5, "пик приведён к 1")
	var r := Synth.RATE
	# sin(3t) > 0 на 0…1,05 с — высокий тон; громко, пока sin(6t) > 0: 0…0,52 с
	near(_freq(s, int(0.05 * r), int(0.45 * r)), Synth.SIREN_HI, 8.0, "первая половина — 780 Гц")
	near(_freq(s, int(1.15 * r), int(1.5 * r)), Synth.SIREN_LO, 8.0, "вторая — 620 Гц")
	var loud := _rms(s, int(0.1 * r), int(0.4 * r))
	var quiet := _rms(s, int(0.62 * r), int(0.95 * r))
	near(quiet / loud, Synth.SIREN_QUIET, 0.02, "тише вдвое с лишним по sin(6t)")
	var step := 0.0
	for i in range(1, s.size()):
		step = maxf(step, absf(s[i] - s[i - 1]))
	ok(absf(s[s.size() - 1] - s[0]) <= step + 1e-5, "стык петли не резче обычного шага")
	eq(Synth.siren_samples(), s, "одинаково при каждом запуске")


func test_jet_noise_loop() -> void:
	var s := Synth.jet_samples()
	eq(s.size(), int(Synth.JET_LEN * Synth.RATE), "петля 2 с")
	var peak := 0.0
	var mean := 0.0
	for v in s:
		peak = maxf(peak, absf(v))
		mean += v
	near(peak, 1.0, 1e-5, "пик приведён к 1")
	near(mean / s.size(), 0.0, 0.02, "без постоянной составляющей")
	var rms := _rms(s, 0, s.size())
	ok(rms > 0.12, "шум, не тишина (%.2f)" % rms)
	var step := 0.0
	for i in range(1, s.size()):
		step = maxf(step, absf(s[i] - s[i - 1]))
	ok(absf(s[s.size() - 1] - s[0]) <= step + 1e-5, "стык петли не резче обычного шага")
	var f := _freq(s, 0, s.size())
	ok(f > Synth.JET_HP and f < Synth.JET_LP * 1.5, "шум в полосе, не белый (%d Гц, у белого ~5500)" % int(f))
	eq(Synth.jet_samples(), s, "детерминированно")
	ok(Synth.jet_samples(Synth.RATE, 8) != s, "другое зерно — другой шум")


func test_loop_stream() -> void:
	var w := Synth.siren()
	eq(w.format, AudioStreamWAV.FORMAT_16_BITS, "16 бит")
	eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD, "петля")
	eq(w.loop_end, w.data.size() / 2, "петля на весь звук")
	eq(w.mix_rate, Synth.RATE, "частота")
	ok(Synth.siren() == w, "собирается один раз")
	var hi := 0
	for i in w.data.size() / 2:
		hi = maxi(hi, absi(w.data.decode_s16(i * 2)))
	ok(hi <= int(32767 * Synth.PEAK) + 1 and hi > 20000, "пик %d — с запасом от полной шкалы" % hi)
