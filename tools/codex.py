#!/usr/bin/env python3
"""Кодекс игры (#1417) — внутренний справочник для команды, собирается из файлов репозитория.

Руками не пишется: правка содержания — в исходниках (`docs/world.md`, `docs/bestiary.md`, `docs/urovni/sloj-1.md`,
`scripts/core/layer_map.gd`, `scripts/core/eco/species.gd`, `docs/concept-art/*.md`), справочник пересобирает CI
(`.github/workflows/codex.yml`) при слиянии в `main`. Без внешних библиотек.

  python3 tools/codex.py [папка]  — `index.html` и `img/` (по умолчанию `build/codex/`; CI публикует на Pages)
"""
import html
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = "docs/concept-art"
LAYER_MAP = "scripts/core/layer_map.gd"
SPECIES = "scripts/core/eco/species.gd"
BESTIARY = "docs/bestiary.md"
WORLD = "docs/world.md"
SLOJ1 = "docs/urovni/sloj-1.md"
LAYER1_SECTION = "Подлёдный сад"
IMG_EXT = (".png", ".jpg", ".jpeg", ".gif")


def read(rel, root=ROOT):
    with open(os.path.join(root, rel), encoding="utf-8") as f:
        return f.read()


# ---------- источники ----------

def layer_map(text):
    """Места слоя 1 из `LayerMap.POINTS` (id → поля) и маршруты `MAIN_ROUTE`/`LINKS`."""
    points = {}
    for m in re.finditer(r'^\s*"(\d\d)": \{(.*)\},?\s*$', text, re.M):
        body = m.group(2)
        p = {k: v for k, v in re.findall(r'"(\w+)": "([^"]*)"', body)}
        for k, v in re.findall(r'"(\w+)": (-?[\d.]+)', body):
            p[k] = float(v)
        p["accepted"] = '"accepted": true' in body
        points[m.group(1)] = p
    main = re.search(r"MAIN_ROUTE[^=]*=\s*\[([^\]]*)\]", text).group(1)
    links = re.search(r"LINKS[^=]*=\s*\[(.*)\]\s*$", text, re.M).group(1)
    return {
        "points": points,
        "main": re.findall(r'"(\d\d)"', main),
        "links": [re.findall(r'"(\d\d)"', g) for g in re.findall(r"\[([^\[\]]*)\]", links)],
    }


def bends(text):
    """Изгибы переходов из схемы слоя (`sloj-1.md`, «Поправка маршрутов»): строка `- **06 → (250; 200) → 10**`
    → {("06", "10"): (250.0, 200.0)}. Прямая между такими местами идёт сквозь рельеф (#1417)."""
    out = {}
    for a, x, z, b in re.findall(r"^- \*\*(\d\d) → \(([−\-\d.,]+); ([−\-\d.,]+)\) → (\d\d)\*\*", text, re.M):
        num = lambda v: float(v.replace("−", "-").replace(",", "."))
        out[(a, b)] = (num(x), num(z))
    return out


def bend_of(bs, a, b):
    """Точка изгиба перехода a↔b (в любую сторону) или None."""
    return bs.get((a, b)) or bs.get((b, a))


def species(text):
    """Реестр видов `Species.ALL`: id, имя, описание, заметки журнала — по порядку журнала."""
    out = []
    for block in re.split(r"\n\t\{\n", text.split("const ALL", 1)[1])[1:]:
        sid = re.search(r'"id": "([^"]+)"', block)
        if not sid:
            continue
        out.append({
            "id": sid.group(1),
            "name": re.search(r'"name": "([^"]+)"', block).group(1),
            "desc": re.search(r'"desc": "([^"]+)"', block).group(1),
            "notes": [t for _k, t in re.findall(r'\["(\w+)", "([^"]+)"\]', block)],
        })
    return out


def bestiary(text):
    """Виды бестиария: имя → раздел, свойства в скобках, пометки, описание, особенность, связи."""
    out, section = {}, ""
    for line in text.splitlines():
        if line.startswith("## "):
            section = line[3:].strip()
            continue
        m = re.match(r"^- \*\*([^*]+)\*\* \(([^)]*)\)((?: \[[^\]]+\])*): (.*)$", line)
        if not m:
            continue
        body = m.group(4)
        parts = re.split(r"\*(Особенность|Связи):\* ", body)
        e = {"section": section, "props": m.group(2), "marks": re.findall(r"\[([^\]]+)\]", m.group(3)),
             "text": parts[0].strip(), "trait": "", "links": ""}
        for i in range(1, len(parts) - 1, 2):
            e["trait" if parts[i] == "Особенность" else "links"] = parts[i + 1].strip()
        out[m.group(1)] = e
    return out


