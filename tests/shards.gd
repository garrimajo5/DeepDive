class_name TestShards
extends RefCounted
## Части прогона тестов для CI (#845): файлы tests/test_*.gd делятся на n частей по сумме времени.
## Время файлов — tests/vremya.txt (строка «файл<TAB>секунды»), его пишет `run.gd -- --times tests/vremya.txt`.
## Новый файл, которого нет в таблице, весит как средний. Раскладка жадная: самые долгие — в самую лёгкую часть.
## Детерминирована: одинаковый список и таблица дают одинаковые части на всех машинах матрицы.

const TIMES := "res://tests/vremya.txt"


## Разобрать «i/n» (i с 1). Неверное — пустой массив.
static func parse(spec: String) -> Array[int]:
	var p := spec.split("/")
	if p.size() != 2 or not p[0].is_valid_int() or not p[1].is_valid_int():
		return []
	var i := p[0].to_int()
	var n := p[1].to_int()
	if n < 1 or i < 1 or i > n:
		return []
	return [i, n]


## Таблица времени из текста «файл<TAB>секунды» (пустые строки и # пропускаются).
static func read_times(text: String) -> Dictionary:
	var out := {}
	for line in text.split("\n"):
		var s := line.strip_edges()
		if s.is_empty() or s.begins_with("#"):
			continue
		var p := s.split("\t")
		if p.size() == 2 and p[1].is_valid_float():
			out[p[0]] = p[1].to_float()
	return out


static func load_times(path: String = TIMES) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return read_times(FileAccess.get_file_as_string(path))


## Текст таблицы по замеру (отсортирован по имени — диф в PR читается).
static func write_times(times: Dictionary) -> String:
	var names := times.keys()
	names.sort()
	var s := "# Время файлов тестов, с — для частей CI (#845). Обновить: run.gd -- --times tests/vremya.txt\n"
	for f in names:
		s += "%s\t%.2f\n" % [f, times[f]]
	return s


## Вес файла: из таблицы, иначе средний по таблице (пустая таблица — 1).
static func weight(file: String, times: Dictionary) -> float:
	if times.has(file):
		return times[file]
	if times.is_empty():
		return 1.0
	var sum := 0.0
	for v in times.values():
		sum += v
	return sum / times.size()


## Разложить файлы на n частей. Возвращает n списков (каждый отсортирован по имени).
static func split(files: Array[String], times: Dictionary, n: int) -> Array:
	var order := files.duplicate()
	order.sort_custom(func(a, b):   # тяжёлые первыми, равные — по имени: раскладка одна на всех машинах
		var wa := weight(a, times)
		var wb := weight(b, times)
		return wa > wb or (wa == wb and a < b))
	var parts: Array = []
	var load_s: Array[float] = []
	for k in n:
		parts.append([] as Array[String])
		load_s.append(0.0)
	for f in order:
		var best := 0
		for k in range(1, n):
			if load_s[k] < load_s[best]:
				best = k
		parts[best].append(f)
		load_s[best] += weight(f, times)
	for p in parts:
		p.sort()
	return parts


## Файлы части i из n (i с 1).
static func pick(files: Array[String], times: Dictionary, i: int, n: int) -> Array[String]:
	var part: Array[String] = []
	part.assign(split(files, times, n)[i - 1])
	return part


## Самые долгие тесты (не файлы) для `run.gd -- --slow N`: N пар [имя, секунды], долгие первыми,
## равные — по имени. N < 1 — пусто.
static func slowest(test_s: Dictionary, n: int) -> Array:
	var names := test_s.keys()
	names.sort_custom(func(a, b): return test_s[a] > test_s[b] or (test_s[a] == test_s[b] and a < b))
	var out: Array = []
	for k in mini(maxi(n, 0), names.size()):
		out.append([names[k], test_s[names[k]]])
	return out


## Текст для вывода: «  12.3 с  test_x.test_y» по строке, с заголовком.
static func slow_text(test_s: Dictionary, n: int) -> String:
	var top := slowest(test_s, n)
	if top.is_empty():
		return ""
	var s := "Самые долгие тесты (%d):\n" % top.size()
	for p in top:
		s += "  %6.1f с  %s\n" % [p[1], p[0]]
	return s


# Строки раннера про файл теста, который не загрузился (#1350): причина из ошибок движка, пойманных при load
# (без «Failed to load» — это лишь следствие), и команда, которая покажет все ошибки разбора.
static func load_fail(file: String, errors: Array) -> Array[String]:
	var out: Array[String] = ["ПАДЕНИЕ  %s: скрипт не загрузился" % file]
	var why: Array[String] = []
	for e in errors:
		var t := String(e)
		if not t.begins_with("Failed to load script") and not why.has(t):
			why.append(t)
	for t in why.slice(0, 5):
		out.append("         - причина: " + t)
	out.append("         - подробно: godot --headless --path . --check-only -s tests/" + file)
	return out


# Фильтр раннера из аргумента (#1350): «tests/test_helm.gd» и «test_helm.gd» значат файл test_helm — путь
# и расширение срезаем, иначе фильтр не совпадёт ни с одним «файл.тест» и прогон выйдет «0 из 0».
static func filter_arg(arg: String) -> String:
	var s := arg.get_file() if arg.contains("/") else arg
	return s.trim_suffix(".gd")


# Строка раннера, когда фильтры не выбрали ни одного теста: прогон красный и говорит почему (#1350).
static func no_match(filters: Array) -> String:
	var names: Array[String] = []
	for f in filters:
		names.append("«%s»" % f)
	return "Фильтр %s не нашёл ни одного теста — проверьте имя (файл без .gd или часть имени теста)" % ", ".join(names)
