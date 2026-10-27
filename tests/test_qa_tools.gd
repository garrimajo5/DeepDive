extends TestCase
## Скрипты тестера tools/qa/*.ps1: Windows PowerShell 5.1 читает UTF-8 без BOM как ANSI,
## и кириллица в строках ломает разбор (issue #37). Каждый .ps1 должен начинаться с BOM.

const DIR := "res://tools/qa"


func _ps1_files() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".ps1"):
			out.append(DIR.path_join(f))
	return out


func test_ps1_found() -> void:
	ok(_ps1_files().size() >= 2, "нашли run-qa.ps1 и publish-qa.ps1")


func test_ps1_start_with_bom() -> void:
	for path in _ps1_files():
		var b := FileAccess.get_file_as_bytes(path)
		ok(b.size() >= 3 and b[0] == 0xEF and b[1] == 0xBB and b[2] == 0xBF, "UTF-8 с BOM: %s" % path)


func test_ps1_valid_utf8() -> void:
	for path in _ps1_files():
		var b := FileAccess.get_file_as_bytes(path)
		var text := b.slice(3).get_string_from_utf8()
		ok(text.length() > 0 and text.contains("\n"), "читается как UTF-8: %s" % path)
		ok(not text.contains("﻿"), "BOM один, в начале: %s" % path)


## run-qa.ps1 ждёт done.txt N × 2 с. Сценарий рос, и ожидания (90 × 2 с) перестало хватать:
## при долгом прогреве после установки игра не доходила до конца (отчёт 2026-10-26-1233, done=False).
## Время сценария — сумма ожиданий и удержаний; сверху четверть на шаги и кадры и 30 с на запуск и прогрев.
func test_run_qa_waits_for_whole_scenario() -> void:
	var ps := FileAccess.get_file_as_bytes(DIR.path_join("run-qa.ps1")).slice(3).get_string_from_utf8()
	var re := RegEx.create_from_string("for \\(\\$i = 0; \\$i -lt (\\d+); \\$i\\+\\+\\) \\{\\s*\\n\\s*Start-Sleep (\\d+)")
	var m := re.search(ps)
	ok(m != null, "цикл ожидания done.txt найден")
	if m == null:
		return
	var budget := int(m.get_string(1)) * int(m.get_string(2))
	var steps: Array = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join("scenario.json")))
	var timed := 0.0
	for st in steps:
		if st.get("do", "") in ["wait", "hold", "drain", "swipe"]:
			timed += float(st.get("s", 0.0))
	var need := timed * 1.25 + 30.0
	ok(need <= budget, "ожидание %d с покрывает сценарий ~%.0f с" % [budget, need])


## #844: телефону — APK только с arm64-v8a, эмулятору тестера — отдельный только с x86_64 (≈27 МБ меньше на телефоне).
func test_two_apks_phone_and_emulator() -> void:
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK, "пресеты читаются")
	var arch := {}
	for i in 2:
		var sec := "preset.%d" % i
		var o := sec + ".options"
		arch[cfg.get_value(sec, "name")] = [cfg.get_value(o, "architectures/arm64-v8a"),
			cfg.get_value(o, "architectures/x86_64"), cfg.get_value(sec, "export_path")]
	eq(arch.get("Android"), [true, false, "build/DeepDive.apk"], "телефон — только arm64-v8a")
	eq(arch.get("Android эмулятор"), [false, true, "build/DeepDive-emulator.apk"], "эмулятор — только x86_64")
	var ci := FileAccess.get_file_as_string("res://.github/workflows/godot.yml")
	ok(ci.contains("--export-debug \"Android эмулятор\" build/DeepDive-emulator.apk"), "CI собирает APK эмулятора")
	ok(ci.contains("build/DeepDive.apk build/DeepDive-emulator.apk --clobber"), "в релиз — оба")
	var run := FileAccess.get_file_as_string("res://tools/qa/run-qa.ps1")
	ok(run.contains("'DeepDive-emulator.apk'"), "run-qa.ps1 ставит на эмулятор x86_64-сборку")
