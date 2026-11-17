extends RefCounted
## Отпечаток состояния живого мира (#1400, (ан) из `docs/roles/dev-b.md`): полный мир 00 → 01 (`tools/crown_wait.gd`)
## на одном зерне идёт локально и на CI по-разному (зерно 1: тревога кроны 46,6 и 79,0 с). Чтобы найти первый
## расходящийся шаг и модуль, тест печатает в лог отпечаток раз в `EVERY` с мира, а здесь его же считают локально.
## Отпечаток — хэш точных байтов (`var_to_bytes`) переменных скрипта: модуля (`EcoSystem`), существ (`EcoAgent`) по
## видам и случая мира. Обход вглубь — массивы, словари и объекты RefCounted до `DEPTH`, каждый объект один раз;
## Callable, узлы и ресурсы пропускаются. Разница в один бит float — уже другой хэш.

## Отпечаток раз в столько секунд мира.
const EVERY := 10.0
## Глубина обхода вложенных массивов и объектов.
const DEPTH := 4


## Отпечаток мира `w`: имя части → хэш (8 знаков hex). Части: «случай», модули по `class_name` (повтор имени — с
## номером), «существа/<вид>».
static func of(w: EcoWorld) -> Dictionary:
	var out := {}
	out["случай"] = "%08x" % (w.random.state & 0xFFFFFFFF)
	for s in w.systems:
		var n := str(s.get_script().get_global_name())
		if n.is_empty():
			n = "модуль"
		var key := n
		var i := 2
		while out.has(key):
			key = "%s#%d" % [n, i]
			i += 1
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_MD5)
		_feed(ctx, s, DEPTH, {})   # свой обход у каждого модуля: общие объекты входят в каждый
		out[key] = ctx.finish().hex_encode().substr(0, 8)
	var by := {}
	var seen := {}
	for a in w.agents:
		if not by.has(a.species):
			var c := HashingContext.new()
			c.start(HashingContext.HASH_MD5)
			by[a.species] = c
		_feed(by[a.species], a, DEPTH, seen)
	for sp in by:
		out["существа/" + str(sp)] = (by[sp] as HashingContext).finish().hex_encode().substr(0, 8)
	return out


## Одна строка лога: время мира, общий хэш и все части — чтобы строку можно было сравнить с чужой целиком.
static func line(t: float, fp: Dictionary) -> String:
	var keys := fp.keys()
	keys.sort()
	var parts: Array[String] = []
	var all := HashingContext.new()
	all.start(HashingContext.HASH_MD5)
	for k in keys:
		parts.append("%s=%s" % [k, fp[k]])
		all.update(("%s=%s;" % [k, fp[k]]).to_utf8_buffer())
	return "отпечаток t=%.1f все=%s %s" % [t, all.finish().hex_encode().substr(0, 8), " ".join(parts)]


## Разбор строки `line`: {t, all, parts (имя → хэш)} или {} для чужой строки.
static func parse(s: String) -> Dictionary:
	var at := s.find("отпечаток t=")
	if at < 0:
		return {}
	var words := s.substr(at).split(" ", false)
	if words.size() < 3:
		return {}
	var r := {"t": float(words[1].trim_prefix("t=")), "all": words[2].trim_prefix("все="), "parts": {}}
	for i in range(3, words.size()):
		var kv := words[i].split("=")
		if kv.size() == 2:
			r["parts"][kv[0]] = kv[1]
	return r


## Первая расходящаяся точка двух серий строк: {t, parts (имена разошедшихся частей)} или {} — сошлись.
static func first_diff(a: Array, b: Array) -> Dictionary:
	var n := mini(a.size(), b.size())
	for i in n:
		var pa := parse(a[i])
		var pb := parse(b[i])
		if pa.is_empty() or pb.is_empty() or pa["all"] == pb["all"]:
			continue
		var names: Array[String] = []
		for k in pa["parts"]:
			if pb["parts"].get(k, "") != pa["parts"][k]:
				names.append(k)
		for k in pb["parts"]:
			if not pa["parts"].has(k):
				names.append(k)
		names.sort()
		return {"t": pa["t"], "parts": names}
	return {}


static func _feed(ctx: HashingContext, v: Variant, depth: int, seen: Dictionary) -> void:
	match typeof(v):
		TYPE_NIL, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return
		TYPE_OBJECT:
			var o: Object = v
			if o == null or not (o is RefCounted) or o is Resource or depth <= 0:
				return
			var id := o.get_instance_id()
			if seen.has(id):
				return
			seen[id] = true
			for pr in o.get_property_list():
				if pr["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
					ctx.update(str(pr["name"]).to_utf8_buffer())
					_feed(ctx, o.get(pr["name"]), depth - 1, seen)
		TYPE_ARRAY:
			if depth <= 0:
				return
			for x in v:
				_feed(ctx, x, depth - 1, seen)
		TYPE_DICTIONARY:
			if depth <= 0:
				return
			for k in v:
				if typeof(k) != TYPE_OBJECT:
					ctx.update(var_to_bytes(k))
				_feed(ctx, v[k], depth - 1, seen)
		_:
			ctx.update(var_to_bytes(v))
