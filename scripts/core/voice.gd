class_name Voice
extends RefCounted
## Голос рации ART-041 по сети (#634; решение владельца 27.10 — встроенными средствами Godot, без библиотек):
## микрофон → моно 8 кГц, 8 бит μ-law, пакеты по 20 мс с номером (162 байта, ≈ 8 КБ/с на говорящего);
## у слушателя — буфер против рывков сети и обратно в частоту микшера.
## Здесь только числа без узлов: `Encoder` (кадры захвата → пакеты, уровень), `Gate` («По голосу»: речь или тишина),
## `Decoder` (пакеты → кадры проигрывателя, уровень для «активности» таблички). Захват `AudioEffectCapture`,
## Канал по сети — `NetLink.CH_VOICE` (`Host.send_voice`/`take_voice`, `Client.send_voice`/`take_voice`), голоса
## нескольких товарищей у слушателя — `Room`. Что уходит и что звучит за шаг — `Station` (захват → пакеты, «По голосу»,
## `link` для «Вас слышно», голоса → `Radio.heard`); узлы захвата `AudioEffectCapture` и проигрывателей
## `AudioStreamGenerator` — `scripts/game/voice_io.gd` (`main.voice_io`). Разрешение микрофона Android — следующая часть.

const RATE := 8000           ## частота голоса в сети, Гц
const FRAME := 160           ## отсчётов в пакете — 20 мс
const HEAD := 2              ## номер пакета, 16 бит
const SIZE := HEAD + FRAME   ## байт в пакете
const MU := 255.0
const GATE := 0.02           ## «По голосу»: уровень (СКЗ кадра), выше которого — речь
const GATE_HOLD := 0.3       ## речь держится после затихания, с — конец слова не обрезаем
const DELAY := 3             ## пакетов в буфере до начала проигрыша (60 мс)
const MAX_BUF := 10          ## больше — самые старые выбрасываем (200 мс), отставание не копится
const FADE := 0.9            ## затухание к нулю, когда пакетов нет, — без щелчка
const LINK_HOLD := 0.3       ## «Вас слышно» держится столько после последнего пакета захвата, с
const LEVEL_K := 4.0         ## СКЗ речи (≈ 0,05…0,25) → высота штрихов `Radio.heard` 0…1

static var _table := PackedFloat32Array()


## −1…1 → байт: знак — старший бит, модуль — 7 бит по закону μ (тихое точнее громкого).
static func encode_sample(x: float) -> int:
	var a := clampf(absf(x), 0.0, 1.0)
	var m := int(roundf(log(1.0 + MU * a) / log(1.0 + MU) * 127.0))
	return m | (128 if x < 0.0 and m > 0 else 0)


static func decode_sample(b: int) -> float:
	if _table.is_empty():
		_table.resize(256)
		for i in 256:
			var y := float(i & 127) / 127.0
			var a := (pow(1.0 + MU, y) - 1.0) / MU
			_table[i] = -a if i & 128 else a
	return _table[b & 255]


## СКЗ пакета (для «По голосу» по каждому пакету, не только по последнему).
static func packet_level(p: PackedByteArray) -> float:
	if p.size() != SIZE:
		return 0.0
	var sum := 0.0
	for i in FRAME:
		var v := decode_sample(p[HEAD + i])
		sum += v * v
	return sqrt(sum / FRAME)


## Номер `a` позже `b` с учётом перехода 65535 → 0.
static func after(a: int, b: int) -> bool:
	var d := (a - b) & 0xFFFF
	return d != 0 and d < 0x8000


static func rms(s: PackedFloat32Array) -> float:
	if s.is_empty():
		return 0.0
	var sum := 0.0
	for v in s:
		sum += v * v
	return sqrt(sum / s.size())


