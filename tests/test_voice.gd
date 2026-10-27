extends TestCase
## Голос рации по сети (#634): μ-law туда и обратно, кадры захвата любой длины → пакеты по 20 мс с номером,
## частота речи сохраняется, выше 4 кГц срезано; «По голосу» держит конец слова; у слушателя — буфер на 60 мс,
## порядок по номерам, опоздавшие мимо, пропавшие — тишина, переход номера 65535 → 0, лишнее не копится.


func _tone(n: int, rate: float, hz: float, amp: float, from := 0) -> PackedVector2Array:
	var f := PackedVector2Array()
	f.resize(n)
	for i in n:
		var v := amp * sin(TAU * hz * float(from + i) / rate)
		f[i] = Vector2(v, v)
	return f


func _packet(seq: int, v: float) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(Voice.SIZE)
	p.encode_u16(0, seq)
	for i in Voice.FRAME:
		p[Voice.HEAD + i] = Voice.encode_sample(v)
	return p


## По 20 мс на 8 кГц (один выходной отсчёт — один входной): последний отсчёт каждого куска — из очередного пакета.
func _frames_of(d: Voice.Decoder, n: int) -> Array[float]:
	var got: Array[float] = []
	for i in n:
		var out := d.pull(Voice.FRAME, Voice.RATE)
		got.append(snappedf(out[Voice.FRAME - 1].x, 0.01))
	return got


func test_mulaw_round_trip() -> void:
	eq(Voice.decode_sample(Voice.encode_sample(0.0)), 0.0, "ноль остаётся нулём")
	near(Voice.decode_sample(Voice.encode_sample(1.0)), 1.0, 1e-6, "полная громкость")
	near(Voice.decode_sample(Voice.encode_sample(-1.0)), -1.0, 1e-6, "полная громкость со знаком")
	eq(Voice.encode_sample(3.0), Voice.encode_sample(1.0), "громче 1 — обрезается")
	for x in [0.003, 0.01, 0.05, 0.2, 0.5, 0.9, -0.004, -0.07, -0.6]:
		var y := Voice.decode_sample(Voice.encode_sample(x))
		ok(absf(y - x) <= absf(x) * 0.05 + 0.0005, "%.3f → %.4f: ошибка в пределах 5%%" % [x, y])
		ok(signf(y) == signf(x), "знак сохранён у %.3f" % x)


func test_seq_wrap() -> void:
	ok(Voice.after(1, 0), "1 после 0")
	ok(Voice.after(0, 65535), "0 после 65535")
	ok(not Voice.after(65535, 0), "65535 — до 0")
	ok(not Voice.after(5, 5), "сам себя не позже")


func test_encoder_packets_for_any_chunks() -> void:
	var e := Voice.Encoder.new()
	var one := e.push(_tone(960, 48000, 400, 0.5), 48000)
	eq(one.size(), 1, "20 мс на 48 кГц — ровно один пакет")
	eq(one[0].size(), 162, "пакет — 2 байта номера и 160 отсчётов")
	eq(one[0].decode_u16(0), 0, "первый номер — 0")
	# 44,1 кГц кусками по 1000 кадров: дробный шаг переносится между вызовами
	var e2 := Voice.Encoder.new()
	var total := 0
	for k in 9:
		total += e2.push(_tone(1000, 44100, 400, 0.5, k * 1000), 44100).size()
	eq(total, int(9000.0 / 44100.0 * Voice.RATE) / Voice.FRAME, "9000 кадров 44,1 кГц — 10 пакетов")
	eq(e2.seq, total, "номер растёт на пакет")
	e2.seq = 65535
	var wrap := e2.push(_tone(5600, 44100, 400, 0.5), 44100)
	eq(wrap[0].decode_u16(0), 65535, "последний номер")
	eq(wrap[1].decode_u16(0), 0, "после 65535 — 0")


func test_encoder_keeps_speech_and_cuts_high() -> void:
	var e := Voice.Encoder.new()
	var p := e.push(_tone(4800, 48000, 400, 0.5), 48000)
	eq(p.size(), 5, "100 мс — пять пакетов")
	near(e.level, 0.5 / sqrt(2.0), 0.03, "тон 400 Гц: уровень как у входа")
	var d := PackedFloat32Array()
	for i in Voice.FRAME:
		d.append(Voice.decode_sample(p[4][Voice.HEAD + i]))
	near(Voice.rms(d), e.level, 0.01, "уровень пакета — по тому, что уйдёт в сеть")
	var hi := Voice.Encoder.new()
	hi.push(_tone(4800, 48000, 12000, 0.5), 48000)
	ok(hi.level < 0.5 / sqrt(2.0) * 0.3, "12 кГц срезано окном понижения: %.3f" % hi.level)
	var quiet := Voice.Encoder.new()
	quiet.push(_tone(960, 48000, 400, 0.0), 48000)
	eq(quiet.level, 0.0, "тишина — уровень 0")


