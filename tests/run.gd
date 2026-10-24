extends SceneTree
## Маленький раннер тестов без сторонних дополнений.
## Запуск: godot --headless --path . -s tests/run.gd [-- имя_файла_или_теста ...]
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
	Warmup.enabled = false       # без прогрева шейдеров: сценовые тесты считают шаги с первого (test_warmup включает)
	Main.menu = false    # без главного меню ART-037: забег сразу (его проверяет test_main_menu)
	Main.intro = false   # без облёта с борта в начале забега (его проверяет test_flyby)
	_run.call_deferred()


func _run() -> void:
	var trap := ErrorTrap.new()
	OS.add_logger(trap)
	var filters: Array = Array(OS.get_cmdline_user_args())
	var files: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var passed := 0
	var failed: Array[String] = []
	var t0 := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load(DIR + "/" + f)
		if script == null or not script.can_instantiate():
			failed.append("%s: скрипт не загрузился" % f)
			print("ПАДЕНИЕ  %s: скрипт не загрузился" % f)
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
			var t: TestCase = script.new()
			t.tree = self
			await t.before()
			await t.call(n)
			await t.after()
			var errs := trap.take()
			for e in errs:
				t.failures.append("ошибка движка: " + e)
			if t.failures.is_empty():
				passed += 1
				print("  ок     ", full)
			else:
				failed.append(full)
				print("ПАДЕНИЕ  ", full)
				for msg in t.failures:
					print("         - ", msg)
			# убрать то, что тест оставил в дереве
			for c in root.get_children():
				c.queue_free()
			await process_frame
	var ms := Time.get_ticks_msec() - t0
	print("\nТестов: %d, прошло: %d, упало: %d (%.1f с)" % [passed + failed.size(), passed, failed.size(), ms / 1000.0])
	for f in failed:
		print("  упал: ", f)
	OS.remove_logger(trap)
	quit(0 if failed.is_empty() and passed > 0 else 1)
