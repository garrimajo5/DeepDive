# SND-001 — эмбиент Подлёдного сада и корабля

Заказ: [#655](https://github.com/garrimajo5/DeepDive/issues/655). Ветка `art/SND-001-embient`, PR #667. Базовый main: `1f23d2d8b2dc9eaba96bbf0976822730099eb13c`. Дата: 26.10.2026. Полный комплект подготовлен для прослушивания и приёмки.

## Файлы и рекомендация

Все файлы ниже — петли, MP3 stereo 44,1 кГц / 192 кбит/с, меньше 6 МБ. Длина указана по декодированным сэмплам. Под «характером» понимается замысел промпта: я звук не слышу и не подтверждаю художественное соответствие на слух.

| Файл | Длина, с | Пик dBFS / true peak dBTP | LUFS | Назначение и задуманное отличие |
|---|---:|---:|---:|---|
| `ambient-shelf-1.mp3` | 25.000249 | -2.68 / -2.68 | -18.27 | Вода подо льдом, мягкий низкий гул, далёкие стоны и треск льда, редкие щелчки. Рекомендую первым для прослушивания: громкость близка к ориентиру −18 LUFS без ограничения пика. |
| `ambient-shelf-2.mp3` | 25.000249 | -1.76 / -1.76 | -23.02 | Более спокойный и тёмный фон воды, меньше событий. Из-за отношения пика к средней громкости оставлен тише (−23 LUFS), чтобы не поднимать пик выше допуска; при сравнении учесть разную громкость. |
| `ship-hum-1.mp3` | 25.000249 | -1.78 / -1.77 | -18.90 | Тёплый тональный электрический гул и мягкая вентиляция в стальном корпусе; отдельные тихие щелчки. |
| `ship-hum-2.mp3` | 25.000249 | -1.76 / -1.76 | -18.48 | Больше воздушной вентиляции, меньше тонального гула. Сохранён без коррекции стыка для сравнения; измеренный скачок на границе заметнее остальных. |
| `ship-hum-2-loopfix.mp3` | 24.900000 | -1.76 / -1.76 | -18.48 | Та же генерация второго варианта, с технической коррекцией стыка 100 мс. Рекомендую первым для корабля: менее тональный замысел, −18,48 LUFS и сильно уменьшенный измеренный скачок границы. Окончательное решение после прослушивания. |

В `src/` сохранены четыре исходные MP3-генерации с суффиксом `-original.mp3` (44,1 кГц / 128 кбит/с). Это исходники тех же вариантов, не дополнительные платные генерации. Перекодирование в 192 кбит/с не восстанавливает качество исходника. Файл первой пробы не изменён.

## Настройки и дословные промпты

Коннектор ElevenLabs Creative Studio: `creative_get_model_schema` → `creative_add_flow_node` / `creative_update_node` → оценка `creative_run_flow_nodes(estimate_only=true)` → запуск `creative_run_flow_nodes(generations_count=1)` → показ/получение `creative_show_flow_results`. Модель `eleven_text_to_sound_v2`, тип `sfx`; для каждой из четырёх генераций `duration_seconds=25`, `loop=true`, `prompt_influence=0.7`. Flow `SDdZBtUnkoZBpb57qnql`. Ни одно готовое аудио не генерировалось повторно.

### ambient-shelf-1.mp3

Node `TC7Nb0IcjLxTD7pY7pUx`; session `UFRbMEHHlnte7V7IX7Wt`; generation `s5Oi6fVu5qXN90hzHN13`. Стоимость успешной генерации по метаданным: 250 кредитов.

> 25-second seamless underwater ambience beneath a thick ice ceiling, 100 meters deep. Soft steady low water rumble, distant muffled ice creaks and slow ice groans overhead, very sparse tiny dry biological clicks far away. Calm spacious alien ocean, restrained dynamics, no foreground events. No music, melody, speech, whales, dolphins, birds or surface waves. Continuous texture with no fade in or fade out.

### ambient-shelf-2.mp3

Node `5GJenRQe0hnU1R3pjhlB`; session `ALXFjc4SGJ2sKc5skWCx`; generation `PiuEpZKcE68brYUax4j6`. Стоимость успешной генерации по метаданным: 250 кредитов.

> 25-second seamless ambience deep underwater beneath thick ice. A very soft broad low-frequency water-pressure drone, slow distant resonant ice flexing, and a few faint tiny irregular alien biological ticks widely spaced in the background. More stillness than events, smooth dark texture, no sharp transients. No music, melody, speech, recognizable animals, sonar, surface splashes or waves. Steady level, no fade in or fade out.

### ship-hum-1.mp3

Node `xGRuRm1Dv91KNDVXQ9gn`; session `cb1J2a1cHGnCP7CKga2K`; generation `3FXdwynmXUMOMGsBI4ww`. Стоимость успешной генерации по метаданным: 250 кредитов.

> 25-second seamless room tone inside the steel pressure hull of a small submarine bridge. Soft steady ventilation airflow, a warm low electrical transformer hum, very occasional subdued metal panel ticks. Close enclosed space with short damped metal resonance, quiet reliable machinery, restrained even dynamics. No voices, music, melody, beeps, buzzers, alarms, sonar or engine revving. Continuous low background bed, no fade in or fade out.

### ship-hum-2.mp3

Node `TMIclaBHLIoZBQ4PmvGl`; session `GHKNLuPrBRI7ArHGVdUY`; generation `zv90A7tNuoo7g8b1kTGD`. Стоимость успешной генерации по метаданным: 250 кредитов.

> 25-second seamless ambience inside a steel submarine cabin. Soft ventilation air moving through ducts, barely audible steady low electrical hum, a few distant gentle hull contraction ticks. Airflow dominates over tone; compact damped steel interior, smooth level, restful machinery. No speech, music, melody, high whine, beeps, buzzers, alarms, sonar or dramatic creaks. No fade in or fade out.

## Техпроверка и обработка

Проверено FFmpeg 7.1: полное декодирование без ошибок, частота и битрейт выходного потока, длина, размер, sample peak и true peak. После перекодирования пики повторно измерены и ниже −1 дБ. Логи `*-ffmpeg-verification.txt` и отчёты `*-technical-check.json`; для первой пробы исторические имена `ffmpeg-verification.txt`, `technical-check.json`. В отчётах `input_*` внутри `output_loudness` — измерение готового файла; `output_*` там — расчёт фильтра loudnorm, а не применённая динамическая обработка.

Для основных четырёх файлов применено только постоянное усиление и MP3-кодирование, чтобы не менять огибающую по времени. Расчёт усиления: минимум из достижения −18 LUFS и запаса true peak −1,5 дБ. Усиления: +22,25 / +20,56 / +33,14 / +9,82 дБ соответственно. Поэтому ambient-shelf-2 остался тише ориентира. Музыкальные слои, речь и чужие сэмплы не добавлялись.

`ship-hum-2-loopfix.mp3`: из той же исходной записи получена циклическая петля 24,9 с. Средняя часть 0,1–24,9 с сохранена; хвост 24,9–25 с и начало 0–0,1 с совмещены линейным перекрытием 100 мс через FFmpeg afade/amix/concat. Это техническое перекрытие имеющихся краёв, без синтеза нового звука, удлинения петли или затухания в тишину. Усиление +9,82 дБ. Исходная и первоначальная подготовленная версия сохранены.

Измеренная разница крайних сэмплов по каналам (dBFS):

| Файл | L | R |
|---|---:|---:|
| `ambient-shelf-1.mp3` | -23.86 | -24.10 |
| `ambient-shelf-2.mp3` | -28.82 | -28.94 |
| `ship-hum-1.mp3` | -21.22 | -23.94 |
| `ship-hum-2.mp3` | -17.58 | -11.52 |
| `ship-hum-2-loopfix.mp3` | -50.19 | -52.39 |

Генератор работал в режиме loop. Числа на границе — диагностический показатель, **не доказательство неслышного стыка**. Владелец/тестер должен прослушать несколько повторений, проверить щелчки, изменение фона, отсутствие узнаваемых животных и речи. Рекомендация по замыслу и технике: `ambient-shelf-1.mp3` + `ship-hum-2-loopfix.mp3`; остальные — альтернативы для сравнения.

## Расход и замечания сервиса

Четыре успешные генерации: **1000 кредитов по метаданным** (250 в предыдущей пробе + 750 в продолжении). Дополнительная техническая обработка не запускала генератор.

Одна версия ship-hum-2 получила `failed`: промпт 462 символа при лимите модели 450. Аудио не создано. Оценка перед запуском ошибку не выявила. Текст сокращён до 394 символов, после чего создан готовый вариант; неудачный prompt/session/generation сохранены в `generation-state.json`. У неудачной записи метаданные также содержат цену 250 кредитов, но баланс и возврат через коннектор недоступны. Поэтому сумма всех цен записей — 1250, из них 250 относятся к failed; точное чистое списание с учётом возможного возврата неизвестно. Не заявляю нулевой расход на ошибку. Предыдущий пакетный ответ 429 не вернул цену; повторы готовых вариантов исключены.

## Использование и открытые вопросы

Владелец сообщил Free, 10000 кредитов и некоммерческое использование; текущий баланс и совпадение рабочих пространств инструментально не проверены. По прямому разрешению владельца применён доступный Creative Studio вместо старых имён MCP. Коммерческая лицензия не заявляется. При публичной некоммерческой публикации нужна атрибуция ElevenLabs (`elevenlabs.io` / `11.ai`); перед коммерческим использованием Free-генерации заменить или отдельно согласовать права.

Собственная интерпретация: глубина 100 м, спокойный характер фона, конкретные тембровые различия вариантов. Новых сюжетных фактов и реплик нет. Открыто: выбор владельцем и проверка слышимого стыка/характера в игре. Палитра и геометрия к звуковому заказу не применяются.
