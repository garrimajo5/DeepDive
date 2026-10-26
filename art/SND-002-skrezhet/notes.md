# SND-002 — правки скрежета
По issue #656, комментарий с правками от 26.10.2026:
https://github.com/garrimajo5/DeepDive/issues/656#issuecomment-6415051998
База main: 5b42fb4f6c53ccbb812168dbea3ccc4c4fc51c02.
Прежний PR #685 уже слит; эта новая ветка и папка прямо указаны в комментарии.
Сонар и удары уже приняты. Здесь только два новых варианта hull-scrape, старые работы не переписаны.

## Файлы и замысел
- hull-scrape-rev1-1.wav — петля 3,71 с: толстая стальная обшивка трётся о грубую скалу под водой; длительные царапины, низкий гул, отдельные резкие зацепы.
- hull-scrape-rev1-2.wav — петля 3,71 с: обшивка трётся о твёрдый лёд; неровные протяжные зацепы, натужные короткие призвуки поверх тёмного низа.
- source/: неизменённые исходные MP3 генераций.
- generation-state.json: настройки и идентификаторы; technical-report.json: фактические измерения и SHA-256.
- prepare_audio.py: воспроизводимая обработка FFmpeg + NumPy, аргумент — путь к FFmpeg.

Это различия по заданным промптам, не результат прослушивания. Я звук не слышу; соответствие тембра скрежету и царапинам оценивают владелец и тестер.
Для первого прослушивания рекомендую вариант 1: замысел сильнее подчёркивает тяжёлую сталь и скалу, больше запас по пику и ровнее громкость на границе. Вариант 2 — альтернатива для более неровных зацепов.
Свойства, которые пока нельзя подтвердить: воспринимаемый низ, отсутствие стеклянного/тонкого призвука и естественность повторения. Нужно прослушать несколько повторов.

## Настройки
ElevenLabs Creative Studio, модель eleven_text_to_sound_v2; duration_seconds=3.8; loop=true; prompt_influence=0.9; generations_count=1 на узел, всего два варианта.
Flow DV3u3KSHZSdIMbzQoqJN.
Обе успешные генерации вернули 3,76 с; по метаданным по 38 кредитов, всего 76. Остаток баланса неизвестен. Покупки/смена тарифа/overage не выполнялись.
Free, некоммерческий прототип, атрибуция: Sound effects generated with ElevenLabs (https://elevenlabs.io). Коммерческое право этой сдачей не заявляется.

### hull-scrape-rev1-1
Node: e9spFWrNpdJMk0gqotfO; session: XYZHsi34EnUB894FZKos; generation: Z73TNmaLkvNnzgPTHIhj.

Seamless loop: thick steel submarine hull dragged across rough rock underwater. Sustained uneven grinding and long scraping scratches, deep dark hull rumble with occasional short harsh metal snags. Heavy resonant low end, muffled water around the hull, continuous friction already underway. No glass, bells, electronic beeps, explosions, voices, music or thin sandpaper hiss.

### hull-scrape-rev1-2
Node: 7uWR2kFEx3h21kbNVqgZ; session: u8K5VdapL79z3lQTzO44; generation: 7ab7xIUWcx9PfoolAwTL.

Seamless loop: heavy steel hull rubbing and gouging against hard ice underwater. Irregular drawn-out metallic creaks and scraping scratches, weighty low resonance, intermittent brief strained squealing catches embedded in the dark grinding. Continuous rough contact, no start impact or end fade. No glass shattering, ringing, electronic whine, voices, music or light abrasive hiss.

## Подготовка и проверка
Конкретные правки требуют WAV-петлю 48 кГц PCM16 и пик ≤ −3 дБ; это имеет приоритет над общим правилом MP3 для петель.
Исходник декодирован в stereo 48 кГц. Последние и первые 50 мс сведены косинусным кроссфейдом; длина уменьшилась до 3,71 с. Начало той же круговой записи перенесено на точку с минимальным перепадом отсчётов и разницей RMS соседних 50 мс менее 0,5 дБ. Никакого синтеза или склейки разных генераций.
Применён постоянный gain: цель около −18 LUFS с ограничением true peak −3,2 dBTP. У варианта 2 пик ограничивает подъём громкости, поэтому он −19,31 LUFS. Компрессор не применялся.
Полное декодирование и повторный замер готовых файлов:
| Вариант | Длина | Формат | Sample peak | True peak | LUFS | Граница |
|---|---:|---|---:|---:|---:|---|
| 1 | 3,71 с | stereo PCM16 48 кГц | −5,63 dBFS | −5,62 dBTP | −18,00 | перепад 1 отсчёт PCM16 (−90,31 dBFS), RMS 0,005 дБ |
| 2 | 3,71 с | stereo PCM16 48 кГц | −3,22 dBFS | −3,20 dBTP | −19,31 | равные крайние отсчёты, RMS 0,429 дБ |

Каждый WAV 712398 байт, без клиппинга. Перевод MP3 в WAV не улучшает качество исходной генерации.
Численные проверки стыка не заменяют слуховую оценку.

## Передача
Выбрать вариант после прослушивания, заменить hull-scrape в игре и включить WAV loop в импорте (либо loop_mode у AudioStreamWAV), весь диапазон 178080 кадров. В этой сдаче код игры и audio/ не менялись; изменение воспроизведения с одноразового на петлю — поток А.
