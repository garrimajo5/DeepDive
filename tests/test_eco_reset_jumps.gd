extends TestCase
## Б3 «плавность», общая проверка всего мира (поток Б): после сброса (новый забег, загрузка, перестройка по дну)
## ни одно существо и ни один центр стаи не прыгает. Раньше рывки на первых шагах ловили по одному виду (вуали,
## стеклоуст, радужники, огнёвки, центры стай и облаков — #1104…#1108, от 9 до 264 м/с); здесь — все системы
## `EcoView` разом, чтобы новый вид с той же ошибкой не прошёл. Смотрим поля-векторы мест у элементов массивов
## системы (`KEYS`) и векторы-поля самой системы. Скорость — по окну LOD_EVERY шагов: дальние стаи шагают раз в три
## кадра (`EcoFish`), за кадр они «прыгают» втрое, но по окну идут ровно. Смотрим первые секунды мира — сюда же
## попадают смены цели вскоре после старта: так нашёлся рывок огнёвок к хищнику на чистке (26 м/с, `EcoOgnevka.DART`).

## Имена полей с местом у элементов массивов систем.
const KEYS := ["p", "pos", "c", "head", "center", "body"]
## Окно, шагов: дальние шагают раз в три кадра.
const LOD_EVERY := 3
## Быстрее этого (м/с) по окну не ходит никто: бросок серпохвоста — 9 м/с, рывок рыбки от хищника — до 12.
const MAX_SPEED := 15.0
const DT := 1.0 / 30.0


## Все места мира: «система.поле[i].место» → вектор (только конечные: «нет цели» — INF).
static func spots(w: EcoWorld) -> Dictionary:
	var out := {}
	for s in w.systems:
		var sname: String = s.get_script().get_global_name()
		for prop in s.get_property_list():
			if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var v = s.get(prop.name)
			var tag := "%s.%s" % [sname, prop.name]
			if v is Array:
				for i in v.size():
					_take(out, "%s[%d]" % [tag, i], v[i])
			elif v is Vector3:
				_put(out, tag, v)
			elif v is RefCounted and not (v is EcoSystem):
				_take(out, tag, v)
	return out


## Места одного элемента: поля KEYS, место агента, голова тела из звеньев.
static func _take(out: Dictionary, tag: String, e) -> void:
	if not (e is Object) or e is EcoSystem:
		return
	for k in KEYS:
		var pv = e.get(k)
		if pv is Vector3:
			_put(out, "%s.%s" % [tag, k], pv)
	var a = e.get("agent")
	if a is EcoAgent:
		_put(out, tag + ".agent", a.p)
	var segs = e.get("segs")
	if segs is PackedVector3Array and segs.size() > 0:
		_put(out, tag + ".segs[0]", segs[0])
		_put(out, tag + ".segs[-1]", segs[segs.size() - 1])


static func _put(out: Dictionary, tag: String, v: Vector3) -> void:
	if v.is_finite():
		out[tag] = v


## Самый быстрый ход по окну за seconds с после сброса: [м/с, имя].
func _worst_after_reset(at: Vector3, seconds: float) -> Array:
	var ev := EcoView.new()
	ev.world.ship.pos = at
	ev.ground = Seabed.height  # как в игре: сброс мира по дну
	var w := ev.world
	var hist: Array[Dictionary] = [spots(w)]
	var worst := 0.0
	var who := ""
	for i in int(seconds / DT):
		w.step(DT)
		hist.append(spots(w))
		if hist.size() > LOD_EVERY + 1:
			hist.pop_front()
		if hist.size() < LOD_EVERY + 1:
			continue
		var a: Dictionary = hist[0]
		var b: Dictionary = hist[hist.size() - 1]
		for k in b:
			if a.has(k):
				var sp: float = (b[k] as Vector3).distance_to(a[k]) / (DT * LOD_EVERY)
				if sp > worst:
					worst = sp
					who = "%s на шаге %d" % [k, i]
	ev.free()
	return [worst, who]


func test_spots_cover_all_moving_species() -> void:
	var ev := EcoView.new()
	ev.ground = Seabed.height
	var names := {}
	for k in spots(ev.world):
		names[k.split(".")[0]] = true
	ev.free()
	for sys in ["EcoFish", "EcoPred", "EcoGrazer", "EcoVeil", "EcoEel", "EcoRaduzh", "EcoOgnevka", "EcoRay",
			"EcoRemora", "EcoPlankton", "EcoCoins", "EcoKrab", "EcoSkalnik", "EcoGrot", "EcoDome"]:
		ok(names.has(sys), "проверка видит места %s" % sys)


func test_no_jump_after_reset_at_start() -> void:
	var r := _worst_after_reset(LayerMap.at("00"), 3.0)
	ok(r[0] < MAX_SPEED, "у старта 00 после сброса без рывков: %.1f м/с (%s)" % r)


func test_no_jump_after_reset_far_from_start() -> void:
	# у Светового колодца 05: рядом моль и ледокрыл, а стаи у старта — дальние, шагают по LOD
	var r := _worst_after_reset(LayerMap.at("05"), 2.0)
	ok(r[0] < MAX_SPEED, "у колодца 05 после сброса без рывков: %.1f м/с (%s)" % r)
