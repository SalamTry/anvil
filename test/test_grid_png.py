#!/usr/bin/env python3
"""Tests for grid-png — dot grid PNG generator."""

import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "grid-png")

# Paper sizes at 300 DPI (mm → px: round(mm * 300 / 25.4))
EXPECTED_SIZES = {
    "a5": (1748, 2480),
    "a6": (1240, 1748),
    "a4": (2480, 3508),
    "letter": (2550, 3300),
}


def run_grid_png(*args, cache_dir=None):
    """Run grid-png script and return (returncode, stdout, stderr)."""
    env = os.environ.copy()
    if cache_dir:
        env["ANVIL_GRID_CACHE"] = cache_dir
    result = subprocess.run(
        [sys.executable, SCRIPT, *args],
        capture_output=True, text=True, env=env,
    )
    return result.returncode, result.stdout.strip(), result.stderr.strip()


class TestGridPNG(unittest.TestCase):

    def setUp(self):
        self.cache_dir = tempfile.mkdtemp(prefix="grid-png-test-")

    def tearDown(self):
        shutil.rmtree(self.cache_dir, ignore_errors=True)

    # ── Correct dimensions for every paper size ──

    def test_a5_dimensions(self):
        self._assert_dimensions("a5", *EXPECTED_SIZES["a5"])

    def test_a6_dimensions(self):
        self._assert_dimensions("a6", *EXPECTED_SIZES["a6"])

    def test_a4_dimensions(self):
        self._assert_dimensions("a4", *EXPECTED_SIZES["a4"])

    def test_letter_dimensions(self):
        self._assert_dimensions("letter", *EXPECTED_SIZES["letter"])

    def _assert_dimensions(self, paper, expected_w, expected_h):
        from PIL import Image
        rc, out, err = run_grid_png(paper, "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0, f"script failed: {err}")
        self.assertTrue(os.path.isfile(out), f"output not found: {out}")
        with Image.open(out) as img:
            self.assertEqual(img.size, (expected_w, expected_h))
            dpi = img.info.get("dpi", (0, 0))
            self.assertAlmostEqual(dpi[0], 300, delta=0.01)
            self.assertAlmostEqual(dpi[1], 300, delta=0.01)

    # ── Color arguments are respected ──

    def test_custom_colors(self):
        from PIL import Image
        rc, out, _ = run_grid_png("a6", "FF0000", "0000FF", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        with Image.open(out) as img:
            self.assertEqual(img.size, EXPECTED_SIZES["a6"])

    # ── Caching ──

    def test_cache_hit_skips_regeneration(self):
        # First run — generates
        rc1, out1, _ = run_grid_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc1, 0)
        mtime1 = os.path.getmtime(out1)

        # Second run — cache hit, same path, file not rewritten
        rc2, out2, _ = run_grid_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc2, 0)
        self.assertEqual(out1, out2)
        mtime2 = os.path.getmtime(out2)
        self.assertEqual(mtime1, mtime2, "cached file should not be rewritten")

    def test_different_colors_different_cache(self):
        rc1, out1, _ = run_grid_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        rc2, out2, _ = run_grid_png("a5", "FF0000", "0000FF", cache_dir=self.cache_dir)
        self.assertEqual(rc1, 0)
        self.assertEqual(rc2, 0)
        self.assertNotEqual(out1, out2)

    # ── File size constraint ──

    def test_a5_under_50kb(self):
        rc, out, _ = run_grid_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        size_kb = os.path.getsize(out) / 1024
        self.assertLess(size_kb, 50, f"A5 PNG is {size_kb:.1f}KB, must be under 50KB")

    # ── Dot placement — minor at 5mm, major at 15mm ──

    def test_dot_positions(self):
        """Minor dots appear at 5mm grid, major dots at 15mm grid."""
        from PIL import Image
        rc, out, _ = run_grid_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        with Image.open(out) as img:
            px = img.load()
            # Background pixel: halfway between dots (2.5mm ≈ 30px from origin)
            bg = px[30, 30]
            self.assertEqual(bg, (255, 255, 255), "mid-grid pixel should be white")

            # Minor dot at 5mm ≈ 59px
            minor_x = round(1 * 5 * 300 / 25.4)
            minor_y = round(1 * 5 * 300 / 25.4)
            minor_pixel = px[minor_x, minor_y]
            self.assertNotEqual(minor_pixel, bg,
                                f"expected minor dot at ({minor_x},{minor_y})")

            # Major dot at 15mm ≈ 177px
            major_x = round(1 * 15 * 300 / 25.4)
            major_y = round(1 * 15 * 300 / 25.4)
            major_pixel = px[major_x, major_y]
            self.assertNotEqual(major_pixel, bg,
                                f"expected major dot at ({major_x},{major_y})")

    # ── Error handling ──

    def test_invalid_paper_size(self):
        rc, _, err = run_grid_png("b7", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertNotEqual(rc, 0)
        self.assertIn("b7", err.lower())

    def test_missing_arguments(self):
        rc, _, _ = run_grid_png(cache_dir=self.cache_dir)
        self.assertNotEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