def sloj1_rows(text):
    """Строки таблиц `docs/urovni/sloj-1.md` по id места: путь, цель, что делает экипаж, информация и затишье."""
    rows = {}
    for line in text.splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        m = re.match(r"^(\d\d)\b", cells[0]) if line.startswith("|") else None
        if not m:
            continue
        r = rows.setdefault(m.group(1), {})
        if len(cells) == 7:
            r.update({"path": cells[3], "time": cells[4], "crew": cells[6]})
        elif len(cells) == 3:
            r.update({"info": cells[1], "calm": cells[2]})
    return rows


def concept_notes(root=ROOT):
    """Заметки концептов: файл → (заголовок, картинки из текста заметки, которые лежат рядом)."""
    out = {}
    folder = os.path.join(root, ART)
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".md"):
            continue
        text = read(os.path.join(ART, name), root)
        head = text.split("\n", 1)[0].lstrip("# ").strip()
        imgs = []
        for f in re.findall(r"`([\w.-]+)`", text):
            if f.lower().endswith(IMG_EXT) and os.path.isfile(os.path.join(folder, f)) and f not in imgs:
                imgs.append(f)
        out[name] = {"head": head, "text": text, "imgs": imgs}
    return out


def stems(name):
    """Основы слов имени для поиска в заголовке: «Скребун» найдётся в «Стеклоуст и скребун»."""
    return [w[:-1] if len(w) > 5 else w for w in name.lower().split()]


def picture(note):
    """Картинка карточки из заметки: первая сцена (jpg), иначе первый лист; иконки мест — не сюда."""
    imgs = [i for i in note["imgs"] if not i.startswith("ikonk")]
    jpg = [i for i in imgs if i.endswith((".jpg", ".jpeg"))]
    return (jpg or imgs or note["imgs"])[0]


def find_concept(name, notes):
    """Заметка концепта вида или места: имя в заголовке, иначе строка таблицы «| Имя |» в заметке."""
    keys = stems(name)
    for f, n in notes.items():
        if all(k in n["head"].lower() for k in keys) and n["imgs"]:
            return f
    for f, n in notes.items():
        if re.search(r"^\| " + re.escape(name) + r" \|", n["text"], re.M) and n["imgs"]:
            return f
    return ""


def models_of(note, root=ROOT):
    """Модели `models/*.glb`, названные в заметке концепта."""
    return [m for m in dict.fromkeys(re.findall(r"(?:models/)?([\w-]+\.glb)", note["text"]))
            if os.path.isfile(os.path.join(root, "models", m))]


# ---------- разметка ----------

def inline_md(s):
    s = html.escape(s, quote=False)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", s)
    s = re.sub(r"(?<![\w*])\*([^*\s][^*]*)\*(?![\w*])", r"<i>\1</i>", s)
    s = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", r'<a href="\2">\1</a>', s)
    s = re.sub(r"&lt;(https?://[^&\s]+)&gt;", r'<a href="\1">\1</a>', s)
    return s


