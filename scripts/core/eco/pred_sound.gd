class_name EcoPredSound
extends RefCounted
## Голос серпохвоста SND-008 (#1054): щелчки поиска, рык броска, укус корпуса, уход после разряда. Здесь — файлы,
## громкости и выбор звука по режиму (`EcoPred.Mode`) и укусу (`EcoPred.Pred.bit_at`); играет `PredView` двумя
## плеерами `AudioStreamPlayer3D` у каждого зверя на шине «Мир» (`SoundMix.WORLD`). По правилу карты `docs/zvuk.md`
## хищника слышно раньше, чем видно (`EcoPredLook.HIDE_FAR`). У гостя сети — режим его мира, существ рядом ставит
## кадр хоста. Приёмка — `docs/zvuk/SND-008.md`.

const CLICK := "res://audio/world/pred-click.wav"
const ROAR := "res://audio/world/pred-roar.wav"
const JAW := "res://audio/world/pred-jaw.wav"
const FLEE := "res://audio/world/pred-flee.wav"
const FILES: Array[String] = [CLICK, ROAR, JAW, FLEE]

## Щелчки — пока ищет (HUNT, INVESTIGATE): сразу при входе в режим, потом раз в CLICK_MIN…CLICK_MAX с.
const CLICK_MIN := 3.0
const CLICK_MAX := 6.0
## Дальность (м): щелчки — до 60 м по заказу, бросок, укус и уход — громче, слышны дальше.
const CLICK_FAR := 60.0
const LOUD_FAR := 80.0
## Громкость (дБ на плеере, в файлах уже −24/−19,5/−20 LUFS): щелчки тише всего — звучат всю охоту, рык — громче
## всех звуков мира, но тише сирены тревоги (`alarm-siren`, шина «Корабль»).
const CLICK_DB := -2.0
const LOUD_DB := 0.0
## В полную громкость ближе (м) — зверь шестиметровый, звук идёт от всего тела.
const UNIT := 8.0
## Вода глушит верха с расстоянием (`attenuation_filter_*`): дальше — глуше.
const MUFFLE_HZ := 2500.0
const MUFFLE_DB := -18.0
## Укус старше этого (с) уже не звучит: зверь стоял вдали или мир догнал после паузы.
const JAW_LATE := 1.0

enum Cue { NONE, CLICK, ROAR, JAW, FLEE }


## Что прозвучит у одного серпохвоста: помнит прошлый режим, отыгранный укус и время следующего щелчка.
class Call:
	extends RefCounted
	var mode := -1
	var bit_seen := -99.0
	var next_click := 0.0
	var clicks := 0
	var index := 0
	var who: EcoPred.Pred
	var last_t := -1e9

	func _init(i := 0) -> void:
		index = i

	## Звук в момент t (`Cue`): dist — до корабля, м. Дальше LOUD_FAR — молчит, но режим и укус запоминает (подплыв
	## ближе, старый бросок не отыграет). Первый вызов только запоминает — зверь, загруженный в броске, не рычит.
	func update(pr: EcoPred.Pred, t: float, dist: float) -> Cue:
		if mode < 0 or pr != who or t < last_t:   # новый забег — мир собран заново или время пошло с начала
			who = pr
			last_t = t
			mode = pr.mode
			bit_seen = pr.bit_at
			next_click = t + EcoPredSound.gap(index, 0)
			return Cue.NONE
		last_t = t
		var cue := Cue.NONE
		var entered := pr.mode != mode
		mode = pr.mode
		if pr.bit_at > bit_seen:
			bit_seen = pr.bit_at
			if t - pr.bit_at <= JAW_LATE:
				cue = Cue.JAW
		if cue == Cue.NONE and entered:
			if pr.mode == EcoPred.Mode.CHARGE:
				cue = Cue.ROAR
			elif pr.mode == EcoPred.Mode.FLEE:
				cue = Cue.FLEE
		if EcoPredSound.searching(pr.mode):
			if entered:
				next_click = t   # начал искать — щёлкает сразу
			if cue == Cue.NONE and t >= next_click:
				cue = Cue.CLICK
				clicks += 1
				next_click = t + EcoPredSound.gap(index, clicks)
		if dist > EcoPredSound.far_of(cue):
			return Cue.NONE
		return cue


## Ищет добычу или проверяет звук — щёлкает.
static func searching(m: int) -> bool:
	return m == EcoPred.Mode.HUNT or m == EcoPred.Mode.INVESTIGATE


## Пауза до следующего щелчка n у зверя i: CLICK_MIN…CLICK_MAX, детерминированно (хост и тест — одинаково).
static func gap(i: int, n: int) -> float:
	var h := fposmod(sin(float(i) * 12.9898 + float(n) * 78.233) * 43758.5453, 1.0)
	return lerpf(CLICK_MIN, CLICK_MAX, h)


## Дальше какого расстояния звук не слышен (м).
static func far_of(cue: Cue) -> float:
	return CLICK_FAR if cue == Cue.CLICK else LOUD_FAR


## Файл звука.
static func path_of(cue: Cue) -> String:
	match cue:
		Cue.CLICK:
			return CLICK
		Cue.ROAR:
			return ROAR
		Cue.JAW:
			return JAW
		Cue.FLEE:
			return FLEE
	return ""
