#!/usr/bin/env python3
"""Тесты workflow тестов инструментов (.github/workflows/tools.yml): python-инструменты проверяются на PR.
Запуск: python3 tools/test_workflows.py (его же гоняет tools.yml вместе с остальными tools/test_*.py)."""
import glob
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


class ToolsWorkflow(unittest.TestCase):
    def setUp(self):
        self.wf = read(".github/workflows/tools.yml")

    def test_runs_on_pr_when_tools_change(self):
        on = self.wf.split("\njobs:")[0]
        self.assertIn("pull_request:", on)
        paths = re.search(r"pull_request:\s*\n\s*paths:\s*\[([^\]]*)\]", on)
        self.assertIsNotNone(paths, "у pull_request нет списка paths")
        self.assertIn('"tools/*.py"', paths.group(1))
        self.assertIn('".github/workflows/tools.yml"', paths.group(1))

    def test_runs_every_tool_test_by_mask(self):
        # По маске, а не списком: новый tools/test_<что>.py не забудется.
        self.assertIn("for t in tools/test_*.py", self.wf)
        self.assertIn('python3 "$t"', self.wf)
        self.assertIn("exit $fail", self.wf)

    def test_tool_tests_are_unittest_scripts(self):
        # Шаг считает упавшим только ненулевой код выхода — каждый тест должен его давать (unittest.main).
        tests = sorted(glob.glob(os.path.join(ROOT, "tools", "test_*.py")))
        self.assertGreaterEqual(len(tests), 5)
        for t in tests:
            with open(t, encoding="utf-8") as f:
                self.assertIn("unittest.main(", f.read(), os.path.basename(t))


if __name__ == "__main__":
    unittest.main(verbosity=1)
