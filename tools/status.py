#!/usr/bin/env python3
"""Страница «Где мы»: собирает статус разработки из GitHub и пишет его в закреплённый issue с меткой «статус».

Источник правды — issues: этап = milestone (7 этапов из docs/plan.md), эпик = issue с меткой «эпик»
(чек-лист «- [ ] что — роль — ⛔ кто блокирует» в теле, настоящие задачи — подзадачами, у сквозных треков
строка «План: `docs/…`» — прогресс считается по галочкам этого файла), роль = метка, блокер = зависимость
«blocked by» или «⛔» в чек-листе. Только stdlib + `gh api` (есть и в сессии, и на раннере GitHub).

    python3 tools/status.py --print   # показать страницу, ничего не меняя
    python3 tools/status.py           # обновить issue «Где мы» (создаст, если его нет)
Запускает CI: .github/workflows/status.yml (по событиям issues, слиянию в main и раз в день).
"""
import datetime as dt
import json
import os
import re
import subprocess
import sys
from urllib.parse import quote

REPO = os.environ.get("STATUS_REPO", "garrimajo5/DeepDive")
STATUS_LABEL = "статус"
STATUS_TITLE = "Где мы — статус разработки"
ROLES = ["поток А", "поток Б", "art", "model", "qa", "звук", "сюжет", "владелец"]
ROLE_NAMES = {
    "поток А": "Dev: корабль (Claude, поток А)",
    "поток Б": "Dev: живой мир (Claude, поток Б)",
    "art": "Концепт-арт, 2D (Codex)",
    "model": "3D-модели (Codex)",
    "qa": "Тестер",
    "звук": "Звук и музыка (владелец + Suno)",
    "сюжет": "Сюжет и лор (владелец)",
    "владелец": "Владелец: решения и приёмка",
}
TASK_RE = re.compile(r"^\s*[-*] \[( |x|X|~)\] (.+?)\s*$")
DOC_RE = re.compile(r"^\s*[-*] \[( |x|X|~)\]")
PLAN_RE = re.compile(r"План:\s*`([^`]+)`")
MSK = dt.timezone(dt.timedelta(hours=3))


# ---------- чистые функции (их проверяет tools/test_status.py) ----------

def parse_tasks(body):
    """Чек-лист тела эпика → [{done, text, roles, blocker}]. Роль — из частей «— …», блокер — после «⛔»."""
    out = []
    for line in (body or "").splitlines():
        m = TASK_RE.match(line)
        if not m:
            continue
        text = m.group(2)
        blocker = None
        if "⛔" in text:
            text, blocker = text.split("⛔", 1)
            blocker = blocker.strip(" —-").strip() or None
        parts = [p.strip() for p in text.split(" — ")]
        roles = []
        for p in parts[1:]:
            for r in ROLES:
                if re.search(r"(^|[\s,])" + re.escape(r) + r"($|[\s,(])", p) and r not in roles:
                    roles.append(r)
        out.append({"done": m.group(1) != " ", "text": parts[0].strip(" —"), "roles": roles, "blocker": blocker})
    return out


def doc_progress(text):
    """Галочки в файле плана: сделано ([x] и снятое [~]) и всего."""
    done = total = 0
    for line in (text or "").splitlines():
        m = DOC_RE.match(line)
        if m:
            total += 1
            done += m.group(1) != " "
    return done, total


def plan_path(body):
    m = PLAN_RE.search(body or "")
    return m.group(1) if m else None


def bar(done, total, width=10):
    if total <= 0:
        return "░" * width
    k = round(width * done / total)
    return "▓" * k + "░" * (width - k)


def pct(done, total):
    return round(100 * done / total) if total else 0


def short(text, n=40):
    """Короткая подпись задачи для таблицы: без `кода` (обрезка внутри него ломает разметку), с «…»."""
    text = text.replace("`", "")
    return text if len(text) <= n else text[:n].rstrip() + "…"


def stage_status(closed, n_epics, done, total, has_later_work):
    """Статус этапа: пройден / ждёт приёмки / в работе / впереди."""
    if closed:
        return "✅ пройден"
    if n_epics == 0:
        return "🟡 сделан, ждёт приёмки владельца" if has_later_work else "⏳ ещё не разложен"
    if total and done >= total:
        return "🟡 сделан, ждёт приёмки владельца"
    return "🔄 в работе" if done > 0 else "⏳ впереди"


# ---------- GitHub ----------

