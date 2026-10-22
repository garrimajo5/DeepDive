class_name NetDrop
extends RefCounted
## Гость потерял хоста (ART-043, `svyaz-poteryana.md`): не уходит в соло молча. Управление остановлено, поверх
## последнего кадра хоста — диалог «Связь с хостом потеряна»; окно ожидания `WINDOW` — одна попытка переподключения
## к прежнему хосту (`NetLink.Client.rejoin`). Истекло — «Нет ответа», «Ждать» — новая попытка. Автоматического
## соло нет: «Играть одному» — через подтверждение. Хост принял гостя и пришёл кадр — «Связь восстановлена» на
## `BACK_TIME`. Отказ хоста («Другая версия игры», «Экипаж полон») — вместо строки ожидания, без повторов.
## Здесь только состояние, тексты и места кнопок (2400×1080, масштаб H/1080, центр W/2); рисует `DropPanel`.

enum Phase { OFF, WAIT, NO_ANSWER, REFUSED, CONFIRM_SOLO, CONFIRM_MENU, BACK }

const WINDOW := 10.0     ## окно одной попытки переподключения, с
const BACK_TIME := 2.0   ## «Связь восстановлена» столько секунд
const REF_H := 1080.0
const REF_CX := 1200.0

## Кнопки: id → прямоугольник в 2400×1080.
const BUTTONS := {
	"wait": Rect2(600, 615, 1200, 112),
	"solo": Rect2(600, 765, 580, 112),
	"menu": Rect2(1220, 765, 580, 112),
	"yes": Rect2(700, 600, 450, 112),
	"no": Rect2(1250, 600, 450, 112),
}
const BOX := Rect2(500, 180, 1400, 745)       ## диалог
const CONFIRM_BOX := Rect2(650, 300, 1100, 470)   ## подтверждение поверх диалога
const BACK_BOX := Rect2(650, 260, 1100, 130)  ## «Связь восстановлена»

var phase := Phase.OFF
var t := 0.0           ## секунд в текущей попытке (или в показе «восстановлена»)
var retry := false     ## попытка по «Ждать» — «Подключаемся… N из 10 с»
var why := ""          ## причина отказа хоста (NetLink.WHY)
var menu_ready := false   ## есть ли главное меню (ART-037): пока нет — «В меню» погашена
var _under := Phase.WAIT  ## что под подтверждением: «Нет» возвращает сюда


## Хост пропал: диалог и первая попытка. true — нужна попытка переподключения.
func open() -> bool:
	phase = Phase.WAIT
	t = 0.0
	retry = false
	why = ""
	return true


func active() -> bool:
	return phase != Phase.OFF


## Управление остановлено: диалог на экране (кроме «Связь восстановлена» — там игра уже идёт).
func blocks() -> bool:
	return phase != Phase.OFF and phase != Phase.BACK


## Ход времени. Возвращает true, когда окно попытки истекло без ответа (попытку — остановить).
func update(dt: float) -> bool:
	t += dt
	if phase == Phase.BACK and t >= BACK_TIME:
		phase = Phase.OFF
	if phase == Phase.WAIT and t >= WINDOW:
		phase = Phase.NO_ANSWER
		return true
	return false


## Хост ответил отказом: причина вместо строки ожидания, без повторов.
func refused(reason: String) -> void:
	if phase == Phase.WAIT:
		phase = Phase.REFUSED
		why = reason


## Хост принял гостя и пришёл свежий кадр: «Связь восстановлена» на BACK_TIME, управление вернулось.
func restored() -> void:
	if blocks():
		phase = Phase.BACK
		t = 0.0


## Касание кнопки (id из BUTTONS). Возвращает, что сделать игре: "rejoin" — новая попытка, "solo" — новый
## одиночный забег, "menu" — выход в меню, "" — ничего.
func press(id: String) -> String:
	match phase:
		Phase.WAIT, Phase.NO_ANSWER, Phase.REFUSED:
			if id == "wait" and phase == Phase.NO_ANSWER:
				phase = Phase.WAIT
				t = 0.0
				retry = true
				return "rejoin"
			if id == "solo":
				_under = phase
				phase = Phase.CONFIRM_SOLO
			elif id == "menu" and menu_ready:
				_under = phase
				phase = Phase.CONFIRM_MENU
		Phase.CONFIRM_SOLO, Phase.CONFIRM_MENU:
			if id == "no":
				phase = _under
				if phase == Phase.WAIT and t >= WINDOW:   # окно истекло, пока решали
					phase = Phase.NO_ANSWER
			elif id == "yes":
				var what := "solo" if phase == Phase.CONFIRM_SOLO else "menu"
				phase = Phase.OFF
				return what
	return ""


## Кнопки, которые сейчас видны: [id, подпись, главная?, доступна?]. «Ждать» во время ожидания — «ждём дальше».
func buttons() -> Array:
	match phase:
		Phase.WAIT, Phase.NO_ANSWER, Phase.REFUSED:
			return [["wait", "Ждать", true, phase != Phase.REFUSED],
				["solo", "Играть одному", false, true],
				["menu", "В меню", false, menu_ready]]
		Phase.CONFIRM_SOLO, Phase.CONFIRM_MENU:
			return [["yes", "Да", false, true], ["no", "Нет", true, true]]
	return []


## Строки диалога: [заголовок, пояснение 1, пояснение 2, строка ожидания].
func lines() -> Array[String]:
	match phase:
		Phase.WAIT, Phase.NO_ANSWER, Phase.REFUSED:
			return ["Связь с хостом потеряна", "Ваше управление остановлено", "У хоста игра может продолжаться",
				wait_line()]
		Phase.CONFIRM_SOLO:
			return ["Продолжить одному?", "Вы покинете сетевой забег.", "Начать новый одиночный забег?", ""]
		Phase.CONFIRM_MENU:
			return ["Покинуть сетевой забег?", "Вы выйдете в меню.", "Возврат — через сбор экипажа.", ""]
		Phase.BACK:
			return ["Связь восстановлена", "Вы снова в экипаже", "", ""]
	return []


## «Ждём хоста · осталось N с» / «Подключаемся… N из 10 с» / «Нет ответа» / причина отказа.
func wait_line() -> String:
	match phase:
		Phase.NO_ANSWER:
			return "Нет ответа"
		Phase.REFUSED:
			return NetLink.WHY.get(why, "Отказ хоста")
		Phase.WAIT:
			if retry:
				return "Подключаемся… %d из %d с" % [mini(int(t) + 1, int(WINDOW)), int(WINDOW)]
			return "Ждём хоста · осталось %d с" % maxi(1, ceili(WINDOW - t))
	return ""


## Прямоугольник из 2400×1080 на экран size: масштаб H/1080, центр по ширине.
static func to_screen(r: Rect2, size: Vector2) -> Rect2:
	var s := size.y / REF_H
	return Rect2(Vector2(size.x * 0.5 + (r.position.x - REF_CX) * s, r.position.y * s), r.size * s)


## Какая видимая доступная кнопка под касанием p ("" — никакая).
func hit(p: Vector2, size: Vector2) -> String:
	for b: Array in buttons():
		if b[3] and to_screen(BUTTONS[b[0]], size).has_point(p):
			return b[0]
	return ""