## Кадры захвата (стерео, частота микшера) → пакеты. Понижение частоты — среднее по окну шага (заодно срезает
## выше 4 кГц), дробный шаг переносится между вызовами: куски любой длины дают тот же поток.
class Encoder:
	extends RefCounted
	var seq := 0
	var level := 0.0             ## СКЗ последнего пакета
	var _sum := 0.0
	var _n := 0
	var _at := 0.0
	var _acc := PackedFloat32Array()

	func push(frames: PackedVector2Array, mix_rate: float) -> Array[PackedByteArray]:
		var out: Array[PackedByteArray] = []
		var step := mix_rate / float(Voice.RATE)
		for f in frames:
			_sum += (f.x + f.y) * 0.5
			_n += 1
			_at += 1.0
			if _at >= step:
				_at -= step
				_acc.append(_sum / _n)
				_sum = 0.0
				_n = 0
				if _acc.size() == Voice.FRAME:
					out.append(_pack())
		return out

	func _pack() -> PackedByteArray:
		var p := PackedByteArray()
		p.resize(Voice.SIZE)
		p.encode_u16(0, seq)
		for i in Voice.FRAME:
			p[Voice.HEAD + i] = Voice.encode_sample(_acc[i])
		level = Voice.rms(_acc)
		_acc.clear()
		seq = (seq + 1) & 0xFFFF
		return p

	## Начать заново (новая передача): недобранный кадр выбрасывается, номер идёт дальше.
	func reset() -> void:
		_sum = 0.0
		_n = 0
		_at = 0.0
		_acc.clear()
		level = 0.0


## «По голосу»: речь, пока уровень выше `GATE`, и ещё `GATE_HOLD` после.
class Gate:
	extends RefCounted
	var open := false
	var _quiet := 0.0

	func update(level: float, dt: float) -> bool:
		if level > Voice.GATE:
			open = true
			_quiet = 0.0
		elif open:
			_quiet += dt
			if _quiet >= Voice.GATE_HOLD:
				open = false
		return open


