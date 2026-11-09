#!/usr/bin/env python3
"""Тесты превью картинок CI в логе job (tools/ci_preview.py, #1379).
Запуск: python3 tools/test_ci_preview.py (его же гоняет .github/workflows/status.yml вместе с тестами инструментов)."""
import io
import os
import struct
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ci_preview as cp  # noqa: E402


def gradient(w, h):
    """Тёмно-синий градиент — как вода в игре: каналы в узких пределах."""
    return [bytes(v for x in range(w) for v in (x * 40 // w, 10 + y * 30 // h, 60 + x * 80 // w)) for y in range(h)]


def png_filtered(w, h, rows, ctype=6):
    """PNG со всеми пятью фильтрами строк по кругу (RGBA) — проверка разбора, как у снимков adb screencap."""
    bpp = 4 if ctype == 6 else 3
    data = [bytes(b for i in range(w) for b in (r[i * 3:i * 3 + 3] + (b"\xff" if bpp == 4 else b""))) for r in rows]
    out = bytearray()
    prev = bytes(w * bpp)
    for y, cur in enumerate(data):
        f = y % 5
        out.append(f)
        for x in range(len(cur)):
            a = cur[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 0:
                pred = 0
            elif f == 1:
                pred = a
            elif f == 2:
                pred = b
            elif f == 3:
                pred = (a + b) >> 1
            else:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else b if pb <= pc else c
            out.append((cur[x] - pred) & 255)
        prev = cur
    return cp._png(w, h, ctype, b"", bytes(out))


class Decode(unittest.TestCase):
    def test_all_filters_rgba(self):
        rows = gradient(37, 11)
        w, h, got = cp.decode(png_filtered(37, 11, rows))
        self.assertEqual((w, h), (37, 11))
        self.assertEqual(got, rows)

    def test_rgb_roundtrip(self):
        rows = gradient(20, 9)
        self.assertEqual(cp.decode(cp.encode_rgb(20, 9, rows))[2], rows)

    def test_rejects_16bit(self):
        bad = cp.SIG + b"".join(
            struct.pack(">I", len(d)) + k + d + struct.pack(">I", zlib.crc32(k + d) & 0xFFFFFFFF)
            for k, d in ((b"IHDR", struct.pack(">IIBBBBB", 2, 2, 16, 2, 0, 0, 0)), (b"IEND", b"")))
        with self.assertRaises(ValueError):
            cp.decode(bad)


class Preview(unittest.TestCase):
    def test_shrink_keeps_aspect_and_mean(self):
        rows = [bytes([100, 50, 200] * 160)] * 72
        w, h, small = cp.shrink(160, 72, rows, 40)
        self.assertEqual((w, h), (40, 18))
        self.assertEqual(small[5][:3], bytes([100, 50, 200]))

    def test_never_upscales(self):
        self.assertEqual(cp.shrink(30, 10, gradient(30, 10), 320)[:2], (30, 10))

    def test_dark_scene_keeps_colors(self):
        """Тёмная вода не слипается: палитра растянута по пределам каналов, цвета близки к исходным."""
        rows = gradient(160, 72)
        w, h, png = cp.preview(png_filtered(160, 72, rows), 160)
        _, _, back = cp.decode(png)
        self.assertGreater(len({back[y][x * 3:x * 3 + 3] for y in range(h) for x in range(w)}), 30)
        err = sum(abs(a - b) for r0, r1 in zip(rows, back) for a, b in zip(r0, r1)) / (w * h * 3)
        self.assertLess(err, 6, "средняя ошибка канала")

    def test_put_take_roundtrip_through_actions_log(self):
        """Блок в логе с метками времени Actions собирается обратно в тот же PNG; два одинаковых имени не затираются."""
        with tempfile.TemporaryDirectory() as d:
            src = os.path.join(d, "08-power.png")
            with open(src, "wb") as f:
                f.write(png_filtered(640, 288, gradient(640, 288)))
            buf = io.StringIO()
            cp.put([src, src, os.path.join(d, "net.png")], width=320, out=buf)
            log = "".join(f"2026-11-09T01:43:36.3034849Z {line}\n" for line in buf.getvalue().splitlines())
            self.assertIn("::group::превью 08-power.png", log)
            self.assertIn("превью net.png: пропущено", log)
            got = cp.take("﻿" + log, os.path.join(d, "out"))
            self.assertEqual([os.path.basename(p) for p in got], ["08-power.png", "08-power-2.png"])
            w, h, _ = cp.decode(open(got[0], "rb").read())
            self.assertEqual((w, h), (320, 144))

    def test_size_limit(self):
        with tempfile.TemporaryDirectory() as d:
            paths = []
            for i in range(3):
                p = os.path.join(d, f"k{i}.png")
                with open(p, "wb") as f:
                    f.write(png_filtered(200, 90, gradient(200, 90)))
                paths.append(p)
            one = len(cp.block("k0.png", *cp.preview(open(paths[0], "rb").read(), 200)))
            buf = io.StringIO()
            skipped = cp.put(paths, width=200, max_kb=(one * 2 + 100) // 1024 + 1, out=buf)
            self.assertEqual(len(skipped), 1)
            self.assertIn("не влезли", buf.getvalue())


class Workflow(unittest.TestCase):
    def test_emulator_job_prints_previews(self):
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        yml = open(os.path.join(root, ".github/workflows/qa-emulator.yml"), encoding="utf-8").read()
        self.assertIn("tools/ci_preview.py put", yml)


if __name__ == "__main__":
    unittest.main()