def gh(path, method="GET", payload=None, paginate=False):
    """`gh api`; paginate — все страницы списка. Листаем сами (&page=N): ссылки «next» у GitHub ведут
    на repositories/<id>/…, а прокси облачной сессии такие пути не пускает."""
    if paginate:
        out, page = [], 1
        while True:
            chunk = gh(f"{path}&page={page}") or []
            out += chunk
            if len(chunk) < 100 or page >= 20:
                return out
            page += 1
    cmd = ["gh", "api", "-X", method, quote(path, safe="/?&=:-_.~,")]
    if payload is not None:
        cmd += ["--input", "-"]
    r = subprocess.run(cmd, input=json.dumps(payload) if payload is not None else None,
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"gh api {path}: {r.stderr.strip()[:300]}")
    out = r.stdout.strip()
    return json.loads(out) if out else None


def labels_of(issue):
    return [l["name"] for l in issue.get("labels", [])]


def read_file(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return ""


def collect():
    ms = gh(f"repos/{REPO}/milestones?state=all&per_page=100", paginate=True)
    epics = gh(f"repos/{REPO}/issues?state=all&labels=эпик&per_page=100", paginate=True)
    open_issues = [i for i in gh(f"repos/{REPO}/issues?state=open&per_page=100", paginate=True)
                   if "pull_request" not in i]
    since = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ")
    recent = [i for i in gh(f"repos/{REPO}/issues?state=closed&since={since}&per_page=100", paginate=True)
              if i.get("closed_at", "") >= since]
    blocked = {}
    for i in open_issues:
        deps = gh(f"repos/{REPO}/issues/{i['number']}/dependencies/blocked_by") or []
        open_deps = [d for d in deps if d.get("state") == "open"]
        if open_deps:
            blocked[i["number"]] = open_deps
    return ms, epics, open_issues, recent, blocked


def epic_row(e):
    """Прогресс эпика: план-документ или чек-лист + подзадачи."""
    body = e.get("body") or ""
    tasks = parse_tasks(body)
    plan = plan_path(body)
    if plan:
        done, total = doc_progress(read_file(plan))
    else:
        done = sum(t["done"] for t in tasks)
        total = len(tasks)
    s = e.get("sub_issues_summary") or {}
    done += s.get("completed", 0)
    total += s.get("total", 0)
    if e["state"] == "closed":
        done = total = max(total, 1)
    return {"n": e["number"], "title": e["title"].removeprefix("Эпик: "), "state": e["state"],
            "ms": (e.get("milestone") or {}).get("number"), "roles": [r for r in labels_of(e) if r in ROLES],
            "done": done, "total": total, "tasks": tasks, "plan": plan}


def render(ms, epics, open_issues, recent, blocked, now=None):
    now = now or dt.datetime.now(MSK)
    rows = [epic_row(e) for e in epics]
    by_ms = {}
    for r in rows:
        by_ms.setdefault(r["ms"], []).append(r)
    stages = sorted([m for m in ms if m["title"].startswith("Этап")], key=lambda m: m["number"])
    first_with_epics = min([m["number"] for m in stages if by_ms.get(m["number"])], default=99)

    L = [f"# {STATUS_TITLE}",
         f"_Обновлено автоматически {now:%d.%m.%Y %H:%M} МСК (`tools/status.py`). Не редактировать руками — "
         f"меняйте эпики, метки и milestones._", ""]

    # --- где мы ---
    stage_lines, current = [], []
    for m in stages:
        er = by_ms.get(m["number"], [])
        d = sum(r["done"] for r in er)
        t = sum(r["total"] for r in er)
        st = stage_status(m["state"] == "closed", len(er), d, t, m["number"] < first_with_epics)
        if st.startswith("🔄"):
            current.append(m["title"])
        prog = f"{bar(d, t)} {pct(d, t)}%" if er else "—"
        eps = ", ".join(f"#{r['n']}" for r in er) or "—"
        stage_lines.append(f"| {m['title']} | {st} | {prog} | {eps} |")
    waiting = [m["title"].split(". ", 1)[-1] for m in stages
               if m["state"] == "open" and m["number"] < first_with_epics]
    head = "**Сейчас:** " + (current[0] if current else "активных этапов нет")
    if len(current) > 1:
        head += " · параллельно: " + ", ".join(c.split(". ", 1)[-1] for c in current[1:])
    if waiting:
        head += f". Этапы {waiting[0]}…{waiting[-1]} сделаны и ждут приёмки владельца (эпик приёмки)."
    L += [head, "", "## Этапы", "| Этап | Статус | Прогресс | Эпики |", "|---|---|---|---|"] + stage_lines

    # --- эпики ---
    def epic_lines(rs):
        out = []
        for r in sorted(rs, key=lambda r: (r["state"] == "closed", r["n"])):
            roles = ", ".join(r["roles"]) or "—"
            mark = "✅ " if r["state"] == "closed" else ""
            blk = []
            for b in blocked.get(r["n"], []):
                blk.append(f"ждёт #{b['number']}")
            blk += sorted({t["blocker"] for t in r["tasks"] if not t["done"] and t["blocker"]})
            src = f" · план `{r['plan']}`" if r["plan"] else ""
            out.append(f"| {mark}#{r['n']} {r['title']}{src} | {roles} | {bar(r['done'], r['total'])} "
                       f"{r['done']}/{r['total']} | {'; '.join(blk) or '—'} |")
        return out

    staged = [r for r in rows if r["ms"]]
    cross = [r for r in rows if not r["ms"]]
    hdr = ["| Эпик | Роли | Прогресс | Блокеры |", "|---|---|---|---|"]
    L += ["", "## Эпики этапов"] + hdr + epic_lines(staged)
    L += ["", "## Сквозные треки и приёмка"] + hdr + epic_lines(cross)

    # --- по ролям ---
    L += ["", "## Кто что делает (открыто)", "| Роль | Задач в эпиках | Issues | Ближайшее |", "|---|---|---|---|"]
    epic_nums = {e["number"] for e in epics}
    work = [i for i in open_issues if i["number"] not in epic_nums and STATUS_LABEL not in labels_of(i)
            and "on-hold" not in labels_of(i) and "idea" not in labels_of(i)]
    for role in ROLES:
        tasks = [(r, t) for r in rows if r["state"] == "open" for t in r["tasks"]
                 if not t["done"] and role in t["roles"]]
        # «проверить» — исправлено и ждёт тестера на устройстве: это работа роли qa
        iss = [i for i in work if role in labels_of(i) or (role == "qa" and "проверить" in labels_of(i))]
        near = [f"#{i['number']}" + (" (в работе)" if "в работе" in labels_of(i) else "")
                + (" (проверить)" if role == "qa" and "проверить" in labels_of(i) else "") for i in iss[:3]]
        near += [f"{short(t['text'])} (#{r['n']})" for r, t in tasks if not t["blocker"]][:max(0, 2 - len(near))]
        flag = " ⚠️ нет исполнителя-агента" if role in ("звук", "сюжет") else ""
        L.append(f"| {ROLE_NAMES[role]}{flag} | {len(tasks)} | {len(iss)} | {'; '.join(near) or '—'} |")

    # --- ждёт владельца и заблокировано ---
    owner = [i for i in open_issues if "ждёт владельца" in labels_of(i)]
    owner_tasks = [(r, t) for r in rows if r["state"] == "open" for t in r["tasks"]
                   if not t["done"] and t["blocker"] and "владел" in t["blocker"] and "on-hold" not in t["blocker"]]
    L += ["", f"## ⛔ Ждёт владельца ({len(owner) + len(owner_tasks)})"]
    L += [f"- #{i['number']} {i['title']}" for i in owner]
    L += [f"- {t['text']} — эпик #{r['n']}" for r, t in owner_tasks]
    blk_issues = [(n, ds) for n, ds in blocked.items() if n not in epic_nums]
    held = [i for i in open_issues if "on-hold" in labels_of(i)]
    if blk_issues or held:
        L += ["", "## Заблокировано и отложено"]
        L += [f"- #{n} ждёт " + ", ".join(f"#{d['number']}" for d in ds) for n, ds in blk_issues]
        L += [f"- #{i['number']} {i['title']} — `on-hold`" for i in held]

    # --- сделано за неделю ---
    done7 = [i for i in recent if "pull_request" not in i and STATUS_LABEL not in labels_of(i)]
    prs7 = [i for i in recent if "pull_request" in i]
    L += ["", f"## ✅ Сделано за 7 дней: {len(done7)} задач, {len(prs7)} PR"]
    L += [f"- #{i['number']} {i['title']}" for i in sorted(done7, key=lambda i: i["closed_at"], reverse=True)[:15]]
    if len(done7) > 15:
        L.append(f"- …и ещё {len(done7) - 15}")
    L += ["", "---", "Как устроено: этап = milestone, эпик = issue «эпик» (чек-лист `- [ ] что — роль — ⛔ кто "
          "блокирует` + подзадачи), роль = метка, блокер = «blocked by». Правила — `CLAUDE.md`, раздел «Роадмап и статус»."]
    return "\n".join(L) + "\n"


def main():
    ms, epics, open_issues, recent, blocked = collect()
    text = render(ms, epics, open_issues, recent, blocked)
    if "--print" in sys.argv:
        print(text)
        return
    found = gh(f"repos/{REPO}/issues?state=open&labels={STATUS_LABEL}&per_page=10") or []
    if found:
        gh(f"repos/{REPO}/issues/{found[0]['number']}", "PATCH", {"body": text, "title": STATUS_TITLE})
        print(f"обновлён #{found[0]['number']}")
    else:
        r = gh(f"repos/{REPO}/issues", "POST", {"title": STATUS_TITLE, "body": text, "labels": [STATUS_LABEL]})
        print(f"создан #{r['number']} — закрепите его в GitHub (Pin issue)")


if __name__ == "__main__":
    main()
