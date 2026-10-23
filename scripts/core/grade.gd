class_name Grade
extends RefCounted
## Виньетка и цветокоррекция по глубине ART-065 (`docs/concept-art/vinyetka.md`, числа — `vinyetka-lut.json`).
## Четыре аффинные таблицы `g = M·c + offset` (мель, средний слой, глубина, ил) смешиваются здесь, на CPU, по глубине
## камеры и `Silt.k`; из смеси собирается одна активная LUT 16³ полосой 256×16 RGBA8 (`lut_data`). Полноэкранный проход
## (`shaders/grade.gdshader`, рисует `GradeView` на CanvasLayer −1 — под интерфейсом) делает одну выборку LUT и поправку
## синего по столбцу `M[:,b]`, затем овал формулой с защитой огней. `shade` — то же самое на CPU для тестов.
## «Экономно» (ART-044) — без LUT, только овал силой `LITE`.

const SIZE := 16          ## узлов на ось
const WIDTH := SIZE * SIZE
const LITE := 0.10        ## сила овала на «Экономно»
const EPS := 0.002        ## насколько должна сдвинуться смесь, чтобы пересобрать LUT
const MEL_TO := 10.0      ## м — до этой глубины мель
const MID_AT := 25.0      ## м — средний слой целиком
const DEEP_AT := 45.0     ## м — глубина целиком

## Строки матрицы M (как в JSON художника), смещение и сила виньетки.
const PRESETS := {
	"mel": {"matrix": [[0.96, 0.015, 0.005], [0.005, 0.975, 0.012], [0.003, 0.008, 0.98]],
		"offset": [0.003, 0.006, 0.009], "vignette": 0.18},
	"sredniy": {"matrix": [[0.9, 0.025, 0.01], [0.005, 0.955, 0.02], [0.005, 0.02, 0.957]],
		"offset": [0.002, 0.009, 0.018], "vignette": 0.26},
	"glubina": {"matrix": [[0.82, 0.035, 0.015], [0.008, 0.88, 0.04], [0.008, 0.045, 0.925]],
		"offset": [0.002, 0.008, 0.022], "vignette": 0.34},
	"il": {"matrix": [[0.84, 0.06, 0.015], [0.025, 0.87, 0.035], [0.025, 0.06, 0.85]],
		"offset": [0.009, 0.014, 0.01], "vignette": 0.38},
}


## Смесь таблиц: матрица (столбцы Basis — столбцы M, `m * c` = M·c), смещение и сила виньетки.
class Mix:
	var m := Basis.IDENTITY
	var off := Vector3.ZERO
	var strength := 0.0

	func lerp_to(o: Mix, t: float) -> Mix:
		var r := Mix.new()
		r.m = Basis(m.x.lerp(o.m.x, t), m.y.lerp(o.m.y, t), m.z.lerp(o.m.z, t))
		r.off = off.lerp(o.off, t)
		r.strength = lerpf(strength, o.strength, t)
		return r

	func blue() -> Vector3:   ## столбец синего — поправка между узлами синего в шейдере
		return m.z

	func differs(o: Mix) -> bool:
		for d: Vector3 in [m.x - o.m.x, m.y - o.m.y, m.z - o.m.z, off - o.off]:
			if maxf(absf(d.x), maxf(absf(d.y), absf(d.z))) > EPS:
				return true
		return false


static func preset(key: String) -> Mix:
	var p: Dictionary = PRESETS[key]
	var a: Array = p.matrix
	var r := Mix.new()
	r.m = Basis(Vector3(a[0][0], a[1][0], a[2][0]), Vector3(a[0][1], a[1][1], a[2][1]), Vector3(a[0][2], a[1][2], a[2][2]))
	r.off = Vector3(p.offset[0], p.offset[1], p.offset[2])
	r.strength = p.vignette
	return r


## Смесь по глубине камеры (м) и илу 0…1: мель → средний `smoothstep(10,25)`, средний → глубина `smoothstep(25,45)`,
## поверх — иловая по `silt`.
static func blend(depth: float, silt: float = 0.0) -> Mix:
	var r: Mix
	if depth <= MID_AT:
		r = preset("mel").lerp_to(preset("sredniy"), smoothstep(MEL_TO, MID_AT, depth))
	else:
		r = preset("sredniy").lerp_to(preset("glubina"), smoothstep(MID_AT, DEEP_AT, depth))
	return r.lerp_to(preset("il"), clampf(silt, 0.0, 1.0))


## Активная LUT 256×16 RGBA8: узел (r,g,b) в (16·b + r, g), без клиппинга кроме 0…1.
static func lut_data(mix: Mix) -> PackedByteArray:
	var d := PackedByteArray()
	d.resize(WIDTH * SIZE * 4)
	for g in SIZE:
		for b in SIZE:
			for r in SIZE:
				var c := mix.m * (Vector3(r, g, b) / 15.0) + mix.off
				var i := ((g * WIDTH) + b * SIZE + r) * 4
				d[i] = roundi(clampf(c.x, 0.0, 1.0) * 255.0)
				d[i + 1] = roundi(clampf(c.y, 0.0, 1.0) * 255.0)
				d[i + 2] = roundi(clampf(c.z, 0.0, 1.0) * 255.0)
				d[i + 3] = 255
	return d


static func lut_image(mix: Mix) -> Image:
	return Image.create_from_data(WIDTH, SIZE, false, Image.FORMAT_RGBA8, lut_data(mix))


## Сила овала в точке экрана uv 0…1 (20:9): центр открыт, угол — полная сила.
static func edge(uv: Vector2) -> float:
	var p := (uv - Vector2(0.5, 0.5)) * 2.0
	return smoothstep(0.36, 1.28, (p * Vector2(0.90, 1.0)).length())


## Защита огней: яркое и холодное насыщенное (экраны, биолюм, пятно прожектора) — без коррекции и виньетки.
static func protect(c: Color) -> float:
	var peak := maxf(c.r, maxf(c.g, c.b))
	var cold := smoothstep(0.08, 0.22, minf(c.g, c.b) - c.r) * smoothstep(0.16, 0.38, peak)
	return maxf(smoothstep(0.38, 0.72, peak), cold)


static func luma(c: Vector3) -> float:
	return c.dot(Vector3(0.2126, 0.7152, 0.0722))


## Двойник шейдера: цвет кадра → цвет после прохода (LUT без квантования). `lite` — «Экономно».
static func shade(c: Color, uv: Vector2, mix: Mix, lite: bool = false) -> Color:
	var src := Vector3(c.r, c.g, c.b)
	var g := src
	var strength := LITE if lite else mix.strength
	var pr := protect(c)
	if not lite:
		g = (mix.m * src + mix.off).clamp(Vector3.ZERO, Vector3.ONE)
		g *= maxf(1.0, luma(src) / maxf(luma(g), 0.00001))   # не темнее исходной яркости
		g = g.lerp(src, pr)
	var amount := strength * edge(uv) * (1.0 - pr) * smoothstep(0.015, 0.09, luma(src))
	g *= Vector3(1.0 - amount, 1.0 - amount * 0.88, 1.0 - amount * 0.65)
	g = g.clamp(Vector3.ZERO, Vector3.ONE)
	return Color(g.x, g.y, g.z, 1.0)
