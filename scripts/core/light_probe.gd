class_name LightProbe
## Проба света сцены 00 → 01 (#1400, черновая PR, не сливать): три варианта на одном пути и позе для сравнения
## на телефоне. Решение гейм-дизайнера 10.11: вода (цвет тумана и фона) ×0,72 и рассеянный ×0,8 — первый вариант,
## прожектор 5 — отдельный сравниваемый, не окончательное число. Перелив воды по вертикали — светлее ко льду,
## темнее вниз, плавно (`WaterLayers.tilt_k`). Альбедо песка не трогаем.
## Переключают шаг сценария `svet` (tools/qa/svet-1400.json) и ключ снимка `svet=`.

enum Kind { BASE, WATER, WATER_SPOT }

const NAMES: Array[String] = ["исходное", "вода ×0,72, рассеянный ×0,8, перелив", "вода + прожектор 5"]
const WATER_K := 0.72
const AMBIENT_K := 0.8
const SPOT := 5.0
## Перелив: ±TILT к цвету тумана, когда луч смотрит прямо вверх / вниз; у горизонта — 1.
const TILT := 0.3

static var kind: int = Kind.BASE
## Растёт при каждой смене — `OceanView.apply_water` пишет воду заново.
static var rev := 0


static func set_kind(k: int) -> void:
	k = clampi(k, 0, NAMES.size() - 1)
	if k != kind:
		kind = k
		rev += 1


static func water_k() -> float:
	return 1.0 if kind == Kind.BASE else WATER_K


static func ambient_k() -> float:
	return 1.0 if kind == Kind.BASE else AMBIENT_K


static func tilt() -> float:
	return 0.0 if kind == Kind.BASE else TILT


static func spot_energy() -> float:
	return SPOT if kind == Kind.WATER_SPOT else Searchlight.ENERGY


static func line() -> String:
	return "свет #1400: вариант %d — %s" % [kind, NAMES[kind]]
