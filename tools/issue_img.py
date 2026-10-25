#!/usr/bin/env python3
"""Картинка (или звук) прямо в issue: кладёт снимок в ветку `issue-img` (папка = номер issue) и пишет в issue комментарий,
где картинка встроена — владелец видит её сразу, в том числе с телефона.

    python3 tools/issue_img.py 576 qa/out/27-power.png "Рукава у пульта энергии"
    python3 tools/issue_img.py 576 v1.png "Вариант 1" v2.png "Вариант 2" --text "Какой вариант берём?"

GitHub не даёт прикладывать файлы к issue через API (только мышкой в браузере), поэтому картинки живут в отдельной
ветке-сироте `issue-img` — в ней только картинки, без кода (её не сливают и не удаляют; CI на неё не запускается),
а в комментарии — ссылка raw.githubusercontent (репозиторий публичный). PNG больше 900 КБ пережимается в JPEG
(Pillow, если есть). Нужны git и `gh`; запускать из папки репозитория.
"""
import io
import json
import os
import subprocess
import sys
import tempfile

REPO = os.environ.get("STATUS_REPO", "garrimajo5/DeepDive")
BRANCH = "issue-img"
MAX_BYTES = 900_000


def gh(path, method="GET", payload=None, ok_404=False):
    cmd = ["gh", "api", "-X", method, path] + (["--input", "-"] if payload is not None else [])
    r = subprocess.run(cmd, input=json.dumps(payload) if payload is not None else None, capture_output=True, text=True)
    if r.returncode != 0:
        if ok_404 and "404" in (r.stdout + r.stderr):
            return None
        raise RuntimeError(f"gh api {path}: {(r.stdout + r.stderr).strip()[:300]}")
    return json.loads(r.stdout) if r.stdout.strip() else None


AUDIO = (".mp3", ".wav", ".ogg")


def raw_url(issue, name):
    return f"https://raw.githubusercontent.com/{REPO}/{BRANCH}/{issue}/{name}"


def is_audio(name):
    return name.lower().endswith(AUDIO)


def comment_body(issue, items, text=""):
    """Текст комментария: вступление, по картинке с подписью на каждую пару (имя, подпись); звук — ссылкой
    «▶ послушать» (GitHub не встраивает аудио, но ссылка играет прямо в браузере телефона)."""
    parts = [text.strip()] if text.strip() else []
    for name, caption in items:
        url = raw_url(issue, name)
        if is_audio(name):
            parts.append(f"**{caption or name}** — [▶ послушать `{name}`]({url})")
        else:
            parts.append(f"**{caption}**\n\n![{caption}]({url})" if caption else f"![{name}]({url})")
    return "\n\n".join(parts)


def shrink(path):
    """Байты файла и имя в ветке: крупный снимок → JPEG 85 % (если есть Pillow); звук — как есть."""
    data = open(path, "rb").read()
    name = os.path.basename(path)
    if len(data) <= MAX_BYTES or is_audio(name):
        return data, name
    try:
        from PIL import Image
    except ImportError:
        return data, name
    img = Image.open(io.BytesIO(data)).convert("RGB")
    if img.width > 1920:
        img = img.resize((1920, round(img.height * 1920 / img.width)))
    out = io.BytesIO()
    img.save(out, "JPEG", quality=85)
    return out.getvalue(), os.path.splitext(name)[0] + ".jpg"


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def git(*args, env=None, data=None):
    r = subprocess.run(["git", *args], cwd=ROOT, env=env, input=data, capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.decode(errors='replace').strip()[:300]}")
    return r.stdout.decode().strip()


def upload_all(issue, pairs):
    """Кладёт картинки в ветку issue-img одним коммитом — git без checkout (временный индекс), поэтому ветка —
    сирота с одними картинками, а рабочая папка не трогается. REST создавать ветки из облачной сессии не даёт,
    git push — даёт везде. Если кто-то запушил одновременно — пробуем ещё раз."""
    files = [(shrink(p), c) for p, c in pairs]
    for attempt in range(3):
        head = git("ls-remote", "origin", f"refs/heads/{BRANCH}").split("\t")[0]
        if head:
            git("fetch", "-q", "origin", f"refs/heads/{BRANCH}")
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, GIT_INDEX_FILE=os.path.join(tmp, "index"))
            if head:
                git("read-tree", f"{head}^{{tree}}", env=env)
            names = []
            for (data, name), _ in files:
                blob = git("hash-object", "-w", "--stdin", data=data)
                git("update-index", "--add", "--cacheinfo", f"100644,{blob},{issue}/{name}", env=env)
                names.append(name)
            tree = git("write-tree", env=env)
            commit = git("commit-tree", tree, *(["-p", head] if head else []),
                         "-m", f"Картинки к #{issue}: {', '.join(names)}")
        try:
            git("push", "-q", "origin", f"{commit}:refs/heads/{BRANCH}")
            return [(n, c) for n, (_, c) in zip(names, files)]
        except RuntimeError:
            if attempt == 2:
                raise
    return []


def main(argv):
    text = ""
    if "--text" in argv:
        k = argv.index("--text")
        text = argv[k + 1]
        argv = argv[:k] + argv[k + 2:]
    if len(argv) < 2 or not argv[0].isdigit():
        print(__doc__)
        return 2
    issue, rest = argv[0], argv[1:]
    pairs = []
    while rest:
        path = rest.pop(0)
        caption = rest.pop(0) if rest and not os.path.exists(rest[0]) else ""
        pairs.append((path, caption))
    items = upload_all(issue, pairs)
    r = gh(f"repos/{REPO}/issues/{issue}/comments", "POST", {"body": comment_body(issue, items, text)})
    print(r["html_url"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
