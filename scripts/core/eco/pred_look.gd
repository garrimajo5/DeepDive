class_name EcoPredLook
extends RefCounted
## Как двигается серпохвост в сцене: модель MOD-011 на скелете ANIM-001 (`models/serpohvost-anim.glb`,
## `docs/concept-art/serpohvost.md`). Тело — по курсу мира (`EcoPred.turn`), клипы на месте: плавание `Swim` и бросок
## `SwimFast` смешиваются по скорости, `Bite` — пасть у корабля в броске, у добычи в охоте и пока ест (жуёт),
## `TailStrike` — вертикальный удар серпом сразу после укуса корпуса. Переходы ANIM-005 (#1753, #1766): `Coil` —
## взвод в начале броска, `Recoil` — отход, когда удар серпом гаснет, `Hover` — замер (`EcoPred.Mode.ALERT`) плавно
## поверх плавания, `BendL`/`BendR` — хвост дугой в повороте по крену тела. Только числа и выбор клипов, без узлов:
## рисует PredView. Модель смотрит головой в −Z.

## Модель художника на скелете (10 костей, 9 клипов: ANIM-001 и ANIM-005).
const RIG_GLB := "res://models/serpohvost-anim.glb"
const SWIM := "Swim"
const SWIM_FAST := "SwimFast"
const BITE := "Bite"
const STRIKE := "TailStrike"
const RECOIL := "Recoil"
const HOVER := "Hover"
const COIL := "Coil"
const BEND_L := "BendL"
const BEND_R := "BendR"
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
## Удар после укуса виден, если укус не старше (с) — длина TailStrike (ANIM-005, #1766: 0,9 с; было 0,6 — ANIM-001);
## старый укус (новый зверь в кадре) не играет.
const STRIKE_TIME := 0.9
## Отход Recoil (1,0 с) начинается, когда удар серпом начал гаснуть: удар уходит в отход смешиванием FADE_OUT.
const RECOIL_AT := STRIKE_TIME - FADE_OUT
const RECOIL_TIME := 1.0
## Отход входит и выходит дольше удара: его концы — нейтраль (Swim на 0 с), а волна под ним в своей фазе, и за
## FADE_OUT хвост перескакивал к ней (кончик хвоста 54–56 м/с² у конца отхода, `tools/pred_jerk.gd`).
const RECOIL_FADE := 0.4
## Отход двигает голову, тело и плавники; хвост продолжает волну плавания — две волны поверх друг друга
## смешиванием давали кончику хвоста 99 % 34 м/с² против 27 (`tools/pred_jerk.gd`).
const RECOIL_BONES: Array[String] = ["Body", "Jaw", "FinFrontL", "FinFrontR", "FinRearL", "FinRearR"]
## Замер Hover набирает вес от 0 до 1 (и сбрасывает) за HOVER_IN с по smoothstep — без скачка позы и без излома
## скорости на концах.
const HOVER_IN := 0.6
## Изгиб в повороте: вес позы BendL/BendR по крену тела (EcoPred.Pred.bank / BANK_MAX), не больше BEND_W — хвост
## и в повороте машет. Крен уже сглажен (EcoPred.BANK_FOLLOW), вес за ним не прыгает. Только хвост и передние
## плавники (BEND_BONES): тело и пасть — от плавания.
const BEND_W := 0.6
## Вес изгиба догоняет крен ещё одним сглаживанием с постоянной BEND_TAU (с): без него — и с ровным пределом
## скорости веса (излом на концах) — хвост в развороте отхода дёргался (кончик хвоста 99 % 27 → 31 м/с²,
## `tools/pred_jerk.gd`).
const BEND_TAU := 0.4
const BEND_BONES: Array[String] = ["Tail01", "Tail02", "Tail03", "FinFrontL", "FinFrontR"]
## Дальше от корабля (м) — без смены клипов: только плавание (LOD).
const CUE_FAR := 80.0
## Дальше ANIM_FAR (м) скелет считается реже: раз в ANIM_FAR_STEP (с) набранным временем — зверь в тумане
## (как дальние стаи, EcoFish.FAR), пять поз в секунду там не видно (issue #850).
const ANIM_FAR := 100.0
const ANIM_FAR_STEP := 0.2
## Дальше HIDE_FAR (м) зверь спрятан, как гротовик и эхоловец (GrotView.FAR): не рисуется, скелет стоит.
const HIDE_FAR := 160.0
## Набранное время отдаётся скелету разом не длиннее (с): фаза плавания вдали не важна, а длинный шаг дерева дорог.
const LAG_MAX := 1.0
## «Экономно» (Б6, `PredView.set_lite`) скелет не прореживает: раньше уже с 25 м поза шла раз в 0,1 с, дальше 60 м —
## раз в 0,2 с, и хвост в луче (до Searchlight.BASE_RANGE) дёргался (#1753: кончик хвоста 99 % ≈ 200 м/с² против 13,
## `tools/pred_jerk.gd lite`), а три скелета по 10 костей — копейки. Пороги те же, что на «Обычно».
## «Дыхание» (Б3, `breath`): зверь качает воду жабрами — тело шире на ± BREATH_W и выше на ± BREATH_H за BREATH_T с
## (ритм ± BREATH_SPREAD и фаза — у каждого свои, `EcoVary`); длина та же — пасть и серп на месте. В броске (доля
## SwimFast, `swim_mix`) вода идёт сквозь жабры сама — размах гаснет вместе с ростом смеси, без скачка. По времени
## мира (у гостя то же); масштаб корня модели — даром, и на «Экономно».
const BREATH_T := 4.0
const BREATH_W := 0.035
const BREATH_H := 0.02
const BREATH_SPREAD := 0.2


