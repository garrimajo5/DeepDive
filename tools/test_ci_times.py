#!/usr/bin/env python3
"""Тесты таблицы времени тестов по логу CI (tools/ci_times.py, #852).
Запуск: python3 tools/test_ci_times.py (его же гоняет job «Инструменты», .github/workflows/tools.yml)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ci_times as ct  # noqa: E402


def log(lines):
    """Строки (секунда, текст) → лог job Actions с метками времени, как отдаёт gh api …/logs."""
    return "\n".join("2026-11-09T07:12:%06.3fZ %s" % (s, t) for s, t in lines) + "\n"


SHARD = log([
    (0.0, "Godot Engine v4.7.2.stable"),
    (1.0, "Часть 1 из 3: файлов 3"),
    (1.5, "  ок     test_a.test_one"),
    (3.0, "  ок     test_a.test_two"),
    (3.25, "  ок     test_b.test_one"),
    (7.0, "ПАДЕНИЕ  test_c.test_one"),
    (7.0, "         - ждали 1, вышло 2"),
    (9.5, "  ок     test_c.test_two"),
    (9.6, ""),
    (9.6, "Тестов: 5, прошло: 4, упало: 1 (8.6 с)"),
    (9.7, "  ок     test_z.test_after_end"),   # после итога — не тест части
])


class Parse(unittest.TestCase):
    def test_file_time_between_last_lines(self):
        got = ct.parse(SHARD)
        self.assertEqual(sorted(got), ["test_a.gd", "test_b.gd", "test_c.gd"])
        self.assertAlmostEqual(got["test_a.gd"], 2.0)   # от «Часть» до последнего «ок» файла
        self.assertAlmostEqual(got["test_b.gd"], 0.25)
        self.assertAlmostEqual(got["test_c.gd"], 6.25)  # «ПАДЕНИЕ» тоже строка файла

    def test_sum_matches_shard_total(self):
        self.assertAlmostEqual(sum(ct.parse(SHARD).values()), 8.5)

    def test_script_load_failure_counts(self):
        text = log([(0, "Часть 2 из 3: файлов 2"), (2, "ПАДЕНИЕ  test_x.gd: скрипт не загрузился"),
                    (5, "  ок     test_y.test_one")])
        got = ct.parse(text)
        self.assertAlmostEqual(got["test_x.gd"], 2.0)
        self.assertAlmostEqual(got["test_y.gd"], 3.0)

    def test_several_jobs_glued(self):
        other = log([(30, "Часть 2 из 3: файлов 1"), (31, "  ок     test_d.test_one")])
        got = ct.parse(SHARD + other)
        self.assertAlmostEqual(got["test_d.gd"], 1.0)   # новая часть — отсчёт заново
        self.assertEqual(len(got), 4)

    def test_lines_without_shard_ignored(self):
        self.assertEqual(ct.parse(log([(1, "  ок     test_a.test_one")])), {})
        self.assertEqual(ct.parse("  ок     test_a.test_one\n"), {})

    def test_bom_and_fraction(self):
        text = "﻿2026-11-09T07:12:01Z Часть 1 из 1: файлов 1\n2026-11-09T07:12:01.2500000Z   ок     test_a.t\n"
        self.assertAlmostEqual(ct.parse(text)["test_a.gd"], 0.25)


class Table(unittest.TestCase):
    def test_average_over_measures(self):
        got = ct.average([{"test_a.gd": 2.0, "test_b.gd": 1.0}, {"test_a.gd": 4.0}, {}])
        self.assertEqual(got, {"test_a.gd": 3.0, "test_b.gd": 1.0})

    def test_roundtrip_like_shards_gd(self):
        text = ct.write_table({"test_b.gd": 1.234, "test_a.gd": 0.0})
        self.assertTrue(text.startswith(ct.HEAD))
        self.assertEqual(text[len(ct.HEAD):], "test_a.gd\t0.00\ntest_b.gd\t1.23\n")
        self.assertEqual(ct.read_table(text), {"test_a.gd": 0.0, "test_b.gd": 1.23})

    def test_merge_keeps_old_drops_gone(self):
        old = {"test_a.gd": 1.0, "test_b.gd": 2.0, "test_gone.gd": 3.0}
        got = ct.merge(old, {"test_a.gd": 5.0, "test_new.gd": 0.5},
                       {"test_a.gd", "test_b.gd", "test_new.gd"})
        self.assertEqual(got, {"test_a.gd": 5.0, "test_b.gd": 2.0, "test_new.gd": 0.5})

    def test_head_same_as_shards_gd(self):
        here = os.path.dirname(os.path.abspath(__file__))
        src = open(os.path.join(here, "..", "tests", "shards.gd"), encoding="utf-8").read()
        self.assertIn(ct.HEAD.replace("\n", "\\n"), src)


class Main(unittest.TestCase):
    def test_writes_table_from_log(self):
        with tempfile.TemporaryDirectory() as d:
            for f in ("test_a.gd", "test_b.gd", "test_c.gd", "test_old.gd"):
                open(os.path.join(d, f), "w").close()
            out = os.path.join(d, "vremya.txt")
            with open(out, "w", encoding="utf-8") as f:
                f.write(ct.write_table({"test_a.gd": 9.0, "test_old.gd": 4.0, "test_gone.gd": 1.0}))
            lp = os.path.join(d, "job.txt")
            with open(lp, "w", encoding="utf-8") as f:
                f.write(SHARD)
            self.assertEqual(ct.main([lp, "--out", out]), 0)
            got = ct.read_table(open(out, encoding="utf-8").read())
            self.assertEqual(got, {"test_a.gd": 2.0, "test_b.gd": 0.25, "test_c.gd": 6.25, "test_old.gd": 4.0})

    def test_two_logs_averaged(self):
        with tempfile.TemporaryDirectory() as d:
            open(os.path.join(d, "test_a.gd"), "w").close()
            out = os.path.join(d, "vremya.txt")
            paths = []
            for k, end in enumerate((3, 5)):
                lp = os.path.join(d, "job%d.txt" % k)
                with open(lp, "w", encoding="utf-8") as f:
                    f.write(log([(1, "Часть 1 из 1: файлов 1"), (end, "  ок     test_a.test_one")]))
                paths.append(lp)
            self.assertEqual(ct.main(paths + ["--out", out]), 0)
            self.assertEqual(ct.read_table(open(out, encoding="utf-8").read()), {"test_a.gd": 3.0})

    def test_empty_log_keeps_table(self):
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, "vremya.txt")
            with open(out, "w", encoding="utf-8") as f:
                f.write("свой текст")
            lp = os.path.join(d, "job.txt")
            open(lp, "w").close()
            self.assertEqual(ct.main([lp, "--out", out]), 1)
            self.assertEqual(open(out, encoding="utf-8").read(), "свой текст")


if __name__ == "__main__":
    unittest.main()
