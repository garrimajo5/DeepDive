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
const STROKES_W := 0.5     ## место справа под три штриха «нажимает» (ART-033)
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
const ACTIVE := Color("67DDEB")   ## «нажимает»: контур ярче и три штриха
const DIM := Color("78949D")      ## «Нет связи»: имя, буква, кружок и контур приглушены
const FADE_T := 0.15              ## «нажимает» входит и выходит за столько секунд, без мигания
const LOST_TEXT := "Нет связи"
const STATUS_EM := 0.3            ## кегль строки «Нет связи», высот плашки
const LOST_NAME_Y := 0.17         ## имя без связи выше середины, строка состояния — ниже
const LOST_STATUS_Y := -0.27
## Три штриха «нажимает»: центры от правого края плашки и высоты, в высотах плашки.
const STROKE_X := [0.52, 0.38, 0.24]
const STROKE_H := [0.3, 0.52, 0.4]
const STROKE_T := 0.055
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


## Разнести таблички, стоящие рядом на экране (#320, правила ART-033): rects — прямоугольники плашек на экране
## (px, y вниз) от ближней к дальней. Ближняя на месте; следующая, если задевает уже поставленную, поднимается над
## ней с зазором GAP высоты — только вверх (не на лицо и не на голостол) и не выше MAX_UP высот (иначе упрётся в
## потолок отсека); не помещается — скрыта (HIDDEN). Возвращает подъём каждой, px (≥ 0), или HIDDEN.
const MAX_UP := 1.5
## Порядок табличек для spread (#374): сначала те, кто нажимает (их состояние важнее), затем ближние. Дальняя,
## что нажимает, встаёт на место, а ближняя поднимается над ней или скрыта — иначе подсветку не увидеть
## (биолог прямо за инженером, `06d2-tag-press`).
static func before(a_on: bool, a_d: float, b_on: bool, b_d: float) -> bool:
	if a_on != b_on:
		return a_on
	return a_d < b_d



const HIDDEN := -1.0
static func spread(rects: Array) -> Array:
	var placed: Array[Rect2] = []
	var out: Array = []
	for r: Rect2 in rects:
		var cur := r
		var ok := true
		var moved := true
		while moved and ok:
			moved = false
			for p in placed:
				if cur.intersects(p):
					cur.position.y = p.position.y - cur.size.y * (1.0 + GAP)
					moved = true
					ok = r.position.y - cur.position.y <= MAX_UP * r.size.y + 0.5
					break
		if ok:
			placed.append(cur)
			out.append(r.position.y - cur.position.y)
		else:
			out.append(HIDDEN)
	return out


## Табличка под плашкой строки состояния (#387): после #380 плашка опускается под табло и доходит до табличек над
## головами. Если табличка r задевает плашку plate (px экрана, y вниз), опускаем её под нижний край плашки с зазором
## GAP высоты — но не больше max_down px (столько, чтобы не легла на макушку, см. LIFT); нужно больше — HIDDEN
## (плашка — интерфейс, на него табличка не ложится, как в #319). Возвращает сдвиг вниз, px (≥ 0), или HIDDEN.
static func under_plate(r: Rect2, plate: Rect2, max_down: float) -> float:
	if not plate.has_area() or not plate.intersects(r):
		return 0.0
	var down := plate.end.y + GAP * r.size.y - r.position.y
	return down if down <= max_down else HIDDEN


## Табличка не ложится на интерфейс (#319): целиком в кадре (screen) и не задевает кнопки и открытые панели
## (blocks — прямоугольники экрана). Иначе скрыта: 3D-плашка под полупрозрачной кнопкой или панелью выглядит
## поверх неё (кнопка noclip у края, панель итога — отчёт qa/2026-10-21-2350).
static func clear_of(r: Rect2, screen: Rect2, blocks: Array) -> bool:
	if not screen.encloses(r):
		return false
	for b: Rect2 in blocks:
		if b.intersects(r):
			return false
	return true


## Прямоугольник экрана вокруг круглой кнопки (Touch.Circle).
static func circle_rect(c: Vector2, radius: float) -> Rect2:
	return Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


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
	return clampf(NAME_X + text_w + STROKES_W + PAD_R, MIN_W, MAX_W)


## Центр имени по X от середины плашки ширины w (имя шириной text_w — от NAME_X).
static func name_x(w: float, text_w: float) -> float:
	return -w * 0.5 + NAME_X + minf(text_w, w - NAME_X - PAD_R - STROKES_W) * 0.5


## Яркость «нажимает» за шаг dt: к 1, пока активен, к 0 после — за FADE_T, ровно, без мигания.
static func glow_step(level: float, active: bool, dt: float) -> float:
	return move_toward(level, 1.0 if active else 0.0, dt / FADE_T)


