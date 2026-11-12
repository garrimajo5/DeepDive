#!/usr/bin/env python3
"""Превью картинок CI прямо в логе job (#1379): артефакты CI из облачной сессии не скачать (blob-хранилище закрыто
прокси), а лог job — можно (`gh api repos/<репо>/actions/jobs/<id>/logs`). Поэтому job печатает уменьшенные копии
своих PNG в лог base64-блоками, а сессия собирает их обратно в файлы и смотрит через Read.

  python3 tools/ci_preview.py put <файл.png>… [--width 320] [--max-kb 900]   # в CI: напечатать превью в лог
  python3 tools/ci_preview.py take <лог.txt|-> <папка>                         # из сохранённого лога
  python3 tools/ci_preview.py take --run <id прогона> <папка> [--repo владелец/репо]  # лог всех job прогона через gh

Только стандартная библиотека (внешние пакеты — по решению владельца): свой разбор PNG (8 бит, серый/RGB/RGBA,
палитра), уменьшение средним по клеткам, палитра 6×6×6 по пределам каналов со сглаживанием 4×4 и запись PNG с палитрой. Блок в логе:
  @@превью <имя> <ш>x<в>@@
  <base64 по 76 знаков>
  @@конец@@
"""
import base64
import os
import re
import struct
import subprocess
import sys
import zlib

BEGIN = "@@превью "
END = "@@конец@@"
LINE = 76
LEVELS = 6  # уровней на канал в палитре: 6×6×6 = 216 цветов
STAMP = re.compile(r"^﻿?\d{4}-\d\d-\d\dT[\d:.]+Z ")  # метка времени в начале строки лога Actions

SIG = b"\x89PNG\r\n\x1a\n"


def _chunks(data):
    if data[:8] != SIG:
        raise ValueError("не PNG")
    i = 8
    while i + 8 <= len(data):
        n, kind = struct.unpack(">I4s", data[i:i + 8])
        yield kind, data[i + 8:i + 8 + n]
        i += 12 + n


