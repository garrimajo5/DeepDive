class_name NameTag
## Табличка игрока над фигурой по ART-033 (`docs/concept-art/tablichka-igroka.md`): кружок с буквой роли и имя,
## над макушкой каждого члена экипажа, кроме своего. Размер — по высоте экрана: 96 px до 2 м, 72 px на 6 м, 48 px
## на 10 м (при высоте окна 1080 px), 10–12 м плавно гаснет, дальше скрыта. Числа и плашка — здесь, рисует NameTagView.
## Размеры плашки — в её высотах (высота плашки = 1).

const LIFT := 0.18          ## низ плашки над макушкой, м
const MAX_LEN := 12         ## имя длиннее — многоточие
const REF_H := 1080.0       ## высота окна, для которой заданы пиксели
const NEAR := 2.0           ## до этого расстояния — самая крупная
const FADE_FROM := 10.0     ## отсюда гаснет
const HIDE_AT := 12.0       ## дальше не видна
const MIN_DEPTH := 0.6     ## ближе к плоскости камеры — скрыта (товарищ вплотную, #319)
const GAP := 0.12           ## зазор между табличками рядом стоящих, высот плашки (#320)
const LETTERS := ["П", "С", "И", "Б"]   ## буква роли: роль видна не только цветом (Crew.Role)

## Плашка в высотах: кружок роли слева, имя после него, ширина по имени до MAX_W.
const CIRCLE_X := 0.5       ## центр кружка от левого края
const CIRCLE_R := 0.36
const RING := 0.07          ## толщина кольца кружка
const NAME_X := 0.98        ## имя начинается отсюда
const PAD_R := 0.32         ## поле справа от имени
const MIN_W := 2.4
const MAX_W := 7.0
const BORDER := 0.045       ## контур плашки
const CORNER := 0.16        ## скругление углов
const NAME_EM := 0.5        ## кегль имени, высот плашки (видимые буквы ≈ 0,43 по ART-033)
const LETTER_EM := 0.56     ## кегль буквы роли (≈ 0,49)
const TEX_H := 64           ## высота текстуры плашки, px

const BACK := Color("0B1C24")
const BACK_A := 0.9
const TEXT := Color("D5E4E8")
const EDGE := Color("9AD9E8")
## Цвет кружка роли по ART-033 (sbor-ekipazha.md): инженер нейтральный (#129), без красного.
const ROLE_RING := [Color("E39E38"), Color("45C2CC"), Color("D5E4E8"), Color("73BD5C")]


## Высота плашки на экране, px при высоте окна REF_H, на расстоянии d м.
static func px(d: float) -> float:
	if d <= NEAR:
		return 96.0
	if d <= 6.0:
		return lerpf(96.0, 72.0, (d - NEAR) / (6.0 - NEAR))
	return lerpf(72.0, 48.0, clampf((d - 6.0) / (FADE_FROM - 6.0), 0.0, 1.0))


## Прозрачность: 1 до FADE_FROM, к HIDE_AT — 0.
static func alpha(d: float) -> float:
	return clampf((HIDE_AT - d) / (HIDE_AT - FADE_FROM), 0.0, 1.0)


static func shown(d: float) -> bool:
	return d < HIDE_AT


## Высота плашки в мире, м: на расстоянии d при вертикальном угле обзора fov_deg занимает px(d) из REF_H.
## depth — глубина по оси взгляда (по ней перспектива меряет размер на экране); сбоку она меньше расстояния,
## и плашка по расстоянию выходила больше 96 px — у края экрана в треть его высоты (#319). Без depth — d.
static func world_height(d: float, fov_deg: float, depth: float = -1.0) -> float:
	var z := d if depth < 0.0 else depth
	return 2.0 * z * tan(deg_to_rad(fov_deg) * 0.5) * px(d) / REF_H


## Видна ли табличка: дальше HIDE_AT — нет, ближе MIN_DEPTH к плоскости камеры (или за ней) — нет.
static func visible_at(d: float, depth: float) -> bool:
	return shown(d) and depth >= MIN_DEPTH


