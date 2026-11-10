#!/usr/bin/env python3
"""Таблица замеров шага живого мира по логам CI (#1350, поток Б 10.11): строки «шаг живого мира … на ПК»
из `test_eco_speed.test_view_step_fits_frame` в логах job «Тесты» последних прогонов «Godot».

Порог `LIMIT_PC_MS` и таблицу `RUNNERS` в tests/test_eco_speed.gd меняют только по замерам разных раннеров CI:
одна машина разброса не показывает. Скрипт собирает эти замеры разом — вместо ручного чтения логов прогон за прогоном.

  python3 tools/ci_speed.py --runs 20 [--branch main] [--repo владелец/репо]   # последние N прогонов с замером
  python3 tools/ci_speed.py --run <id> [--run <id>…]                          # выбранные прогоны
  python3 tools/ci_speed.py <лог.txt|->…                                      # сохранённые логи job

Печатает строку на прогон (шаг, порог, на ПК, мерки, запас до порога на ПК), сводку на ПК (мин., медиана, макс.)
и строки в формате `RUNNERS` для машин, которые порог с запасом `MARGIN` не покрывает. Порог и запас берёт из
tests/test_eco_speed.gd. Прогоны без замера (тесты пропущены, файл в другой части не дошёл) пропускает, `--runs`
добирает следующими — смотрит не больше 5·N прогонов. Только стандартная библиотека.
"""
import os
import re
import statistics
import sys

LINE = re.compile(r"шаг живого мира (\d+\.\d+) мс, порог (\d+\.\d+) \(на ПК (\d+\.\d+) из (\d+\.\d+); "
                  r"мерка (\d+\.\d+) мс, объекты (\d+\.\d+) мс; часы: (\S+)\)")
TEST_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tests", "test_eco_speed.gd")


def parse(text):
    """Лог (одного или нескольких job) → список замеров {step, limit, pc, limit_pc, ref, obj, clock}."""
    out = []
    for m in LINE.finditer(text):
        out.append({"step": float(m.group(1)), "limit": float(m.group(2)), "pc": float(m.group(3)),
                    "limit_pc": float(m.group(4)), "ref": float(m.group(5)), "obj": float(m.group(6)),
                    "clock": m.group(7)})
    return out


def consts(text):
    """Порог на ПК и запас из test_eco_speed.gd → (LIMIT_PC_MS, MARGIN); нет строки — None."""
    def num(name):
        m = re.search(r"^const %s := (\d+(?:\.\d+)?)" % name, text, re.M)
        return float(m.group(1)) if m else None
    return num("LIMIT_PC_MS"), num("MARGIN")


def headroom(pc, limit_pc):
    """Запас до порога на ПК, доля (0,10 — шаг на 10 % ниже порога)."""
    return limit_pc / pc - 1.0 if pc > 0 else float("inf")


def summary(rows):
    """Замеры → (мин., медиана, макс.) шага на ПК; пусто — None."""
    pcs = [r["pc"] for r in rows]
    if not pcs:
        return None
    return min(pcs), statistics.median(pcs), max(pcs)


def uncovered(rows, limit_pc, margin):
    """Замеры, которые порог с запасом не покрывает (как test_limit_covers_runners: pc·(1 + запас) > порог)."""
    return [r for r in rows if r["pc"] * (1.0 + margin) > limit_pc + 1e-9]


def runners_line(r, label):
    """Строка таблицы RUNNERS: [шаг, мерка ref, мерка obj]."""
    return "\t[%.2f, %.3f, %.3f],  # %s (%.2f на ПК)" % (r["step"], r["ref"], r["obj"], label, r["pc"])


def gh(*args):
    import subprocess
    return subprocess.run(["gh", "api", *args], check=True, capture_output=True, text=True).stdout


def run_info(run_id, repo):
    """Прогон → (короткий sha, дата, итог)."""
    out = gh(f"repos/{repo}/actions/runs/{run_id}", "--jq",
             '"\\(.head_sha[0:7]) \\(.created_at[0:16]) \\(.conclusion)"').split()
    return out if len(out) == 3 else ["?", "?", "?"]


