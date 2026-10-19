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
