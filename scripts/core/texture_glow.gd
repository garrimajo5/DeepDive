class_name TextureGlow
## Голубые места текстур художника светятся (огни голостола, кнопки пультов, рамка сканера), остальное — нет.
## Та же маска, что в shaders/tex_glow.gdshader: оттенок 0,45…0,56, насыщенность > 0,4, яркость > 0,55 (#67DDEB — 0,52 / 0,53 / 0,92).

const HUE_MIN := 0.45
const HUE_MAX := 0.56
const SAT_MIN := 0.4
const VAL_MIN := 0.55

## Модели мостика, у которых светятся голубые места (экраны пульта светятся целиком — отдельно).
const MODELS: Array[String] = ["golostol-korpus", "pult-pilota", "pult-energii", "polzunok", "skaner-biologa"]


static func glows(c: Color) -> bool:
	return c.h >= HUE_MIN and c.h <= HUE_MAX and c.s > SAT_MIN and c.v > VAL_MIN


## Доля светящихся пикселей текстуры (проверка, что маска ловит огни, а не металл).
static func share(img: Image, step: int = 4) -> float:
	var n := 0
	var all := 0
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			all += 1
			if glows(img.get_pixel(x, y)):
				n += 1
	return float(n) / maxf(all, 1)
