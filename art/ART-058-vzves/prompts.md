# Источник форм
Встроенный ImageGen, 2026-10-22. Своя генерация на прозрачном фоне, без чужих изображений. Первый вариант оказался похож на кусочки льда с непрозрачными пузырями и отклонён; финальный источник — source/sprites.png.

## Генерация
Production VFX sprite atlas, transparent background, exactly 4×4 evenly spaced cells, no grid or lettering. Six distinct irregular soft torn marine snow flecks, three curved organic threads, three simple dust motes, three air bubbles with partial rims and small upper-left highlight, final cell empty. Nearly white cool gray-blue, alpha carries shape; generous empty margins. No winter snowflakes, glow, shadows, warm colors or scenery.

## Уточнение
Preserve exact grid positions. Remove saturated blue fringes and halos. Marine snow should be airy organic aggregates, not rocks or ice. Bubbles must have fully transparent centers, only incomplete fine rims and a tiny highlight. Keep background and final cell transparent.

## Упаковка
Из источника взяты альфа-силуэты, каждый кадр отдельно обрезан и вписан в ячейку 128² с прозрачными полями. RGB готового атласа постоянный #D5E4E8; сила альфы снижена по семействам. Источник с RGB-артефактами не используется как игровая текстура. Скрипт src/pack.py воспроизводит точные отступы и RGBA.
