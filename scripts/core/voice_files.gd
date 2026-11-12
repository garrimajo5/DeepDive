class_name VoiceFiles
## Файлы голосов эфира SND-009 (#1476): реплика TXT-002 по ID (`EcoLink.VOICE` "id", `Comms.Msg.voice_id`) → WAV
## `audio/voice/<роль>-<m|f>/<id>.wav`. Папка — заявленная роль сообщения (у подделки — роль, которой эхоловец
## прикинулся) и внешность того, кто в экипаже держит эту роль (`Crew.Member.look`: 0 — `m`, 1 — `f`); подделка
## звучит тем же голосом, что настоящий доклад той же роли. Имя файла — ID строчными без `radio_`, `_` → `-`:
## `RADIO_TRUE_P01` → `true-p01`, `RADIO_FAKE_LIGHT03` → `fake-light03`. Файла нет (голоса ещё не сданы, реплика без
## озвучки) — `stream` даёт null, сообщение идёт только текстом. Играет `scripts/game/radio_voices.gd`
## (`main.radio_voices`) на шине «Эфир» (`SoundMix.radio_bus`: полоса рации и лёгкий перегруз — файлы чистые).

const DIR := "res://audio/voice"
## Корень папок голосов: в игре — DIR; тест подменяет на временную папку с синтетическим WAV (`user://…`).
static var root := DIR
## Обработка «рации» на шине «Эфир»: полоса телефонного канала и лёгкий перегруз.
const RADIO_LOW_CUT := 300.0    ## Гц, ниже — срезано
const RADIO_HIGH_CUT := 3400.0  ## Гц, выше — срезано
const RADIO_DRIVE := 0.3        ## перегруз AudioEffectDistortion (0…1)
const RADIO_DB := 0.0           ## громкость реплики: файлы сведены под связь (≈ −20 LUFS, как `comms-in.wav`)
const ROLES := ["pilot", "sonar", "engineer", "biolog"]   ## по `Crew.Role`
const SEX := ["m", "f"]                                     ## по `Crew.Member.look`
## Буква роли в ID настоящего доклада (`RADIO_TRUE_<буква>NN`) — по `Crew.Role`.
const TRUE_LETTER := ["P", "S", "E", "B"]


## Имя файла без расширения по ID реплики; "" — ID не из TXT-002.
static func file_name(id: String) -> String:
	var u := id.strip_edges().to_upper()
	if not u.begins_with("RADIO_") or u.length() <= 6:
		return ""
	return u.substr(6).to_lower().replace("_", "-")


## Папка голоса: роль и внешность.
static func folder(role: int, look: int) -> String:
	return "%s-%s" % [ROLES[clampi(role, 0, ROLES.size() - 1)], SEX[clampi(look, 0, SEX.size() - 1)]]


## Путь к файлу голоса; "" — без озвучки.
static func path(role: int, look: int, id: String) -> String:
	var f := file_name(id)
	return "" if f == "" else "%s/%s/%s.wav" % [root, folder(role, look), f]


## Роль, чьим голосом звучит настоящий доклад по ID (`RADIO_TRUE_P02` → пилот); −1 — не настоящий доклад.
static func true_role(id: String) -> int:
	var u := id.to_upper()
	if not u.begins_with("RADIO_TRUE_") or u.length() < 12:
		return -1
	return TRUE_LETTER.find(u.substr(11, 1))


## Внешность говорящего: первый в экипаже с этой ролью; никого — мужской голос (0).
static func look_of(role: int, crew: Array) -> int:
	for m in crew:
		if m is Crew.Member and int(m.role) == role:
			return clampi(int(m.look), 0, SEX.size() - 1)
	return 0


## Звук реплики для проигрывателя на шине «Голоса»; null — файла нет, только текст.
static func stream(role: int, look: int, id: String) -> AudioStream:
	var p := path(role, look, id)
	if p == "":
		return null
	if ResourceLoader.exists(p):   # в игре: импортированный файл
		return load(p) as AudioStream
	if not p.begins_with("res://") and FileAccess.file_exists(p):   # тест: WAV во временной папке без импорта
		return AudioStreamWAV.load_from_file(p)
	return null


## Длина реплики, с; 0 — нет звука.
static func length(s: AudioStream) -> float:
	return 0.0 if s == null else maxf(0.0, s.get_length())
