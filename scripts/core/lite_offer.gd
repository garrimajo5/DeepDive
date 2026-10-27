class_name LiteOffer
extends RefCounted
## Предложение «Телефон не справляется — включить «Экономно»?» ART-044 (`docs/concept-art/grafika.md`,
## `grafika-sostoyaniya.png`, «05 После прогрева и проверки игры»): диалог 1400×540, «Да» (главная) / «Нет» 520×112.
## Открывается не по длительности прогрева, а после нескольких секунд устойчиво низких кадр/с в игре: настоящее время
## кадров копится окнами по 0,5 с (`push`, из `Main._process`), окно ниже `LOW` добавляет `HOLD`-счёт, быстрое — отнимает
## вдвое. Только когда можно (`update`): не на «Экономно», не во время тревоги, меню, паузы, настроек, облёта, шторок;
## раз за сеанс (`asked`), отказ запоминается в настройках (`Settings.lite_no`). «Да» — уровень «Экономно»
## (`Main._offer_do`). Рисует `scripts/game/lite_offer_panel.gd` (`main.lite_offer_panel`), шаг — `Main._offer_step`.
## Тесты и снимки выключают (`Main.offer = false`), прогон тестера — тоже, кроме шага `slow` (`force`).

const LOW := 22.0      ## кадр/с окна ниже этого — «низкие» (цель — 30)
const HOLD := 6.0      ## столько секунд низких окон подряд (с допуском) — и предложить
const WINDOW := 0.5    ## окно замера, с (как у счётчика `Graphics.Fps`)
const RECOVER := 2.0   ## быстрое окно отнимает от счёта во столько раз больше своей длины

## Раскладка (макет 2400×1080, масштаб и обрезка боков — `Splash`).
const BOX := Rect2(500, 270, 1400, 540)
const YES := Rect2(640, 648, 520, 112)
const NO := Rect2(1240, 648, 520, 112)
const LINES := ["Телефон не справляется", "Включить «Экономно»?", "Меньше деталей — плавнее игра"]
const LINE_TOP := [328.0, 423.0, 499.0]   ## верх глифов строк
const LINE_PX := [48.0, 42.0, 32.0]
const BUTTON_PX := 38.0
const DIM := 0.45   ## затемнение сцены под диалогом

var open := false
var asked := false   ## уже предлагали в этом сеансе
var low := 0.0       ## накопленные секунды низких кадр/с
var armed := false   ## копить можно (ставит `update`)
var _frames := 0
var _time := 0.0


## Настоящее время кадра dt (не шаг игры). Пока не `armed` — счёт сброшен.
func push(dt: float) -> void:
	if dt <= 0.0:
		return
	_frames += 1
	_time += dt
	if _time < WINDOW - 1e-4:
		return
	var fps := _frames / _time
	if armed:
		low = low + _time if fps < LOW else maxf(0.0, low - _time * RECOVER)
	else:
		low = 0.0
	_frames = 0
	_time = 0.0


## Можно ли предлагать сейчас: уровень, отказ, уже предлагали, что-то мешает (тревога, меню, пауза…).
static func allowed(level: int, declined: bool, was_asked: bool, blocked: bool) -> bool:
	return level != Graphics.ECONOMY and not declined and not was_asked and not blocked


## Шаг игры: true — диалог только что открылся. blocked — тревога, меню, пауза, настройки, облёт, шторки.
func update(level: int, declined: bool, blocked: bool) -> bool:
	if open:
		return false
	armed = allowed(level, declined, asked, blocked)
	if not armed:
		low = 0.0
		return false
	if low >= HOLD:
		open = true
		asked = true
		low = 0.0
		return true
	return false


## Открыть сразу (шаг тестера `slow`): как после низких кадр/с, даже если уже предлагали.
func force() -> void:
	open = true
	asked = true
	low = 0.0


static func layout_rect(id: String) -> Rect2:
	match id:
		"yes":
			return YES
		"no":
			return NO
		"box":
			return BOX
	return Rect2()


static func screen_rect(id: String, size: Vector2) -> Rect2:
	return Splash.rect_to_screen(layout_rect(id), size)


## Что под касанием p ("" — мимо кнопок).
func hit(p: Vector2, size: Vector2) -> String:
	if not open:
		return ""
	return Splash.hit_ids(p, size, ["yes", "no"], screen_rect)


## Нажатие: "yes" — включить «Экономно», "no" — отказ (запомнить); диалог закрывается. Иначе — "".
func press(id: String) -> String:
	if not open or id not in ["yes", "no"]:
		return ""
	open = false
	return id


## Системная «Назад» над диалогом — как «Нет».
func back() -> String:
	return press("no")