func test_gate_holds_word_end() -> void:
	var g := Voice.Gate.new()
	ok(not g.update(0.005, 0.02), "фон ниже порога — молчит")
	ok(g.update(0.1, 0.02), "речь — открыто")
	var t := 0.0
	while t < Voice.GATE_HOLD - 0.05:
		ok(g.update(0.0, 0.02), "конец слова держится (%.2f с)" % t)
		t += 0.02
	g.update(0.0, 0.1)
	ok(not g.open, "после %.1f с тишины — закрыто" % Voice.GATE_HOLD)


func test_decoder_waits_delay_then_plays_in_order() -> void:
	var d := Voice.Decoder.new()
	d.push(_packet(10, 0.3))
	d.push(_packet(12, 0.5))
	eq(_frames_of(d, 1), [0.0] as Array[float], "двух пакетов мало — тишина")
	ok(not d.playing(), "ещё ждёт")
	d.push(_packet(11, 0.4))
	eq(_frames_of(d, 4), [0.3, 0.4, 0.5, 0.0] as Array[float], "по номерам, не по приходу; кончились — тишина")
	ok(not d.playing(), "буфер пуст — ждёт новую передачу")
	eq(d.level, 0.0, "в тишине уровень 0")


func test_decoder_late_and_lost() -> void:
	var d := Voice.Decoder.new()
	for s in [100, 101, 102]:
		d.push(_packet(s, 0.2))
	d.push(_packet(104, 0.5))
	_frames_of(d, 2)
	d.push(_packet(100, 0.9))
	eq(d.late, 1, "уже сыгранный номер — мимо")
	eq(_frames_of(d, 3), [0.2, 0.0, 0.5] as Array[float], "103 не пришёл — тишина вместо него")
	eq(d.lost, 1, "пропажа посчитана")
	near(d.level, Voice.decode_sample(Voice.encode_sample(0.5)), 1e-6, "уровень звучащего кадра")
	d.push(_packet(103, 0.9))
	eq(d.buffered(), 0, "пропавший, пришедший после своего места, не играет")


func test_decoder_seq_wrap_and_overflow() -> void:
	var d := Voice.Decoder.new()
	for s in [65534, 65535, 0, 1]:
		d.push(_packet(s, 0.1 * (s % 7 + 1)))
	eq(_frames_of(d, 4), [0.1, 0.2, 0.1, 0.2] as Array[float], "65534, 65535, 0, 1 — подряд")
	var f := Voice.Decoder.new()
	for s in Voice.MAX_BUF + 5:
		f.push(_packet(s, 0.1))
	eq(f.buffered(), Voice.MAX_BUF, "больше 200 мс не копим")
	eq(f.late, 5, "самые старые выброшены")
	_frames_of(f, 1)
	eq(f.lost, 0, "играет с самого старого из оставшихся, без пропусков")


func test_decoder_new_run_any_seq() -> void:
	var d := Voice.Decoder.new()
	for s in [500, 501, 502]:
		d.push(_packet(s, 0.3))
	_frames_of(d, 5)
	ok(not d.playing(), "передача кончилась")
	for s in [0, 1, 2]:
		d.push(_packet(s, 0.4))
	eq(_frames_of(d, 1), [0.4] as Array[float], "гость переподключился — номера с нуля играют")
	eq(d.late, 0, "и не считаются опоздавшими")


func test_round_trip_keeps_pitch() -> void:
	var e := Voice.Encoder.new()
	var d := Voice.Decoder.new()
	for p in e.push(_tone(48000 / 5, 48000, 400, 0.5), 48000):
		d.push(p)
	var out := d.pull(48000 / 10, 48000)
	var cross := 0
	var sum := 0.0
	for i in range(1, out.size()):
		sum += out[i].x * out[i].x
		if signf(out[i].x) != signf(out[i - 1].x) and out[i].x != 0.0:
			cross += 1
	near(float(cross), 80.0, 4.0, "100 мс тона 400 Гц — около 80 переходов через ноль")
	near(sqrt(sum / (out.size() - 1)), 0.5 / sqrt(2.0), 0.04, "громкость сохранилась")
	ok(d.playing(), "играет")


func test_room_per_speaker() -> void:   # голоса товарищей у слушателя: свой Decoder на место, уровень для Radio.heard
	var r := Voice.Room.new()
	var pk: Array = []
	for i in Voice.DELAY:
		pk.append([2, _packet(i, 0.5)])
		pk.append([1, _packet(100 + i, 0.1)])
	pk.append(["мусор"])
	r.take(pk)
	eq(r.decoders.size(), 2, "два говорящих")
	eq(r.talking(), [] as Array[int], "буфер набран, но ещё не играет")
	r.decoder(1).pull(Voice.FRAME + 1, Voice.RATE)
	r.decoder(2).pull(Voice.FRAME + 1, Voice.RATE)
	eq(r.talking(), [1, 2] as Array[int])
	ok(r.level(2) > r.level(1), "громче — выше уровень")
	eq(r.level(3), 0.0, "чужого нет — тишина")
	r.forget(2)
	eq(r.talking(), [1] as Array[int], "ушёл — забыт")
