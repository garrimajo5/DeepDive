class_name WearDrops
extends RefCounted
## «Корабль устал» внутри по ART-074, частицы (docs/concept-art/ustalost-korpusa.md): капли с потолка у бортов мостика
## и машинного, редкие искры за фронтом пульта энергии, тонкий пар над корпусом вентиля. Всё — функция времени и потери
## прочности (`CabinWear.loss`), своего состояния нет: у гостя те же карточки по его часам и корпусу из кадра.
## 24 карточки (12 на «Экономно») — четыре группы по 6 (по 3): капли мостика, капли машинного, искры, пар.
## Рисует `scripts/game/wear_drops_view.gd` одним MultiMesh шейдером пара `shaders/steam.gdshader`, атлас
## `textures/ustalost/atlas.png` (4×4: 0–3 капля, 4–7 искра, 8–15 шлейф пара). Без огней.

const ATLAS := "res://textures/ustalost/atlas.png"
const COUNT := 24
const COUNT_LITE := 12
const HIDE_BELOW := 0.38      ## потеря меньше — MultiMesh скрыт (корпус ≥ 62 %)

enum Kind { DRIP, SPARK, STEAM }

# капли: падают с потолка у бортов, цикл 3,8 с, фазы через 1,713 с
const DRIP_CYCLE := 3.8
const DRIP_PHASE := 1.713
const DRIP_TOP := 3.05
const DRIP_BOTTOM := 0.25
const DRIP_SIZE := Vector2(0.028, 0.12)
const DRIP_X := [4.66, 2.72]                      ## у борта мостика и машинного
const DRIP_Z := [[-4.65, -0.35, 1.2], [14.7, 15.4, 18.8]]
const DRIP_LEFT_Z := 0.8   ## пятая капля мостика слева — мимо щитка разряда (−3,9; −0,5)
# искры: пакет раз в 9 с за фронтом пульта энергии, жизнь 0,16 с
const SPARK_AT := Vector3(-4.58, 0.38, -0.98)
const SPARK_EVERY := 9.0
const SPARK_LIFE := 0.16
const SPARK_SIZE := Vector2(0.18, 0.07)
const SPARK_GLOW := 0.2    ## эмиссия RGB × 1,2
# пар над корпусом вентиля
const STEAM_AT := Vector3(-2.92, 1.58, 17.2)
const STEAM_RISE := 0.48
const STEAM_DRIFT := 0.12
const STEAM_ALPHA := 0.11


## Одна карточка: центр в осях корабля, размер, кадр атласа first…first+span по доле age, альфа, свечение.
class Card:
	var kind := Kind.DRIP
	var pos := Vector3.ZERO
	var size := Vector2.ZERO
	var age := 0.0
	var first := 0
	var span := 0
	var alpha := 0.0
	var glow := 0.0


## Силы групп по потере 0…1 (капли с 62 % корпуса, пар с 52 %, искры с 38 %).
static func drip_k(loss: float) -> float:
	return smoothstep(0.38, 0.82, loss)


static func steam_k(loss: float) -> float:
	return smoothstep(0.48, 0.85, loss)


static func spark_k(loss: float) -> float:
	return smoothstep(0.62, 0.86, loss)


static func count(lite: bool) -> int:
	return COUNT_LITE if lite else COUNT


static func shown(loss: float) -> bool:
	return loss > HIDE_BELOW


## Карточка i из count(lite) в момент t при потере loss.
static func card(i: int, t: float, loss: float, lite: bool) -> Card:
	var per := 3 if lite else 6
	var group := i / per
	var index := i % per
	var side := -1.0 if index % 2 == 0 else 1.0
	var c := Card.new()
	if group < 2:   # капли: группа 0 — мостик, 1 — машинное
		c.kind = Kind.DRIP
		c.age = fposmod(t + float(index) * DRIP_PHASE, DRIP_CYCLE) / DRIP_CYCLE
		var z: float = DRIP_Z[group][index % 3]
		if group == 0 and index == 4:
			z = DRIP_LEFT_Z
		c.pos = Vector3(side * float(DRIP_X[group]), lerpf(DRIP_TOP, DRIP_BOTTOM, c.age), z)
		c.size = DRIP_SIZE
		c.first = 0
		c.span = 3
		c.alpha = 0.8 * drip_k(loss) * sin(PI * c.age)
	elif group == 2:   # искры: короткий пакет, карточки веером вниз
		c.kind = Kind.SPARK
		var phase := fposmod(t, SPARK_EVERY)
		c.age = clampf(phase / SPARK_LIFE, 0.0, 1.0)
		var fly := 0.04 * c.age
		c.pos = SPARK_AT + Vector3(index * 0.018 + side * fly, -index * 0.026 - fly, 0.0)
		c.size = SPARK_SIZE
		c.first = 4 + index % 4
		c.span = 0
		c.alpha = 0.8 * spark_k(loss) * (1.0 - phase / SPARK_LIFE) if phase < SPARK_LIFE else 0.0
		c.glow = SPARK_GLOW
	else:   # тонкий шлейф пара над вентилем
		c.kind = Kind.STEAM
		c.age = fposmod(t + float(index) * DRIP_PHASE, DRIP_CYCLE) / DRIP_CYCLE
		c.pos = STEAM_AT + Vector3(-side * STEAM_DRIFT * c.age, STEAM_RISE * c.age, 0.03 * sin(c.age * TAU + index))
		c.size = Vector2(0.12 + 0.13 * c.age, 0.26 + 0.3 * c.age)
		c.first = 8
		c.span = 7
		c.alpha = STEAM_ALPHA * steam_k(loss) * sin(PI * c.age)
	return c


## Все карточки кадра.
static func cards(t: float, loss: float, lite: bool) -> Array[Card]:
	var out: Array[Card] = []
	for i in count(lite):
		out.append(card(i, t, loss, lite))
	return out
