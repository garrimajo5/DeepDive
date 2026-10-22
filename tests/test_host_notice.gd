extends TestCase
## Уведомления хоста о гостях (ART-043): «… отключился» 4 с, «… вернулся» 2 с, плашка тает в конце.


func test_left_shows_four_seconds() -> void:
	var n := HostNotice.new()
	ok(not n.active(), "сначала пусто")
	n.left("Игорь", true)
	ok(n.active())
	eq(n.title, "Игорь отключился")
	eq(n.sub, "Роль свободна · пост освобождён")
	n.update(3.9)
	ok(n.active(), "ещё видно на 3,9 с")
	n.update(0.2)
	ok(not n.active(), "через 4 с скрыто")


func test_left_without_post() -> void:
	var n := HostNotice.new()
	n.left("Ира", false)
	eq(n.sub, "Роль свободна", "поста не держал — только роль")
	n.left("Ира", false, true)
	eq(n.title, "Ира отключилась", "женская внешность")
	ok(n.joined("Ира", true))
	eq(n.title, "Ира вернулась")


func test_back_only_after_left() -> void:
	var n := HostNotice.new()
	ok(not n.joined("Игорь"), "новый гость — не «вернулся»")
	ok(not n.active())
	n.left("Игорь", false)
	n.update(5.0)
	ok(n.joined("Игорь"), "отключившийся вошёл снова")
	eq(n.title, "Игорь вернулся")
	eq(n.sub, "")
	n.update(1.9)
	ok(n.active(), "2 с")
	n.update(0.2)
	ok(not n.active())
	ok(not n.joined("Игорь"), "второй вход того же — уже не «вернулся»")


func test_newer_replaces_and_fades() -> void:
	var n := HostNotice.new()
	n.left("Игорь", true)
	n.update(1.0)
	n.left("Ира", false)
	eq(n.title, "Ира отключился", "новое сменяет прежнее")
	near(n.alpha(), 1.0, 0.001, "в начале непрозрачна")
	n.update(HostNotice.LEFT_TIME - HostNotice.FADE * 0.5)
	near(n.alpha(), 0.5, 0.01, "тает в конце")


func test_box_in_reference_screen() -> void:
	var r := NetDrop.to_screen(HostNotice.BOX, Vector2(2400, 1080))
	near(r.size.x, 1090.0, 0.5)
	near(r.size.y, 175.0, 0.5)
	near(r.position.y, 260.0, 0.5)
	near(r.get_center().x, 1200.0, 0.5, "по центру")
