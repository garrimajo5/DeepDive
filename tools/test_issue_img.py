#!/usr/bin/env python3
"""Тесты tools/issue_img.py: текст комментария со встроенными картинками, ссылки, пережатие крупного снимка.
Запуск: python3 tools/test_issue_img.py (гоняет и .github/workflows/status.yml)."""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import issue_img  # noqa: E402


class Body(unittest.TestCase):
    def test_raw_url_in_issue_folder(self):
        self.assertEqual(issue_img.raw_url(576, "a.jpg"),
                         f"https://raw.githubusercontent.com/{issue_img.REPO}/issue-img/576/a.jpg")

    def test_variants_with_captions_and_text(self):
        body = issue_img.comment_body(5, [("v1.jpg", "Вариант 1"), ("v2.jpg", "Вариант 2")], "Какой берём?")
        self.assertTrue(body.startswith("Какой берём?"))
        self.assertIn("**Вариант 1**\n\n![Вариант 1](", body)
        self.assertIn("/issue-img/5/v2.jpg)", body)
        self.assertLess(body.index("Вариант 1"), body.index("Вариант 2"))

    def test_no_caption(self):
        self.assertEqual(issue_img.comment_body(7, [("s.png", "")]), f"![s.png]({issue_img.raw_url(7, 's.png')})")


class Shrink(unittest.TestCase):
    def test_small_file_kept(self):
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
            f.write(b"x" * 1000)
        data, name = issue_img.shrink(f.name)
        self.assertEqual((len(data), name), (1000, os.path.basename(f.name)))
        os.unlink(f.name)

    def test_big_png_to_jpeg(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("нет Pillow")
        path = os.path.join(tempfile.mkdtemp(), "shot.png")
        Image.effect_noise((2400, 1080), 120).convert("RGB").save(path)   # шум — PNG точно больше 900 КБ
        self.assertGreater(os.path.getsize(path), issue_img.MAX_BYTES)
        data, name = issue_img.shrink(path)
        self.assertEqual(name, "shot.jpg")
        self.assertTrue(data.startswith(b"\xff\xd8"))                    # JPEG
        self.assertLess(len(data), os.path.getsize(path))


if __name__ == "__main__":
    unittest.main(verbosity=1)
