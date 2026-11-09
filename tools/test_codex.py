#!/usr/bin/env python3
"""Тесты «Кодекса игры» (tools/codex.py, #1417): разбор источников, полнота справочника, сборка.
Запуск: python3 tools/test_codex.py (его же гоняет .github/workflows/codex.yml перед сборкой)."""
import os
import re
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import codex  # noqa: E402


class Sources(unittest.TestCase):
    def test_layer_map(self):
        lm = codex.layer_map(codex.read(codex.LAYER_MAP))
        self.assertEqual(len(lm["points"]), 11)
        self.assertEqual(lm["points"]["01"]["name"], "Каменный цветок")
        self.assertEqual(lm["points"]["10"]["depth"], 290.0)
        self.assertFalse(lm["points"]["07"]["accepted"])
        self.assertEqual(lm["main"][0], "00")
        self.assertIn(["07", "08"], lm["links"])

    def test_species_registry(self):
        reg = codex.species(codex.read(codex.SPECIES))
        ids = [s["id"] for s in reg]
        n = len(re.findall(r'^\t\t"id": "', codex.read(codex.SPECIES), re.M))
        self.assertEqual(len(reg), n, "каждый вид реестра разобран")
        self.assertEqual(ids[0], "fish")
        pred = reg[ids.index("pred")]
        self.assertEqual(pred["name"], "Серпохвост")
        self.assertTrue(any("сонар" in t for t in pred["notes"]))

    def test_bestiary_line(self):
        b = codex.bestiary("## Подлёдный сад\n- **Скребун** (фауна, пасущийся, 1,5 м) [в игре] [концепт]: Панцирник. "
                           "*Особенность:* Ест мох. *Связи:* Стеклоуст\n")
        e = b["Скребун"]
        self.assertEqual(e["section"], "Подлёдный сад")
        self.assertEqual(e["marks"], ["в игре", "концепт"])
        self.assertEqual(e["text"], "Панцирник.")
        self.assertEqual(e["trait"], "Ест мох.")
        self.assertEqual(e["links"], "Стеклоуст")
        self.assertEqual(len(codex.bestiary(codex.read(codex.BESTIARY))), 100)

    def test_concept_by_head_or_table(self):
        notes = codex.concept_notes()
        self.assertEqual(codex.find_concept("Скребун", notes), "stekloust-skrebun.md")
        self.assertEqual(codex.find_concept("Каменный цветок", notes), "kamennyy-tsvetok.md")
        self.assertEqual(codex.find_concept("Веерник", notes), "flora-otmeli.md")   # строка таблицы «| Веерник |»
        self.assertEqual(codex.find_concept("Блиц", notes), "")

    def test_markdown(self):
        h = codex.markdown("# Заголовок\n\nАбзац **жирно** и `код`.\n\n- раз\n- два\n\n| a | b |\n|---|---|\n| 1 | 2 |\n")
        self.assertIn("<h2>Заголовок</h2>", h)
        self.assertIn("<b>жирно</b>", h)
        self.assertIn("<code>код</code>", h)
        self.assertIn("<ul><li>раз</li><li>два</li></ul>", h)
        self.assertIn("<td>1</td><td>2</td>", h)
        self.assertNotIn("---", h)
        self.assertIn("&lt;script&gt;", codex.markdown("<script>"))


class Build(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dir = tempfile.mkdtemp()
        cls.page = codex.build(cls.dir)

    def test_nothing_missing(self):
        self.assertEqual(codex.missing(self.page), [])

    def test_missing_place_or_species_fails(self):
        cut = re.sub(r'<article class="card" id="mesto-08">.*?</article>', "", self.page, flags=re.S)
        self.assertEqual(codex.missing(cut), ["место 08 Наблюдение поля"])
        cut = re.sub(r'<article class="card" id="vid-echo">.*?</article>', "", self.page, flags=re.S)
        self.assertEqual(codex.missing(cut), ["вид echo Эхоловец"])

    def test_world_species_and_status(self):
        for name in ("Светящийся мох", "Огнецвет", "Ленточник", "Ледяная моль", "Инеевая бахрома"):
            self.assertIn(f"<h3>{name} ", self.page, "вид мира без реестра")
        self.assertIn('<span class="st s-game">в игре</span>', self.page)
        self.assertIn('<span class="st s-plan">в планах</span>', self.page)   # Блиц — только бестиарий

    def test_images_local(self):
        srcs = re.findall(r'<img[^>]* src="([^"]+)"', self.page)
        self.assertTrue(srcs)
        for s in srcs:
            self.assertTrue(s.startswith("img/"), s)
            self.assertTrue(os.path.isfile(os.path.join(self.dir, s)), s)
        self.assertNotRegex(self.page, r'(src|href)="https?://[^"]*\.(js|css)', "без внешних CDN")

    def test_phone_viewport(self):
        self.assertIn('name="viewport"', self.page)


if __name__ == "__main__":
    unittest.main(verbosity=1)
