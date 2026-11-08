class_name ValveSteam
extends RefCounted
## Пар вентиля сброса по ART-071 (`docs/concept-art/par-ventilya.md`). Логика без узлов: пул частиц в осях корабля,
## рождение у сопла, пока `EngineRoom.venting`; отпустили — рождения нет, живые доживают. Путь, размер, альфа и кадр
## атласа — функции возраста (без случайных чисел в кадре: угол разброса частицы постоянный, по золотому углу).
## Рисует `scripts/game/steam_view.gd` одним MultiMesh (атлас `textures/par/atlas.png`, шейдер `shaders/steam.gdshader`).

const ATLAS := "res://textures/par/atlas.png"
const GRID := 4                        ## атлас 4×4: 0–3 струя, 4–7 разрыв, 8–11 клубы, 12–15 тающие клочья
const LAST := 15                       ## последний кадр, 15→0 не зацикливать
const NOZZLE := EngineRoom.VALVE_POS + Vector3(0.18, 0.12, 0.0)   ## (−2,82; 1,42; 17,2)
const LIFE := 1.25                     ## жизнь частицы, с
const RATE := 38.4                     ## рождений в секунду (48 живых)
const RATE_LITE := 19.2                ## «Экономно» (ART-044) — 24 живых
const LIMIT := 48
const LIMIT_LITE := 24
const SPREAD := 0.075                  ## разброс по y/z, м: sin(π·a) под постоянным углом
const GOLDEN := 2.399963               ## золотой угол — углы соседних частиц не повторяются
const COLD := Color("C6D6DE")          ## обычный оттенок
const WARM := Color("E8C49F")          ## перегрев — подкраской, без красного (#129)
const DARK := 0.08                     ## в полной темноте пар слабый, не светится белым


class Puff:
	var age := 0.0
	var angle := 0.0


var puffs: Array[Puff] = []
var lite := false
var born := 0          ## всего рождено (угол следующей)
var _acc := 0.0


## Шаг: venting — пар идёт в этом шаге (EngineRoom.venting).
func update(dt: float, venting: bool) -> void:
	for p in puffs:
		p.age += dt
	puffs = puffs.filter(func(p: Puff) -> bool: return p.age < LIFE)
	if not venting:
		_acc = 0.0
		return
	_acc += dt * (RATE_LITE if lite else RATE)
	var cap := LIMIT_LITE if lite else LIMIT
	while _acc >= 1.0:
		_acc -= 1.0
		if puffs.size() >= cap:
			continue
		var p := Puff.new()
		p.age = _acc / (RATE_LITE if lite else RATE)   # родилась внутри шага — уже чуть прожила
		p.angle = fposmod(born * GOLDEN, TAU)
		born += 1
		puffs.append(p)


## Положение частицы возраста s (с) с углом разброса angle — в осях корабля.
static func pos(s: float, angle: float) -> Vector3:
	var a := clampf(s / LIFE, 0.0, 1.0)
	var x := 0.70 * s / (1.0 + 2.5 * s)
	var y := 0.75 * s - 0.10 * s * s - 0.30 * HashNoise.smooth(0.62, 1.0, a)
	var w := sin(PI * a) * SPREAD
	return NOZZLE + Vector3(x, y + cos(angle) * w, sin(angle) * w)


## Размер карточки (ширина, высота), м по доле жизни a.
static func size(a: float) -> Vector2:
	var h := 0.09 + 0.33 * HashNoise.smooth(0.0, 0.85, a)
	return Vector2(h * (0.6 + 0.4 * a), h)


## Альфа по доле жизни: ≤ 0,25, быстро появляется, с 0,55 тает.
static func alpha(a: float) -> float:
	return 0.25 * HashNoise.smooth(0.0, 0.045, a) * (1.0 - HashNoise.smooth(0.55, 1.0, a))


## Кадры атласа и вес второго: [floor(n), min(floor(n)+1, 15), smoothstep(fract(n))], n = a·15 (двойник шейдера).
static func frames(a: float) -> Array:
	var n := clampf(a, 0.0, 1.0) * LAST
	var f0 := mini(int(floor(n)), LAST)
	return [f0, mini(f0 + 1, LAST), smoothstep(0.0, 1.0, n - floor(n))]


## Оттенок пара: холодный, на перегреве тёплый (SCRAM тёплое убирает); × свет отсеков lamp_k, не темнее DARK.
static func tint(r: Reactor, lamp_k: float = 1.0) -> Color:
	var warm := 0.0 if r.scram > 0.0 or not r.hot else clampf(r.heat / 100.0, 0.0, 1.0)
	var c := COLD.lerp(WARM, warm)
	var k := maxf(lamp_k, DARK)
	return Color(c.r * k, c.g * k, c.b * k, 1.0)