def decode(data):
    """PNG → (ширина, высота, строки RGB байтами). Чересстрочные и 16-битные — ValueError."""
    w = h = depth = ctype = inter = None
    pal = b""
    idat = []
    for kind, body in _chunks(data):
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, inter = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            pal = body
        elif kind == b"IDAT":
            idat.append(body)
        elif kind == b"IEND":
            break
    if w is None:
        raise ValueError("нет IHDR")
    if depth != 8 or inter:
        raise ValueError(f"не поддержано: глубина {depth}, чересстрочный {inter}")
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(ctype)
    if bpp is None:
        raise ValueError(f"тип цвета {ctype}")
    raw = zlib.decompress(b"".join(idat))
    stride = w * bpp
    prev = bytearray(stride)
    rows = []
    pos = 0
    for _ in range(h):
        f = raw[pos]
        cur = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        if f == 1:
            for x in range(bpp, stride):
                cur[x] = (cur[x] + cur[x - bpp]) & 255
        elif f == 2:
            cur = bytearray((a + b) & 255 for a, b in zip(cur, prev))
        elif f == 3:
            for x in range(stride):
                left = cur[x - bpp] if x >= bpp else 0
                cur[x] = (cur[x] + ((left + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = cur[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                cur[x] = (cur[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(cur))
        prev = cur
    out = []
    for r in rows:
        if ctype == 2:
            out.append(r)
        elif ctype == 6:
            o = bytearray(w * 3)
            o[0::3], o[1::3], o[2::3] = r[0::4], r[1::4], r[2::4]
            out.append(bytes(o))
        elif ctype in (0, 4):
            g = r[0::bpp]
            o = bytearray(w * 3)
            o[0::3] = o[1::3] = o[2::3] = g
            out.append(bytes(o))
        else:
            out.append(b"".join(pal[i * 3:i * 3 + 3] for i in r))
    return w, h, out


def shrink(w, h, rows, width):
    """Уменьшить до ширины width (не больше исходной) средним по клеткам; итог — (ш, в, строки RGB)."""
    nw = max(1, min(width, w))
    nh = max(1, round(h * nw / w))
    xs = [x * w // nw for x in range(nw + 1)]
    ys = [y * h // nh for y in range(nh + 1)]
    out = []
    for j in range(nh):
        acc = [0] * (nw * 3)
        band = rows[ys[j]:max(ys[j] + 1, ys[j + 1])]
        for r in band:
            for c in range(3):
                ch = r[c::3]
                for i in range(nw):
                    a, b = xs[i], max(xs[i] + 1, xs[i + 1])
                    acc[i * 3 + c] += sum(ch[a:b])
        o = bytearray(nw * 3)
        for i in range(nw):
            n = len(band) * (max(xs[i] + 1, xs[i + 1]) - xs[i])
            for c in range(3):
                o[i * 3 + c] = acc[i * 3 + c] // n
        out.append(bytes(o))
    return nw, nh, out


BAYER = (0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5)  # порог 4×4 для упорядоченного сглаживания


def ranges(rows):
    """Пределы каналов (мин, макс): палитра растягивается по ним — тёмная глубина не слипается в два цвета."""
    lo, hi = [255] * 3, [0] * 3
    for r in rows:
        for c in range(3):
            ch = r[c::3]
            lo[c] = min(lo[c], min(ch))
            hi[c] = max(hi[c], max(ch))
    return [(lo[c], max(hi[c], lo[c] + 1)) for c in range(3)]


def palette(rng):
    lv = [[round(a + (b - a) * k / (LEVELS - 1)) for k in range(LEVELS)] for a, b in rng]
    return bytes(v for r in lv[0] for g in lv[1] for b in lv[2] for v in (r, g, b))


def encode_indexed(w, h, rows):
    """Строки RGB → PNG с палитрой 6×6×6 по пределам каналов, со сглаживанием 4×4."""
    rng = ranges(rows)
    tabs = []
    for a, b in rng:
        k = (LEVELS - 1) / (b - a)
        tabs.append([[min(LEVELS - 1, max(0, int((v - a) * k + (t + 0.5) / 16))) for v in range(256)]
                     for t in range(16)])
    body = bytearray()
    for y, r in enumerate(rows):
        body.append(0)
        row_t = BAYER[(y & 3) * 4:(y & 3) * 4 + 4]
        for x in range(w):
            t = row_t[x & 3]
            i = x * 3
            body.append((tabs[0][t][r[i]] * LEVELS + tabs[1][t][r[i + 1]]) * LEVELS + tabs[2][t][r[i + 2]])
    return _png(w, h, 3, palette(rng), bytes(body))


def encode_rgb(w, h, rows):
    """Строки RGB → PNG RGB (для тестов и как образец)."""
    return _png(w, h, 2, b"", b"".join(b"\0" + r for r in rows))


def _png(w, h, ctype, pal, body):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    out = SIG + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0))
    if pal:
        out += chunk(b"PLTE", pal)
    return out + chunk(b"IDAT", zlib.compress(body, 9)) + chunk(b"IEND", b"")


def preview(data, width):
    w, h, rows = decode(data)
    nw, nh, small = shrink(w, h, rows, width)
    return nw, nh, encode_indexed(nw, nh, small)


def block(name, w, h, png):
    b64 = base64.b64encode(png).decode()
    lines = [f"{BEGIN}{name} {w}x{h}@@"]
    lines += [b64[i:i + LINE] for i in range(0, len(b64), LINE)]
    lines.append(END)
    return "\n".join(lines)


def put(paths, width=320, max_kb=900, out=sys.stdout):
    """Напечатать превью файлов; суммарно не больше max_kb КБ base64 — остальное перечислить строкой."""
    left = max_kb * 1024
    skipped = []
    for p in paths:
        name = os.path.basename(p)
        try:
            with open(p, "rb") as f:
                w, h, png = preview(f.read(), width)
        except (OSError, ValueError, zlib.error) as e:
            print(f"превью {name}: пропущено ({e})", file=out)
            continue
        text = block(name, w, h, png)
        if len(text) > left:
            skipped.append(name)
            continue
        left -= len(text)
        print(f"::group::превью {name} ({len(png) // 1024 + 1} КБ)", file=out)
        print(text, file=out)
        print("::endgroup::", file=out)
    if skipped:
        print(f"превью не влезли в {max_kb} КБ: {', '.join(skipped)}", file=out)
    return skipped


def take(text, folder):
    """Собрать файлы из лога (метки времени Actions срезаются). Вернуть список записанных путей."""
    os.makedirs(folder, exist_ok=True)
    done = []
    name = None
    buf = []
    for line in text.splitlines():
        line = STAMP.sub("", line).rstrip("\r")
        if name is None:
            m = re.match(r"^@@превью (\S+) \d+x\d+@@$", line)
            if m:
                name, buf = m.group(1), []
        elif line == END:
            base = os.path.splitext(os.path.basename(name))[0] or "kadr"
            path = os.path.join(folder, base + ".png")
            n = 2
            while path in done:
                path = os.path.join(folder, f"{base}-{n}.png")
                n += 1
            with open(path, "wb") as f:
                f.write(base64.b64decode("".join(buf)))
            done.append(path)
            name = None
        else:
            buf.append(line.strip())
    return done


def run_logs(run_id, repo):
    jobs = subprocess.run(["gh", "api", f"repos/{repo}/actions/runs/{run_id}/jobs", "--jq", ".jobs[].id"],
                          check=True, capture_output=True, text=True).stdout.split()
    return "\n".join(subprocess.run(["gh", "api", f"repos/{repo}/actions/jobs/{j}/logs"], check=True,
                                    capture_output=True, text=True).stdout for j in jobs)


def main(argv):
    if len(argv) < 2 or argv[0] not in ("put", "take"):
        print(__doc__)
        return 2
    args = list(argv[1:])

    def opt(key, default):
        if key in args:
            i = args.index(key)
            v = args[i + 1]
            del args[i:i + 2]
            return v
        return default

    if argv[0] == "put":
        width = int(opt("--width", "320"))
        max_kb = int(opt("--max-kb", "900"))
        put(args, width, max_kb)
        return 0
    repo = opt("--repo", "garrimajo5/DeepDive")
    run = opt("--run", None)
    if run:
        text = run_logs(run, repo)
        folder = args[0]
    else:
        src, folder = args[0], args[1]
        text = sys.stdin.read() if src == "-" else open(src, encoding="utf-8", errors="replace").read()
    for p in take(text, folder):
        print(p)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
