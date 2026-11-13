extends SceneTree
## Маленький раннер тестов без сторонних дополнений.
## Запуск: godot --headless --path . -s tests/run.gd [-- имя_файла_или_теста ...]
## Фильтр — часть имени «файл.тест»; путь и .gd срезаются, ни одного теста — ошибка с объяснением (#1350).
## Часть прогона для CI (#845): `-- --shard 2/3` — файлы части 2 из 3 по сумме времени (`TestShards`).
## Замер времени файлов: `-- --times tests/vremya.txt` — после прогона пишет таблицу для раскладки частей.
## Сообщения пройденных проверок: `-- --say` — под «ок» строки `ok`/`eq`/`near` со своим сообщением (замер виден в логе).
## Самые долгие тесты: `-- --slow 20` — после прогона печатает 20 самых долгих тестов (не файлов), `TestShards.slowest`.
## Берёт все tests/test_*.gd, в каждом — методы test_*. Ошибка движка во время теста (null, неверный тип и т. п.)
## тоже валит тест: её ловит свой Logger. Код выхода 0 — всё зелёное, 1 — есть падения.

const DIR := "res://tests"


class ErrorTrap:
	extends Logger
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s (%s:%d %s)" % [rationale if rationale else code, file.get_file(), line, function])
		_mutex.unlock()

	func take() -> Array[String]:
		_mutex.lock()
		var e := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return e


func _initialize() -> void:
	SaveGame.default_path = ""   # не читать и не писать сохранение игрока
	AddressScreen.default_path = ""   # и последний адрес входа ART-039
	Settings.default_path = ""   # и настройки ART-037
	RunTimeline.default_path = ""   # и хронометраж забегов (#633)
	Warmup.enabled = false       # без прогрева шейдеров: сценовые тесты считают шаги с первого (test_warmup включает)
	Main.menu = false    # без главного меню ART-037: забег сразу (его проверяет test_main_menu)
	Main.intro = false   # без облёта с борта в начале забега (его проверяет test_flyby)
	Main.hints = false   # без подсказок первого забега ART-038 (их проверяет test_tutorial)
	Main.offer = false   # без предложения «Экономно» ART-044 (его проверяет test_lite_offer)
	_run.call_deferred()


func _run() -> void:
	var trap := ErrorTrap.new()
	OS.add_logger(trap)
	var filters: Array = []
	var shard: Array[int] = []
	var times_out := ""
	var slow_n := 0
	var args := Array(OS.get_cmdline_user_args())
	var a := 0
	while a < args.size():
		var arg: String = args[a]
		if arg == "--say":
			TestCase.say = true
			a += 1
		elif arg == "--shard" and a + 1 < args.size():
			shard = TestShards.parse(args[a + 1])
			if shard.is_empty():
				print("Неверная часть «%s»: нужно i/n, например 2/3" % args[a + 1])
				quit(1)
				return
			a += 2
		elif arg == "--times" and a + 1 < args.size():
			times_out = args[a + 1]
			a += 2
		elif arg == "--slow" and a + 1 < args.size():
			if not args[a + 1].is_valid_int() or args[a + 1].to_int() < 1:
				print("Неверное число «%s»: нужно --slow N, N ≥ 1" % args[a + 1])
				quit(1)
				return
			slow_n = args[a + 1].to_int()
			a += 2
		else:
			filters.append(TestShards.filter_arg(arg))
			a += 1
	var files: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	if not shard.is_empty():
		files = TestShards.pick(files, TestShards.load_times(), shard[0], shard[1])
		print("Часть %d из %d: файлов %d" % [shard[0], shard[1], files.size()])
	var file_ms := {}
	var test_s := {}
	var passed := 0
	var failed: Array[String] = []
	var t0 := Time.get_ticks_msec()
	for f in files:
		var f0 := Time.get_ticks_msec()
		trap.take()
		var script: GDScript = load(DIR + "/" + f)
		if script == null or not script.can_instantiate():
			failed.append("%s: скрипт не загрузился" % f)
			for line in TestShards.load_fail(f, trap.take()):
				print(line)
			continue
		var names: Array[String] = []
		for m in script.get_script_method_list():
			var n: String = m["name"]
			if n.begins_with("test_") and not names.has(n):
				names.append(n)
		for n in names:
			var full := "%s.%s" % [f.get_basename(), n]
			if not filters.is_empty() and not filters.any(func(s): return full.contains(s)):
				continue
			trap.take()
			var n0 := Time.get_ticks_msec()
			var t: TestCase = script.new()
			t.tree = self
			await t.before()
			await t.call(n)
			await t.after()
			test_s[full] = (Time.get_ticks_msec() - n0) / 1000.0
			var errs := trap.take()
			for e in errs:
				t.failures.append("ошибка движка: " + e)
			if t.failures.is_empty():
				passed += 1
				print("  ок     ", full)
				for msg in t.spoken:
					print("         · ", msg)
			else:
				failed.append(full)
				print("ПАДЕНИЕ  ", full)
				for msg in t.failures:
					print("         - ", msg)
			# убрать то, что тест оставил в дереве
			for c in root.get_children():
				c.queue_free()
			await process_frame
		file_ms[f] = (Time.get_ticks_msec() - f0) / 1000.0
	var ms := Time.get_ticks_msec() - t0
	print("\nТестов: %d, прошло: %d, упало: %d (%.1f с)" % [passed + failed.size(), passed, failed.size(), ms / 1000.0])
	for f in failed:
		print("  упал: ", f)
	if passed + failed.size() == 0 and not filters.is_empty():
		print(TestShards.no_match(filters))
	if slow_n > 0:
		print("\n", TestShards.slow_text(test_s, slow_n))
	if not times_out.is_empty():
		var fa := FileAccess.open(times_out, FileAccess.WRITE)
		if fa:
			fa.store_string(TestShards.write_times(file_ms))
			print("Время файлов записано: ", times_out)
	OS.remove_logger(trap)
	quit(0 if failed.is_empty() and passed > 0 else 1)
