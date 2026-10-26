class_name HullSound
extends RefCounted
## Разовые звуки корабля SND-002 (#656): импульс сонара, удары по корпусу (три разновидности) и скрежет о дно.
## Здесь — какие файлы, какой удар звучит и насколько громко; играет `scripts/game/ship_sounds.gd` (`main.ship_sounds`)
## на шине «Корабль». Сигналы — `Main.ping_sonar` (импульс прошёл) и `Main._on_hit` (`Vitals.hit_taken`).

const PING := "res://audio/ship/sonar-ping.wav"
## Прямой, косой и снизу (SND-002: hull-hit-1-2, 2-1, 3-1).
const HITS: Array[String] = ["res://audio/ship/hull-hit-1.wav", "res://audio/ship/hull-hit-2.wav",
		"res://audio/ship/hull-hit-3.wav"]
const SCRAPE := "res://audio/ship/hull-scrape.wav"

const PING_DB := -6.0       ## импульс — заметно, но под гулом и тревогой
const JAM_DB := -14.0       ## импульс завяз в иле — глухо (пока нет своего sonar-jam)
const HIT_DB := 0.0         ## сильный удар — в полную
const HIT_SOFT_DB := -12.0  ## слабый удар (1 %) — тише на 12 дБ
const HIT_FULL := 15        ## с этой доли корпуса удар — в полную
const SCRAPE_DB := -4.0


## Громкость удара по доле корпуса: 1 % — HIT_SOFT_DB, HIT_FULL % и больше — HIT_DB.
static func hit_db(percent: int) -> float:
	var t := clampf(float(percent - 1) / float(HIT_FULL - 1), 0.0, 1.0)
	return lerpf(HIT_SOFT_DB, HIT_DB, t)


## Какой из HITS звучит: удары чередуются по счётчику n (прямой, косой, снизу), подряд одинаковых нет — откуда бьёт
## существо, мир пока не сообщает. Удар о дно — не из HITS, его звук — SCRAPE (−1).
static func hit_index(kind: String, n: int) -> int:
	if kind == "scrape":
		return -1
	return posmod(n, HITS.size())


## Звук на удар: путь и громкость.
static func for_hit(percent: int, kind: String, n: int) -> Dictionary:
	var i := hit_index(kind, n)
	if i < 0:
		return {"path": SCRAPE, "db": SCRAPE_DB}
	return {"path": HITS[i], "db": hit_db(percent)}
