#!/usr/bin/env python3
"""Тесты мини-сценария тестера (tools/qa/mini.py, #1350).
Запуск: python3 tools/test_qa_mini.py (его же гоняет job «Инструменты», .github/workflows/tools.yml)."""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "qa"))
import mini  # noqa: E402

STEPS = [
    {"do": "wait", "s": 1},                       # 1
    {"do": "press", "what": "dive"},              # 2
    {"do": "hull", "pct": 40},                    # 3
    {"do": "ship", "x": 0, "y": -30, "z": 0},     # 4
    {"do": "wait", "s": 2},                       # 5
    {"do": "shot", "name": "10-one"},             # 6
    {"do": "log", "note": "про 10"},              # 7
    {"do": "silt", "on": True},                   # 8
    {"do": "wait", "s": 3},                       # 9
    {"do": "shot", "name": "11-two"},             # 10
    {"do": "log", "note": "про 11"},              # 11
    {"do": "quit"},                               # 12
]


class Mini(unittest.TestCase):
    def test_start_and_quit(self):
        out, _, _ = mini.cut(STEPS, "11")
        self.assertEqual(out[:len(mini.START)], mini.START, "стандартное начало CLAUDE.md")
        self.assertEqual([s["do"] for s in mini.START], ["wait", "press", "wait", "brief", "tutorial", "cards"])
        self.assertEqual(mini.START[1]["what"], "dive", "без press dive игра стоит в меню")
        self.assertEqual(out[-1], {"do": "quit"})
        self.assertEqual(sum(1 for s in out if s["do"] == "quit"), 1, "quit один")

    def test_shot_prefix_takes_wait_and_notes(self):
        out, first, lost = mini.cut(STEPS, "11")
        body = out[len(mini.START):-1]
        self.assertEqual(body, STEPS[8:11], "ожидание перед снимком, снимок, его заметки")
        self.assertEqual(first, 8)
        self.assertIn("silt", lost)
        self.assertIn("ship", lost)

    def test_range_between_shots(self):
        out, _, _ = mini.cut(STEPS, "10", "11-two")
        self.assertEqual(out[len(mini.START):-1], STEPS[4:11])

    def test_log_step_number_is_one_based(self):
        out, first, _ = mini.cut(STEPS, "@9")
        self.assertEqual(first, 8, "«шаг 9» лога — индекс 8")
        self.assertEqual(out[len(mini.START):-1], STEPS[8:11], "до ближайшего снимка и его заметок")

    def test_digits_are_shot_prefix(self):
        out, first, _ = mini.cut(STEPS, "10")
        self.assertEqual(first, 4, "«10» — снимок 10-one, не шаг 10")

    def test_ship_goes_back(self):
        out2, first2, lost2 = mini.cut(STEPS, "10", ship=True)
        self.assertEqual(first2, 3, "с шага ship")
        self.assertEqual(out2[len(mini.START)], STEPS[3])
        self.assertEqual(lost2, [], "с ship — корабль на месте, жаловаться не на что")
        _, _, lost = mini.cut(STEPS, "10")
        self.assertEqual(lost, ["ship"], "без --ship — выпал ship; hull до него не в счёт")

    def test_missing(self):
        with self.assertRaises(SystemExit):
            mini.cut(STEPS, "99-net")
        with self.assertRaises(SystemExit):
            mini.cut(STEPS, "@40")
        with self.assertRaises(SystemExit):
            mini.cut(STEPS, "11", "10")

    def test_real_scenario_parses_and_writes(self):
        with open(mini.SCENARIO, encoding="utf-8") as f:
            steps = json.load(f)
        shots = [s["name"] for s in steps if s.get("do") == "shot"]
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "a", "mini.json")
            self.assertEqual(mini.main([shots[-1], "-o", path]), 0)
            with open(path, encoding="utf-8") as f:
                got = json.load(f)
        self.assertIn({"do": "shot", "name": shots[-1]}, got)
        self.assertEqual(got[-1], {"do": "quit"})
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        with open(os.path.join(root, "scripts", "core", "qa_script.gd"), encoding="utf-8") as f:
            kinds_line = next(line for line in f if line.startswith("const KINDS"))
        for s in mini.START + [{"do": "quit"}]:
            self.assertIn('"%s"' % s["do"], kinds_line, "шаг %s знает QaScript.KINDS" % s["do"])


if __name__ == "__main__":
    unittest.main()
