class_name HintPointer
extends RefCounted
## Указатель на пост для подсказок первого забега ART-038 (`docs/concept-art/podskazki.md`): атлас
## `textures/podskazki/ukazatel.png` 512² сеткой 2×2 — (0,0) кольцо с шевроном (пост виден), (256,0) стрелка влево
## (пост вне кадра), (0,256) кольцо с точкой (игрок рядом). Показываем одну ячейку, не весь атлас.
## Пост в кадре — указатель в мире над постом (слой корабля), остриё шеврона — в ANCHORS; символ на экране
## PX_MIN…PX_MAX px при H = 1080 (по расстоянию), покачивание ±BOB px за BOB_PERIOD. Пост вне кадра или за спиной —
## мировой скрыт, у левого или правого края 2D-стрелка (у правого — зеркально), отступ EDGE, y EDGE_Y, символ ARROW px,
## в нижние углы не заходит. Здесь — числа и геометрия; рисуют `HintPointerView` (мир) и `TutorialPanel` (стрелка).

const PATH := "res://textures/podskazki/ukazatel.png"
const CELL := 256.0
const SEEN := Rect2(0, 0, 256, 256)    ## кольцо с шевроном
const ARROW_CELL := Rect2(256, 0, 256, 256)   ## стрелка влево
const NEAR := Rect2(0, 256, 256, 256)  ## кольцо с точкой — игрок в радиусе поста
## Символ кольца с шевроном в ячейке (по альфе атласа): y 51…204 — высота 153 px, центр по x 128; остриё шеврона —
## 76 px ниже середины ячейки. Стрелка — x 94…202, y 58…197 (139 px).
const SYMBOL_H := 153.0 / 256.0        ## высота символа в долях ячейки
const TIP := 76.0 / 256.0              ## остриё ниже середины ячейки, доли
const ARROW_H := 139.0 / 256.0
const ARROW_W := 108.0 / 256.0         ## ширина символа стрелки (x 94…202)
const ARROW_X := 148.0 / 256.0         ## его центр от левого края ячейки

const REF_H := 1080.0
const PX_MIN := 96.0     ## символ на экране не меньше (ART-038: ≥ 96 px при H = 1080)
const PX_MAX := 160.0    ## и не больше вблизи
const PX_K := 240.0      ## px·м: 160 px до 1,5 м, 96 px с 2,5 м
const BOB := 4.0         ## покачивание мирового указателя, px при H = 1080
const BOB_PERIOD := 2.0  ## с
const MIN_DEPTH := 0.3   ## ближе к плоскости камеры — не рисуем в мире (стрелка тоже не нужна: пост вплотную)

const ARROW := 128.0     ## символ стрелки у края, px при H = 1080
const EDGE := 60.0       ## отступ стрелки от края
const EDGE_Y := Vector2(260.0, 560.0)   ## центр стрелки по y — не в нижних углах и не на строке приборов

## Остриё шеврона над постом, оси корабля (y — над палубой). Штурвал — над креслом пилота (как в макете), пульт
## энергии — перед его лицом (не в стене, как метка «Занято»), сонар — над голостолом, «Маршрут» — над своим постом
## справа от стола.
const ANCHORS := {
	"helm": Vector3(0.0, 1.75, Deck.CHAIR_Z),
	"energy": Vector3(BridgeProps.ENERGY_POS.x + 0.4, 1.9, BridgeProps.ENERGY_POS.z),
	"sonar": Vector3(0.0, 1.65, BridgeProps.TABLE_Z),
	"route": Vector3(1.5, 1.5, BridgeProps.TABLE_Z),
}


## Символ на экране, px при H = 1080, на расстоянии d м.
static func px(d: float) -> float:
	return clampf(PX_K / maxf(d, 0.01), PX_MIN, PX_MAX)


## Высота ячейки в мире (м), чтобы символ был px(d) на экране высотой screen_h при глубине depth и угле fov.
static func cell_height(d: float, depth: float, fov_deg: float) -> float:
	var sym := 2.0 * depth * tan(deg_to_rad(fov_deg) * 0.5) * px(d) / REF_H
	return sym / SYMBOL_H


## Покачивание, px при H = 1080 (вверх — плюс), t — секунды.
static func bob(t: float) -> float:
	return BOB * sin(TAU * t / BOB_PERIOD)


## Ячейка мирового указателя: игрок в радиусе поста — кольцо с точкой, иначе кольцо с шевроном.
static func cell(near: bool) -> Rect2:
	return NEAR if near else SEEN


## Виден ли пост: проекция острия p (px) в кадре size с полем под символ, и пост перед камерой (depth).
static func on_screen(p: Vector2, depth: float, size: Vector2) -> bool:
	if depth < MIN_DEPTH:
		return false
	var s := size.y / REF_H
	var m := Vector2(PX_MIN * 0.5 * s, PX_MIN * s)   # символ над остриём: целиком над краем
	return p.x >= m.x and p.x <= size.x - m.x and p.y >= m.y and p.y <= size.y


## Стрелка у края экрана для поста вне кадра: local — остриё в осях камеры (x вправо, −z вперёд), p — его проекция
## (px), size — экран. Сторона — по x в осях камеры (за спиной тоже верно); y — проекция, зажатая в EDGE_Y, за
## спиной — середина EDGE_Y. Возвращает [прямоугольник ячейки на экране, зеркалить (правый край)].
static func edge(local: Vector3, p: Vector2, size: Vector2) -> Array:
	var s := size.y / REF_H
	var right := local.x > 0.0
	var y := lerpf(EDGE_Y.x, EDGE_Y.y, 0.5) * s
	if -local.z > MIN_DEPTH:
		y = clampf(p.y, EDGE_Y.x * s, EDGE_Y.y * s)
	var h := ARROW * s / ARROW_H                 # ячейка, в которой символ — ARROW px
	var cx := EDGE * s + ARROW_W * h * 0.5      # центр символа: его край на EDGE от края экрана
	var off := ARROW_X * h                       # центр символа от левого края ячейки
	if right:
		cx = size.x - cx
		off = h - off                            # ячейка зеркальна
	return [Rect2(cx - off, y - h * 0.5, h, h), right]


## Что показать для цели: "world" — указатель над постом, "edge" — стрелка у края, "" — ничего (пост вплотную перед
## камерой: остриё ближе MIN_DEPTH, но в кадре).
static func mode(local: Vector3, p: Vector2, size: Vector2) -> String:
	var depth := -local.z
	if on_screen(p, depth, size):
		return "world"
	if depth > 0.0 and depth < MIN_DEPTH and Rect2(Vector2.ZERO, size).has_point(p):
		return ""
	return "edge"
