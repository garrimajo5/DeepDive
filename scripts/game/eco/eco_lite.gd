class_name EcoLite
extends RefCounted
## Два варианта меша вида для «Экономно» (#1798): смена уровня графики не пересобирает меш, а ставит заранее
## собранный. Вид держит `lite`, метод сборки (по `lite`) и список полей, которые сборка ставит, — `keys` (путь
## для `get_indexed`: "mesh", "rock:mesh"). `switch` сохраняет текущий вариант и ставит другой (нет в запасе —
## собирает), `prefetch` собирает второй вариант заранее и возвращает вид как был (EcoView — по одному виду за
## кадр, под шторкой прогрева). Материал у вариантов общий: сборка берёт его у вида, а не создаёт новый.

## Поля, которые сборка ставит (сохраняются копией: сборка чистит массивы на месте).
var keys: Array[String] = []
## Метод сборки вида по его `lite`.
var build := "_build"

var _saved := {}


func _init(fields: Array[String], method := "_build") -> void:
	keys = fields
	build = method


## Вариант on уже собран.
func has(on: bool) -> bool:
	return _saved.has(on)


## Поставить виду вариант on: текущий — в запас, on — из запаса или сборкой. true — собирали.
func switch(view: Object, on: bool) -> bool:
	if bool(view.get("lite")) == on:
		return false
	_save(view)
	view.set("lite", on)
	if _saved.has(on):
		_load(view, on)
		return false
	view.call(build)
	return true


## Собрать второй вариант заранее; вид остаётся как был. true — собирали (false — уже в запасе).
func prefetch(view: Object) -> bool:
	var on := bool(view.get("lite"))
	if _saved.has(not on):
		return false
	_save(view)
	view.set("lite", not on)
	view.call(build)
	_save(view)
	view.set("lite", on)
	_load(view, on)
	return true


func _save(view: Object) -> void:
	var d := {}
	for k in keys:
		d[k] = _copy(view.get_indexed(NodePath(k)))
	_saved[bool(view.get("lite"))] = d


func _load(view: Object, on: bool) -> void:
	var d: Dictionary = _saved[on]
	for k in keys:
		view.set_indexed(NodePath(k), _copy(d[k]))


## Массивы — копией (сборка и шаг вида чистят и пишут их на месте), остальное — как есть.
static func _copy(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY, TYPE_DICTIONARY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
				TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, \
				TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return v.duplicate()
	return v
