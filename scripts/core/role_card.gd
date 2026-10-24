class_name RoleCard
extends RefCounted
## Карточка роли у поста по ART-045 (`docs/concept-art/kartochka-roli.md`): при первом подходе к посту своей роли —
## карточка 620×370 (значок из атласа ART-042, название, буква роли в круге, три строки, «Понятно»); «Понятно»
## сворачивает её в «?» 112×112, пока игрок у поста, «?» открывает снова. Прочитано — по типу поста, помнят настройки
## (`Settings.cards`). Ушёл от поста, не нажав «Понятно», — тоже показано (один раз, без таймера).
## Чужая роль (кооп) — плашка «Это пост инженера / Вы тоже можете им пользоваться» на 3 с, раз за забег на пост.
## В одиночном забеге все посты свои. Тревога, меню, голосование, брифинг, потеря связи, итог — скрыто (`hidden`);
## открытая при тревоге карточка сворачивается — после тревоги только «?». Пока идут подсказки ART-038 или пост занят
## другим (метка «Занято» ART-033) — не показывается (`quiet`). Здесь — таблица, состояние и места (макет
## 2400×1080, масштаб H/1080); рисует `scripts/game/role_card_panel.gd` (`main.role_card_panel`), ставит `Main._card_step`.

const REF_H := 1080.0
const CARD := Vector2(620, 370)
const LEFT_X := 70.0           ## карточка слева
const RIGHT_FROM := 1360.0     ## справа: x = W − 1360
const TOP := 180.0
const GAP := 12.0
const ICON := Rect2(24, 24, 72, 72)       ## значок в карточке
const TITLE_AT := Vector2(116, 74)        ## базовая линия названия
const TITLE_PX := 40.0
const LETTER_C := Vector2(562, 54)        ## центр круга буквы роли
const LETTER_D := 56.0
const LETTER_PX := 32.0
const LINES_AT := Vector2(28, 132)        ## базовая линия первой строки
const LINE_STEP := 42.0
const LINE_PX := 30.0
const BUTTON := Rect2(28, 235, 564, 112)  ## «Понятно»
const BUTTON_PX := 36.0
const ASK := Rect2(70, 240, 112, 112)     ## «?»
const ASK_PX := 48.0
const FOREIGN := Vector2(1360, 145)       ## плашка чужой роли, по центру по x
const FOREIGN_Y := 230.0
const FOREIGN_PX := Vector2(40, 28)       ## кегли двух строк
const FOREIGN_TIME := 3.0
const FADE := 0.15
const OK_TEXT := "Понятно"
const FOREIGN_SUB := "Вы тоже можете им пользоваться"

## Атлас значков постов ART-042 (`shema-znachki.png`): 512×384, ячейки 128².
const ATLAS := "res://textures/shema/znachki.png"
const CELL := 128

## Пост → [название, роль, строки 1…3, ячейка атласа, сторона (false — слева, true — справа: не закрывать прибор)].
const CARDS := {
	"helm": ["Штурвал", Crew.Role.PILOT, ["Ведите корабль", "Действие — сесть / встать", "Крестовина — ход и руль"],
		Vector2i(0, 0), false],
	"energy": ["Энергия", Crew.Role.ENGINEER,
		["Распределяйте энергию", "Действие — открыть пульт", "Вверх-вниз — система, влево-вправо — доля"],
		Vector2i(1, 0), true],
	"scanner": ["Сканер", Crew.Role.BIOLOGIST,
		["Изучайте существ", "Действие — сканировать", "Держите цель в поле зрения"], Vector2i(2, 0), false],
	"sonar": ["Сонар", Crew.Role.SONAR, ["Находите контакты", "Действие — импульс", "Свайп — осмотреться"],
		Vector2i(3, 0), false],
	"zap": ["Разряд", Crew.Role.ENGINEER, ["Снимайте угрозу с корпуса", "Действие — разряд", "Дождитесь готовности"],
		Vector2i(0, 1), true],
	"valve": ["Вентиль", Crew.Role.ENGINEER,
		["Снижайте перегрев", "Держите действие — сброс пара", "Отпустите — закрыть вентиль"], Vector2i(2, 1), true],
}
const LETTERS := ["П", "С", "И", "Б"]
const WHOSE := ["пилота", "сонарщика", "инженера", "биолога"]

var on := true
var read := {}          ## прочитанные посты (id → true), помнят настройки
var warned := {}        ## чужие посты, о которых уже сказали в этом забеге
var post := ""          ## пост с карточкой, у которого стоит игрок; "" — ни у какого
var own := false        ## этот пост своей роли
var open := false       ## карточка развёрнута
var shown := false      ## не скрыто тревогой и прочим (для «?» и плашки)
var foreign := ""       ## плашка чужой роли про этот пост
var foreign_t := 0.0
var a := 0.0            ## прозрачность карточки
var q := 0.0            ## прозрачность «?»
var f := 0.0            ## прозрачность плашки чужой роли
var status := Rect2()   ## строка приборов на экране: «?» и карточка обходят её снизу (ставит `Main._card_step`)


## Пост своей роли: в одиночном забеге — любой; в коопе — по таблице.
static func is_own(id: String, role: int, solo: bool) -> bool:
	return CARDS.has(id) and (solo or int(CARDS[id][1]) == role)


## Пост с карточкой, у которого стоит игрок: за штурвалом — штурвал, у открытого пульта — энергия, иначе пост рядом.
static func post_at(seated: bool, at_power: bool, near: String) -> String:
	if seated:
		return "helm"
	if at_power:
		return "energy"
	return near if CARDS.has(near) else ""


