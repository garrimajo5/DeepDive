class_name BusyMark
## Метка «Занято» на посту, который держит другой (ART-033, `docs/concept-art/tablichka-igroka.md`): над рабочей
## поверхностью штурвала и пульта энергии (`Crew.BUSY`) — подложка с контуром замка, слово «Занято» и табличка
## занявшего (кружок роли, буква, имя — как `NameTag`). Видна до SHOW_AT м при подходе, свой пост не помечается,
## без кнопки. Пока метка видна, табличка над головой занявшего скрыта (одна и та же табличка дважды рядом).
## Размеры — в высотах таблички занявшего (= 1, по расстоянию как `NameTag.px`); рисует BusyMarkView.

const SHOW_AT := 3.0        ## дальше не видна, м
const FADE_FROM := 2.5      ## отсюда гаснет к SHOW_AT
const WORD := "Занято"
## Низ метки — 0,2 м над рабочей поверхностью (ART-033: 0,15–0,25 м). Штурвал: верх обода колеса ≈ 1,3 м
## (ступица 0,95 м, колесо ~0,35 м); пульт энергии у стены x −4,9: верх пульта 1,65 м (`AlarmBoard.HINT_ENERGY_SIZE`),
## метка перед его лицом, чтобы не уходила в стену.
const ANCHORS := {
	"helm": Vector3(0.0, 1.5, BridgeProps.WHEEL_Z),
	"energy": Vector3(BridgeProps.ENERGY_POS.x + 0.4, 1.85, BridgeProps.ENERGY_POS.z),
}

## Подложка в высотах таблички: поле PAD вокруг, замок слева, слово, зазор, табличка занявшего.
const PAD := 0.2
const H := 1.0 + 2.0 * PAD       ## высота подложки
const LOCK_X := 0.32             ## центр замка от левого края поля
const LOCK_W := 0.4              ## корпус замка
const LOCK_H := 0.34
const LOCK_Y := -0.12            ## центр корпуса от середины (вниз), дужка над ним
const SHACKLE_R := 0.13
const LOCK_T := 0.055            ## толщина линий замка
const WORD_X := 0.72             ## слово от левого края поля
const WORD_EM := 0.5
const TAG_GAP := 0.35            ## между словом и табличкой
const CORNER := 0.12
const BORDER := 0.03
const TEX_H := 90                ## высота текстуры подложки, px

const EDGE_GAP := 0.02           ## поле от края экрана и от кнопок, доля высоты экрана (#373)

const BACK := Color("132B36")
const BACK_A := 0.88
const EDGE := Color("2E5866")
const LOCK := Color("D5E4E8")


## Помеченные посты: [[id, занявший], …] — посты Crew.BUSY, которые держит не свой игрок (Crew.holder).
static func marks(crew: Array, me: Crew.Member) -> Array:
	var out: Array = []
	for id: String in Crew.BUSY:
		var m := Crew.holder(crew, me, id)
		if m != null:
			out.append([id, m])
	return out


## Прозрачность на расстоянии d: 1 до FADE_FROM, к SHOW_AT — 0.
static func alpha(d: float) -> float:
	return clampf((SHOW_AT - d) / (SHOW_AT - FADE_FROM), 0.0, 1.0)


static func shown(d: float) -> bool:
	return d < SHOW_AT


## Левый край таблички занявшего от левого края подложки (word_w — ширина слова в высотах).
static func tag_x(word_w: float) -> float:
	return PAD + WORD_X + word_w + TAG_GAP


## Ширина подложки для слова word_w и таблички шириной plate_w (высоты).
static func width(word_w: float, plate_w: float) -> float:
	return tag_x(word_w) + plate_w + PAD


## Центр точки x (от левого края подложки) от середины подложки шириной w.
static func from_center(x: float, w: float) -> float:
	return x - w * 0.5


## Сдвиг метки на экране (px, y вниз), чтобы она вся была в кадре и не лежала под кнопками (#373): r — метка на
## экране, screen — видимая область, keep_out — кнопки (прямоугольники). Сначала внутрь экрана с полем EDGE_GAP;
## задела кнопку — самый короткий сдвиг из четырёх (влево, вправо, вверх, вниз), при котором она остаётся в кадре.
static func fit(r: Rect2, screen: Rect2, keep_out: Array) -> Vector2:
	var g := EDGE_GAP * screen.size.y
	var inner := screen.grow(-g)
	var off := Vector2.ZERO
	off.x = clampf(r.position.x, inner.position.x, maxf(inner.end.x - r.size.x, inner.position.x)) - r.position.x
	off.y = clampf(r.position.y, inner.position.y, maxf(inner.end.y - r.size.y, inner.position.y)) - r.position.y
	for k: Rect2 in keep_out:
		var cur := Rect2(r.position + off, r.size)
		var kg := k.grow(g)
		if not cur.intersects(kg):
			continue
		var best := Vector2.INF
		for mv: Vector2 in [Vector2(kg.position.x - cur.end.x, 0.0), Vector2(kg.end.x - cur.position.x, 0.0),
				Vector2(0.0, kg.position.y - cur.end.y), Vector2(0.0, kg.end.y - cur.position.y)]:
			if inner.encloses(Rect2(cur.position + mv, cur.size)) and mv.length() < best.length():
				best = mv
		if best != Vector2.INF:
			off += best
	return off


## Подложка шириной w (высоты таблички): скруглённый тёмный фон с тонким контуром и контур замка слева.
static func panel_image(w: float) -> Image:
	var px := TEX_H / H                  # px на высоту таблички
	var wp := roundi(w * px)
	var hp := TEX_H
	var img := Image.create_empty(wp, hp, false, Image.FORMAT_RGBA8)
	var r := CORNER * px
	var bw := BORDER * px
	var lc := Vector2((PAD + LOCK_X) * px, hp * 0.5 - LOCK_Y * px)    # центр корпуса замка (y вниз)
	var half := Vector2(LOCK_W, LOCK_H) * px * 0.5
	var sc := lc - Vector2(0.0, half.y)                               # центр дужки — на верхней кромке корпуса
	var t := LOCK_T * px
	for y in hp:
		for x in wp:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := NameTag._round_rect(p, Vector2(wp, hp), r)
			if d > 0.5:
				continue
			var c := Color(BACK, BACK_A)
			if d > -bw:
				c = c.lerp(Color(EDGE, 1.0), clampf(d + bw + 0.5, 0.0, 1.0))
			# корпус замка — контур прямоугольника
			var q := (p - lc).abs() - half
			var box := absf(Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0))
			var k := clampf(t * 0.5 + 0.5 - box, 0.0, 1.0)
			# дужка — верхняя половина кольца
			if p.y <= sc.y + 0.5:
				var ring := absf(p.distance_to(sc) - SHACKLE_R * px)
				k = maxf(k, clampf(t * 0.5 + 0.5 - ring, 0.0, 1.0))
			if k > 0.0:
				c = c.lerp(Color(LOCK, 1.0), k)
			c.a *= clampf(0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return img
