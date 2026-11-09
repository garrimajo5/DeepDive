class_name PlayFrame
extends RefCounted
## Кадр для страницы Google Play по шаблону ART-046 (`docs/concept-art/google-play.md`): холст 1920×1080, сверху
## плашка подписи y 0…152 (#0B1C24, текст #D5E4E8 66 px, центр (960, 78)), снимок игры — в рамку 16:9 x 176, y 170,
## 1568×882 целиком, без растяжения, с тёмными полями (1600×720 20:9 — полосы сверху и снизу). Служебных рамки и
## строки «концепт» шаблона нет. Здесь — раскладка и сборка из картинок; подпись рисует `PlayCaption`
## (`scripts/game/play_caption.gd`), сводят шаг тестера `play` (`QaRunner`), `shot.gd kadr=<n>` и `tools/play_frame.gd`.

const SIZE := Vector2i(1920, 1080)
const PLATE_H := 152                         ## плашка подписи сверху
const BOX := Rect2i(176, 170, 1568, 882)     ## рамка снимка, 16:9
const TEXT_CENTER := Vector2i(960, 78)       ## центр строки подписи
const FONT_PX := 66
const BG := Color8(0x0B, 0x1C, 0x24)         ## фон и плашка — палитра ART-028
const FIELD := Color8(0x05, 0x0E, 0x12)      ## поля в рамке вокруг снимка не того соотношения — темнее фона
const TEXT := Color8(0xD5, 0xE4, 0xE8)
## Подписи четырёх кадров по порядку листа `google-play-kadry.png` (1 — вчетвером, 2 — пробоина, 3 — сканер,
## 4 — голосование). Публиковать — когда эти части есть в выкладываемой сборке (решение владельца).
const CAPTIONS := ["Ведите батискаф вчетвером", "Чините пробоины вместе", "Изучайте живую отмель", "Глубже или наверх?"]


## Подпись кадра n (1…4); вне диапазона — пусто.
static func caption(n: int) -> String:
	return CAPTIONS[n - 1] if n >= 1 and n <= CAPTIONS.size() else ""


## Имя файла кадра n: kadr-1 … kadr-4.
static func file_name(n: int) -> String:
	return "kadr-%d" % n


## Где лежит снимок размера src в рамке BOX: целиком, с сохранением пропорций, по центру.
static func fit(src: Vector2i) -> Rect2i:
	if src.x <= 0 or src.y <= 0:
		return Rect2i(BOX.position, Vector2i.ZERO)
	var k := minf(float(BOX.size.x) / src.x, float(BOX.size.y) / src.y)
	var sz := Vector2i(mini(roundi(src.x * k), BOX.size.x), mini(roundi(src.y * k), BOX.size.y))
	return Rect2i(BOX.position + (BOX.size - sz) / 2, sz)


## Где лежит картинка подписи размера cap на холсте: по центру TEXT_CENTER, внутри плашки.
static func caption_rect(cap: Vector2i) -> Rect2i:
	var pos := TEXT_CENTER - cap / 2
	pos.y = clampi(pos.y, 0, maxi(PLATE_H - cap.y, 0))
	return Rect2i(pos, cap)


## Собрать кадр: фон, поля рамки, снимок (копия, исходник не меняется), поверх — подпись с прозрачностью
## (null — без подписи, как в headless-тестах, где текст не рисуется).
static func compose(shot: Image, cap: Image = null) -> Image:
	var out := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	out.fill(BG)
	out.fill_rect(BOX, FIELD)
	if shot != null and not shot.is_empty():
		var r := fit(shot.get_size())
		var s := shot.duplicate() as Image
		s.convert(Image.FORMAT_RGBA8)
		if s.get_size() != r.size:
			s.resize(r.size.x, r.size.y, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(s, Rect2i(Vector2i.ZERO, r.size), r.position)
	if cap != null and not cap.is_empty():
		var c := cap.duplicate() as Image
		c.convert(Image.FORMAT_RGBA8)
		var cr := caption_rect(c.get_size())
		out.blend_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), cr.position)
	out.convert(Image.FORMAT_RGB8)   # магазин — без прозрачности
	return out
