#!/usr/bin/env python3
"""Таблица времени тестов tests/vremya.txt по логу CI job «Тесты» (#852, как разовый расчёт в #1474).

В облаке полный прогон с `--times` идёт ~15 мин и под нагрузкой врёт, а лог job CI можно взять через gh. Время
файла — от последней строки предыдущего файла (или строки «Часть i из n») до последней строки этого файла
(«ок» или «ПАДЕНИЕ»), по меткам времени Actions в начале строк. Файлы, которых в логе нет, берут время из старой
таблицы; файлов, которых уже нет в tests/, в новой таблице нет.

  python3 tools/ci_times.py --run <id прогона Godot> [--repo владелец/репо] [--out tests/vremya.txt]
  python3 tools/ci_times.py <лог.txt|->… [--out tests/vremya.txt]      # из сохранённых логов job

Формат — как `TestShards.write_times` (tests/shards.gd): шапка, затем «файл<TAB>секунды» по имени.
Только стандартная библиотека.
"""
import datetime
import os
import re
import sys

HEAD = "# Время файлов тестов, с — для частей CI (#845). Обновить: run.gd -- --times tests/vremya.txt\n"
STAMP = re.compile(r"^\ufeff?(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(?:\.(\d+))?Z (.*)$")
START = re.compile(r"^Часть \d+ из \d+")
TEST = re.compile(r"^(?:  ок     |ПАДЕНИЕ  )(test_\w+)(?:\.|: )")
END = re.compile(r"^Тестов: \d+")


def stamp(day, frac):
    t = datetime.datetime.strptime(day, "%Y-%m-%dT%H:%M:%S").replace(tzinfo=datetime.timezone.utc).timestamp()
    return t + (float("0." + frac) if frac else 0.0)


def parse(text):
    """Лог job (одного или нескольких, подряд) → {файл.gd: секунды}. Время одного файла в разных частях
    складывается (так не бывает, но и не теряется)."""
    out = {}
    prev = None      # метка последней строки предыдущего файла (или начала части)
    cur = None       # файл, который идёт сейчас
    last = None      # метка последней строки текущего файла
    def close():
        if cur is not None and prev is not None and last is not None:
            out[cur + ".gd"] = out.get(cur + ".gd", 0.0) + max(0.0, last - prev)
    for line in text.splitlines():
        m = STAMP.match(line)
        if not m:
            continue
        t, body = stamp(m.group(1), m.group(2)), m.group(3)
        if START.match(body):
            close()
            prev, cur, last = t, None, None
            continue
        if END.match(body):
            close()
            prev, cur, last = None, None, None
            continue
        tm = TEST.match(body)
        if not tm or prev is None:
            continue
        name = tm.group(1)
        if name != cur:
            close()
            if last is not None:
                prev = last
            cur = name
        last = t
    close()
    return out


def read_table(text):
    """Как `TestShards.read_times`."""
    out = {}
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        p = s.split("\t")
        if len(p) == 2:
            try:
                out[p[0]] = float(p[1])
            except ValueError:
                pass
    return out


def write_table(times):
    """Как `TestShards.write_times`: по имени, два знака."""
    return HEAD + "".join("%s\t%.2f\n" % (f, times[f]) for f in sorted(times))


def merge(old, new, present=None):
    """Новые времена поверх старых; present — файлы, что есть в tests/ (None — не фильтровать)."""
    out = dict(old)
    out.update(new)
    if present is not None:
        out = {f: v for f, v in out.items() if f in present}
    return out


def run_logs(run_id, repo):
    import subprocess
    jobs = subprocess.run(["gh", "api", f"repos/{repo}/actions/runs/{run_id}/jobs", "--jq",
                           '.jobs[] | select(.name | startswith("Тесты")) | .id'],
                          check=True, capture_output=True, text=True).stdout.split()
    return "\n".join(subprocess.run(["gh", "api", f"repos/{repo}/actions/jobs/{j}/logs"], check=True,
                                    capture_output=True, text=True).stdout for j in jobs)


def main(argv):
    out_path = "tests/vremya.txt"
    repo = "garrimajo5/DeepDive"
    run_id = None
    logs = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--out", "--repo", "--run") and i + 1 < len(argv):
            if a == "--out":
                out_path = argv[i + 1]
            elif a == "--repo":
                repo = argv[i + 1]
            else:
                run_id = argv[i + 1]
            i += 2
            continue
        if a in ("-h", "--help"):
            print(__doc__)
            return 0
        logs.append(a)
        i += 1
    if run_id is None and not logs:
        print(__doc__)
        return 2
    text = run_logs(run_id, repo) if run_id else ""
    for p in logs:
        text += "\n" + (sys.stdin.read() if p == "-" else open(p, encoding="utf-8").read())
    new = parse(text)
    if not new:
        print("В логе нет строк тестов — таблица не тронута")
        return 1
    old = read_table(open(out_path, encoding="utf-8").read()) if os.path.exists(out_path) else {}
    tests_dir = os.path.dirname(out_path) or "."
    present = {f for f in os.listdir(tests_dir) if f.startswith("test_") and f.endswith(".gd")}
    table = merge(old, new, present or None)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(write_table(table))
    kept = len([f for f in table if f not in new])
    print(f"Записано {out_path}: файлов {len(table)}, из лога {len(new)}, из старой таблицы {kept}, "
          f"сумма {sum(table.values()):.0f} с")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
