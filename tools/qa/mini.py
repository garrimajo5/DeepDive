#!/usr/bin/env python3
"""Мини-сценарий тестера из tools/qa/scenario.json (#1350, 11.11): ракурс или провал одного кадра — без полного прогона.

Берёт шаги сценария с нужного места до нужного снимка, ставит впереди стандартное начало из CLAUDE.md
(«Тестер»: wait 1, press dive, wait 8, brief off, tutorial off, cards off — без press dive игра стоит в меню)
и в конце — quit.

  python3 tools/qa/mini.py 36b                  # от снимка 36b-ognecvet-posle (первый, чьё имя начинается с 36b) до него же
  python3 tools/qa/mini.py 36a 36b              # от снимка 36a… до снимка 36b… включительно
  python3 tools/qa/mini.py @797                 # «шаг 797» из лога тестера (номер с 1), до ближайшего снимка после него
  python3 tools/qa/mini.py 36b --ship           # назад — до ближайшего шага ship перед началом (корабль на месте)
  python3 tools/qa/mini.py 36b --put            # сразу в user://qa/scenario.json игры (Linux, облачная сессия)
  python3 tools/qa/mini.py 36b -o mini.json     # в файл; без -o и --put — в stdout

С --put помнить (CLAUDE.md): пока файл лежит, тесты не запускать — сценовые тесты его забирают.
Шаги, ставящие состояние раньше начала (hull, hot, breach, silt…), в мини-сценарий не попадают — для них --ship
или более раннее начало; что выпало после ближайшего ship перед началом, печатается в stderr. Там же — экраны,
открытые до начала и не закрытые (пауза, настройки, «Графика»…): без них первый back мини-сценария откроет паузу,
а не закроет экран (#1350, 13.11).
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCENARIO = os.path.join(HERE, "scenario.json")
USER_PATH = os.path.expanduser("~/.local/share/godot/app_userdata/Погружение/qa/scenario.json")

START = [
    {"do": "wait", "s": 1},
    {"do": "press", "what": "dive"},
    {"do": "wait", "s": 8},
    {"do": "brief", "on": False},
    {"do": "tutorial", "on": False},
    {"do": "cards", "on": False},
]
# Шаги, что меняют состояние игры надолго: выпали до начала — предупреждаем.
STATEFUL = {"ship", "hull", "hot", "breach", "silt", "drain", "charge", "mate", "sample", "fly", "outside",
            "floor", "save", "slow", "hud", "luch_ten", "dome", "gone"}
# Экраны (#1350, 13.11): нажатие открывает экран поверх прежнего, back или своя кнопка закрывает верхний.
# «Назад» без открытых экранов — пауза; «Выйти» → «Да» — главное меню, из него уводит press dive.
OPENERS = {"settings", "graphics", "golos", "zvuk", "map", "hint_map", "new", "exit", "journal", "jcell0", "crew",
           "lobby_addr", "lobby_new"}
CLOSERS = {"map_back", "no", "jclose", "resume"}
PAUSE = "пауза"
MENU = "главное меню"


def opened(steps, upto):
    """Экраны, открытые шагами до индекса upto и не закрытые к нему, снизу вверх: ["пауза", "settings", "graphics"]."""
    stack = []
    for st in steps[:upto]:
        do, what = st.get("do"), st.get("what")
        if do == "back":
            if not stack:
                stack.append(PAUSE)
            elif stack[-1] != MENU:
                stack.pop()
        elif do != "press":
            continue
        elif what == "dive":
            stack = []
        elif what == "yes" and stack and stack[-1] == "exit":
            stack = [MENU]
        elif what in OPENERS:
            stack.append(what)
        elif what in CLOSERS and stack and stack[-1] != MENU:
            stack.pop()
    return stack


def find(steps, key, after=0):
    """Индекс шага по ключу: @N — «шаг N» лога (с 1), иначе имя снимка или его начало (первый с after).
    Без @ число — начало имени снимка: имена снимков сами начинаются с цифр (01-start, 36b…)."""
    if key.startswith("@") and key[1:].isdigit():
        i = int(key[1:]) - 1
        if not 0 <= i < len(steps):
            raise SystemExit("шага %s нет: в сценарии %d шагов" % (key, len(steps)))
        return i
    for i in range(after, len(steps)):
        st = steps[i]
        if st.get("do") == "shot" and str(st.get("name", "")).startswith(key):
            return i
    raise SystemExit("снимка «%s» нет%s" % (key, " после шага %d" % after if after else ""))


def next_shot(steps, i):
    for j in range(i, len(steps)):
        if steps[j].get("do") == "shot":
            return j
    return len(steps) - 1


def cut(steps, start, end=None, ship=False):
    """(шаги мини-сценария, индекс первого взятого, выпавшие шаги состояния до него)."""
    a = find(steps, start)
    if steps[a].get("do") == "shot" and end is None:
        b = a
    elif end is None:
        b = next_shot(steps, a)
    else:
        b = find(steps, end, a)
    if b < a:
        raise SystemExit("конец раньше начала")
    if ship:
        while a > 0 and steps[a].get("do") != "ship":
            a -= 1
    # пред снимком обычно ждут: если начали ровно со снимка, берём и ожидание перед ним
    if steps[a].get("do") == "shot" and a > 0 and steps[a - 1].get("do") == "wait":
        a -= 1
    # заметки снимка (log) — за ним
    while b + 1 < len(steps) and steps[b + 1].get("do") == "log":
        b += 1
    body = [s for s in steps[a:b + 1] if s.get("do") != "quit"]
    # выпавшее состояние — от ближайшего ship перед началом (с ним корабль на месте; раньше — обычно чужое место)
    z = a - 1
    while z > 0 and steps[z].get("do") != "ship":
        z -= 1
    lost = [] if steps[a].get("do") == "ship" else \
        sorted({s["do"] for s in steps[max(z, 0):a] if s.get("do") in STATEFUL})
    return START + body + [{"do": "quit"}], a, lost


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("start", help="снимок (имя или начало) или @N — «шаг N» лога")
    p.add_argument("end", nargs="?", help="последний снимок (имя или начало); по умолчанию — первый снимок от начала")
    p.add_argument("--ship", action="store_true", help="начать с ближайшего шага ship перед началом")
    p.add_argument("--scenario", default=SCENARIO)
    g = p.add_mutually_exclusive_group()
    g.add_argument("-o", "--out")
    g.add_argument("--put", action="store_true", help="в " + USER_PATH)
    a = p.parse_args(argv)
    with open(a.scenario, encoding="utf-8") as f:
        steps = json.load(f)
    mini, first, lost = cut(steps, a.start, a.end, a.ship)
    text = "[\n" + ",\n".join("  " + json.dumps(s, ensure_ascii=False) for s in mini) + "\n]\n"
    out = USER_PATH if a.put else a.out
    if out:
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        with open(out, "w", encoding="utf-8") as f:
            f.write(text)
        print("мини-сценарий: %d шагов (с шага %d) → %s" % (len(mini), first + 1, out), file=sys.stderr)
    else:
        sys.stdout.write(text)
    if lost:
        print("до начала выпали шаги состояния: %s — нужен ли --ship или раннее начало?" % ", ".join(lost),
              file=sys.stderr)
    screens = opened(steps, first)
    if screens:
        print("до начала открыты и не закрыты экраны: %s — первый back закроет не то; начни раньше, с шага, "
              "который их открывает" % " → ".join(screens), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
