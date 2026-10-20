class_name VoteHolo
extends RefCounted
## Голосование на голограмме над голостолом (ART-016, лист `golostol-sostoyaniya.png`, «Голосование»): пока экипаж
## решает «глубже или наверх», рельеф сонара гаснет, над столом — два поля: «ГЛУБЖЕ» (стрелка вниз) и «НАВЕРХ»
## (стрелка вверх). Под полем — метки голосов: кружок цвета роли с буквой (`Crew.ROLE_COLORS`) и счёт.
## В одиночной игре голоса ролей — их мнения (`Run.opinions`), решает игрок; таймер — с сетью (этап «Кооп»).
## Здесь — числа и раскладка без узлов, в осях голограммы (`SonarView`: центр стола, y — от её плоскости);
## рисует `scripts/game/vote_view.gd`.

## Поля стоят поперёк взгляда от поста «Маршрут» (+X от стола, взгляд к −X): «глубже» — слева (+Z), «наверх» —
## справа (−Z), как на листе.
const SPREAD := 0.36       ## от центра стола до центра поля, м
const DISC_Y := 0.50       ## диск поля над плоскостью голограммы, м
const DISC_R := 0.17
const ARROW_Y := 0.70      ## центр стрелки
const ARROW_H := 0.22
const WORD_Y := 0.86       ## подпись поля
const MARK_Y := 0.30       ## метки голосов — в луче под диском
const MARK_STEP := 0.12    ## между метками, м
const MARK_SIZE := 0.10    ## диаметр кружка метки, м (на телефоне от 24 px — ART-016)
const COUNT_Y := 0.17      ## счёт под метками
const DIM_SONAR := 0.85    ## насколько гаснет рельеф сонара в голосовании
const CHOICES: Array[String] = ["deep", "up"]
const WORDS := {"deep": "ГЛУБЖЕ", "up": "НАВЕРХ"}
const HOLO := Color("67DDEB")
const TEXT := Color("D5E4E8")
const BACK := Color("0B1C24")


## Центр поля choice ("deep" | "up") в осях голограммы, на высоте h.
static func field_pos(choice: String, h: float = DISC_Y) -> Vector3:
	return Vector3(0.0, h, SPREAD if choice == "deep" else -SPREAD)


## Голоса ролей по мнениям Run.opinions ([кто, наверх?, почему]): {"deep": [роль…], "up": [роль…]},
## роль — индекс Crew.Role; порядок — как у Crew.ROLE_NAMES.
static func votes(opinions: Array) -> Dictionary:
	var out := {"deep": [], "up": []}
	for role in Crew.ROLE_NAMES.size():
		for o in opinions:
			if o[0] == Crew.ROLE_NAMES[role]:
				out["up" if o[1] else "deep"].append(role)
	return out


## Буква метки роли: П, С, И, Б.
static func letter(role: int) -> String:
	return Crew.ROLE_NAMES[role].substr(0, 1)


## Место i-й из n меток под полем choice: в ряд поперёк взгляда, по центру поля, первая — слева от поста
## «Маршрут» (+Z).
static func mark_pos(choice: String, i: int, n: int) -> Vector3:
	var p := field_pos(choice, MARK_Y)
	p.z -= (float(i) - (n - 1) * 0.5) * MARK_STEP
	return p


## Показывать ли голосование: решение открыто и забег не окончен (после «наверх» — итог, result_wanted).
static func wanted(at_vote: bool, ended: bool) -> bool:
	return at_vote and not ended


## Итог на голограмме (лист ART-016, «Итог»): тёмная подложка над столом, заголовок «ЗАБЕГ ЗАВЕРШЁН» и четыре строки —
## Образцы / Виды / Места / Пробоины (Run.summary). Подложка поворачивается к глазам смотрящего (board_yaw), итог
## статичен. Числа — в осях подложки: x вправо, y вверх от плоскости голограммы, лицом к +Z.
const BOARD_Y := 0.56      ## центр подложки над голограммой, м (над полом 1,16…1,82 м — в высоте проекции)
const BOARD_W := 0.84
const BOARD_H := 0.66
const BOARD_PAD := 0.06    ## от края подложки до текста
const TITLE := "ЗАБЕГ ЗАВЕРШЁН"
const TITLE_DY := 0.24     ## заголовок над центром подложки
const ROW_TOP := 0.11      ## первая строка над центром
const ROW_STEP := 0.11     ## между строками
const LINE_W := 0.004      ## толщина рамки и разделителей


## Показывать ли итог: решение принято «наверх», панель итога открыта.
static func result_wanted(at_vote: bool, ended: bool) -> bool:
	return at_vote and ended


## Высота i-й строки итога от центра подложки.
static func row_y(i: int) -> float:
	return ROW_TOP - ROW_STEP * i


## Поворот подложки вокруг y, чтобы её лицо (+Z) смотрело на глаз eye (в осях голограммы).
static func board_yaw(eye: Vector3) -> float:
	var d := Vector2(eye.x, eye.z)
	return 0.0 if d.length() < 1e-4 else atan2(d.x, d.y)


## Прямоугольники рамки и разделителей между строками (rows строк) в плоскости подложки: [центр, размер].
static func board_lines(rows: int) -> Array:
	var w := BOARD_W
	var h := BOARD_H
	var out := [
		[Vector2(0, h / 2), Vector2(w, LINE_W)], [Vector2(0, -h / 2), Vector2(w, LINE_W)],
		[Vector2(-w / 2, 0), Vector2(LINE_W, h)], [Vector2(w / 2, 0), Vector2(LINE_W, h)],
	]
	for i in rows - 1:
		out.append([Vector2(0, (row_y(i) + row_y(i + 1)) * 0.5), Vector2(w - BOARD_PAD * 2, LINE_W * 0.5)])
	return out


## Контур стрелки в плоскости (x вправо, y вверх), высота h, острие вниз (down) или вверх; по часовой стрелке.
static func arrow_outline(h: float, down: bool) -> PackedVector2Array:
	var w := h * 0.62       # ширина наконечника
	var s := h * 0.26       # ширина древка
	var t := h * 0.46       # высота наконечника
	var pts := PackedVector2Array([
		Vector2(-s / 2, h / 2), Vector2(s / 2, h / 2), Vector2(s / 2, -h / 2 + t), Vector2(w / 2, -h / 2 + t),
		Vector2(0, -h / 2), Vector2(-w / 2, -h / 2 + t), Vector2(-s / 2, -h / 2 + t),
	])
	if not down:
		for i in pts.size():
			pts[i].y = -pts[i].y
	return pts


## Кружок метки: тёмная середина, кольцо цвета роли (белое — цвет даёт modulate), size × size px, RGBA.
static func ring_image(size: int = 64) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var r := Vector2(x - c, y - c).length() / c
			var ring := clampf((r - 0.74) * 12.0, 0.0, 1.0) * clampf((1.0 - r) * 12.0, 0.0, 1.0)
			var fill := clampf((1.0 - r) * 12.0, 0.0, 1.0)
			var col := BACK.lerp(Color.WHITE, ring)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, maxf(ring, fill * 0.85)))
	return img
