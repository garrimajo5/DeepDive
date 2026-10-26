class_name HullSound
extends RefCounted
## Разовые звуки корабля SND-002 (#656): импульс сонара, удары по корпусу (три разновидности) и скрежет о дно.
## Здесь — какие файлы, какой удар звучит и насколько громко; играет `scripts/game/ship_sounds.gd` (`main.ship_sounds`)
## на шине «Корабль». Сигналы — `Main.ping_sonar` (импульс прошёл), `Main._on_hit` (`Vitals.hit_taken`) и удар о лёд
## (`Helm.Ship.knock`). Удары — на столкновения с разными объектами (#656): существо — по тому, откуда бьёт (`side`),
## дно — удар снизу со скрежетом хвостом, лёд — прямой удар без урона.

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
const SCRAPE_TAIL_DB := -10.0   ## скрежет под ударом о дно — хвостом, тише удара
const ICE_KNOCK := 1.2      ## м/с вверх: с такой скорости упор в лёд — удар (ниже — молча)
const ICE_SOFT_DB := -14.0  ## удар о лёд на ICE_KNOCK
const ICE_DB := -4.0        ## на полном подъёме (Helm.Ship.CLIMB)

enum Side { FRONT, SIDE, BELOW }   ## индексы HITS: прямой, косой, снизу
const BELOW_Y := -1.2       ## м ниже центра корабля — удар снизу
const FRONT_COS := 0.8      ## cos угла от носа (≈ 37°) — прямой удар


## Громкость удара по доле корпуса: 1 % — HIT_SOFT_DB, HIT_FULL % и больше — HIT_DB.
static func hit_db(percent: int) -> float:
	var t := clampf(float(percent - 1) / float(HIT_FULL - 1), 0.0, 1.0)
	return lerpf(HIT_SOFT_DB, HIT_DB, t)


## Откуда удар: local — точка удара в осях корабля (нос −Z, правый борт +X, y вверх; `Main.hit_local`).
static func side(local: Vector3) -> int:
	if local.y < BELOW_Y:
		return Side.BELOW
	var flat := Vector2(local.x, local.z)
	if flat.length() > 0.01 and -flat.normalized().y >= FRONT_COS:
		return Side.FRONT
	return Side.SIDE


## Какой из HITS звучит. Удар о дно ("scrape") — снизу. Существо — по стороне удара at (side); точки нет (at —
## пустой Variant) — удары чередуются по счётчику n, подряд одинаковых нет.
static func hit_index(kind: String, n: int, at: Variant = null) -> int:
	if kind == "scrape":
		return Side.BELOW
	if at is Vector3:
		return side(at)
	return posmod(n, HITS.size())


## Звук на удар: путь и громкость; tail — скрежет под ударом (удар о дно), пусто — без него.
static func for_hit(percent: int, kind: String, n: int, at: Variant = null) -> Dictionary:
	var d := {"path": HITS[hit_index(kind, n, at)], "db": hit_db(percent), "tail": ""}
	if kind == "scrape":
		d["tail"] = SCRAPE
		d["tail_db"] = SCRAPE_TAIL_DB
	return d


## Упор в лёд снизу со скоростью vy м/с: громкость прямого удара; меньше ICE_KNOCK — NAN (молча).
static func ice_db(vy: float) -> float:
	if vy < ICE_KNOCK:
		return NAN
	return lerpf(ICE_SOFT_DB, ICE_DB, clampf((vy - ICE_KNOCK) / (Helm.Ship.CLIMB - ICE_KNOCK), 0.0, 1.0))
