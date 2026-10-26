class_name EcoSurface
## Матовость и влажность тел живого мира (Б2, `docs/grafika-plan-eco.md`): у каждого вида — правдоподобные
## шероховатость (`roughness`) и сила блика (`specular`) по тому, из чего он: мокрый панцирь краба и иглы шипоежа
## блестят, чешуя светляков и монетников — ещё ярче, слизистая кожа хищников влажная, тело хватня и внутренности
## стеклоуста — матово-влажные, губки и подушки — сухо-матовые. Раньше числа стояли наугад по видам (почти все —
## 0,95, как камень). Только числа: у StandardMaterial3D — свойства, у своих шейдеров — uniform `rough`/`spec`;
## ключи шейдеров не меняются, кадр не дороже — выключатель «Экономно» не нужен. Огоньки без света и чужие
## шейдеры (без uniform rough) не трогает. Места-ориентиры (камень, кости, раковина) держат свои числа.
## Проверяет `tests/test_eco_surface.gd`.

## Поверхности: [шероховатость, блик]. Блик 0,5 — обычный неметалл Godot.
const KINDS := {
	"панцирь": Vector2(0.35, 0.6),
	"чешуя": Vector2(0.3, 0.65),
	"кожа": Vector2(0.42, 0.55),
	"студень": Vector2(0.55, 0.4),
	"стекло": Vector2(0.12, 0.7),
	"губка": Vector2(0.9, 0.15),
	"камень": Vector2(0.8, 0.25),
	"лист": Vector2(0.55, 0.4),
	"стебель": Vector2(0.65, 0.35),
}

## Виды (имена узлов EcoView) → поверхности по имени сетки внутри; "*" — все прочие сетки вида.
const TABLE := {
	"Светляки": {"*": "чешуя"},
	"Скребуны": {"*": "панцирь"},
	"Серпохвосты": {"*": "кожа"},
	"Пиявники": {"*": "кожа"},
	"Веерники": {"*": "стебель"},
	"Гротовик": {"Панцирь": "панцирь", "Ноги": "панцирь", "Риф": "камень"},
	"Ледокрылы": {"*": "кожа"},
	"Присоски": {"*": "кожа"},
	"Эхоловец": {"*": "кожа"},
	"Волнолист": {"Листья": "лист", "Моллюски": "панцирь"},
	"Пузырчатка": {"Стебли": "стебель"},
	"Трубный орган": {"*": "губка"},
	"Подушечник": {"Подушки": "губка"},
	"Стеклоусты": {"Камни логов": "камень", "Оболочка": "стекло", "Внутренности": "студень", "Присоска": "кожа"},
	"Хватни": {"Тела": "студень", "Щупальца": "студень", "Пестрянки": "чешуя"},
	"Ленточник": {"Ленты": "лист", "Шипоежи": "панцирь", "Иглы": "панцирь"},
	"Кольчужник": {"Нора": "камень", "Тело": "панцирь", "Клешни": "панцирь", "Иглы": "панцирь"},
	"Скальник": {"*": "камень"},
	"Монетники": {"Монетники": "чешуя", "Глазуны": "кожа"},
}


## Поверхность сетки gi вида who ("" — не трогать).
static func kind_of(who: String, gi: String) -> String:
	var t: Dictionary = TABLE.get(who, {})
	return String(t.get(gi, t.get("*", "")))


## Расставить числа всем видам под root (EcoView). Повторный вызов (после пересборки по дну) безопасен.
static func apply(root: Node) -> void:
	for c in root.get_children():
		var who := String(c.name)
		if not TABLE.has(who):
			continue
		var gis: Array = [c] if c is GeometryInstance3D else []
		gis.append_array(c.find_children("*", "GeometryInstance3D", true, false))
		for gi in gis:
			var k := kind_of(who, String(gi.name))
			if k == "":
				continue
			for m in EcoRim.materials(gi as GeometryInstance3D):
				put(m, KINDS[k])


## Числа одному материалу (x — шероховатость, y — блик). Без света и чужие шейдеры не трогает; true — тронут.
static func put(m: Material, v: Vector2) -> bool:
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			return false
		b.roughness = v.x
		b.metallic_specular = v.y
		return true
	if m is ShaderMaterial and has_uniform(m as ShaderMaterial):
		(m as ShaderMaterial).set_shader_parameter("rough", v.x)
		(m as ShaderMaterial).set_shader_parameter("spec", v.y)
		return true
	return false


## Есть ли у шейдера материала uniform шероховатости и блика.
static func has_uniform(m: ShaderMaterial) -> bool:
	return m.shader != null and m.shader.code.contains("uniform float rough") \
			and m.shader.code.contains("uniform float spec")


## Числа материала сейчас: [шероховатость, блик] (для тестов; чужое — Vector2(-1, -1)).
static func read(m: Material) -> Vector2:
	if m is BaseMaterial3D:
		return Vector2((m as BaseMaterial3D).roughness, (m as BaseMaterial3D).metallic_specular)
	if m is ShaderMaterial and has_uniform(m as ShaderMaterial):
		var sm := m as ShaderMaterial
		return Vector2(float(sm.get_shader_parameter("rough")), float(sm.get_shader_parameter("spec")))
	return Vector2(-1, -1)
