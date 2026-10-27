extends TestCase
## Общая плашка экранных панелей (UiStyle): те же скругления, рамки и цвета, что панели собирали сами.


func test_box_border_only_with_width() -> void:
	var plain := UiStyle.box(Color.BLACK, 12.4)
	eq(plain.get_corner_radius(CORNER_TOP_LEFT), 12, "скругление округлено")
	eq(plain.get_border_width(SIDE_LEFT), 0, "без толщины — без рамки (заливка до края)")
	var framed := UiStyle.box(Color.BLACK, 12.0, Color.RED, 0.3)
	eq(framed.get_border_width(SIDE_TOP), 1, "рамка не тоньше пикселя")
	eq(framed.border_color, Color.RED, "цвет рамки")
	eq(UiStyle.box(Color.BLACK, 8.0, Color.RED, 2.6).get_border_width(SIDE_BOTTOM), 3, "толщина округлена")


func test_menu_button() -> void:
	var main := UiStyle.menu_button(true, 2.0)
	eq(main.bg_color, MainMenu.MAIN, "главная — голубая")
	eq(main.get_border_width(SIDE_LEFT), 0, "без рамки")
	eq(main.get_corner_radius(CORNER_BOTTOM_RIGHT), roundi(MainMenu.RADIUS * 2.0), "скругление по раскладке")
	var off := UiStyle.menu_button(false, 1.0, 0.6, 0.6, 0.5)
	eq(off.bg_color, Color(MainMenu.PANEL, 0.3), "погашенная панель, затухание экрана")
	eq(off.border_color, Color(MainMenu.EDGE, 0.3), "рамка тоже")
	eq(off.get_border_width(SIDE_TOP), 2, "рамка 2 px при s = 1")
	eq(UiStyle.dialog(1.0).bg_color, Color(MainMenu.PANEL, 0.97), "окно подтверждения почти непрозрачно")


func test_palette_shared() -> void:
	eq(CommsPanel.TEXT, UiStyle.TEXT, "связь — общий цвет текста")
	eq(RadioPanel.ACCENT, UiStyle.ACCENT, "рация — общий акцент")
