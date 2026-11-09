extends TestCase
## Порядок в репозитории: разведочные скрипты сессий (`tools/_*.gd`) не попадают в main, у каждого `.uid` есть свой
## файл. Раньше в main попали `tools/_kr.gd` (разведка #1225) и `tools/_probe_turn.gd.uid` без скрипта.

const DIRS := ["res://tools", "res://tools/qa", "res://scripts/core", "res://scripts/core/eco", "res://scripts/game",
	"res://scripts/game/eco", "res://tests", "res://shaders"]


func test_no_orphan_uid() -> void:
	for dir: String in DIRS:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".uid"):
				var src := dir.path_join(f.trim_suffix(".uid"))
				ok(FileAccess.file_exists(src), "у %s есть свой файл" % dir.path_join(f))


func test_no_probe_scripts_in_tools() -> void:
	for f in DirAccess.get_files_at("res://tools"):
		ok(not f.begins_with("_"), "разведка сессии не в репозитории: tools/%s" % f)
