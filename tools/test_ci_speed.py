#!/usr/bin/env python3
"""Тесты таблицы замеров шага живого мира по логам CI (tools/ci_speed.py, #1350).
Запуск: python3 tools/test_ci_speed.py (его же гоняет job «Инструменты», .github/workflows/tools.yml)."""
import io
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ci_speed as cs  # noqa: E402

LOG = """2026-11-10T19:19:13.2515188Z   ок     test_eco_speed.test_limit_covers_runners
2026-11-10T19:19:16.5089390Z     шаг живого мира 5.00 мс, порог 5.79 (на ПК 3.28 из 3.80; мерка 0.810 мс, объекты 0.335 мс; часы: процессора)
2026-11-10T19:19:16.5136476Z   ок     test_eco_speed.test_view_step_fits_frame
"""
HOT = ("2026-11-10T10:00:00.0Z     шаг живого мира 6.35 мс, порог 6.70 (на ПК 3.60 из 3.80; мерка 1.060 мс, "
       "объекты 0.405 мс; часы: процессора)\n")


class Parse(unittest.TestCase):
    def test_line_of_ci_log(self):
        got = cs.parse(LOG)
        self.assertEqual(len(got), 1)
        r = got[0]
        self.assertEqual((r["step"], r["limit"], r["pc"], r["limit_pc"]), (5.00, 5.79, 3.28, 3.80))
        self.assertEqual((r["ref"], r["obj"], r["clock"]), (0.810, 0.335, "процессора"))

    def test_several_jobs_and_noise(self):
        self.assertEqual(len(cs.parse(LOG + "мусор\n" + HOT)), 2)
        self.assertEqual(cs.parse("  ок     test_eco_speed.test_limit_covers_runners\n"), [])

    def test_consts_from_real_test_file(self):
        """Порог и запас читаются из tests/test_eco_speed.gd — переименование константы сломает и скрипт."""
        with open(cs.TEST_FILE, encoding="utf-8") as f:
            limit, margin = cs.consts(f.read())
        self.assertIsNotNone(limit)
        self.assertIsNotNone(margin)
        self.assertGreater(limit, 1.0)
        self.assertLess(margin, 1.0)


class Report(unittest.TestCase):
    def test_summary_and_headroom(self):
        rows = cs.parse(LOG + HOT)
        self.assertEqual(cs.summary(rows), (3.28, 3.44, 3.60))
        self.assertAlmostEqual(cs.headroom(3.8 / 1.1, 3.8), 0.10)
        self.assertIsNone(cs.summary([]))

    def test_uncovered_like_limit_test(self):
        """Как test_limit_covers_runners: 3,28·1,1 = 3,61 ≤ 3,8 — покрыт; 3,60·1,1 = 3,96 — нет."""
        rows = cs.parse(LOG + HOT)
        bad = cs.uncovered(rows, 3.8, 0.10)
        self.assertEqual([r["pc"] for r in bad], [3.60])

    def test_runners_line_format(self):
        r = cs.parse(HOT)[0]
        self.assertEqual(cs.runners_line(r, "раннер CI, main abc1234"),
                         "\t[6.35, 1.060, 0.405],  # раннер CI, main abc1234 (3.60 на ПК)")

    def test_report_prints_rows_and_runners(self):
        out = io.StringIO()
        rows = [("a", r) for r in cs.parse(LOG + HOT)]
        self.assertEqual(cs.report(rows, 3.8, 0.10, out), 1)
        text = out.getvalue()
        self.assertIn("Замеров 2: на ПК 3.28–3.60, медиана 3.44", text)
        self.assertIn("строки для RUNNERS", text)
        self.assertIn("[6.35, 1.060, 0.405]", text)

    def test_report_empty(self):
        out = io.StringIO()
        self.assertEqual(cs.report([], 3.8, 0.10, out), 0)
        self.assertIn("замеров нет", out.getvalue())


class Main(unittest.TestCase):
    def test_from_saved_log(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "job.txt")
            with open(p, "w", encoding="utf-8") as f:
                f.write(LOG)
            old = sys.stdout
            sys.stdout = io.StringIO()
            try:
                code = cs.main([p])
                text = sys.stdout.getvalue()
            finally:
                sys.stdout = old
        self.assertEqual(code, 0)
        self.assertIn("job.txt\t5.00\t5.79\t3.28", text)

    def test_no_args_prints_help(self):
        old = sys.stdout
        sys.stdout = io.StringIO()
        try:
            self.assertEqual(cs.main([]), 2)
        finally:
            sys.stdout = old


if __name__ == "__main__":
    unittest.main()
