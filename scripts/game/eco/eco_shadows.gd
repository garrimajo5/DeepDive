class_name EcoShadows
## Тени живого мира (Б1, `docs/grafika-plan-eco.md`): «герои» и места-ориентиры отбрасывают тень света сквозь лёд
## на дно — сидят на нём, видны глубина и вес. Фон, стаи, мелочь, огоньки и прозрачное — без тени: каждый узел
## с тенью — ещё вызов отрисовки на каскад. На «Экономно» тени гасит сам свет (Graphics «shadows» = 0), поэтому
## отдельный выключатель у мира не нужен. Список и потолок проверяет `tests/test_eco_shadows.gd`.

## Виды и места (имена узлов EcoView), чьи тела отбрасывают тень.
const HEROES: Array[String] = ["Серпохвосты", "Ледокрылы", "Гротовик", "Скальник", "Кольчужник", "Эхоловец",
		"Кости левиафана", "Раковина древних"]
## Потолок узлов мира с тенью (каждый — вызов отрисовки в каждом каскаде).
const BUDGET := 24


## Включить (или погасить) тень узла.
static func cast(gi: GeometryInstance3D, on := true) -> void:
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Все узлы под root, что отбрасывают тень.
static func casters(root: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	if root is GeometryInstance3D and (root as GeometryInstance3D).cast_shadow != \
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		out.append(root)
	for c in root.get_children():
		out.append_array(casters(c))
	return out
