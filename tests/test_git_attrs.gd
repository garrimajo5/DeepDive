extends TestCase
## `.gitattributes`: строки CHANGELOG.md из двух веток под одной датой сливаются без конфликта (#1379).
## Действует при локальном merge/rebase (влить свежий main в ветку); сервер GitHub его не читает.


func test_changelog_merges_by_union() -> void:
	var text := FileAccess.get_file_as_string("res://.gitattributes")
	ok(text != "", ".gitattributes читается")
	ok("CHANGELOG.md merge=union" in text.split("\n"), "CHANGELOG.md merge=union")
	ok("*.png binary" in text.split("\n"), "картинки по-прежнему двоичные")
