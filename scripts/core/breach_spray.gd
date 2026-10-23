class_name BreachSpray
extends RefCounted
## Частицы пробоины изнутри по ART-072 (`docs/concept-art/proboina-chastitsy.md`): струя из отверстия, брызги на воде,
## искры сварки и вспышка электрода. Логика без узлов: три пула в осях узла пробоины `BreachView.spot_node`
## (+Z — внутрь отсека, y — вверх, начало — точка на борту), путь, размер, альфа и кадр атласа — функции возраста.
## Случайных чисел нет: разброс частицы задаёт номер рождения (золотой угол и дробные доли). Рисует `BreachView`
## тремя MultiMesh с общим материалом (`shaders/breach_spray.gdshader`, атлас `textures/proboina/atlas.png`).

const ATLAS := "res://textures/proboina/atlas.png"
const LIFT := 0.012                    ## обшивка над бортом (двойник BreachView.LIFT)
const JET_FROM := Vector3(0.0, 0.0, 0.05)
const JET_LIMIT := 48
const JET_LIMIT_LITE := 24
const JET_LITE_LEN := 1.45             ## «Экономно»: карточки струи длиннее — меньше штук без разрывов
const SPLASH_LIMIT := 32
const SPLASH_LIMIT_LITE := 16
const SPLASH_LIFE := 0.45
const SPLASH_R := 0.34                 ## разлёт брызг, м
const SPARK_LIMIT := 31                ## + электрод = 32
const SPARK_LIMIT_LITE := 15
const SPARK_LIFE := 0.72
const SPARK_FROM := Vector3(0.0, 0.0, 0.08)   ## контакт резака со швом
const SPARK_G := 9.0
const SPARK_WET := 0.02                ## вода выше — искры в ней гаснут
const SPARK_QUENCH := 0.08             ## за столько секунд
const GOLDEN := 2.399963
const WATER := Color("C0E1EB")         ## вода холодная
const HOT := Color("FFF2D5")           ## искра у резака
const COOL := Color("F18A3D")          ## остывая — янтарь, без красного (#129)
const GLOW := 1.5                      ## эмиссия искр (bloom), без новых огней
const DARK := 0.12                     ## в темноте вода не светится белым
## Кадры атласа 4×4 по группам: первый и последний (переходов между группами нет).
const JET_FRAMES := Vector2i(0, 7)
const SPLASH_FRAMES := Vector2i(8, 11)
const SPARK_FRAMES := Vector2i(12, 14)
const FLASH_FRAME := 15


class Bit:
	var age := 0.0
	var life := 1.0
	var angle := 0.0
	var k := 0.0            ## доля 0…1 от номера рождения (скорость, разлёт)
	var v := Vector3.ZERO   ## начальная скорость (искры)
	var floor_y := -1.0     ## пол в осях пробоины (искры)


var jet: Array[Bit] = []
var splash: Array[Bit] = []
var sparks: Array[Bit] = []
var flash := false      ## вспышка электрода — пока варят
var lite := false
var born := 0
var _acc := [0.0, 0.0, 0.0]
var _spot: Breach.Spot = null


static func S(e0: float, e1: float, x: float) -> float:
	return smoothstep(e0, e1, x)


## Скорость струи у отверстия (Breach.JET_V под углом JET_UP), м/с.
static func jet_v0() -> Vector3:
	return Vector3(0.0, Breach.JET_UP, 1.0).normalized() * Breach.JET_V


## Жизнь частицы струи: до удара о воду (или стену отсека — Breach.jet_reach).
static func jet_life(s: Breach.Spot, water_h: float) -> float:
	return maxf(0.05, Breach.jet_reach(s, water_h) / jet_v0().z)


## Положение частицы струи возраста t (с) с углом разброса angle.
static func jet_pos(t: float, angle: float) -> Vector3:
	var w := 0.035 + 0.18 * t * t
	return JET_FROM + jet_v0() * t + Vector3(sin(angle) * w, -0.5 * Breach.JET_G * t * t + cos(angle) * w * 0.35, 0.0)


static func jet_vel(t: float) -> Vector3:
	return jet_v0() + Vector3(0.0, -Breach.JET_G * t, 0.0)


## Карточка струи (ширина, длина), м по доле жизни a; «Экономно» — длиннее.
static func jet_size(a: float, is_lite: bool = false) -> Vector2:
	return Vector2(0.14 + 0.18 * a, (0.30 + 0.12 * a) * (JET_LITE_LEN if is_lite else 1.0))


static func jet_alpha(a: float) -> float:
	return 0.58 * S(0.0, 0.025, a) * (1.0 - S(0.85, 1.0, a))


## Центр брызг в осях пробоины: где струя падает на воду, чуть над водой.
static func splash_at(s: Breach.Spot, water_h: float) -> Vector3:
	return Vector3(0.0, water_h - s.p.y + 0.012, Breach.jet_reach(s, water_h) - LIFT)


## Брызга возраста t от центра c: разлёт по углу на ≤ SPLASH_R, вверх 0,9 м/с, g −9, не ниже воды.
static func splash_pos(c: Vector3, t: float, angle: float, k: float) -> Vector3:
	var r := SPLASH_R * (0.4 + 0.6 * k) * clampf(t / SPLASH_LIFE, 0.0, 1.0)
	return c + Vector3(cos(angle) * r, maxf(0.0, 0.9 * t - 4.5 * t * t), sin(angle) * r)


static func splash_size(a: float) -> Vector2:
	return Vector2(0.12 + 0.25 * a, 0.06 + 0.10 * sin(PI * a))


