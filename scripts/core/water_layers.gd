class_name WaterLayers
## Слои воды по ART-069 (`docs/concept-art/sloi-vody.md`, `sloi-vody.json`): подлёдная муть 0…6 м, термоклин
## 28,5…31,5 м и придонная пыль 0…3 м над дном добавляются к туману по глубине ART-059 в материалах дна, льда и
## дальней воды (`OceanView`) — 0 новых вызовов. Плотность слоя интегрируется аналитически вдоль отрезка
## камера → точка (профиль — разность двух smoothstep), поэтому вверх и вниз с одной глубины видно разное.
## Шейдер — `shaders/water_layers.gdshaderinc`; здесь числа и двойник формул для тестов.
## Запись FOG в шейдере заменяет штатный туман — база ART-059 `1 − exp(−dist · density)` восстанавливается там же.

## Слой по мировой y (лёд y = 0): [низ, верх], мягкость краёв (м), добавочная плотность (1/м), предел альфы, цвет.
const ICE := {"y": Vector2(-6.0, 0.0), "edge": 1.5, "density": 0.008, "cap": 0.11, "color": Color("3A8190")}
const THERMO := {"y": Vector2(-31.5, -28.5), "edge": 1.0, "density": 0.017, "cap": 0.10, "color": Color("234F69")}
## Пыль — по высоте над дном (`Seabed.mesh_height`), не ближе PROTECT к камере (камни в пятне прожектора видны).
const DUST := {"y": Vector2(0.0, 3.0), "edge": 1.0, "density": 0.035, "cap": 0.10, "color": Color("2B5359")}
const PROTECT := Vector2(12.0, 45.0)
const TOTAL_CAP := 0.16
## Дрожание термоклина ±0,12 м: sin(x·0,09 + t·0,25)·sin(z·0,07 − t·0,15), периоды ≈ 25 и 42 с.
const WAVE := 0.12
## Расширение края слоя с расстоянием (`edge`): с SPREAD_FROM м по SPREAD м на метр, не больше SPREAD_MAX.
const SPREAD_FROM := 60.0
const SPREAD := 0.1
const SPREAD_MAX := 30.0
## Сила по уровням ART-044: «Экономно» 0 (шейдер без расчёта слоёв), «Обычно» 0,6, «Красиво» 0,9.
const GAIN_LITE := 0.0
const GAIN_NORMAL := 0.6
const GAIN_BEAUTIFUL := 0.9
## Ил главнее: добавки × (1 − 0,85·Silt.k).
const SILT_DIM := 0.85


## Сила слоёв по уровню и илу.
static func gain(level: float, silt: float) -> float:
	return maxf(level, 0.0) * clampf(1.0 - SILT_DIM * silt, 0.0, 1.0)


## ∫ smoothstep(a, b, y) dy от a до y.
static func soft_integral(y: float, a: float, b: float) -> float:
	if y <= a:
		return 0.0
	if y >= b:
		return y - (a + b) * 0.5
	var t := (y - a) / (b - a)
	return (b - a) * (t * t * t - 0.5 * t * t * t * t)


## Первообразная профиля слоя [lo, hi] с мягкими краями e.
static func band_integral(y: float, lo: float, hi: float, e: float) -> float:
	return soft_integral(y, lo - e, lo + e) - soft_integral(y, hi - e, hi + e)


## Мягкость края подлёдного слоя и термоклина для точки на расстоянии dist (issue #516): e + clamp((dist − 60)·0,1, 0, 30).
## Ближе 60 м — край ART-069; к дальней воде (380 м) граница слоя размыта на ±30 м — у горизонта мягкая полоса, не
## линия: без этого луч дотягивался до слоя в угле 0,3°. Толщина слоя (интеграл профиля) та же.
static func edge(e: float, dist: float) -> float:
	return e + clampf((dist - SPREAD_FROM) * SPREAD, 0.0, SPREAD_MAX)