def markdown(text, shift=1):
    """Простой Markdown → HTML: заголовки (ниже на `shift`), абзацы, списки, таблицы, цитаты, код."""
    out, para, items, table = [], [], [], []
    kind = ""

    def flush():
        nonlocal kind
        if para:
            out.append("<p>" + inline_md(" ".join(para)) + "</p>")
            para.clear()
        if items:
            out.append(f"<{kind}>" + "".join(f"<li>{inline_md(i)}</li>" for i in items) + f"</{kind}>")
            items.clear()
        if table:
            rows = [[c.strip() for c in r.strip().strip("|").split("|")] for r in table]
            body = [r for r in rows[1:] if not all(re.fullmatch(r":?-+:?", c) for c in r)]
            h = "".join(f"<th>{inline_md(c)}</th>" for c in rows[0])
            b = "".join("<tr>" + "".join(f"<td>{inline_md(c)}</td>" for c in r) + "</tr>" for r in body)
            out.append(f'<div class="tw"><table><tr>{h}</tr>{b}</table></div>')
            table.clear()

    code = None
    for line in text.splitlines():
        if line.startswith("```"):
            if code is None:
                flush()
                code = []
            else:
                out.append("<pre>" + html.escape("\n".join(code)) + "</pre>")
                code = None
            continue
        if code is not None:
            code.append(line)
            continue
        s = line.strip()
        m = re.match(r"^(#{1,6}) (.*)$", s)
        if m:
            flush()
            n = min(len(m.group(1)) + shift, 6)
            out.append(f"<h{n}>{inline_md(m.group(2))}</h{n}>")
        elif not s:
            flush()
        elif s.startswith("|"):
            if para or items:
                flush()
            table.append(s)
        elif re.match(r"^([-*]|\d+\.) ", s):
            if para or table:
                flush()
            k = "ol" if s[0].isdigit() else "ul"
            if items and k != kind:
                flush()
            kind = k
            items.append(re.sub(r"^([-*]|\d+\.) ", "", s))
        elif s.startswith(">"):
            flush()
            out.append("<blockquote>" + inline_md(s.lstrip("> ")) + "</blockquote>")
        elif items and line.startswith(" "):
            items[-1] += " " + s
        else:
            if items or table:
                flush()
            para.append(s)
    flush()
    return "\n".join(out)


class Images:
    """Картинки справочника: копия в `img/` рядом с index.html."""

    def __init__(self, out_dir, root=ROOT):
        self.out_dir, self.root, self.done = out_dir, root, {}

    def url(self, rel):
        if rel in self.done:
            return self.done[rel]
        src = os.path.join(self.root, rel)
        name = rel.replace("/", "_")
        os.makedirs(os.path.join(self.out_dir, "img"), exist_ok=True)
        shutil.copyfile(src, os.path.join(self.out_dir, "img", name))
        url = "img/" + name
        self.done[rel] = url
        return url

    def tag(self, rel, alt):
        return f'<img loading="lazy" src="{self.url(rel)}" alt="{html.escape(alt)}">'


STATUS = {"game": ("в игре", "s-game"), "concept": ("только концепт", "s-concept"), "plan": ("в планах", "s-plan")}


def badge(st):
    t, c = STATUS[st]
    return f'<span class="st {c}">{t}</span>'


def esc(s):
    return html.escape(str(s), quote=False)


# ---------- разделы ----------

def section_world(world, notes, img):
    out = ['<section id="mir"><h2>Мир</h2>', markdown(world, shift=1)]
    figs = []
    for f in ("ekipazh.md", "kovcheg-7.md"):
        n = notes.get(f)
        if n:
            figs += [(os.path.join(ART, i), n["head"]) for i in n["imgs"][:4]]
    if figs:
        out.append('<h3>Экипаж и корабль — концепты</h3><div class="gal">')
        for rel, cap in figs:
            out.append(f"<figure>{img.tag(rel, cap)}<figcaption>{esc(cap)}</figcaption></figure>")
        out.append("</div>")
    out.append("</section>")
    return "\n".join(out)


def map_svg(lm, bs=None):
    bs = bs or {}
    pts = lm["points"]
    xs = [p["x"] for p in pts.values()] + [-350.0, 350.0]
    zs = [p["z"] for p in pts.values()] + [-350.0, 350.0]
    x0, x1, z0, z1 = min(xs) - 30, max(xs) + 40, min(zs) - 30, max(zs) + 30
    w, h = x1 - x0, z1 - z0
    seg = []
    for path, cls in [(lm["main"], "main")] + [(p, "link") for p in lm["links"]]:
        for a, b in zip(path, path[1:]):
            pa, pb = pts[a], pts[b]
            k = bend_of(bs, a, b)
            if k:   # обязательный изгиб из схемы: ломаная через точку хода, не прямая сквозь рельеф
                seg.append(f'<polyline class="{cls}" points="{pa["x"]:g},{pa["z"]:g} {k[0]:g},{k[1]:g} '
                           f'{pb["x"]:g},{pb["z"]:g}"/><circle class="bend" cx="{k[0]:g}" cy="{k[1]:g}" r="5"/>')
            else:
                seg.append(f'<line class="{cls}" x1="{pa["x"]}" y1="{pa["z"]}" x2="{pb["x"]}" y2="{pb["z"]}"/>')
    dots = []
    for pid, p in pts.items():
        cls = "pt" if p["accepted"] else "pt prop"
        right = p["x"] > 350.0   # за восточным краем — подпись слева от точки, иначе уходит за рамку
        tx, anchor = (p["x"] - 12, ' text-anchor="end"') if right else (p["x"] + 12, "")
        dots.append(f'<a href="#mesto-{pid}"><circle class="{cls}" cx="{p["x"]}" cy="{p["z"]}" r="9"/>'
                    f'<text x="{tx}" y="{p["z"] + 5}"{anchor}>{pid} {esc(p["name"])}</text></a>')
    return (f'<svg class="map" viewBox="{x0} {z0} {w} {h}" role="img" aria-label="Карта слоя 1">'
            f'<rect class="shelf" x="-350" y="-350" width="700" height="700"/>' + "".join(seg) + "".join(dots) +
            f'<text class="n" x="{x0 + 8}" y="{z0 + 24}">север −Z ↑</text></svg>')


