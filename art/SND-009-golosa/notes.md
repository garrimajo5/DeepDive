Принимать: голоса по выбору владельца — pilot-m №3, pilot-f №2, sonar-m №1, sonar-f №1, engineer-m №2, engineer-f №3, biolog-m №3, biolog-f №3. Этап 2 частичный: 53/60 основных реплик на семи сохранённых голосах; biolog-f ждёт #1761. Дубли подделок пока не выбраны на слух.

## 16.11.2026 — этап 2, семь голосов

Заказ [#1476](https://github.com/garrimajo5/DeepDive/issues/1476), PR #1494 (черновик). Проверенная база origin/main: `3fbac59b742c4f0609f648e63f88c99e97a6f183`. Новая инструкция automation-6 от 18:59 UTC сняла проверку тарифа; работа продолжена в существующей ветке. **Тариф — Creator по паспорту; сделано на Creator. Баланс до и после недоступен**, фактическое списание не измерено. 60 вызовов TTS, 78 успешных генераций, суммарная длина исходников 174,753379 с. Поле price в метаданных не является замером списания. Старые записи не переатрибутированы.

### Состав и назначение

В `audio/voice/<роль-пол>/`: 35 настоящих реплик `true-*.wav`, 18 основных подделок `fake-<id>.wav`, 36 вариантов подделок `fake-<id>-1.wav` / `-2.wav`, 7 отдельных TTS-проб `proba.wav` (первая настоящая реплика роли). Всего 96 рабочих WAV, из них 18 основных подделок — побитовые копии первого дубля для предварительной комплектации. Это технический выбор, не художественная рекомендация. Для окончательного выбора нужно сравнить оба дубля на слух с нормальной речью; интонационные отличия не подтверждены.

Два `true-s04-short-v1.wav` — архив коротких первых обработок, не игровые файлы. Исходные MP3 сохранены в `sources/stage2-20261116/`; промежуточные версии границ — `sources/processed-v1/` и `sources/processed-v2/`. Старые кандидаты этапа 1 сохранены.

Отсутствуют 7 основных реплик biolog-f, её 4 дубля подделок и отдельная проба. Ошибка сохранения выбранного голоса описана в [#1761](https://github.com/garrimajo5/DeepDive/issues/1761); повторного сохранения или замены голоса не было. Полный заказ не сдан, PR не готов к слиянию.

### Генерация и воспроизводимость

ElevenLabs Creative Studio, `creative_list_voices`, `creative_generate_speech`, `creative_get_flow_run_status`; модель `eleven_multilingual_v2`, flow `CkmgVTH6aqoiPXdmdulS`. Skill: creative-studio подключённого плагина ElevenLabs. Точные тексты prompt, voice_id, session/node/generation IDs и направления интонации — семь манифестов `stage2-20261116/*.json`; сводка вызовов — `stage2-20261116-runs.json`. Временные подписанные preview URL удалены из публикуемых манифестов; исходники скачаны и сохранены.

Все prompt — дословные утверждённые русские реплики TXT-002, без добавленных тегов или произносимых пояснений. Английский контекст вызовов: “DeepDive SND009 <key>/<id>. Exact approved Russian text; dry calm crew voice. Direction: <direction>. Same default voice settings for real/fake. Creator per passport.” В первой пробе контекст служебный. **Context не является подтверждённым управлением интонацией TTS.** Инструмент не раскрывает численные stability/style/speed и отдельную настройку интонации; значения по умолчанию одинаково не переопределялись для настоящих и подделок. Соответствие актёрского исполнения направлениям TXT-002 требует слуховой приёмки.

| Голос | Сохранённый voice_id |
|---|---|
| pilot-m | ruRZj2VupLa0mYlo5SXJ |
| pilot-f | aBEDcTmclOFVR8g3BS2I |
| sonar-m | 6gj1WRBTx34niXU6kVCd |
| sonar-f | Ko0sT4Srx9LnyxaI5twm |
| engineer-m | 30RHL2K6DadEA9fglZzw |
| engineer-f | ggYSA3jFuePklOLLsw5D |
| biolog-m | TRGuYuwLGF5S4HYfHIMd |

Авторитетный ID каждого вызова — поле voice в манифесте.

### Обработка и контроль

FFmpeg 7.1: декодирование, mono PCM16 48 кГц, постоянное усиление около −20 LUFS с запасом пика, обрезка краёв и конечная тишина. Эффект рации, музыка, EQ и шум не добавлялись. `src/process-stage2.ps1` — первичная обработка; `src/finalize-stage2.ps1` — финальная правка границ; точный применённый фильтр каждого изменённого файла записан как final_edge_filter в `stage2-20261116-technical.json`. Исходные версии сохранены.

Короткие «Пилот, слышу тебя» сначала замедлены без изменения высоты: sonar-f atempo=0.908558, sonar-m atempo=0.865288; исходные короткие версии сохранены. Финальные фильтры местами дополнительно растягивают короткие записи до минимальной длины, параметры перечислены в JSON. Естественность после atempo нужно проверить на слух.

`src/verify-stage2.ps1` читает RIFF/data и проверяет 78 самостоятельных записей; `stage2-20261116-verification.json` — результаты, `technical/stage2-20261116/` — FFmpeg loudness logs. Все 78 прошли: длительность 1,570083–3,029833 с; −20,17…−19,26 LUFS; true peak ≤ −2,10 dBTP; ≤290942 байт. Начальная тишина по порогу −50 dBFS 0,007604–0,097146 с, конечная 0,241563–0,259688 с. 18 основных подделок проверены по SHA256 на равенство выбранному дублю.

Пороговая проверка границ не доказывает сохранность тихих согласных. **Не прослушано:** дословное произношение, ударения («импульс», «прожектор», «сонара»), отсутствие обрезанных слов, спокойствие настоящих реплик, естественность растяжения и нужный нажим подделок — владельцу/тестеру. Петель нет, стык не применяется. Все сравнения ниже только измерительные.

### Дубли: предварительно первый, окончательно после прослушивания

| Голос / реплика | Дубль 1, с | Дубль 2, с | Предварительно |
|---|---:|---:|---|
| biolog-m/fake-light04.wav | 3.03 | 2.696 | 1 |
| biolog-m/fake-pulse04.wav | 2.956 | 2.813 | 1 |
| engineer-f/fake-light03.wav | 2.839 | 2.496 | 1 |
| engineer-f/fake-pulse03.wav | 2.528 | 2.503 | 1 |
| engineer-m/fake-light03.wav | 2.213 | 2.253 | 1 |
| engineer-m/fake-pulse03.wav | 2.105 | 1.987 | 1 |
| pilot-f/fake-light01.wav | 2.65 | 2.373 | 1 |
| pilot-f/fake-light05.wav | 2.232 | 2.319 | 1 |
| pilot-f/fake-pulse02.wav | 2.892 | 2.514 | 1 |
| pilot-m/fake-light01.wav | 2.777 | 2.645 | 1 |
| pilot-m/fake-light05.wav | 2.462 | 2.255 | 1 |
| pilot-m/fake-pulse02.wav | 2.774 | 2.708 | 1 |
| sonar-f/fake-light02.wav | 2.59 | 2.327 | 1 |
| sonar-f/fake-pulse01.wav | 2.624 | 2.607 | 1 |
| sonar-f/fake-pulse05.wav | 2.748 | 3.023 | 1 |
| sonar-m/fake-light02.wav | 2.298 | 2.502 | 1 |
| sonar-m/fake-pulse01.wav | 2.652 | 2.97 | 1 |
| sonar-m/fake-pulse05.wav | 2.582 | 2.876 | 1 |

---
## История до этапа 2

Принимать: `audio/voice/pilot-m/kandidat-3.wav`, `audio/voice/pilot-f/kandidat-2.wav`, `audio/voice/sonar-m/kandidat-1.wav`, `audio/voice/sonar-f/kandidat-1.wav`, `audio/voice/engineer-m/kandidat-2.wav`, `audio/voice/engineer-f/kandidat-3.wav`, `audio/voice/biolog-m/kandidat-3.wav`, `audio/voice/biolog-f/kandidat-3.wav` — выбор владельца, основной пакет ещё не сдан.

## 13.11.2026 — явный выбор и начало сохранения голосов

Владелец выбрал набор в [#1719](https://github.com/garrimajo5/DeepDive/issues/1719#issuecomment-6836487560). Он заменяет редакционный набор по умолчанию. Проверенная база main: `ecac99847f79b19113f8ad933c6bb6741d04a68c`; ветка и старые файлы сохранены.

`creative_save_designed_voice` успешно сохранил семь голосов; `creative_list_voices(search="DeepDive SND009")` подтвердил семь записей. ID, view_state_id и ответы — в `voice-save-20261113.json`. Повторно эти голоса не сохранять.

Восьмой вызов, biolog-f кандидат 3 (`Sj1FsO8GTi4V4JRQz9Ik`, `viewstate_01m700fw6we39aefmsse91r68y`), вернул `INVALID_ARGUMENT`: `This picker already started a generation. Resuming it again would charge a second one.` Сохранённый voice_id не возвращён, biolog-f в списке библиотеки с названием проекта отсутствует. Это фактическая ошибка инструмента; причина не установлена. Повторный вызов и повторная генерация не выполнялись. Продолжение требует устранения ошибки сохранения или подтверждённого library voice_id именно выбранной пробы.

Новых аудиогенераций: 0, новая длительность: 0 с. Баланс недоступен; запрос дополнительного инструмента чтения тарифа и кредитов вернул отсутствие такой возможности. Creator известен по решению владельца, через сервис не подтверждён. Сохранение голосов не меняет происхождение старых аудиофайлов. Основные 60 файлов, дополнительные дубли и TTS-пробы ещё не созданы. Новых технических замеров аудио и прослушивания не было.

---
# SND-009 — этап 1: кандидаты голосов

Заказ: https://github.com/garrimajo5/DeepDive/issues/1476
База main: `792541695f20f1ddef315c2e270b63d9b7b19e35`.
Решение заказчика о пяти репликах и двух этапах: https://github.com/garrimajo5/DeepDive/issues/1476#issuecomment-6738427942.

**Сданы только 24 пробы (8 голосов × 3). Основной пакет 60 реплик, дубли подделок и короткие proba.wav ещё не созданы. Голоса в библиотеку не сохранены, выбора ещё нет.**

Тариф для всех новых проб: **сделано на Creator**, по подтверждению владельца 07.11 и паспорту. Подключённый сервис не предоставляет чтение тарифа и баланса: фактический тариф API независимо не подтверждён, баланс недоступен до/после. Сервис успешно выполнил 8 вызовов Voice Design, по 3 пробы; повторных генераций 0. Стоимость не выведена из длительностей или price.credits. Покупок, смены тарифа и клонирования голосов нет.

## Назначение и ограничения

Все файлы `audio/voice/<роль>-<m|f>/kandidat-1…3.wav` внутри этой папки заказа — голоса для сравнения, один раз, пять настоящих реплик подряд, а не готовые игровые сообщения. Пилот — ровный, собранный средний тембр; сонарщик — тише, выше и мягче, без шёпота; инженер — ниже, с лёгкой хрипотцой и усталостью; биолог — живее и чуть быстрее, без восторга. Это **замысел промптов**, а не результат прослушивания.

Внутри каждой группы три кандидата созданы одним промптом; различия тембра и произношения сервис не описывает, я их не слышал. Проверяемое отличие — длительность всего блока и пики в таблице ниже; из неё нельзя заключать, что все слова произнесены правильно. Кандидаты не являются клонами конкретных людей.

Предварительный порядок первого прослушивания (по средней длительности группы и запасу пика, **не художественный выбор**): pilot-m 3, pilot-f 3, sonar-m 1, sonar-f 1, engineer-m 2, engineer-f 1, biolog-m 2, biolog-f 2. Более короткие варианты проверить на спешку/пропуски, более длинные — на лишние паузы. После первого обязательно сравнить остальные два. Окончательное предпочтение и слышимые различия фиксирует слушатель.

Проверить на слух: дословность пяти фраз, естественность русского, ударение «сонара», «сонарщик», «реактора», «неисправностях», «ориентиры»; различимость четырёх ролей одного пола через динамик телефона. «Импульс» и «прожектор» будут в подделках этапа 2 и сейчас не звучат. Отсутствие эффекта рации, музыки, шумов и актёрского нажима не подтверждено прослушиванием.

## Инструмент и обработка

ElevenLabs `creative_design_voice`, `model_id=eleven_ttv_v3`, `language=ru`; в text переданы дословно пять RADIO_TRUE_<роль>01…05 через пробел. Остальные параметры (guidance_scale, loudness, seed, should_enhance) не передавались — значения по умолчанию сервиса, численные значения в ответе не раскрыты. Автогенерация текста не использована.

Первый контроль скачивания ранее созданного SND-007 — HTTP 200; затем первая новая проба pilot-m — HTTP 200, после этого остальные группы. VPN и ключи не менялись.

Исходные MP3 — `sources/<роль>-<пол>/kandidat-N.mp3`; точные запросы, тексты, generated_voice_id, длительности сервиса — `*-generation.json`. Временные подписанные ссылки удалены из публикуемых метаданных; ID сохранены для получения свежих previews без повторной генерации.

FFmpeg 7.1: преобразование в моно PCM16 WAV 48 кГц, постоянное усиление до −20 LUFS с ограничением true peak −2 dBTP. Без EQ, эффектов рации, компрессии, изменения скорости, обрезки фраз или склейки. Loudnorm используется как измеритель, а не динамическая обработка. Скрипт — `src/process.ps1`; полные исходные и итоговые измерения — `technical/`; таблица и SHA256 — `technical-results.json`.

Длительность WAV измерена по RIFF data, поэтому отличается от округления/MP3 длительности сервиса примерно на 0.002 с. Все файлы полностью декодированы. Это непетлевые пробы: стык петли неприменим. Начальная/конечная тишина для этих длинных проб сохранена как у Voice Design, не подгонялась под критерий отдельных игровых реплик; для этапа 2 нужна отдельная проверка краёв и 1.5–5 с. Техническая проверка не заменяет прослушивание.

## Продолжение

После выбора — сохранить только выбранные generated_voice_id, получить постоянные voice_id и создать основной пакет по TXT-002. По заказу выбор публикует гейм-дизайнер; инструмент сохранения дополнительно требует выбора пользователя. Если выбор сделает только агент, не выдавать его за прослушивание человеком или за явный выбор пользователя: согласовать с владельцем перед сохранением. Не перегенерировать эти 24 пробы при повторном запуске.

Самостоятельные решения: WAV 48 кГц моно PCM16; сохранение исходников и полных проб без обрезки; постоянное усиление с запасом пика −2 dBTP. Никаких изменений кода, docs/ или игрового audio/.

## Точные промпты и пробные тексты

### biolog-f

Adult female Russian speaker with native, accent-free Russian speech. A calm professional on a long expedition beneath the ice. Not an announcer or a film actor. Lively, curious, slightly faster pace. Interested without excitement. Clean dry voice, no radio effect, echo, static or music.

Текст (141 знаков):

Я у сканера. Слушаю вас. Сверяю наблюдения с архивом. Записываю наблюдения по ходу. Пока не спешу с выводами. Сонарщик, готов сверить записи.

### biolog-m

Adult male Russian speaker with native, accent-free Russian speech. A calm professional on a long expedition beneath the ice. Not an announcer or a film actor. Lively, curious, slightly faster pace. Interested without excitement. Clean dry voice, no radio effect, echo, static or music.

Текст (141 знаков):

Я у сканера. Слушаю вас. Сверяю наблюдения с архивом. Записываю наблюдения по ходу. Пока не спешу с выводами. Сонарщик, готов сверить записи.

### engineer-f

Adult female Russian speaker with native, accent-free Russian speech. A calm professional on a long expedition beneath the ice. Not an announcer or a film actor. Lower timbre than the other crew, slightly raspy, a little tired but intelligible. Clean dry voice, no radio effect, echo, static or music.

Текст (140 знаков):

Я у пульта. Слушаю экипаж. Проверяю питание корабля. Слежу за работой реактора. О неисправностях доложу отдельно. Пилот, по связи всё слышу.

### engineer-m

Adult male Russian speaker with native, accent-free Russian speech. A calm professional on a long expedition beneath the ice. Not an announcer or a film actor. Lower timbre than the other crew, slightly raspy, a little tired but intelligible. Clean dry voice, no radio effect, echo, static or music.

Текст (140 знаков):

Я у пульта. Слушаю экипаж. Проверяю питание корабля. Слежу за работой реактора. О неисправностях доложу отдельно. Пилот, по связи всё слышу.

### pilot-f

Adult female Russian speaker with native, accent-free Russian speech. A calm professional on a long expedition beneath the ice. Not an announcer or a film actor. Even, composed, mid-range timbre. Speaks briefly, used to giving commands. Clean dry voice, no radio effect, echo, static or music.

Текст (164 знаков):

Я у штурвала. Слушаю вас. Маршрут передо мной. Можно сверить ориентиры. О повороте предупрежу заранее. Сонарщик, я на связи. Если понадобится остановиться, скажите.

### pilot-m

Adult male Russian speaker with native, accent-free Russian speech. A calm professional on a long expedition beneath the ice. Not an announcer or a film actor. Even, composed, mid-range timbre. Speaks briefly, used to giving commands. Clean dry voice, no radio effect, echo, static or music.

Текст (164 знаков):

Я у штурвала. Слушаю вас. Маршрут передо мной. Можно сверить ориентиры. О повороте предупрежу заранее. Сонарщик, я на связи. Если понадобится остановиться, скажите.

### sonar-f

Adult female Russian speaker with native, accent-free Russian speech. A calm professional on a long expedition beneath the ice. Not an announcer or a film actor. Quiet, focused, slightly higher and softer timbre than a pilot. Not whispering. Clean dry voice, no radio effect, echo, static or music.

Текст (124 знаков):

Я у сонара. Слушаю эфир. Сверяю отметки с картой. О новых отметках сообщу. Пилот, слышу тебя. Готов сверить маршрут с тобой.

### sonar-m

Adult male Russian speaker with native, accent-free Russian speech. A calm professional on a long expedition beneath the ice. Not an announcer or a film actor. Quiet, focused, slightly higher and softer timbre than a pilot. Not whispering. Clean dry voice, no radio effect, echo, static or music.

Текст (124 знаков):

Я у сонара. Слушаю эфир. Сверяю отметки с картой. О новых отметках сообщу. Пилот, слышу тебя. Готов сверить маршрут с тобой.

## Файлы и техпроверка

| Голос / кандидат | generated_voice_id | Длина, с | LUFS | dBTP | Байт |
|---|---|---:|---:|---:|---:|
| biolog-f / 1 | 7m1ugmuPaZZftoH1o7mp | 11.076 | -20 | -5.66 | 1063368 |
| biolog-f / 2 | GJpL1KwE1aaIqFSVfPVU | 10.919 | -19.99 | -5.04 | 1048320 |
| biolog-f / 3 | Sj1FsO8GTi4V4JRQz9Ik | 9.718 | -20 | -5.81 | 932964 |
| biolog-m / 1 | LyDDslJ3tf0fzvBMzMnU | 10.606 | -20.01 | -5.87 | 1018228 |
| biolog-m / 2 | lOj7QOw29J4K10CFwVGt | 10.371 | -20 | -2.93 | 995658 |
| biolog-m / 3 | TRGuYuwLGF5S4HYfHIMd | 10.188 | -20 | -5.48 | 978104 |
| engineer-f / 1 | q1ZUCwl7mi8CweJwMugX | 11.233 | -19.99 | -4.44 | 1078414 |
| engineer-f / 2 | GuiKJkWy6dpG8Wdqxqlq | 11.233 | -20 | -4.25 | 1078414 |
| engineer-f / 3 | ggYSA3jFuePklOLLsw5D | 9.796 | -19.99 | -4.78 | 940488 |
| engineer-m / 1 | 3u3a9Ki3iyziWf6AxW6i | 10.606 | -20 | -4.86 | 1018228 |
| engineer-m / 2 | 30RHL2K6DadEA9fglZzw | 10.527 | -20 | -3.6 | 1010704 |
| engineer-m / 3 | QCojhXSLJab3swu1ysBM | 10.031 | -19.99 | -4.08 | 963056 |
| pilot-f / 1 | mysJ4RbaGHFQyXuzUJr7 | 11.154 | -20 | -4.45 | 1070890 |
| pilot-f / 2 | aBEDcTmclOFVR8g3BS2I | 12.748 | -20.01 | -4.92 | 1223864 |
| pilot-f / 3 | gCj3Qfje6oBPAeF5UNQW | 11.311 | -20.01 | -5.99 | 1085936 |
| pilot-m / 1 | MYNbVkg19vwUpShah3Vr | 10.266 | -20 | -4.35 | 985626 |
| pilot-m / 2 | Mm5Vt0IBEmvG6q4xokro | 10.762 | -19.99 | -3.46 | 1033274 |
| pilot-m / 3 | ruRZj2VupLa0mYlo5SXJ | 10.606 | -20 | -4.88 | 1018228 |
| sonar-f / 1 | Ko0sT4Srx9LnyxaI5twm | 9.953 | -20 | -3.42 | 955534 |
| sonar-f / 2 | rhIHH9QqgjYimn1MtpRU | 10.109 | -20 | -3.84 | 970580 |
| sonar-f / 3 | sOV3Xzch23pVQNeHejhU | 9.874 | -19.99 | -4.55 | 948010 |
| sonar-m / 1 | 6gj1WRBTx34niXU6kVCd | 9.326 | -20 | -3.19 | 895348 |
| sonar-m / 2 | woqkv2vjZbDChlVOJJzX | 9.404 | -20.06 | -2 | 902870 |
| sonar-m / 3 | 40ISidUW2pCQALyfH53V | 9.169 | -20.01 | -4.27 | 880302 |

Всего длительность WAV: 250.985 с. Все 24 — 48000 Гц, 1 канал, PCM16; каждый меньше 6 МБ.

