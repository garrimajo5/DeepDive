class_name EcoPredLook
extends RefCounted
## Как двигается серпохвост в сцене: модель MOD-011 на скелете ANIM-001 (`models/serpohvost-anim.glb`,
## `docs/concept-art/serpohvost.md`). Тело — по курсу мира (`EcoPred.turn`), клипы на месте: плавание `Swim` и бросок
## `SwimFast` смешиваются по скорости, `Bite` — пасть у корабля в броске, у добычи в охоте и пока ест (жуёт),
## `TailStrike` — вертикальный удар серпом сразу после укуса корпуса. Только числа и выбор клипов, без узлов:
## рисует PredView. Модель смотрит головой в −Z.

## Модель художника на скелете (10 костей, 4 клипа).
const RIG_GLB := "res://models/serpohvost-anim.glb"
const SWIM := "Swim"
const SWIM_FAST := "SwimFast"
const BITE := "Bite"
const STRIKE := "TailStrike"
## Длина циклов плавания (с) — у ANIM-001 бросок ровно вдвое чаще.
const SWIM_LEN := 2.4
const SWIM_FAST_LEN := 1.2
## Кости, которые двигает укус поверх плавания: только челюсть — хвост в укусе продолжает волну.
const BITE_BONES: Array[String] = ["Jaw"]
## Наклон тела вверх-вниз не больше (рад).
const PITCH_MAX := deg_to_rad(30.0)  # тот же предел — EcoPred.PITCH_MAX (курс тела)
## Смесь плавания: до этой скорости — только Swim, с этой — только SwimFast (м/с: патруль и бегство EcoPred).
const MIX_FROM := EcoPred.PATROL_SPEED
const MIX_TO := EcoPred.FLEE_SPEED
## Медленнее патруля волна реже: в покое — эта доля частоты Swim.
const REST_RATE_K := 0.5
## Вход и выход разовых клипов смешиванием (с) — ANIM-001: позы укуса и удара кончаются нейтральной.
const FADE_IN := 0.12
const FADE_OUT := 0.2
## Укус в броске начинается раньше касания: при 9,5 м/с за пик пасти (~0,4 с) — от 8,5 м (EcoPred.BITE_DIST) до 12 м.
const BITE_SHIP_DIST := 12.0
## У добычи в охоте пасть раскрывается ближе (м).
const BITE_PREY_DIST := 6.0
## Пока ест — жуёт: новый укус не чаще (с).
const CHEW_EVERY := 1.5
## Удар после укуса виден, если укус не старше (с) — длина TailStrike; старый укус (новый зверь в кадре) не играет.
const STRIKE_TIME := 0.6
## Дальше от корабля (м) — без смены клипов: только плавание (LOD).
const CUE_FAR := 80.0


## Куда смотрит голова сейчас (плавный курс EcoPred.turn).
static func forward(pr: EcoPred.Pred) -> Vector3:
	return pr.look


## Поворот тела: −Z модели смотрит в forward, спина вверх, в повороте — крен на EcoPred.Pred.bank вокруг оси тела
## (> 0 — левым боком вниз).
static func basis(pr: EcoPred.Pred) -> Basis:
	return Basis.looking_at(forward(pr), Vector3.UP) * Basis(Vector3.BACK, pr.bank)


## Доля броска в смеси плавания 0…1: 0 — Swim, 1 — SwimFast.
static func swim_mix(pr: EcoPred.Pred) -> float:
	return clampf((pr.agent.v.length() - MIX_FROM) / (MIX_TO - MIX_FROM), 0.0, 1.0)


## Сколько циклов плавания в секунду: от 1/2,4 (Swim) к 1/1,2 (SwimFast) по смеси, медленнее патруля — реже.
static func swim_rate(pr: EcoPred.Pred) -> float:
	var rate := lerpf(1.0 / SWIM_LEN, 1.0 / SWIM_FAST_LEN, swim_mix(pr))
	var slow := clampf(pr.agent.v.length() / MIX_FROM, 0.0, 1.0)
	return rate * lerpf(REST_RATE_K, 1.0, slow)


## Пасть пора раскрыть сейчас: в броске у корабля ship или в охоте у самой добычи.
static func jaw_close(pr: EcoPred.Pred, ship: Vector3) -> bool:
	match pr.mode:
		EcoPred.Mode.CHARGE:
			return pr.agent.distance_to(ship) < BITE_SHIP_DIST
		EcoPred.Mode.HUNT:
			return pr.prey != null and pr.agent.distance_to(pr.prey.agent.p) < BITE_PREY_DIST
	return false


## Когда какой разовый клип запустить — по одному на зверя. update говорит, что играть в этот кадр.
class Cues:
	extends RefCounted
	## Когда был последний укус-клип и какой укус корпуса (EcoPred.Pred.bit_at) уже отыгран ударом.
	var bite_at := -99.0
	var strike_seen := -99.0
	## Пасть закрылась — следующее сближение снова укусит.
	var armed := true

	## Что запустить в момент t: {"bite": bool, "strike": bool}. far — зверь дальше CUE_FAR: клипы не меняются,
	## но события запоминаются (подплыв ближе, старый укус не отыграет).
	func update(pr: EcoPred.Pred, ship: Vector3, t: float, far := false) -> Dictionary:
		var out := {"bite": false, "strike": false}
		if pr.bit_at > strike_seen:
			strike_seen = pr.bit_at
			out["strike"] = not far and t - pr.bit_at < STRIKE_TIME and t >= pr.bit_at
		var close := EcoPredLook.jaw_close(pr, ship)
		if close and armed:
			armed = false
			out["bite"] = true
		elif not close:
			armed = true
		if pr.mode == EcoPred.Mode.EAT and t - bite_at >= CHEW_EVERY:
			out["bite"] = true
		if far:
			out["bite"] = false
		elif out["bite"]:
			bite_at = t
		return out