## Шаг времени. at — пост с карточкой (`post_at`), mine — он своей роли (`is_own`); hidden — тревога, меню,
## голосование, брифинг, потеря связи, итог; quiet — идут подсказки ART-038 или пост занят другим. true — прочитанные
## поменялись (сохранить).
func update(dt: float, at: String, mine: bool, hidden: bool, quiet: bool = false) -> bool:
	var changed := false
	if at != post:
		if open:   # ушёл, не нажав «Понятно», — показано
			changed = _mark() or changed
		open = false
		post = at
		own = mine
	if not on:
		post = ""
		open = false
	if open and (hidden or quiet):
		open = false
		if hidden:   # тревога: после неё — только «?»
			changed = _mark() or changed
	var calm := not hidden and not quiet
	if post != "" and own and calm and not read.has(post):
		open = true
	if post != "" and not own and calm and not warned.has(post):
		warned[post] = true
		foreign = post
		foreign_t = 0.0
	if foreign != "":
		if not hidden:
			foreign_t += dt
		if foreign_t >= FOREIGN_TIME or post != foreign:
			foreign = ""
	shown = calm
	a = move_toward(a, 1.0 if open else 0.0, dt / FADE)
	q = move_toward(q, 1.0 if ask_shown() else 0.0, dt / FADE)
	f = move_toward(f, 1.0 if foreign != "" and not hidden else 0.0, dt / FADE)
	return changed


## «?» над постом своей роли, когда карточка прочитана и свёрнута.
func ask_shown() -> bool:
	return on and post != "" and own and shown and not open and read.has(post)


## Свернуть в «?» («Понятно» или места на экране нет). true — прочитанные поменялись.
func fold() -> bool:
	if not open:
		return false
	open = false
	return _mark()


func _mark() -> bool:
	if post == "" or read.has(post):
		return false
	read[post] = true
	return true


## Касание p на экране size (карточка — в rect): "ok" — свёрнута, "ask" — открыта снова, "" — мимо.
func tap(p: Vector2, size: Vector2, rect: Rect2) -> String:
	if open and button_rect(rect, size).has_point(p):
		fold()
		return "ok"
	if ask_shown() and q > 0.0 and ask_rect(size, status).has_point(p):
		open = true
		return "ask"
	return ""


## Где касания идут карточке, а не взгляду (Touch.Router.blocks).
func blocks(size: Vector2, rect: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if open and rect.has_area():
		out.append(rect)
	elif ask_shown():
		out.append(ask_rect(size, status))
	return out


## Место карточки на экране size: сторона поста; ляжет на что-то из avoid — другая сторона; обе заняты — Rect2()
## (тогда сразу «?»). Строку приборов status обходит снизу.
static func card_rect(id: String, size: Vector2, avoid: Array = [], status: Rect2 = Rect2()) -> Rect2:
	var s := size.y / REF_H
	var right: bool = CARDS[id][4] if CARDS.has(id) else false
	for side: bool in [right, not right]:
		var x := size.x - RIGHT_FROM * s if side else LEFT_X * s
		var r := Rect2(x, TOP * s, CARD.x * s, CARD.y * s)
		if status.has_area() and r.intersects(status):
			r.position.y = status.end.y + GAP * s
		var free := r.end.y <= size.y and r.position.x >= 0.0 and r.end.x <= size.x
		for b: Rect2 in avoid:
			if b.has_area() and r.intersects(b):
				free = false
		if free:
			return r
	return Rect2()


static func button_rect(card: Rect2, size: Vector2) -> Rect2:
	var s := size.y / REF_H
	return Rect2(card.position + BUTTON.position * s, BUTTON.size * s)


static func ask_rect(size: Vector2, status_rect: Rect2 = Rect2()) -> Rect2:
	var s := size.y / REF_H
	var r := Rect2(ASK.position * s, ASK.size * s)
	if status_rect.has_area() and r.intersects(status_rect):
		r.position.y = status_rect.end.y + GAP * s
	return r


static func foreign_rect(size: Vector2) -> Rect2:
	var s := size.y / REF_H
	var w := minf(FOREIGN.x * s, size.x - 32.0)
	return Rect2((size.x - w) * 0.5, FOREIGN_Y * s, w, FOREIGN.y * s)


## Ячейка атласа значка поста.
static func cell(id: String) -> Rect2:
	var c: Vector2i = CARDS[id][3]
	return Rect2(c.x * CELL, c.y * CELL, CELL, CELL)


static func title(id: String) -> String:
	return CARDS[id][0]


static func letter(id: String) -> String:
	return LETTERS[int(CARDS[id][1])]


static func lines(id: String) -> Array:
	return CARDS[id][2]


## «Это пост инженера».
static func foreign_title(id: String) -> String:
	return "Это пост %s" % WHOSE[int(CARDS[id][1])]


## Прочитанные — для настроек (по порядку таблицы).
func read_list() -> Array:
	var out: Array = []
	for id: String in CARDS:
		if read.has(id):
			out.append(id)
	return out


func set_read(ids: Array) -> void:
	read.clear()
	for id in ids:
		if CARDS.has(str(id)):
			read[str(id)] = true


## Новый забег: чужие посты — снова один раз; прочитанное остаётся.
func reset_run() -> void:
	warned.clear()
	foreign = ""
	post = ""
	open = false
	a = 0.0
	q = 0.0
	f = 0.0
