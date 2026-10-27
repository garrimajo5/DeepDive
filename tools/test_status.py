#!/usr/bin/env python3
"""Тесты страницы «Где мы» (tools/status.py): разбор чек-листа эпика, прогресс по плану, статус этапа, отрисовка.
Запуск: python3 tools/test_status.py (его же гоняет .github/workflows/status.yml перед обновлением страницы)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import status  # noqa: E402


class ParseTasks(unittest.TestCase):
    def test_roles_and_blocker(self):
        body = ("Вступление\n## Задачи\n"
                "- [x] Связь на мостике — поток А (#316)\n"
                "- [ ] Озвучка реплик — звук — ⛔ владелец: выбор инструмента\n"
                "- [ ] Механика загадок — поток А, поток Б\n"
                "текст без галочки\n")
        t = status.parse_tasks(body)
        self.assertEqual(len(t), 3)
        self.assertTrue(t[0]["done"])
        self.assertEqual(t[0]["roles"], ["поток А"])
        self.assertEqual(t[1]["text"], "Озвучка реплик")
        self.assertEqual(t[1]["roles"], ["звук"])
        self.assertEqual(t[1]["blocker"], "владелец: выбор инструмента")
        self.assertEqual(t[2]["roles"], ["поток А", "поток Б"])
        self.assertIsNone(t[2]["blocker"])

    def test_animation_role(self):
        t = status.parse_tasks("- [ ] Анимации экипажа — заказ ANIM — анимация, поток А\n")
        self.assertEqual(t[0]["roles"], ["поток А", "анимация"])

    def test_role_word_not_inside_other_words(self):
        # «art» не находится внутри «старт», «qa» — внутри других слов
        t = status.parse_tasks("- [ ] Старт забега — поток А\n")
        self.assertEqual(t[0]["roles"], ["поток А"])

    def test_empty(self):
        self.assertEqual(status.parse_tasks(None), [])


class Progress(unittest.TestCase):
    def test_doc_progress_counts_removed_as_done(self):
        text = "- [x] а\n- [ ] б\n  - [~] снято\n- [X] в\nне задача\n"
        self.assertEqual(status.doc_progress(text), (3, 4))

    def test_plan_path(self):
        self.assertEqual(status.plan_path("План: `docs/grafika-plan.md` — задачи там"), "docs/grafika-plan.md")
        self.assertIsNone(status.plan_path("без плана"))

    def test_bar_and_pct(self):
        self.assertEqual(status.bar(0, 0), "░" * 10)
        self.assertEqual(status.bar(5, 10), "▓" * 5 + "░" * 5)
        self.assertEqual(status.pct(1, 3), 33)


class Week(unittest.TestCase):
    def test_week_stats(self):
        recent = [
            {"number": 1, "state_reason": "completed", "closed_at": "2", "labels": [{"name": "баг"}]},
            {"number": 2, "state_reason": "completed", "closed_at": "3", "labels": [{"name": "art"}]},
            {"number": 3, "state_reason": "completed", "closed_at": "1", "labels": [{"name": "model"}]},
            {"number": 4, "state_reason": "not_planned", "closed_at": "4", "labels": []},
            {"number": 5, "closed_at": "5", "labels": [], "pull_request": {}},          # PR в списке issues — не задача
        ]
        prs = [{"merged_at": "x", "head": {"ref": "feat/a-x"}}, {"merged_at": "x", "head": {"ref": "fix/b-y"}},
               {"merged_at": "x", "head": {"ref": "art/ART-1-z"}}, {"merged_at": "x", "head": {"ref": "qa/2026"}},
               {"merged_at": None, "head": {"ref": "feat/a-closed-unmerged"}}]
        w = status.week_stats(recent, prs)
        self.assertEqual((w["pr"], w["pr_code"], w["pr_art"], w["pr_qa"]), (4, 2, 1, 1))
        self.assertEqual((w["done"], w["bugs"], w["art"], w["model"], w["dropped"]), (3, 1, 1, 1, 1))
        self.assertEqual([i["number"] for i in w["list"]], [2, 1, 3])   # свежие сверху

    def test_page_shows_week_table(self):
        page = status.render([], [], [], [{"number": 9, "title": "Готово", "state_reason": "completed",
                                          "closed_at": "1", "labels": []}], {},
                             prs=[{"merged_at": "x", "head": {"ref": "art/A"}}])
        self.assertIn("| PR слито | 1 | код и документы 0 · сдачи художника 1 · отчёты тестера 0 |", page)
        self.assertIn("| Issues закрыто как сделанные | 1 |", page)


class Stage(unittest.TestCase):
    def test_statuses(self):
        self.assertEqual(status.stage_status(True, 0, 0, 0, False), "✅ пройден")
        self.assertTrue(status.stage_status(False, 0, 0, 0, True).startswith("🟡"))   # раньше эпиков — ждёт приёмки
        self.assertTrue(status.stage_status(False, 0, 0, 0, False).startswith("⏳"))
        self.assertTrue(status.stage_status(False, 2, 3, 3, False).startswith("🟡"))  # всё сделано
        self.assertTrue(status.stage_status(False, 2, 1, 3, False).startswith("🔄"))
        self.assertTrue(status.stage_status(False, 2, 0, 3, False).startswith("⏳"))


class Render(unittest.TestCase):
    def test_page(self):
        ms = [{"number": 1, "title": "Этап 1. Каркас", "state": "open"},
              {"number": 4, "title": "Этап 4. Забег", "state": "open"}]
        epic = {"number": 10, "title": "Эпик: забег", "state": "open", "milestone": {"number": 4},
                "labels": [{"name": "эпик"}, {"name": "qa"}],
                "body": "- [x] раз — qa\n- [ ] два — владелец — ⛔ владелец\n",
                "sub_issues_summary": {"completed": 1, "total": 2}}
        owner_issue = {"number": 11, "title": "Вопрос", "labels": [{"name": "ждёт владельца"}, {"name": "поток А"}]}
        page = status.render(ms, [epic], [epic, owner_issue], [], {})
        self.assertIn("**Сейчас:** Этап 4. Забег", page)
        self.assertIn("Каркас", page)
        self.assertIn("2/4", page)                       # 1 галочка + 1 подзадача из 2+2
        self.assertIn("#11 Вопрос", page)                # ждёт владельца — issue
        self.assertIn("два — эпик #10", page)            # ждёт владельца — задача чек-листа
        self.assertIn("Сюжет и тексты (Codex пишет, владелец утверждает)", page)  # тексты — Codex, 27.10
        self.assertNotIn("нет исполнителя-агента", page)

    def test_on_hold_not_waiting_owner_and_verify_is_qa(self):
        ms = [{"number": 4, "title": "Этап 4. Забег", "state": "open"}]
        epic = {"number": 10, "title": "Эпик: экипаж", "state": "open", "milestone": None,
                "labels": [{"name": "эпик"}], "sub_issues_summary": {"completed": 0, "total": 0},
                "body": "- [ ] Одежда — model — ⛔ on-hold (владелец)\n- [ ] Анимации — model — ⛔ владелец\n"}
        fix = {"number": 12, "title": "Провал кадра", "labels": [{"name": "проверить"}, {"name": "поток А"}]}
        page = status.render(ms, [epic], [epic, fix], [], {})
        owner = page.split("## ⛔ Ждёт владельца")[1].split("##")[0]
        self.assertIn("Анимации", owner)
        self.assertNotIn("Одежда", owner)                # on-hold — решение уже есть, не ждёт
        qa_row = [l for l in page.splitlines() if l.startswith("| Тестер")][0]
        self.assertIn("#12 (проверить)", qa_row)         # «проверить» — работа тестера

    def test_owner_acceptance_listed(self):
        # дела самого владельца без блокера (приёмка этапа, бета) тоже ждут его — отдельным списком
        ms = [{"number": 4, "title": "Этап 4. Забег", "state": "open"}]
        epic = {"number": 10, "title": "Эпик: приёмка", "state": "open", "milestone": None,
                "labels": [{"name": "эпик"}], "sub_issues_summary": {"completed": 0, "total": 0},
                "body": "- [ ] Этап 1: корабль удобно вести — владелец\n- [x] Выбор музыки — владелец\n"
                        "- [ ] Сварка — поток А\n"}
        page = status.render(ms, [epic], [epic], [], {})
        owner = page.split("## ⛔ Ждёт владельца")[1].split("\n## ")[0]
        self.assertIn("(1)", page.split("## ⛔ Ждёт владельца")[1].splitlines()[0])
        self.assertIn("Приёмка и твои дела", owner)
        self.assertIn("Этап 1: корабль удобно вести — эпик #10", owner)
        self.assertNotIn("Выбор музыки", owner)          # сделано
        self.assertNotIn("Сварка", owner)                # не роль владельца
        self.assertNotIn("Решения", owner)               # решений не ждут — заголовка нет

    def test_short_drops_code_marks(self):
        self.assertEqual(status.short("Кадры по `tools/qa/play-kadry.json` для Google Play", 20), "Кадры по tools/qa/pl…")


if __name__ == "__main__":
    unittest.main(verbosity=1)
