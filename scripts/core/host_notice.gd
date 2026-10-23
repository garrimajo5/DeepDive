class_name HostNotice
extends RefCounted
## Уведомления хоста о гостях (ART-043, `svyaz-poteryana.md`): гость отключился — «Игорь отключился» и
## «Роль свободна · пост освобождён» на `LEFT_TIME`; тот же гость вошёл снова — «Игорь вернулся» на `BACK_TIME`.
## Глагол — по внешности (`Crew.Member.look` 1 — женская модель): «Ира отключилась». Мир при этом идёт,
## управление не останавливается. Новое уведомление сменяет прежнее. Здесь только состояние, тексты и место плашки (2400×1080, масштаб H/1080, центр W/2, как `NetDrop`); рисует `DropPanel`.

const LEFT_TIME := 4.0   ## «… отключился» столько секунд
const BACK_TIME := 2.0   ## «… вернулся» столько секунд
const FADE := 0.3        ## плашка тает в конце показа, с
const BOX := Rect2(655, 260, 1090, 175)   ## 1090×175, y 260

var title := ""
var sub := ""
var t := 0.0      ## секунд показа
var time := 0.0   ## сколько показывать (0 — ничего нет)
var gone := {}    ## имена отключившихся гостей: войдёт снова — «вернулся»


## Гость отключился. held_post — держал пост (штурвал, пульт): теперь пост свободен; female — «отключилась».
func left(name: String, held_post: bool, female := false) -> void:
	gone[name] = true
	var sub_text := "Роль свободна · пост освобождён" if held_post else "Роль свободна"
	_show("%s %s" % [name, "отключилась" if female else "отключился"], sub_text, LEFT_TIME)


## Гость вошёл. true — это вернулся отключившийся (показано «вернулся»), false — новый гость.
func joined(name: String, female := false) -> bool:
	if not gone.has(name):
		return false
	gone.erase(name)
	_show("%s %s" % [name, "вернулась" if female else "вернулся"], "", BACK_TIME)
	return true


func update(dt: float) -> void:
	if active():
		t += dt
		if t >= time:
			time = 0.0


func active() -> bool:
	return time > 0.0


## Прозрачность плашки: 1, в последние FADE секунд тает к 0.
func alpha() -> float:
	if not active():
		return 0.0
	return clampf((time - t) / FADE, 0.0, 1.0)


func reset() -> void:
	time = 0.0
	t = 0.0
	gone.clear()


func _show(a: String, b: String, secs: float) -> void:
	title = a
	sub = b
	t = 0.0
	time = secs