## Профиль слоя в точке y: 1 внутри, 0 снаружи, smoothstep на краях.
static func band(y: float, lo: float, hi: float, e: float) -> float:
	return smoothstep(lo - e, lo + e, y) - smoothstep(hi - e, hi + e, y)


## Сколько метров отрезка длиной len (по высоте от ya до yb) лежит в слое — с весом профиля.
static func band_length(ya: float, yb: float, len: float, lo: float, hi: float, e: float) -> float:
	var dy := yb - ya
	if absf(dy) < 0.0001:
		return band(ya, lo, hi, e) * len
	return maxf(0.0, (band_integral(yb, lo, hi, e) - band_integral(ya, lo, hi, e)) / dy * len)


## Альфа слоя с мягким пределом: cap·(1 − exp(−τ/cap)) — у нуля как 1 − exp(−τ), к cap подходит плавно.
## У художника был min(cap, 1 − exp(−τ)): излом производной давал резкую линию у горизонта на снимке 30 м.
static func soft_cap(tau: float, cap: float) -> float:
	return cap * (1.0 - exp(-tau / cap))


## Сдвиг термоклина в точке p (м) в момент t (с).
static func wave(p: Vector3, t: float) -> float:
	return WAVE * sin(p.x * 0.09 + t * 0.25) * sin(p.z * 0.07 - t * 0.15)


## Альфа и цвет добавки на отрезке камера cam → точка p. cam_above — высота камеры над дном, p_above — точки
## (у дна 0). Возвращает [альфа до силы, цвет]; итог — `mix`.
static func add(cam: Vector3, p: Vector3, cam_above: float, p_above: float, t: float = 0.0) -> Array:
	var dist := cam.distance_to(p)
	var w := wave(p, t)
	var li := band_length(cam.y, p.y, dist, ICE.y.x, ICE.y.y, edge(ICE.edge, dist))
	var lt := band_length(cam.y, p.y, dist, THERMO.y.x + w, THERMO.y.y + w, edge(THERMO.edge, dist))
	var ld := band_length(cam_above, p_above, dist, DUST.y.x, DUST.y.y, DUST.edge)
	var ai := soft_cap(li * ICE.density, ICE.cap)
	var at := soft_cap(lt * THERMO.density, THERMO.cap)
	var ad := soft_cap(ld * DUST.density, DUST.cap) * smoothstep(PROTECT.x, PROTECT.y, dist)
	var total := ai + at + ad
	var c := Color(0, 0, 0)
	if total > 0.00001:
		var ci: Color = ICE.color.srgb_to_linear()
		var ct: Color = THERMO.color.srgb_to_linear()
		var cd: Color = DUST.color.srgb_to_linear()
		c = Color(
			(ci.r * ai + ct.r * at + cd.r * ad) / total,
			(ci.g * ai + ct.g * at + cd.g * ad) / total,
			(ci.b * ai + ct.b * at + cd.b * ad) / total)
	return [total, c]


## Итоговый туман (линейный цвет, альфа) — как FOG в шейдере: база ART-059 и добавка поверх.
## base_color — цвет тумана в линейном виде, density — env.fog_density, g — gain().
static func fog(cam: Vector3, p: Vector3, cam_above: float, p_above: float, base_color: Color, density: float,
		g: float, t: float = 0.0) -> Array:
	var a0 := 1.0 - exp(-cam.distance_to(p) * density)
	if g <= 0.0:
		return [a0, base_color]
	var r := add(cam, p, cam_above, p_above, t)
	var la := clampf(float(r[0]) * g, 0.0, TOTAL_CAP)
	var cl: Color = r[1]
	var a := a0 + la * (1.0 - a0)
	if a <= 0.00001:
		return [0.0, base_color]
	var k0 := a0 * (1.0 - la) / a
	var k1 := la / a
	return [a, Color(base_color.r * k0 + cl.r * k1, base_color.g * k0 + cl.g * k1, base_color.b * k0 + cl.b * k1)]