## Цвета таблички: [контур, кружок роли, буква и имя]; без связи — всё приглушено (#78949D), красного нет.
static func colors(role: int, lost: bool) -> Array:
	if lost:
		return [DIM, DIM, DIM]
	return [EDGE, ring_color(role), TEXT]


static func letter_x(w: float) -> float:
	return -w * 0.5 + CIRCLE_X


## Текстура плашки: скруглённый фон, контур, кольцо роли слева (буква и имя — подписи поверх). w — ширина в высотах.
static func plate_image(w: float, ring: Color, edge: Color = EDGE) -> Image:
	var key := "%s|%s" % [ring.to_html(), edge.to_html()]
	if not _plates.has(key):
		_plates[key] = _plate_full(float(PLATE_CAP.x + 1 + PLATE_CAP.y) / TEX_H, ring, edge)
	return stretch(_plates[key], roundi(w * TEX_H), PLATE_CAP, func() -> Image: return _plate_full(w, ring, edge))


## Слой «нажимает» поверх плашки: яркий контур #67DDEB (толще обычного) и три вертикальных штриха у правого края;
## остальное прозрачно. Прозрачность слоя — яркость `glow_step`.
static func glow_image(w: float) -> Image:
	if _glow == null:
		_glow = _glow_full(float(GLOW_CAP.x + 1 + GLOW_CAP.y) / TEX_H)
	return stretch(_glow, roundi(w * TEX_H), GLOW_CAP, func() -> Image: return _glow_full(w))


## Плашка по ширине собирается из готовой узкой заготовки (#725): левый край с кружком, один средний столбец
## (в середине картинка по x не меняется — до краёв и кружка дальше их влияния) и правый край со штрихами —
## копированием, без попиксельного счёта в GDScript (было ~18 мс на табличку при появлении товарища).
## Попиксельно совпадает с полным расчётом `_plate_full`/`_glow_full` (тест). Края, px: x — слева, y — справа.
const PLATE_CAP := Vector2i(60, 16)
const GLOW_CAP := Vector2i(18, 38)
static var _plates := {}       ## заготовки плашек по цветам кружка и контура
static var _glow: Image = null  ## заготовка слоя «нажимает»


static func stretch(part: Image, wp: int, cap: Vector2i, full: Callable) -> Image:
	if wp < cap.x + 1 + cap.y:
		return full.call()
	var h := part.get_height()
	var img := Image.create_empty(wp, h, false, Image.FORMAT_RGBA8)
	img.blit_rect(part, Rect2i(0, 0, cap.x + 1, h), Vector2i.ZERO)
	var x := cap.x + 1
	var mid := wp - cap.y   # конец середины
	while x < mid:   # середина — удвоением уже собранного куска
		var n := mini(x - cap.x, mid - x)
		img.blit_rect(img, Rect2i(cap.x, 0, n, h), Vector2i(x, 0))
		x += n
	img.blit_rect(part, Rect2i(cap.x + 1, 0, cap.y, h), Vector2i(mid, 0))
	return img


## Полный попиксельный расчёт плашки — заготовка и эталон для теста.
static func _plate_full(w: float, ring: Color, edge: Color = EDGE) -> Image:
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
				c = c.lerp(Color(edge, 1.0), clampf(d + bw + 0.5, 0.0, 1.0))
			var dc := absf(p.distance_to(Vector2(cx, cy)) - CIRCLE_R * h)
			var k := clampf(RING * h * 0.5 + 0.5 - dc, 0.0, 1.0)
			if k > 0.0:
				c = c.lerp(Color(ring, 1.0), k)
			c.a *= cover
			img.set_pixel(x, y, c)
	return img


## Полный попиксельный расчёт слоя «нажимает» — заготовка и эталон для теста.
static func _glow_full(w: float) -> Image:
	var h := TEX_H
	var wp := roundi(w * h)
	var img := Image.create_empty(wp, h, false, Image.FORMAT_RGBA8)
	var r := CORNER * h
	var bw := BORDER * h * 1.8
	for y in h:
		for x in wp:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _round_rect(p, Vector2(wp, h), r)
			if d > 0.5:
				continue
			var k := clampf(d + bw + 0.5, 0.0, 1.0) * clampf(0.5 - d, 0.0, 1.0)
			for i in STROKE_X.size():
				var sx: float = wp - float(STROKE_X[i]) * h
				var hy: float = float(STROKE_H[i]) * h * 0.5
				var dx := absf(p.x - sx) - STROKE_T * h * 0.5
				var dy := absf(p.y - h * 0.5) - hy
				k = maxf(k, clampf(0.5 - maxf(dx, dy), 0.0, 1.0))
			if k > 0.0:
				img.set_pixel(x, y, Color(ACTIVE, k))
	return img


## Знаковое расстояние до скруглённого прямоугольника [0, size] с радиусом r, px.
static func _round_rect(p: Vector2, size: Vector2, r: float) -> float:
	var q := (p - size * 0.5).abs() - (size * 0.5 - Vector2(r, r))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