## Пакеты одного говорящего → кадры проигрывателя. Ждёт `DELAY` пакетов, играет по номерам; опоздавший — мимо,
## пропавший — тишина на 20 мс (`lost`), буфер пуст — затихает и снова ждёт `DELAY` (номера с любого места).
class Decoder:
	extends RefCounted
	var level := 0.0             ## СКЗ кадра, который сейчас звучит; тишина — 0
	var lost := 0                ## пропавших пакетов
	var late := 0                ## опоздавших и лишних, выброшенных
	var _buf := {}               ## номер → PackedFloat32Array
	var _next := -1              ## номер следующего к проигрышу
	var _playing := false
	var _cur := PackedFloat32Array()
	var _ci := 0
	var _a := 0.0
	var _b := 0.0
	var _pos := 0.0

	func playing() -> bool:
		return _playing

	func buffered() -> int:
		return _buf.size()

	func push(packet: PackedByteArray) -> void:
		if packet.size() != Voice.SIZE:
			return
		var seq := packet.decode_u16(0)
		if _next >= 0 and not Voice.after(seq, _next) and seq != _next:
			late += 1
			return
		if _buf.has(seq):
			return
		var s := PackedFloat32Array()
		s.resize(Voice.FRAME)
		for i in Voice.FRAME:
			s[i] = Voice.decode_sample(packet[Voice.HEAD + i])
		_buf[seq] = s
		while _buf.size() > Voice.MAX_BUF:
			var old := _oldest()
			_buf.erase(old)
			late += 1
			if _next >= 0 and not Voice.after(_next, old):
				_next = (old + 1) & 0xFFFF

	func _oldest() -> int:
		var o := -1
		for k in _buf:
			if o < 0 or Voice.after(o, k):
				o = k
		return o

	## Следующий отсчёт 8 кГц.
	func _sample() -> float:
		if _ci < _cur.size():
			_ci += 1
			return _cur[_ci - 1]
		if not _playing:
			if _buf.size() < Voice.DELAY:
				level = 0.0
				return _b * Voice.FADE
			_playing = true
			_next = _oldest()
		if _buf.is_empty():
			_playing = false
			_next = -1     ## новая передача может прийти с любым номером (гость переподключился)
			level = 0.0
			return _b * Voice.FADE
		if _buf.has(_next):
			_cur = _buf[_next]
			_buf.erase(_next)
		else:
			lost += 1
			_cur = PackedFloat32Array()
			_cur.resize(Voice.FRAME)
		_next = (_next + 1) & 0xFFFF
		level = Voice.rms(_cur)
		_ci = 1
		return _cur[0]

	## `count` кадров для проигрывателя на `mix_rate` (линейная интерполяция между отсчётами 8 кГц).
	func pull(count: int, mix_rate: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		out.resize(count)
		var step := float(Voice.RATE) / mix_rate
		for i in count:
			var v := lerpf(_a, _b, _pos)
			out[i] = Vector2(v, v)
			_pos += step
			while _pos >= 1.0:
				_pos -= 1.0
				_a = _b
				_b = _sample()
		return out


## Голоса товарищей у слушателя: по `Decoder` на место в экипаже. `take` — пакеты из `NetLink.take_voice`, `talking` —
## чьи голоса сейчас звучат (для `Radio.heard` с уровнем `level`), `forget` — товарищ ушёл.
class Room:
	extends RefCounted
	var decoders := {}           ## место в экипаже → Decoder

	func take(packets: Array) -> void:
		for e in packets:
			if e is Array and (e as Array).size() == 2 and e[1] is PackedByteArray:
				decoder(int(e[0])).push(e[1])

	func decoder(who: int) -> Decoder:
		if not decoders.has(who):
			decoders[who] = Decoder.new()
		return decoders[who]

	func level(who: int) -> float:
		return (decoders[who] as Decoder).level if decoders.has(who) else 0.0

	## Места, чей голос сейчас звучит (проигрывается и не тишина пропавшего пакета).
	func talking() -> Array[int]:
		var out: Array[int] = []
		for who: int in decoders:
			var d: Decoder = decoders[who]
			if d.playing() and d.level > 0.0:
				out.append(who)
		out.sort()
		return out

	func forget(who: int) -> void:
		decoders.erase(who)


## Голос игрока за шаг (рация ART-041): свой захват → пакеты в сеть, голоса товарищей → проигрыватели и `Radio.heard`.
## Без узлов: кадры захвата и число кадров проигрывателя даёт `VoiceIO`. «Нажать и держать» — уходит всё, пока
## `talk`; «По голосу» — только пакеты, где `Gate` открыт (тишина не идёт). `link` — захват даёт пакеты и есть куда
## слать: «Вас слышно» по `Radio.link`, в «По голосу» — и в паузах речи.
class Station:
	extends RefCounted
	var encoder := Encoder.new()
	var gate := Gate.new()
	var room := Room.new()
	var link := false
	var sent := 0                ## пакетов ушло (для теста и лога)
	var _since := 1.0e9          ## с последнего пакета захвата, с
	var _was := false

	## Кадры захвата за шаг → пакеты к отправке. talk — `Radio.wants()`, by_voice — режим «По голосу»,
	## online — есть куда слать (гость на борту или хост с гостями).
	func outgoing(frames: PackedVector2Array, mix_rate: float, dt: float, talk: bool, by_voice: bool,
			online: bool) -> Array[PackedByteArray]:
		var out: Array[PackedByteArray] = []
		if not talk:
			if _was:
				encoder.reset()
				gate.open = false
			_was = false
			_since = 1.0e9
			link = false
			return out
		_was = true
		var ps := encoder.push(frames, mix_rate)
		_since = 0.0 if not ps.is_empty() else _since + dt
		for p in ps:
			if not by_voice or gate.update(Voice.packet_level(p), float(Voice.FRAME) / Voice.RATE):
				out.append(p)
		link = online and _since <= Voice.LINK_HOLD
		if online:
			sent += out.size()
		else:
			out.clear()
		return out

	## Пакеты из `NetLink.take_voice` ([[место, пакет], …]).
	func incoming(packets: Array) -> void:
		room.take(packets)

	## `count` кадров проигрывателя голоса места who.
	func pull(who: int, count: int, mix_rate: float) -> PackedVector2Array:
		return room.decoder(who).pull(count, mix_rate)

	## Звучащие голоса: [[место, высота штрихов 0…1], …] для `Radio.heard`.
	func voices() -> Array:
		var out := []
		for who in room.talking():
			out.append([who, clampf(room.level(who) * Voice.LEVEL_K, 0.0, 1.0)])
		return out