## Куда смотрит голова сейчас (плавный курс EcoPred.turn).
static func forward(pr: EcoPred.Pred) -> Vector3:
	return pr.look


## Поворот тела: −Z модели смотрит в forward, спина вверх, в повороте — крен на EcoPred.Pred.bank вокруг оси тела
## (> 0 — левым боком вниз).
static func basis(pr: EcoPred.Pred) -> Basis:
	return Basis.looking_at(forward(pr), Vector3.UP) * Basis(Vector3.BACK, pr.bank)


## Доля дыхания зверя в момент t: −1…1 · размах; в броске (swim_mix → 1) — 0.
static func breath(pr: EcoPred.Pred, t: float) -> float:
	var rate := EcoVary.spread(pr.index, EcoVary.RATE, BREATH_SPREAD)
	var phase := EcoVary.unit(pr.index, EcoVary.SHADE) * TAU
	return sin(t * TAU / BREATH_T * rate + phase) * (1.0 - swim_mix(pr))


## Множитель размера тела по доле дыхания: шире и выше, длина (ось −Z модели) та же.
static func breath_scale(k: float) -> Vector3:
	return Vector3(1.0 + BREATH_W * k, 1.0 + BREATH_H * k, 1.0)


## Доля броска в смеси плавания 0…1: 0 — Swim, 1 — SwimFast.
static func swim_mix(pr: EcoPred.Pred) -> float:
	return clampf((pr.agent.v.length() - MIX_FROM) / (MIX_TO - MIX_FROM), 0.0, 1.0)


## Сколько циклов плавания в секунду: от 1/2,4 (Swim) к 1/1,2 (SwimFast) по смеси, медленнее патруля — реже.
static func swim_rate(pr: EcoPred.Pred) -> float:
	var rate := lerpf(1.0 / SWIM_LEN, 1.0 / SWIM_FAST_LEN, swim_mix(pr))
	var slow := clampf(pr.agent.v.length() / MIX_FROM, 0.0, 1.0)
	return rate * lerpf(REST_RATE_K, 1.0, slow)