def bends_note(bs):
    """Оговорка у карты: схема связей, а не путь хода, и изгибы из схемы слоя."""
    if not bs:
        return ""
    fmt = lambda v: f"{v:g}".replace("-", "−")
    turns = "; ".join(f"{a} → ({fmt(x)}; {fmt(z)}) → {b}" for (a, b), (x, z) in bs.items())
    return (f'<p class="leg"><b>Схема связей мест, не путь хода.</b> Линии — порядок посещения; прямые идут сквозь '
            f'рельеф. Обязательные изгибы (<span class="b"></span>) из <code>{SLOJ1}</code>: {turns}.</p>')


def section_layer(lm, rows, sloj1, notes, img):
    pts = lm["points"]
    bs = bends(sloj1)
    out = ['<section id="sloj1"><h2>Слой 1 «Подлёдный сад»</h2>',
           f'<p class="src">Источник: <code>{LAYER_MAP}</code>, <code>{SLOJ1}</code>.</p>', map_svg(lm, bs),
           bends_note(bs),
           '<p class="leg"><span class="k main"></span> основной маршрут '
           + " → ".join(lm["main"]) + ' &nbsp; <span class="k link"></span> петли и ответвления: '
           + "; ".join(" → ".join(p) for p in lm["links"])
           + ' &nbsp; <span class="d"></span> «предложение» карты #818</p><div class="cards">']
    for pid, p in pts.items():
        r = rows.get(pid, {})
        st = "game"
        icon = f"textures/places/{p['key']}.png"
        note = find_concept(p["name"], notes)
        pic = ""
        if os.path.isfile(os.path.join(ROOT, icon)):
            pic += img.tag(icon, p["name"])
        if note:
            pic += img.tag(os.path.join(ART, picture(notes[note])), notes[note]["head"])
        lines = [f'<p><b>Глубина ориентира:</b> {p["depth"]:g} м; x, z: {p["x"]:g}, {p["z"]:g}</p>']
        if not p["accepted"]:
            lines.append("<p class=\"warn\">«Предложение» карты #818 — место ещё строится.</p>")
        if r.get("path"):
            lines.append(f'<p><b>Путь:</b> {esc(r["path"])}; <b>цель:</b> {esc(r["time"])} мин</p>')
        if r.get("crew"):
            lines.append(f'<p><b>Что делает экипаж:</b> {inline_md(r["crew"])}</p>')
        if r.get("info"):
            lines.append(f'<p><b>Информация и решение:</b> {inline_md(r["info"])}</p>')
        if r.get("calm"):
            lines.append(f'<p><b>Затишье:</b> {inline_md(r["calm"])}</p>')
        if note:
            lines.append(f'<p class="src">Концепт: <code>{ART}/{note}</code></p>')
        out.append(f'<article class="card" id="mesto-{pid}"><div class="pics">{pic}</div><div>'
                   f'<h3>{pid} {esc(p["name"])} {badge(st)}</h3>{"".join(lines)}</div></article>')
    out.append("</div>")
    body = sloj1.split("\n## ", 1)
    if len(body) > 1:
        out.append('<details><summary>Схема слоя целиком (<code>docs/urovni/sloj-1.md</code>)</summary>'
                   + markdown("## " + body[1], shift=1) + "</details>")
    out.append("</section>")
    return "\n".join(out)