## Разнести таблички, стоящие рядом на экране (#320): rects — прямоугольники плашек на экране (px, y вниз)
## в порядке от ближней к дальней. Ближняя остаётся на месте; следующая, если задевает уже поставленную, встаёт
## над ней, слева или справа (с зазором GAP высоты) — куда ближе к своему месту. Вверх — не выше MAX_UP высот
## (иначе упрётся в потолок отсека). Возвращает сдвиг каждой, px (x вправо, y вниз).
const MAX_UP := 1.5
static func spread(rects: Array) -> Array:
	var placed: Array[Rect2] = []
	var out: Array = []
	for r: Rect2 in rects:
		var cur := r
		for _step in 8:
			var hit := -1
			for k in placed.size():
				if cur.intersects(placed[k]):
					hit = k
					break
			if hit < 0:
				break
			var p := placed[hit]
			var g := GAP * r.size.y
			var cands: Array[Rect2] = []
			var up := Rect2(Vector2(cur.position.x, p.position.y - cur.size.y - g), cur.size)
			if r.position.y - up.position.y <= MAX_UP * r.size.y + 0.5:
				cands.append(up)
			cands.append(Rect2(Vector2(p.position.x - cur.size.x - g, cur.position.y), cur.size))
			cands.append(Rect2(Vector2(p.end.x + g, cur.position.y), cur.size))
			var best := cands[0]
			var best_cost := INF
			for c in cands:
				var free := true
				for q in placed:
					if c.intersects(q):
						free = false
						break
				var cost := c.position.distance_to(r.position) + (0.0 if free else 1e6)
				if cost < best_cost:
					best_cost = cost
					best = c
			cur = best
		placed.append(cur)
		out.append(cur.position - r.position)
	return out


## Имя на плашке: до MAX_LEN букв, длиннее — многоточие; пустое — название роли.
static func label(name: String, role: int) -> String:
	var n := name.strip_edges()
	if n == "":
		n = Crew.ROLE_NAMES[clampi(role, 0, Crew.ROLE_NAMES.size() - 1)]
	return n if n.length() <= MAX_LEN else n.substr(0, MAX_LEN - 1) + "…"


static func letter(role: int) -> String:
	return LETTERS[clampi(role, 0, LETTERS.size() - 1)]


static func ring_color(role: int) -> Color:
	return ROLE_RING[clampi(role, 0, ROLE_RING.size() - 1)]


## Ширина плашки (в высотах) для имени шириной text_w высот.
static func width(text_w: float) -> float:
	return clampf(NAME_X + text_w + PAD_R, MIN_W, MAX_W)


## Центр имени по X от середины плашки ширины w (имя шириной text_w — от NAME_X).
static func name_x(w: float, text_w: float) -> float:
	return -w * 0.5 + NAME_X + minf(text_w, w - NAME_X - PAD_R) * 0.5


static func letter_x(w: float) -> float:
	return -w * 0.5 + CIRCLE_X


## Текстура плашки: скруглённый фон, контур, кольцо роли слева (буква и имя — подписи поверх). w — ширина в высотах.
static func plate_image(w: float, ring: Color) -> Image:
	var h := TEX_H
	var wp := roundi(w * h)
	var img := Image.create_empty(wp, h, false, Image.FORMAT_RGBA8)
	var r := CORNER * h
	var bw := BORDER * h
	var cx := CIRCLE_X * h
	var cy := h * 0.5
	for y in h:
		for x in wp:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _round_rect(p, Vector2(wp, h), r)   # < 0 внутри, px до края
			if d > 0.5:
				continue
			var cover := clampf(0.5 - d, 0.0, 1.0)
			var c := Color(BACK, BACK_A)
			if d > -bw:
				c = c.lerp(Color(EDGE, 1.0), clampf(d + bw + 0.5, 0.0, 1.0))
			var dc := absf(p.distance_to(Vector2(cx, cy)) - CIRCLE_R * h)
			var k := clampf(RING * h * 0.5 + 0.5 - dc, 0.0, 1.0)
			if k > 0.0:
				c = c.lerp(Color(ring, 1.0), k)
			c.a *= cover
			img.set_pixel(x, y, c)
	return img


## Знаковое расстояние до скруглённого прямоугольника [0, size] с радиусом r, px.
static func _round_rect(p: Vector2, size: Vector2, r: float) -> float:
	var q := (p - size * 0.5).abs() - (size * 0.5 - Vector2(r, r))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