static func splash_alpha(a: float) -> float:
	return 0.45 * S(0.0, 0.08, a) * (1.0 - S(0.15, 1.0, a))


## Начальная скорость искры по доле k и углу: 1,5–3 м/с, веером внутрь отсека и вниз.
static func spark_v0(k: float, angle: float) -> Vector3:
	var speed := 1.5 + 1.5 * k
	var yaw := sin(angle) * 0.8
	var pitch := -0.8 + 0.95 * fposmod(k * 7.31, 1.0)
	return speed * Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


## Когда искра долетает до высоты y (ниже старта), с.
static func _fall_time(vy: float, y: float) -> float:
	return (vy + sqrt(vy * vy + 2.0 * SPARK_G * maxf(0.0, -y))) / SPARK_G


## Положение искры возраста t: баллистика с одним отскоком от пола floor_y (вертикаль × 0,23, горизонталь × 0,55).
static func spark_pos(v: Vector3, t: float, floor_y: float) -> Vector3:
	var tb := _fall_time(v.y, floor_y - SPARK_FROM.y)
	if t <= tb:
		return SPARK_FROM + v * t + Vector3(0.0, -0.5 * SPARK_G * t * t, 0.0)
	var pb := SPARK_FROM + Vector3(v.x * tb, floor_y - SPARK_FROM.y, v.z * tb)
	var vb := spark_vel(v, tb - 1e-5, floor_y)
	var u := t - tb
	var up := -vb.y * 0.23
	return pb + Vector3(vb.x * 0.55 * u, maxf(0.0, up * u - 0.5 * SPARK_G * u * u), vb.z * 0.55 * u)


static func spark_vel(v: Vector3, t: float, floor_y: float) -> Vector3:
	var tb := _fall_time(v.y, floor_y - SPARK_FROM.y)
	if t <= tb:
		return v + Vector3(0.0, -SPARK_G * t, 0.0)
	var vy := -(v.y - SPARK_G * tb) * 0.23
	return Vector3(v.x * 0.55, vy - SPARK_G * (t - tb), v.z * 0.55)


## Жизнь искры: 0,72 с; в воде выше 2 см — гаснет за 0,08 с после входа в неё.
static func spark_life(v: Vector3, floor_y: float, water: float) -> float:
	if water <= SPARK_WET:
		return SPARK_LIFE
	return minf(SPARK_LIFE, _fall_time(v.y, floor_y + water - SPARK_FROM.y) + SPARK_QUENCH)


## Карточка искры: вытянута по скорости, след назад.
static func spark_size(v: Vector3) -> Vector2:
	return Vector2(0.12, clampf(v.length() * 0.09, 0.12, 0.32))


static func spark_alpha(a: float) -> float:
	return S(0.0, 0.03, a) * (1.0 - S(0.7, 1.0, a))


## Цвет искры по доле жизни: #FFF2D5 → #F18A3D.
static func spark_color(a: float) -> Color:
	return HOT.lerp(COOL, S(0.05, 0.70, a))


## Кадр группы по доле жизни: дробный номер в пределах [first, last] (двойник шейдера — смешение соседних).
static func frame(a: float, frames: Vector2i) -> float:
	return frames.x + clampf(a, 0.0, 1.0) * (frames.y - frames.x)


## Шаг по состоянию пробоины: струя и брызги — пока открыта, искры — пока варят; закрыли — живые доживают.
func update(dt: float, b: Breach) -> void:
	for pool: Array[Bit] in [jet, splash, sparks]:
		for p in pool:
			p.age += dt
	jet = jet.filter(func(p: Bit) -> bool: return p.age < p.life)
	splash = splash.filter(func(p: Bit) -> bool: return p.age < p.life)
	sparks = sparks.filter(func(p: Bit) -> bool: return p.age < p.life)
	if b.last != _spot:   # другое место — прежние частицы не переносим
		_spot = b.last
		jet.clear()
		splash.clear()
		sparks.clear()
	var s := b.active
	flash = b.welding and s != null
	if s == null:
		_acc = [0.0, 0.0, 0.0]
		return
	var life := jet_life(s, b.water)
	_emit(jet, 0, dt, (JET_LIMIT_LITE if lite else JET_LIMIT) / life, JET_LIMIT_LITE if lite else JET_LIMIT, life, b)
	var sl := SPLASH_LIMIT_LITE if lite else SPLASH_LIMIT
	_emit(splash, 1, dt, sl / SPLASH_LIFE, sl, SPLASH_LIFE, b)
	if b.welding:
		var kl := SPARK_LIMIT_LITE if lite else SPARK_LIMIT
		_emit(sparks, 2, dt, kl / SPARK_LIFE, kl, SPARK_LIFE, b)
	else:
		_acc[2] = 0.0


func _emit(pool: Array[Bit], g: int, dt: float, rate: float, cap: int, life: float, b: Breach) -> void:
	_acc[g] += dt * rate
	while _acc[g] >= 1.0:
		_acc[g] -= 1.0
		if pool.size() >= cap:
			continue
		var p := Bit.new()
		p.age = _acc[g] / rate   # родилась внутри шага — уже чуть прожила
		p.angle = fposmod(born * GOLDEN, TAU)
		p.k = fposmod(born * 0.618034, 1.0)
		p.life = life
		born += 1
		if g == 2:
			p.floor_y = -b.active.p.y
			p.v = spark_v0(p.k, p.angle)
			p.life = spark_life(p.v, p.floor_y, b.water)
		pool.append(p)


func count() -> int:
	return jet.size() + splash.size() + sparks.size() + (1 if flash else 0)
