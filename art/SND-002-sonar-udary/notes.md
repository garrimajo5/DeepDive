# SND-002 — сонар и удары корпуса

Issue: #656. Базовый origin/main: `fd9e69bf8fc24065ee01fab017bcd1a446dd0676`. Ветка: `art/SND-002-sonar-udary`.

## Сдача и прослушивание
Десять WAV: по два варианта сонара, каждой из трёх разновидностей удара и скрежета. Все — отдельные одноразовые эффекты, не петли. В `hull-hit-2-1` первая цифра — разновидность удара, вторая — вариант.
Исходники генератора сохранены в `source/*.mp3`. `generation-state.json` хранит полные промпты и идентификаторы; `technical-report.json` — измерения и SHA-256; `src/prepare_audio.py` воспроизводит только техническую обработку через FFmpeg, без синтеза.

Рекомендую начать прослушивание с sonar-ping-1, hull-hit-1-1, hull-hit-2-1, hull-hit-3-1 и hull-scrape-1: по замыслу это основной набор с различимыми прямым, косым и нижним ударами. Вторые варианты дают более мягкие атаки или иную фактуру. Это рекомендация по промптам и техническим данным, не слуховая оценка. Я звук не слышу: отсутствие писка, лишних ударов, речи, подходящий тембр и естественное затухание должен подтвердить владелец/тестер. Аудио доступно по ссылкам в issue.

## Файлы
| Файл | Длительность, с | Пик dBFS / true peak dBTP | Размер, байт | Задуманный характер |
|---|---:|---:|---:|---|
| `hull-hit-1-1.wav` | 1.68 | -3.91 / -3.91 | 322638 | Прямой тяжёлый удар тела, короткий глухой резонанс обшивки. |
| `hull-hit-1-2.wav` | 1.68 | -3.92 / -3.92 | 322638 | Более мягкая атака прямого удара, плотный низкий стук. |
| `hull-hit-2-1.wav` | 1.76 | -3.00 / -3.00 | 337998 | Косой удар с коротким шероховатым контактом. |
| `hull-hit-2-2.wav` | 1.76 | -3.01 / -3.00 | 337998 | Боковое столкновение с небольшой абразивной атакой и изгибом стали. |
| `hull-hit-3-1.wav` | 1.88 | -3.00 / -3.00 | 361038 | Широкий удар снизу, низкий гул и короткий скрип. |
| `hull-hit-3-2.wav` | 1.88 | -3.00 / -3.00 | 361038 | Удар снизу с более длинной дрожью металла. |
| `hull-scrape-1.wav` | 2.56 | -3.01 / -3.00 | 491598 | Непрерывное грубое скольжение стали по камню с кратким нарастанием. |
| `hull-scrape-2.wav` | 2.56 | -3.00 / -3.00 | 491598 | Более зернистый песчано-гравийный контакт с мягким входом и выходом. |
| `sonar-ping-1.wav` | 3.48 | -3.00 / -3.00 | 668238 | Округлый чистый импульс и просторный затухающий хвост снизу. |
| `sonar-ping-2.wav` | 3.48 | -3.00 / -3.00 | 668238 | Более мягкая полая атака и два далёких рассеянных отражения. |

## Генерация и права
ElevenLabs Creative Studio: `creative_add_flow_node`, `creative_run_flow_nodes`; модель `eleven_text_to_sound_v2`, node_type `sfx`. Схема модели проверена перед генерацией. Параметры: `prompt_influence=0.7`, `loop=false`, `generations_count=1` для каждого отдельно описанного варианта. Все промпты короче 450 символов.
Flow: `vby126pIFDEjrMif696H`. Оценка до запуска — 230 кредитов. Все 10 генераций завершены успешно, суммарная стоимость по метаданным — 230 кредитов. Остаток баланса недоступен; покупок, смены плана и доплат не было.
Free и некоммерческое использование — по уточнениям владельца в звуковом чате, отражённым в #641. При публикации нужна атрибуция ElevenLabs (https://elevenlabs.io). Коммерческие права этой сдачей не заявляются.

## Проверка и обработка
FFmpeg 7.1 полностью декодировал каждый исходник и итоговый WAV без ошибок. Итог: PCM signed 16-bit little-endian, stereo, 48000 Hz. Длины: сонар 3.48 с, удары 1.68–1.88 с, скрежет 2.56 с — внутри интервалов issue. Все WAV меньше 0.7 МБ, прочие файлы меньше лимитов.
Исходник — MP3 44.1 кГц / 128 кбит/с; преобразование в WAV 48 кГц не возвращает потерянное MP3 качество. Оригиналы сохранены. Применён постоянный gain до целевого true peak −3 dBTP и короткие fade-in 5 мс / fade-out 50 мс для мягких границ. Это не компрессор и не изменение тембра; у тихих исходников усиливается также фоновый шум, что нужно оценить на слух. Fade может немного смягчить начальный удар.
После обработки sample peak и true peak повторно измерены: от −3.92 до −3.00 дБ, ниже требования −1 дБ. Громкость LUFS отражена в отчёте, но не нормализована: для коротких ударов сохранена динамика. Пики выровнены для сравнения, воспринимаемая громкость может отличаться. Сведение и проверка на телефоне — в игре после приёмки; код игры, аудиобиблиотека и сцены не изменены.

