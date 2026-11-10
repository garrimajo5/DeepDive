class_name Searchlight
## Прожектор «Ковчега-7» (js/ship.js: SpotLight(0xe6fbff, 2.8, 120, 0.45) из-под носа с прицелом на (0, −10, −40) —
## вперёд и вниз на 18°) и видимый конус луча в воде (S.beam: открытый конус 0,3 → 13 м длиной 55 м, светлее у линзы).
## Дальность и размер конуса растут как √доли «Прожектор» в реакторе (не меньше половины), при доле 0 света нет.
## Кнопка «Свет» за штурвалом: горит — янтарная «Свет вкл», погашен — тусклое кольцо «Свет выкл».

## Прожектор в осях корабля: под носом, перед носовым окном.
const LAMP := Vector3(0.0, 0.8, -6.8)
const COLOR := Color("e6fbff")
## Ярче, чем в браузере (2,2 — у тестера пятна не было видно, #47): отмель под льдом светлая, свет складывается
## с рассеянным, а дальше 40 м его наполовину съедает туман.
const ENERGY := 10.0
## Энергия погашенного прожектора: свет не прячем, а почти гасим — набор огней на предметах один (issue #159).
## Не 0: свет с нулевой энергией движок может отбросить, и шейдеры опять соберутся вторым набором.
const DARK := 0.001
const SPOT_EDGE := 0.7                     ## SpotLight3D.spot_angle_attenuation: край конуса гаснет мягко
const ATTENUATION := 0.15                  ## SpotLight3D.spot_attenuation: свет почти не слабеет до конца дальности
const BASE_RANGE := 120.0
## Сдвиг тени по нормали (SpotLight3D.shadow_normal_bias, по умолчанию 1,0). Дно и бросает, и ловит тень прожектора;
## на склоне под скользящим лучом 1,0 даёт «акне» — частые светлые и тёмные полосы поперёк пятна (issue #489).
## 2,0 в кадре 05-turn-and-dive уже чисто, берём с запасом.
const SHADOW_NORMAL_BIAS := 2.5
const HALF_ANGLE := 0.45                   ## рад
## Наклон вниз 14°, а не 18° браузера (прицел (0, −10, −40)): из кресла пилота кромка пульта — ≈ 15° ниже
## горизонта, и при 18° середина пятна пряталась под ними (#47).
const PITCH := 14.0
const BEAM_LENGTH := 55.0
const BEAM_TIP := 0.3
const BEAM_END := 13.0
const BEAM_COLOR := Color(0.81, 0.965, 1.0, 0.06)   ## складывается с водой
const BUTTON_ON := Color(1.0, 0.74, 0.32, 0.9)      ## янтарь
const BUTTON_OFF := Color(0.75, 0.95, 1.0, 0.3)
## Рисунок прожектора по ART-062 (`docs/concept-art/prozhektor.md`): маска пятна в `SpotLight3D.light_projector`
## (проектор работает только с тенями — тени у прожектора, кастеры — мир) и поле взвеси в конусе луча.
const MASK := "res://textures/prozhektor/maska.png"   ## RGBA 512², каждый канал = L, A = 1
const FIELD := "res://textures/prozhektor/luch.png"   ## L8 256×512: U — поперёк, V — вдоль луча
const DENSITY_BASE := 0.28                            ## плотность луча 0,28 + 0,72·поле
const DRIFT := Vector2(0.006, -0.014)                 ## дрейф поля, 1/с: V −0,014 ≈ 0,77 м/с к лампе
const SILT_DIM := 0.25                                ## в иле плотность × (1 − 0,25·k)


## Наклон луча вниз от горизонта, градусы.
static func pitch_deg() -> float:
	return PITCH


## Половина угла конуса для SpotLight3D.spot_angle, градусы (≈ 25,8°).
static func spot_angle_deg() -> float:
	return rad_to_deg(HALF_ANGLE)


static func lit(on: bool, k: float) -> bool:
	return on and k > 0.0


## Масштаб луча от доли k: √max(0,25; k); при k = 0 — 0.
static func scale(k: float) -> float:
	return 0.0 if k <= 0.0 else sqrt(maxf(0.25, k))


static func range_m(k: float) -> float:
	return BASE_RANGE * scale(k)


## Яркость конуса вдоль луча: t = 0 у линзы, 1 — на конце. У самой линзы конус гаснет (первые 12 %):
## из кресла пилот смотрит вдоль луча, и яркое начало конуса иначе видно кольцом посреди окна.
static func beam_shade(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var k := 1.0 - t
	return (k * k * 0.9 + 0.1 * k) * HashNoise.smooth(0.0, 0.12, t)


## Плотность луча по полю взвеси (0…1) и илу k (0…1).
static func density(field: float, silt_k: float) -> float:
	return (DENSITY_BASE + (1.0 - DENSITY_BASE) * field) * (1.0 - SILT_DIM * silt_k)


## UV поля в конусе (локальные оси луча, конус вдоль −Z): U — угол вокруг оси, V — доля длины; дрейф по времени.
static func beam_uv(p: Vector3, t: float = 0.0) -> Vector2:
	var u := atan2(p.y, p.x) / TAU + 0.5
	var v := clampf(-p.z / BEAM_LENGTH, 0.0, 1.0)
	return Vector2(u, v) + DRIFT * t


## Сколько ила вокруг (Silt.k) по укорочению луча reach = Silt.beam_k(): ил укорачивает луч один раз (в длине конуса),
## а здесь — только для плотности.
static func silt_k(reach: float) -> float:
	return clampf((1.0 - reach) / (1.0 - Silt.BEAM_K), 0.0, 1.0)


static func button_label(on: bool) -> String:
	return "Свет вкл" if on else "Свет выкл"


## Где луч касается дна: от точки p по лучу вниз на down_deg при курсе yaw (нос в (−sin yaw, 0, −cos yaw)).
## Расстояние до дна, м, или −1, если дна нет ближе max_dist.
static func floor_hit(p: Vector3, yaw: float, down_deg: float, max_dist: float, step: float = 0.25) -> float:
	var a := deg_to_rad(down_deg)
	var d := Vector3(-sin(yaw) * cos(a), -sin(a), -cos(yaw) * cos(a))
	var t := step
	while t <= max_dist:
		var q := p + d * t
		if q.y <= Seabed.height(q.x, q.z):
			return t
		t += step
	return -1.0


## Меш видимого конуса вдоль −Z (вперёд), с цветом вершин по beam_shade. Лицевая сторона наружу, но рисуется с обеих.
static func beam_arrays(segments: int = 24, rings: int = 12) -> Array:
	var n := segments + 1
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	var slope := (BEAM_END - BEAM_TIP) / BEAM_LENGTH   # нормаль стенки конуса: наружу и немного назад
	for j in rings + 1:
		var t := float(j) / rings
		var r := lerpf(BEAM_TIP, BEAM_END, t)
		var v := beam_shade(t)
		for i in n:
			var a := float(i) / segments * TAU
			pos.append(Vector3(cos(a) * r, sin(a) * r, -t * BEAM_LENGTH))
			nor.append(Vector3(cos(a), sin(a), slope).normalized())
			col.append(Color(v, v, v))
	var idx := PackedInt32Array()
	for j in rings:
		for i in segments:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nor
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	return arr