def layer1_species(reg, best):
    """Виды слоя 1: реестр (по порядку журнала), виды мира с пометкой «в игре», затем раздел бестиария «Подлёдный сад»."""
    names = [s["name"] for s in reg]
    for n, e in best.items():
        if "в игре" in e["marks"] and n not in names:
            names.append(n)
    for n, e in best.items():
        if e["section"] == LAYER1_SECTION and n not in names:
            names.append(n)
    return names


def section_species(reg, best, notes, img):
    by_name = {s["name"]: s for s in reg}
    out = ['<section id="vidy"><h2>Существа слоя 1</h2>',
           f'<p class="src">Источник: <code>{SPECIES}</code>, <code>{BESTIARY}</code>, заметки <code>{ART}/</code>. '
           "Статус: «в игре» — вид в реестре или пометка «[в игре]» в бестиарии; «только концепт» — есть концепт; "
           "«в планах» — только запись бестиария.</p><div class=\"cards\">"]
    for n in layer1_species(reg, best):
        s, e = by_name.get(n), best.get(n, {})
        note = find_concept(n, notes)
        marks = e.get("marks", [])
        st = "game" if s or "в игре" in marks else ("concept" if note or "концепт" in marks else "plan")
        pic = img.tag(os.path.join(ART, picture(notes[note])), notes[note]["head"]) if note else ""
        lines = []
        if e:
            lines.append(f'<p class="props">{esc(e["props"])} · раздел бестиария «{esc(e["section"])}»</p>')
        if s:
            lines.append(f"<p>{inline_md(s['desc'])}</p>")
        elif e:
            lines.append(f"<p>{inline_md(e['text'])}</p>")
        if e.get("trait"):
            lines.append(f'<p><b>Особенность:</b> {inline_md(e["trait"])}</p>')
        if s and s["notes"]:
            lines.append("<p><b>В журнале (наблюдения):</b></p><ul>"
                         + "".join(f"<li>{inline_md(t)}</li>" for t in s["notes"]) + "</ul>")
        if e.get("links"):
            lines.append(f'<p><b>Связи:</b> {inline_md(e["links"])}</p>')
        src = []
        if s:
            src.append(f"реестр <code>{s['id']}</code>")
        if note:
            src.append(f"концепт <code>{note}</code>")
            src += [f"модель <code>models/{m}</code>" for m in models_of(notes[note])]
        if src:
            lines.append('<p class="src">' + ", ".join(src) + "</p>")
        aid = "vid-" + (s["id"] if s else re.sub(r"\W+", "-", n.lower()))
        out.append(f'<article class="card" id="{aid}"><div class="pics">{pic}</div><div>'
                   f'<h3>{esc(n)} {badge(st)}</h3>{"".join(lines)}</div></article>')
    out.append("</div></section>")
    return "\n".join(out)


