extends TestCase
## Угол в живом мире — на двойной точности (#1400, (ао)): `Vector3.angle_to` и `Vector2.angle_to` считают atan2f, а он
## разный в glibc облака (Ubuntu 24.04) и раннера CI (ubuntu-26.04) — полный мир расходился к 40 с (PR #1980).
## `EcoAgent.angle`/`angle2` — `atan2` GDScript, одинаковый на обеих машинах.


func test_angle_matches_godot() -> void:
	var rnd := EcoRandom.new(3)
	for i in 500:
		var a := Vector3(rnd.range_f(-5, 5), rnd.range_f(-5, 5), rnd.range_f(-5, 5))
		var b := Vector3(rnd.range_f(-5, 5), rnd.range_f(-5, 5), rnd.range_f(-5, 5))
		near(EcoAgent.angle(a, b), a.angle_to(b), 1e-5, "угол 3D %s %s" % [a, b])
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.y)
		near(EcoAgent.angle2(a2, b2), a2.angle_to(b2), 1e-5, "угол 2D со знаком %s %s" % [a2, b2])
	near(EcoAgent.angle(Vector3.FORWARD, Vector3.BACK), PI, 1e-6, "ровно назад — π")
	eq(EcoAgent.angle(Vector3.UP, Vector3.UP), 0.0, "тот же курс — 0")
	ok(EcoAgent.angle2(Vector2.RIGHT, Vector2.DOWN) > 0.0, "знак как у Vector2.angle_to")


## Ни одного float32-угла (atan2f) в логике живого мира: `angle_to` и `Vector2.angle()` в `scripts/core/eco/` нет.
func test_no_float_angle_in_world() -> void:
	var bad: Array[String] = []
	var dir := "res://scripts/core/eco/"
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		var lines := FileAccess.get_file_as_string(dir + f).split("\n")
		for i in lines.size():
			var code := lines[i].split("#")[0]
			if code.contains(".angle_to(") or code.contains(".angle()") or code.contains(".slerp("):
				bad.append("%s:%d" % [f, i + 1])
	ok(bad.is_empty(), "float32-угол в мире: %s" % [bad])
