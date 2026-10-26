# SND-003 — пробоина, тревога и разряд

Issue #657, базовый origin/main `9c1a079c9ada92294a6e502648d735444abe531e`. Ветка `art/SND-003-proboina-trevoga`. Дата 26.10.2026. **Частичная работа: 2 из 6 вариантов, заказ остаётся «в работе».**

## Готовые файлы

| Файл | Тип | Длина | Формат | Пик sample / true | LUFS | Замысел |
|---|---|---:|---|---:|---:|---|
| breach-jet-1.mp3 | петля | 6,95 с | MP3 stereo 44,1 кГц / 192 кбит/с | −6,40 / −6,23 дБ | −18,24 | Узкая мощная струя под давлением, бурление о металл |
| breach-jet-2.mp3 | петля | 6,95 с | MP3 stereo 44,1 кГц / 192 кбит/с | −7,44 / −7,40 дБ | −18,26 | Более широкая турбулентная струя, меньше шипения, больше бурления |

Оба файла по 168689 байт. Рекомендую первым для прослушивания вариант 1: по замыслу он отчётливее обозначает небольшую пробоину под давлением. Это рекомендация по промпту и технике, не слуховая оценка. Я звук не слышу: характер струи, отсутствие дождя/душа/водопада, речи и слышимого стыка проверяют владелец и тестер.

## Настройки и учёт

ElevenLabs Creative Studio: creative_get_model_schema, creative_add_flow_node, creative_run_flow_nodes(estimate_only=true), creative_run_flow_nodes(generations_count=1), creative_show_flow_results. Модель eleven_text_to_sound_v2, prompt_influence=0.7. Все промпты короче 450 символов. Flow `HIazYUdOjFxEaHj6tC13`.

Две завершённые генерации — **140 кредитов по метаданным** (70 каждая). При запуске alarm-siren-1 получен 429 rate_limited, request id 898884b965477a31ba7f557e1a2f3044; стоимость/идентификатор новой генерации не возвращены. Новых запусков после 429 не делалось. Перед продолжением прочитать существующий flow и восстановить результат, если он появился; готовые breach-jet не генерировать заново.

## Проверка и обработка

Исходники в source/*.mp3: MP3 44,1 кГц / 128 кбит/с. Полное декодирование FFmpeg 7.1 без ошибок. Подготовленные петли перекодированы в 192 кбит/с — это не восстанавливает потерянное исходное качество. Применён постоянный gain −5,10 / −6,99 дБ. Для циклического стыка края исходной записи перекрыты на 50 мс через FFmpeg afade/amix/concat: средняя часть 0,05–6,95 с плюс смешанные хвост/начало. Без синтеза, удлинения или затухания в тишину. Итог 6,95 с — внутри требуемых 5–10 с.

Повторно измерены sample peak и true peak (ниже −1 дБ), длительность, формат и размер; SHA-256 и измерения — в *-technical.json. Разница крайних сэмплов: вар.1 −46,86/−34,44 dBFS, вар.2 −37,66/−37,23 dBFS. Это диагностика, не доказательство незаметного стыка. Скрипт src/prepare_audio.py воспроизводит техническую обработку, исходники сохранены.

## Все подготовленные варианты и дословные промпты

### breach-jet-1

Запрошено 7 с, loop=true; Узкая мощная струя, свист давления приглушён, бурление у палубы.
Node `rvbGqCxa3twXDlLpBjiC`; session `SJ6xc2lkPzeQkaSS4QfU`, generation `zsWBh4I2mZo0VqHC80ti`, completed, 70 кредитов.

7-second seamless loop of a powerful narrow jet of pressurized seawater forcing through a small breach into a steel submarine compartment. Dense rushing water, low pressure roar and turbulent bubbling against metal close by. Steady urgent flow, enclosed steel hull resonance. No rain, shower, waterfall, voices, music or alarms. No fades.

### breach-jet-2

Запрошено 7 с, loop=true; Более широкая турбулентная струя, больше низкого бурления.
Node `mQ6nRhUmI0F5WGHeBwkF`; session `Y0BJ10bc73Ywyd0HzzID`, generation `YY08YpZ3mCjkJErSc8pG`, completed, 70 кредитов.

7-second seamless loop inside a damaged steel submarine compartment: a broad turbulent stream of seawater under high pressure, thick low rushing noise and coarse bubbling as water churns over metal. Less hiss, more dense liquid turbulence than a narrow jet. No rain, shower, waterfall, speech, music or siren. Steady flow with no fade in or out.

### alarm-siren-1

Запрошено 3 с, loop=true; Двухтоновый низкий металлический гудок, короткие чёткие чередования.
Node `G1DmS7UkKovM6inDg0hE`; запуск получил 429; аудио не получено.

3-second seamless loop of an industrial submarine emergency horn inside a steel hull. Two alternating low-mid metallic notes, clear measured pulses with a restrained short room resonance. Urgent and audible but not painfully loud, rounded attack. No police siren, car alarm, sweeping pitch, music, voices or extra beeps. Repeat evenly without fades.

### alarm-siren-2

Запрошено 3 с, loop=true; Более протяжный полый двухтоновый гудок, мягче атака.
Node `6PSHeRvIf4oAdWZabS7T`; ещё не запускался.

3-second seamless loop of a two-tone warning horn in a steel research submarine. Alternating hollow low notes with slightly longer holds, soft-edged onset and compact metallic room resonance. Serious measured warning, restrained dynamics. No police or car siren, rapid warbling, high squeal, music, speech or other beeps. Even repetition without fades.

### zap-1

Запрошено 1.6 с, loop=false; Короткий электрический удар, резкий треск и низкий хвост корпуса.
Node `fP2qRBr1Y4HwAyKPEGX7`; ещё не запускался.

One powerful electrical discharge across a submerged steel submarine hull, sharp dense crack at the start followed by rough electric crackle and a brief low metallic resonance fading to silence over 1.6 seconds. Muffled underwater perspective. No laser, sci-fi pew, explosion, voices, music or repeated strikes.

### zap-2

Запрошено 1.6 с, loop=false; Более широкий дуговой разряд, зернистый треск с мягким гулом после.
Node `hqquwCoXzLCrM14RNkbU`; ещё не запускался.

A single broad electric arc snapping across wet thick steel underwater, gritty short crackling burst and a soft bass hull shudder decaying naturally into silence. 1.6 seconds, close submerged vessel perspective, forceful but controlled. No laser, sci-fi pew, cinematic explosion, music, voices or repeating shocks.

## Права и открытые вопросы

Free и 10000 кредитов — по сообщению владельца на момент обсуждения; текущий баланс/тариф рабочего пространства коннектор не показывает. Владелец разрешил некоммерческое использование через Creative Studio вместо старых MCP-инструментов. При публикации нужна атрибуция ElevenLabs (elevenlabs.io); коммерческие права не заявляются. Покупок, включения доплат и смены плана не было.

Осталось: два варианта тревоги 2–4 с и два разряда 1–2 с, техпроверка и полная сдача. Собственная интерпретация — характер двух струй и варианты гудка/разряда в пределах заказа. Новых сюжетных фактов и реплик нет. Палитра и геометрия к звуку не применяются.