CSS = """
:root{--bg:#0b1820;--fg:#dcebef;--mut:#8aa6ae;--card:#122633;--line:#24414f;--acc:#67ddeb;--warn:#e8b85a}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.5 system-ui,sans-serif}
header{position:sticky;top:0;background:#08131aee;border-bottom:1px solid var(--line);padding:8px 16px;z-index:2}
header b{color:var(--acc)}nav a{color:var(--fg);margin-right:14px;text-decoration:none;white-space:nowrap}
main{max-width:1100px;margin:0 auto;padding:0 16px 48px}h2{color:var(--acc);border-bottom:1px solid var(--line);
padding-top:16px}a{color:var(--acc)}code{background:#0006;padding:0 4px;border-radius:3px;font-size:.9em}
.src,.props,.leg{color:var(--mut);font-size:.88em}.warn{color:var(--warn)}
.tw{overflow-x:auto}table{border-collapse:collapse;font-size:.9em}td,th{border:1px solid var(--line);padding:4px 6px;
vertical-align:top}blockquote{border-left:3px solid var(--acc);margin:8px 0;padding:2px 12px;color:var(--mut)}
pre{overflow-x:auto;background:#0006;padding:8px}img{max-width:100%;height:auto;border-radius:6px;display:block}
.gal{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:10px}figure{margin:0}
figcaption{color:var(--mut);font-size:.8em}.cards{display:grid;gap:12px}
.card{display:grid;grid-template-columns:minmax(0,220px) minmax(0,1fr);gap:14px;background:var(--card);
border:1px solid var(--line);border-radius:8px;padding:12px}.card h3{margin:0 0 6px}.pics{display:grid;gap:6px;align-content:start}
.card p{margin:4px 0}@media (max-width:640px){.card{grid-template-columns:1fr}.pics{grid-template-columns:repeat(2,1fr)}}
.st{font-size:.7em;padding:1px 7px;border-radius:9px;vertical-align:middle;white-space:nowrap}
.s-game{background:#1f6b4a}.s-concept{background:#6b5a1f}.s-plan{background:#3b4a55}
.map{width:100%;max-height:80vh;background:#06121a;border:1px solid var(--line);border-radius:8px}
.map .shelf{fill:#0e2a36;stroke:#24414f}.map line,.map polyline{stroke-width:4;fill:none}.map .bend{fill:#e8f4f6}.map .main{stroke:var(--acc)}
.map .link{stroke:#8aa6ae;stroke-dasharray:10 8}.map .pt{fill:var(--acc)}.map .prop{fill:var(--warn)}
.map text{fill:var(--fg);font-size:17px}.map .n{fill:var(--mut)}
.k{display:inline-block;width:22px;height:4px;vertical-align:middle}.k.main{background:var(--acc)}
.b{display:inline-block;width:9px;height:9px;border-radius:50%;background:#e8f4f6;vertical-align:middle}
.k.link{background:repeating-linear-gradient(90deg,#8aa6ae 0 6px,transparent 6px 10px)}
.d{display:inline-block;width:10px;height:10px;border-radius:5px;background:var(--warn)}
a,code{overflow-wrap:anywhere}svg a,svg text{overflow-wrap:normal}details{margin-top:16px}summary{cursor:pointer;color:var(--acc)}
"""


def build(out_dir, root=ROOT):
    """Собрать справочник; вернуть HTML."""
    lm = layer_map(read(LAYER_MAP, root))
    reg = species(read(SPECIES, root))
    best = bestiary(read(BESTIARY, root))
    notes = concept_notes(root)
    sloj1 = read(SLOJ1, root)
    img = Images(out_dir, root)
    page = "\n".join([
        "<!doctype html><html lang=\"ru\"><head><meta charset=\"utf-8\">",
        '<meta name="viewport" content="width=device-width,initial-scale=1"><title>Кодекс «Погружения»</title>',
        f"<style>{CSS}</style></head><body>",
        '<header><b>Кодекс «Погружения»</b> · внутренний справочник, со спойлерами<nav>'
        '<a href="#mir">Мир</a><a href="#sloj1">Слой 1</a><a href="#vidy">Существа</a></nav></header><main>',
        '<p class="src">Собран из файлов репозитория скриптом <code>tools/codex.py</code> (#1417); править — '
        "исходные документы, не эту страницу.</p>",
        section_world(read(WORLD, root), notes, img),
        section_layer(lm, sloj1_rows(sloj1), sloj1, notes, img),
        section_species(reg, best, notes, img),
        "</main></body></html>",
    ])
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "index.html"), "w", encoding="utf-8") as f:
        f.write(page)
    return page


def missing(page, root=ROOT):
    """Чего нет в справочнике: места `LayerMap` и виды реестра `Species` (по якорю и имени)."""
    out = []
    for pid, p in layer_map(read(LAYER_MAP, root))["points"].items():
        if f'id="mesto-{pid}"' not in page or esc(p["name"]) not in page:
            out.append(f"место {pid} {p['name']}")
    for s in species(read(SPECIES, root)):
        if f'id="vid-{s["id"]}"' not in page or esc(s["name"]) not in page:
            out.append(f"вид {s['id']} {s['name']}")
    return out


def main(argv):
    out_dir = argv[0] if argv else os.path.join(ROOT, "build", "codex")
    if os.path.isdir(os.path.join(out_dir, "img")):
        shutil.rmtree(os.path.join(out_dir, "img"))
    page = build(out_dir)
    out_file = os.path.join(out_dir, "index.html")
    lost = missing(page)
    if lost:
        print("Нет в справочнике: " + "; ".join(lost), file=sys.stderr)
        return 1
    print(f"Кодекс: {out_file} ({len(page) // 1024} КБ)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
