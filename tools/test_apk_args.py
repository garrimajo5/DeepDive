#!/usr/bin/env python3
"""Тесты ключей движка в APK (tools/apk_args.py, #1393). Запуск: python3 tools/test_apk_args.py."""
import os
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apk_args as aa  # noqa: E402

# Байты из CommandLineFileParserTest.kt (Godot 4.7.2): `_cl_` экспорта без своих ключей.
CL_DEFAULT = bytes([2, 0, 0, 0, 17, 0, 0, 0, 45, 45, 120, 114, 95, 109, 111, 100, 101, 95, 114, 101, 103, 117, 108,
                    97, 114, 15, 0, 0, 0, 45, 45, 117, 115, 101, 95, 105, 109, 109, 101, 114, 115, 105, 118, 101])


class ApkArgs(unittest.TestCase):
    def test_parse_godot_bytes(self):
        self.assertEqual(aa.parse(CL_DEFAULT), ["--xr_mode_regular", "--use_immersive"])

    def test_encode_matches_godot(self):
        self.assertEqual(aa.encode(["--xr_mode_regular", "--use_immersive"]), CL_DEFAULT)

    def test_broken_is_empty(self):
        self.assertEqual(aa.parse(b""), [])
        self.assertEqual(aa.parse(bytes([2, 0, 0, 0, 17, 0, 0])), [])

    def test_v1_signature(self):
        for n in ("META-INF/MANIFEST.MF", "META-INF/CERT.SF", "META-INF/CERT.RSA", "META-INF/ANDROIDD.EC"):
            self.assertTrue(aa.is_v1_signature(n), n)
        for n in ("META-INF/services/x", "assets/_cl_", "lib/x86_64/libgodot_android.so"):
            self.assertFalse(aa.is_v1_signature(n), n)

    def test_patch_keeps_files_and_prepends(self):
        with tempfile.TemporaryDirectory() as d:
            src, dst = os.path.join(d, "in.apk"), os.path.join(d, "out.apk")
            with zipfile.ZipFile(src, "w") as z:
                z.writestr(zipfile.ZipInfo("AndroidManifest.xml"), b"m" * 100, compress_type=zipfile.ZIP_DEFLATED)
                z.writestr(zipfile.ZipInfo("lib/x86_64/libgodot_android.so"), b"so", compress_type=zipfile.ZIP_STORED)
                z.writestr(aa.CL, CL_DEFAULT)
                z.writestr("META-INF/CERT.SF", b"old")
                z.writestr("META-INF/MANIFEST.MF", b"old")
            got = aa.patch(src, dst, ["--rendering-method", "gl_compatibility"])
            self.assertEqual(got, ["--rendering-method", "gl_compatibility", "--xr_mode_regular", "--use_immersive"])
            with zipfile.ZipFile(dst) as z:
                names = z.namelist()
                self.assertEqual(aa.parse(z.read(aa.CL)), got)
                self.assertEqual(z.getinfo(aa.CL).compress_type, zipfile.ZIP_STORED)
                self.assertEqual(z.getinfo("lib/x86_64/libgodot_android.so").compress_type, zipfile.ZIP_STORED)
                self.assertEqual(z.getinfo("AndroidManifest.xml").compress_type, zipfile.ZIP_DEFLATED)
                self.assertEqual(z.read("AndroidManifest.xml"), b"m" * 100)
                self.assertNotIn("META-INF/CERT.SF", names)
                self.assertNotIn("META-INF/MANIFEST.MF", names)
                self.assertEqual(names.count(aa.CL), 1)

    def test_patch_without_cl(self):
        with tempfile.TemporaryDirectory() as d:
            src, dst = os.path.join(d, "in.apk"), os.path.join(d, "out.apk")
            with zipfile.ZipFile(src, "w") as z:
                z.writestr("classes.dex", b"dex")
            self.assertEqual(aa.patch(src, dst, ["--a"]), ["--a"])

    def test_workflow_uses_it(self):
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        text = open(os.path.join(root, ".github/workflows/qa-emulator.yml"), encoding="utf-8").read()
        self.assertIn("tools/apk_args.py", text)
        self.assertIn("gl_compatibility", text)
        self.assertIn("apksigner", text)
        self.assertIn("zipalign", text)


if __name__ == "__main__":
    unittest.main()