## Промпты и идентификаторы

### sonar-ping-1
Одноразовый эффект; запрошено 3.5 с; статус completed; стоимость 35 кредитов.
Node `lVE4XF4L714CQw4ESBgy`; session `ehqbeFaHYJSuVo1vk3xU`; generation `pVjrxcTJJGi2J7tzilgm`.

A single clean rounded underwater sonar ping at the start, deep resonant tone, followed by a spacious echo descending into dark water and fading for three seconds. Heard inside a submerged steel research vessel beneath thick ice. No electronic beep, shrill squeal, music, voices or animals.

### sonar-ping-2
Одноразовый эффект; запрошено 3.5 с; статус completed; стоимость 35 кредитов.
Node `o9QK3HEjAyGQiIMNSJRy`; session `sfeoeawGab5yFJOFVxFv`; generation `Bwa8NpJYTufdq7PubO3x`.

One low, clear underwater sonar pulse, slightly hollow and soft at the onset, with two distant diffuse returns from below and a smooth three-second decay into silence. Under ice, muffled deep water acoustics. No alarm, electronic beeping, music, speech or animal calls.

### hull-hit-1-1
Одноразовый эффект; запрошено 1.7 с; статус completed; стоимость 17 кредитов.
Node `4m35z8NNYJkgxSpqAcOw`; session `20hCoBNSH9MH5yM0iMnC`; generation `In6cNWdJAtD8x8duyrUH`.

One heavy blunt creature impact against thick submerged submarine steel, a short low thud at the beginning followed by a restrained resonant hull groan decaying to silence. Interior perspective, underwater muffling. No explosion, bell, voices, music or second strike.

### hull-hit-1-2
Одноразовый эффект; запрошено 1.7 с; статус completed; стоимость 17 кредитов.
Node `x9rLk6g4X8MyC8EuFIAp`; session `1mQFjNAkKHeNNW9bEJu8`; generation `yTYv1S59sec9x17piMGw`.

A single dense soft-edged body slam into a thick steel underwater vessel, bass-heavy knock and short enclosed metal resonance fading away. Close interior perspective. No ringing bell, explosion, glass, music, speech or repeated hits.

### hull-hit-2-1
Одноразовый эффект; запрошено 1.8 с; статус completed; стоимость 18 кредитов.
Node `ft77nOMOSlNspJHGwND4`; session `31FRfdtw8e0PHChynWfC`; generation `LBIRrLjrmUig6PGUCzUH`.

One oblique heavy strike against a submerged steel hull, a dull low clunk with a brief gritty contact and a hollow structural vibration fading to silence. Heard from inside the vessel. No explosion, bell, alarm, voices or repeated blows.

### hull-hit-2-2
Одноразовый эффект; запрошено 1.8 с; статус completed; стоимость 18 кредитов.
Node `txhAvHVaAqIfvAl2rMH6`; session `r4B7QFWvJR0glKtWnTxN`; generation `x8iFn953wlmSJDNk5JO7`.

A single heavy sideways collision with thick submarine plating, muffled hollow knock, tiny abrasive onset and low steel flex resonance. Quick attack, smooth decay to silence. No high ringing, explosion, music, voices or multiple impacts.

### hull-hit-3-1
Одноразовый эффект; запрошено 1.9 с; статус completed; стоимость 19 кредитов.
Node `wyUOdbd1w7bCAlOr90UJ`; session `F1eHIk02ut6WmWTXJDVK`; generation `7HvNqhdFecQuYRbYJacB`.

One forceful broad creature impact beneath a submerged vessel, very low rounded boom through thick steel followed by a short creak and fading hull resonance. No explosive crack, bell, alarm, music, speech or second impact.

### hull-hit-3-2
Одноразовый эффект; запрошено 1.9 с; статус completed; стоимость 19 кредитов.
Node `DqhbrEGi9OgkGRbK4QmN`; session `Q1nLdmr4QfbKx51THsMn`; generation `fb9onAsBcWSGe70oKVOU`.

Single deep blunt impact on a submarine hull from below, dense thump with a slightly longer low metallic shudder decaying to silence. Underwater, close enclosed interior acoustics. No explosion, bell-like ring, music, voices or repeated strikes.

### hull-scrape-1
Одноразовый эффект; запрошено 2.6 с; статус completed; стоимость 26 кредитов.
Node `Uh4o4x7lQQkRltxz7Own`; session `yXW4CfSIL6shVvYn9MiH`; generation `RjPIqs0BQmqT2C4u4egi`.

One continuous low grinding scrape of thick submarine steel sliding across rough underwater rock and sand, builds briefly then releases and fades out. Dull gritty vibration heard inside the hull. No brake squeal, high screech, sparks, music, speech or repeated impacts.

### hull-scrape-2
Одноразовый эффект; запрошено 2.6 с; статус completed; стоимость 26 кредитов.
Node `NouCo2KoI3zQJR8dGjj0`; session `1QhvGXrgFynPs7bnNgWz`; generation `ISCvVTAMOX2VJ57IIQk9`.

A single sustained abrasive contact of a submerged steel hull against gravel and stone, low coarse rumble with granular sand texture, gentle onset and release into silence. Muffled underwater interior sound. No piercing squeal, bells, explosions, music or voices.
