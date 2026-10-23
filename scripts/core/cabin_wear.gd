class_name CabinWear
extends RefCounted
## «Корабль устал» внутри по ART-074 (docs/concept-art/ustalost-korpusa.md): потёки на стенах и потолке, мокрый пол
## у бортов мостика и машинного — по потере прочности корпуса `Vitals.hull`, как следы снаружи ART-049.
## Маска `textures/ustalost/maska.png` (плитка 1 × 1 м, линейные данные): R — потёки, G — пятна пола, B — порог потери.
## Рисует `shaders/ship_surface.gdshader` (uniform wear_mask, wear_loss) — тот же материал, 0 новых вызовов;
## ставят `BridgeView.set_wear` / `RoomsView.set_wear` из `Main._wear`. `amount` — двойник шейдера для тестов.
## Ремонт идёт обратно по тому же весу — отдельных таймеров нет.

const MASK := preload("res://textures/ustalost/maska.png")
const EASE := 0.3            ## с — вход сглажен: скачок потери 0 → 1 проходит за это время
const GATE_W := 0.14         ## ширина перехода порога B
const POSTS := [             ## x/z постов — вокруг них карта гаснет (подход к посту чистый)
	Vector2(0.0, -4.2),      # штурвал
	Vector2(-3.9, -2.0),     # энергия
	Vector2(3.85, -2.0),     # сканер
	Vector2(0.0, -1.2),      # сонар
	Vector2(-3.9, -0.5),     # разряд
	Vector2(-2.2, 17.2),     # вентиль
	Vector2(2.2, 17.2),      # щиток
]
const POST_R := 0.8          ## м — у поста сухо
const POST_FADE := 1.25      ## м — дальше карта в полную силу
const WINDOW_Z := Vector2(-5.7, -5.35)   ## рамка носового окна чистая
const STREAK_Y := Vector2(1.35, 2.85)    ## потёки гаснут к низу стены
const ALBEDO_K := 0.68
const ROUGH := 0.24
const ROUGH_K := 0.72
const COAT_K := 0.7

enum Face { WALL, FLOOR, CEILING }

var loss := 0.0   ## сглаженная потеря прочности 0…1


## Потеря прочности по корпусу в %: 0 — целый, 1 — разрушен.
static func target(hull: float) -> float:
	return clampf(1.0 - hull / 100.0, 0.0, 1.0)


## Шаг: потеря идёт к корпусу не быстрее 1/EASE в секунду.
func step(dt: float, hull: float) -> void:
	loss = move_toward(loss, target(hull), dt / EASE)


## Сразу к корпусу (новый забег, снимок).
func snap(hull: float) -> void:
	loss = target(hull)


## Порог маски: пиксель с порогом b «мокнет», когда потеря его прошла.
static func gate(b: float, l: float) -> float:
	return smoothstep(b, b + GATE_W, l)


## Отсеки, где есть износ: мостик (z < 2) и машинное (z 14…19,5).
static func zone(z: float) -> float:
	var bridge := 1.0 - smoothstep(1.8, 2.0, z)
	var engine := smoothstep(14.0, 14.2, z) * (1.0 - smoothstep(19.3, 19.5, z))
	return maxf(bridge, engine)


## Чистые места: подходы к постам и рамка носового окна (1 — карта в силе, 0 — сухо).
static func safe(p: Vector3) -> float:
	var s := smoothstep(WINDOW_Z.x, WINDOW_Z.y, p.z)
	for q: Vector2 in POSTS:
		s *= smoothstep(POST_R, POST_FADE, Vector2(p.x, p.z).distance_to(q))
	return s


## У борта: стена мостика x 4,9, машинного 3,0; полоса 0,8 м.
static func near_wall(p: Vector3) -> float:
	var wall := lerpf(3.0, 4.9, 1.0 - smoothstep(1.8, 2.0, p.z))
	return smoothstep(wall - 0.8, wall - 0.15, absf(p.x))


## Сила износа в точке p (оси корабля) грани face при маске data (r, g, b) и потере l — двойник шейдера.
static func amount(p: Vector3, face: int, data: Color, l: float) -> float:
	var wet := data.r * smoothstep(STREAK_Y.x, STREAK_Y.y, p.y)
	if face == Face.FLOOR:
		wet = data.g * near_wall(p)
	elif face == Face.CEILING:
		wet = data.r * near_wall(p) * 0.6
	return wet * gate(data.b, l) * zone(p.z) * safe(p)
