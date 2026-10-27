class_name EcoFernDust
extends RefCounted
## Муть у волнолиста (docs/grafika-plan-eco.md, Б3 «Мелочь жизни», «облачка и пузырьки от существ»): свёрнутые
## листья копят осевший ил. Луч прожектора разворачивает куст — раскрытие переходит UNFURL, и листья стряхивают ил:
## у кончика каждого второго листа (UNFURL_N облачков вразнобой за SPAN с) встаёт облачко. Под раскрытыми листьями
## открыты моллюски: спокойная стая светляков у куста (центр ближе EcoFern.CAME_R к вершине) клюёт их — раз в
## FEED_EVERY с (± RATE_SPREAD) у одного из моллюсков на дне поднимается маленькое облачко песка.
## Облачка те же, что у скребунов (EcoGrazerDust: стоят, где подняты, растут, поднимаются, уплывают по течению,
## тают; светлее в луче прожектора) — свой пул на POOL мест, цвет — зелёно-бурый ил в тон листа.
## Мир и его случай не меняются: что делает куст — по раскрытию между шагами и стаям рядом, разброс — хешем EcoVary;
## у гостя сети мир идёт сам (раскрытие то же), стаи — из кадра хоста, поэтому муть та же.
## Рисует FernView дочерним MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки,
## шейдеров не прибавилось. «Экономно» — общий выключатель мелочи жизни EcoGrazerDust.lite.

## Мест в пуле: луч раскрывает куртину из четырёх кустов по три облачка, и ещё клюют рыбы.
const POOL := 24
## Раскрытие переходит эту долю вверх — листья стряхивают ил.
const UNFURL := 0.5
## Облачков у кончиков (у каждого второго листа), вразнобой за SPAN с; непрозрачность и доля размера.
const UNFURL_N := 3
const SPAN := 0.4
const UNFURL_ALPHA := 0.55
const UNFURL_SCALE := 0.6
## Облачко у кончика — на этой доле длины листа (лист к кончику загнут, кончик тоньше).
const TIP := 0.85
const SCATTER := 0.12
## Рыбы клюют моллюсков: пауза (с), её разброс, непрозрачность и доля размера облачка; над дном (м).
const FEED_EVERY := 1.1
const RATE_SPREAD := 0.25
const FEED_ALPHA := 0.3
const FEED_SCALE := 0.3
const FEED_LIFT := 0.1
const SALT := 263
## Цвет: зелёно-бурый ил в тон листа (#3D9D91) — в темноте тусклый, в луче светлее, но не белый: на светлом песке
## бледная муть не видна.
const COLOR := Color(0.17, 0.21, 0.18)
const LIT := Color(0.25, 0.30, 0.26)

var dust := EcoGrazerDust.new(POOL)
var _open := PackedFloat32Array()
## Время следующего клевка у каждого куста (−INF — рыб нет).
var _next := PackedFloat32Array()
var _made := 0
var _last := -1e9


## Стая клюёт моллюсков куста fe: куст раскрыт (EcoFern.FEED_OPEN) и спокойная стая рядом (как зовёт EcoFern).
static func feeding(system: EcoFern, fe: EcoFern.Fern) -> bool:
	if fe.open <= EcoFern.FEED_OPEN or system.fish == null:
		return false
	for sh in system.fish.shoals:
		if sh.riding or sh.alarm > 0.0 or sh.alive < 3 or sh.leader():
			continue
		if sh.center.distance_to(fe.top) < EcoFern.CAME_R:
			return true
	return false


## Кончик листа j куста fe в момент t (по EcoFern.leaf_basis), с разбросом по ключу key.
static func tip(fe: EcoFern.Fern, j: int, t: float, key: int) -> Vector3:
	var at := fe.pos + EcoFern.leaf_basis(fe, j, t) * Vector3(0.0, EcoFern.LEAF_LEN * TIP, 0.0)
	return at + Vector3(EcoVary.unit(key, SALT) * 2.0 - 1.0, EcoVary.unit(key, SALT + 1) * 2.0 - 1.0,
			EcoVary.unit(key, SALT + 2) * 2.0 - 1.0) * SCATTER


## Шаг мути в момент t (время мира). ship — корабль: дальше EcoGrazerDust.NEAR — нет; ground — дно (моллюски).
func update(system: EcoFern, t: float, ship: Vector3, ground: Callable = Callable()) -> void:
	if system == null:
		return
	var n := system.ferns.size()
	if t < _last or _last < -1e8 or _open.size() != n:   # первый шаг или время пошло назад — запомнить
		_open.resize(n)
		_next.resize(n)
		for i in n:
			_open[i] = system.ferns[i].open
			_next[i] = -INF
		_last = t
		return
	_last = t
	for i in n:
		var fe := system.ferns[i]
		var was := _open[i]
		_open[i] = fe.open
		var near := not EcoGrazerDust.lite and fe.pos.distance_to(ship) <= EcoGrazerDust.NEAR
		if near and was < UNFURL and fe.open >= UNFURL:
			_unfurl(fe, t)
		if not feeding(system, fe):
			_next[i] = -INF
			continue
		if _next[i] == -INF:   # рыбы только подплыли — первый клевок не сразу
			_next[i] = t + FEED_EVERY * EcoVary.unit(_made * 16 + i, SALT + 3)
		if t < _next[i]:
			continue
		_made += 1
		var key := _made * 16 + i
		_next[i] = t + FEED_EVERY * EcoVary.spread(key, SALT + 4, RATE_SPREAD)
		if near:
			var p := EcoFern.shell_pos(fe, key % EcoFern.SHELLS, ground)
			dust.add(p + Vector3(0, FEED_LIFT, 0), t, FEED_ALPHA * EcoVary.spread(key, SALT + 5, 0.2), key,
					FEED_SCALE * EcoVary.spread(key, SALT + 6, 0.15))


## Листья стряхивают ил: облачко у кончика каждого второго листа, вразнобой за SPAN с.
func _unfurl(fe: EcoFern.Fern, t: float) -> void:
	for c in UNFURL_N:
		_made += 1
		var key := _made * 16 + fe.index
		var j := (c * EcoFern.LEAVES) / UNFURL_N + key % 2
		var born := t + SPAN * EcoVary.unit(key, SALT + 7)
		dust.add(tip(fe, j, t, key), born, UNFURL_ALPHA * EcoVary.spread(key, SALT + 8, 0.2), key,
				UNFURL_SCALE * EcoVary.spread(key, SALT + 9, 0.15))