## Вес изгиба в повороте −BEND_W…BEND_W: > 0 — поворот влево (крен левым боком вниз, BendL), < 0 — вправо (BendR).
static func bend(pr: EcoPred.Pred) -> float:
	return clampf(pr.bank / EcoPred.BANK_MAX, -1.0, 1.0) * BEND_W


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
	## Какой укус корпуса уже отыгран отходом Recoil.
	var recoil_seen := -99.0
	## Пасть закрылась — следующее сближение снова укусит.
	var armed := true
	## Режим зверя в прошлый вызов: бросок только начался — взвод Coil.
	var mode_was := -1
	## Вес замера Hover 0…1 (плавно, HOVER_IN; ровная доля — _hover_lin) и время прошлого вызова.
	var hover := 0.0
	var _hover_lin := 0.0
	## Вес изгиба −BEND_W…BEND_W (плавно, BEND_TAU): > 0 — BendL.
	var bend := 0.0
	var _t := -1.0

	## Что запустить в момент t: {"bite", "strike", "coil", "recoil": bool}; вес замера — в hover. far — зверь
	## дальше CUE_FAR: клипы не меняются, но события запоминаются (подплыв ближе, старый укус не отыграет).
	func update(pr: EcoPred.Pred, ship: Vector3, t: float, far := false) -> Dictionary:
		var out := {"bite": false, "strike": false, "coil": false, "recoil": false}
		var dt := clampf(t - _t, 0.0, 0.5) if _t >= 0.0 else 0.0
		_t = t
		var want := 1.0 if pr.mode == EcoPred.Mode.ALERT else 0.0
		_hover_lin = want if far else move_toward(_hover_lin, want, dt / HOVER_IN)
		hover = smoothstep(0.0, 1.0, _hover_lin)
		var turn := EcoPredLook.bend(pr)
		bend = turn if far else lerpf(bend, turn, 1.0 - exp(-dt / BEND_TAU))
		if pr.mode == EcoPred.Mode.CHARGE and mode_was != EcoPred.Mode.CHARGE and mode_was >= 0:
			out["coil"] = not far
		mode_was = pr.mode
		if pr.bit_at > strike_seen:
			strike_seen = pr.bit_at
			out["strike"] = not far and t - pr.bit_at < STRIKE_TIME and t >= pr.bit_at
		if pr.bit_at > recoil_seen and t >= pr.bit_at + RECOIL_AT:
			recoil_seen = pr.bit_at
			out["recoil"] = not far and t - pr.bit_at - RECOIL_AT < RECOIL_TIME * 0.5
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


## Часы скелета одного зверя (LOD анимации, issue #850): вблизи — каждый кадр, вдали — реже набранным временем,
## спрятанный — стоит, а пропущенное (не больше LAG_MAX) отдаёт, когда снова покажется.
class Clock:
	extends RefCounted
	## Пропущенное время, ещё не отданное дереву анимации (с).
	var lag := 0.0

	## Сколько времени отдать дереву анимации в этот кадр: dt — шаг кадра, dist — до корабля (м); 0 — дерево не трогать.
	## lite — «Экономно»: с #1753 шаг тот же (параметр оставлен для вызовов).
	func tick(dt: float, dist: float, lite := false) -> float:
		lag = minf(lag + dt, LAG_MAX)
		if dist > HIDE_FAR or lag < step_at(dist, lite) - 1e-6 or lag <= 0.0:
			return 0.0
		return flush()

	## Отдать всё набранное сразу (разовый клип не ждёт следующей позы).
	func flush() -> float:
		var out := lag
		lag = 0.0
		return out

	## Не чаще какого шага (с) меняется поза на расстоянии dist; 0 — каждый кадр.
	static func step_at(dist: float, _lite := false) -> float:
		if dist > ANIM_FAR:
			return ANIM_FAR_STEP
		return 0.0