def run_logs(run_id, repo):
    jobs = gh(f"repos/{repo}/actions/runs/{run_id}/jobs", "--jq",
              '.jobs[] | select(.name | startswith("Тесты")) | select(.conclusion != "skipped") | .id').split()
    text = []
    for j in jobs:
        try:
            text.append(gh(f"repos/{repo}/actions/jobs/{j}/logs"))
        except Exception:   # лог стёрт или job ещё идёт
            pass
    return "\n".join(text)


def recent_runs(repo, branch, limit):
    """id завершённых прогонов «Godot» на ветке, новые первыми (не больше limit)."""
    ids = []
    page = 1
    while len(ids) < limit:
        got = gh("-X", "GET", f"repos/{repo}/actions/workflows/godot.yml/runs", "-f", f"branch={branch}",
                 "-f", "status=completed", "-f", "per_page=50", "-f", f"page={page}",
                 "--jq", ".workflow_runs[].id").split()
        if not got:
            break
        ids += got
        page += 1
    return ids[:limit]


def report(rows, limit_pc, margin, out=None):
    """rows — [(метка, замер)] → печать таблицы; возвращает число непокрытых замеров."""
    out = out or sys.stdout
    if not rows:
        print("В логах нет строк «шаг живого мира» — замеров нет", file=out)
        return 0
    print("прогон\tшаг\tпорог\tна ПК\tмерка\tобъекты\tзапас", file=out)
    for label, r in rows:
        print("%s\t%.2f\t%.2f\t%.2f\t%.3f\t%.3f\t%+.0f %%" % (
            label, r["step"], r["limit"], r["pc"], r["ref"], r["obj"], 100 * headroom(r["pc"], limit_pc)), file=out)
    lo, med, hi = summary([r for _, r in rows])
    print("Замеров %d: на ПК %.2f–%.2f, медиана %.2f; порог %.2f, запас у худшего %+.0f %% (нужно ≥ %.0f %%)" % (
        len(rows), lo, hi, med, limit_pc, 100 * headroom(hi, limit_pc), 100 * margin), file=out)
    bad = [(label, r) for label, r in rows if uncovered([r], limit_pc, margin)]
    if bad:
        print("Порог с запасом не покрывает — строки для RUNNERS:", file=out)
        for label, r in bad:
            print(runners_line(r, "раннер CI, " + label), file=out)
    return len(bad)


def main(argv):
    repo = "garrimajo5/DeepDive"
    branch = "main"
    runs = []
    count = 0
    logs = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--repo", "--run", "--runs", "--branch") and i + 1 < len(argv):
            v = argv[i + 1]
            if a == "--repo":
                repo = v
            elif a == "--branch":
                branch = v
            elif a == "--run":
                runs.append(v)
            else:
                count = int(v)
            i += 2
            continue
        if a in ("-h", "--help"):
            print(__doc__)
            return 0
        logs.append(a)
        i += 1
    if not runs and not logs and count <= 0:
        print(__doc__)
        return 2
    limit_pc, margin = None, None
    if os.path.exists(TEST_FILE):
        with open(TEST_FILE, encoding="utf-8") as f:
            limit_pc, margin = consts(f.read())
    limit_pc = limit_pc or 3.8
    margin = 0.10 if margin is None else margin
    rows = []
    for p in logs:
        if p == "-":
            text = sys.stdin.read()
        else:
            with open(p, encoding="utf-8") as f:
                text = f.read()
        rows += [(os.path.basename(p) if p != "-" else "stdin", r) for r in parse(text)]
    for rid in runs:
        sha, day, concl = run_info(rid, repo)
        rows += [("%s %s %s %s" % (rid, sha, day, concl), r) for r in parse(run_logs(rid, repo))]
    if count > 0:
        found = 0
        for rid in recent_runs(repo, branch, 5 * count):
            got = parse(run_logs(rid, repo))
            if not got:
                continue
            sha, day, concl = run_info(rid, repo)
            rows += [("%s %s %s %s" % (rid, sha, day, concl), r) for r in got]
            found += 1
            if found >= count:
                break
    report(rows, limit_pc, margin)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
