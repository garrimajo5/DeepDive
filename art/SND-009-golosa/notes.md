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
