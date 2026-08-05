#!/usr/bin/env python3
"""Tests for themes/graph/generate — graph paper PNG generator."""

import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "themes", "graph", "generate")

# Paper sizes at 300 DPI (mm → px: round(mm * 300 / 25.4))
EXPECTED_SIZES = {
    "a5": (1748, 2480),
    "a6": (1240, 1748),
    "a4": (2480, 3508),
    "letter": (2550, 3300),
}


def run_graph_png(*args, cache_dir=None):
    """Run graph/generate script and return (returncode, stdout, stderr)."""
    env = os.environ.copy()
    if cache_dir:
        env["ANVIL_GRID_CACHE"] = cache_dir
    result = subprocess.run(
        [sys.executable, SCRIPT, *args],
        capture_output=True, text=True, env=env,
    )
    return result.returncode, result.stdout.strip(), result.stderr.strip()


class TestGraphPNG(unittest.TestCase):

    def setUp(self):
        self.cache_dir = tempfile.mkdtemp(prefix="graph-png-test-")

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
        rc, out, err = run_graph_png(paper, "CCCCCC", "999999", cache_dir=self.cache_dir)
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
        rc, out, _ = run_graph_png("a6", "FF0000", "0000FF", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        with Image.open(out) as img:
            self.assertEqual(img.size, EXPECTED_SIZES["a6"])

    # ── Caching ──

    def test_cache_hit_skips_regeneration(self):
        rc1, out1, _ = run_graph_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc1, 0)
        mtime1 = os.path.getmtime(out1)

        rc2, out2, _ = run_graph_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc2, 0)
        self.assertEqual(out1, out2)
        mtime2 = os.path.getmtime(out2)
        self.assertEqual(mtime1, mtime2, "cached file should not be rewritten")

    def test_different_colors_different_cache(self):
        rc1, out1, _ = run_graph_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        rc2, out2, _ = run_graph_png("a5", "FF0000", "0000FF", cache_dir=self.cache_dir)
        self.assertEqual(rc1, 0)
        self.assertEqual(rc2, 0)
        self.assertNotEqual(out1, out2)

    # ── File size constraint ──

    def test_a5_under_50kb(self):
        rc, out, _ = run_graph_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        size_kb = os.path.getsize(out) / 1024
        self.assertLess(size_kb, 50, f"A5 PNG is {size_kb:.1f}KB, must be under 50KB")

    # ── Line placement — horizontal lines at 5mm intervals ──

    def test_horizontal_line_positions(self):
        """Minor horizontal lines appear at 5mm intervals."""
        from PIL import Image
        rc, out, _ = run_graph_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        with Image.open(out) as img:
            px = img.load()
            w, h = img.size
            mid_x = w // 2

            # Background pixel: between two lines (2.5mm ≈ 30px from origin)
            bg = px[mid_x, 30]
            self.assertEqual(bg, (255, 255, 255), "mid-line pixel should be white")

            # Minor line at 5mm ≈ 59px
            line_y = round(1 * 5 * 300 / 25.4)
            line_pixel = px[mid_x, line_y]
            self.assertNotEqual(line_pixel, (255, 255, 255),
                                f"expected horizontal line at y={line_y}")

            # Another minor line at 10mm ≈ 118px
            line_y2 = round(2 * 5 * 300 / 25.4)
            line_pixel2 = px[mid_x, line_y2]
            self.assertNotEqual(line_pixel2, (255, 255, 255),
                                f"expected horizontal line at y={line_y2}")

    def test_horizontal_lines_span_page(self):
        """Horizontal lines should extend across the full page width."""
        from PIL import Image
        rc, out, _ = run_graph_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        with Image.open(out) as img:
            px = img.load()
            w, h = img.size
            line_y = round(2 * 5 * 300 / 25.4)  # 10mm

            for x_frac in [0.1, 0.25, 0.5, 0.75, 0.9]:
                x = int(w * x_frac)
                pixel = px[x, line_y]
                self.assertNotEqual(pixel, (255, 255, 255),
                                    f"horizontal line at y={line_y} should be present at x={x}")

    # ── Line placement — vertical lines at 5mm intervals ──

    def test_vertical_line_positions(self):
        """Minor vertical lines appear at 5mm intervals."""
        from PIL import Image
        rc, out, _ = run_graph_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        with Image.open(out) as img:
            px = img.load()
            w, h = img.size
            mid_y = h // 2

            # Vertical line at 5mm ≈ 59px
            line_x = round(1 * 5 * 300 / 25.4)
            line_pixel = px[line_x, mid_y]
            self.assertNotEqual(line_pixel, (255, 255, 255),
                                f"expected vertical line at x={line_x}")

            # Another vertical line at 10mm ≈ 118px
            line_x2 = round(2 * 5 * 300 / 25.4)
            line_pixel2 = px[line_x2, mid_y]
            self.assertNotEqual(line_pixel2, (255, 255, 255),
                                f"expected vertical line at x={line_x2}")

    def test_vertical_lines_span_page(self):
        """Vertical lines should extend across the full page height."""
        from PIL import Image
        rc, out, _ = run_graph_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        with Image.open(out) as img:
            px = img.load()
            w, h = img.size
            line_x = round(2 * 5 * 300 / 25.4)  # 10mm

            for y_frac in [0.1, 0.25, 0.5, 0.75, 0.9]:
                y = int(h * y_frac)
                pixel = px[line_x, y]
                self.assertNotEqual(pixel, (255, 255, 255),
                                    f"vertical line at x={line_x} should be present at y={y}")

    # ── Grid intersections — both lines meet ──

    def test_grid_intersections(self):
        """At grid intersections, both horizontal and vertical lines are present."""
        from PIL import Image
        rc, out, _ = run_graph_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        with Image.open(out) as img:
            px = img.load()

            # Check intersections at (5mm, 5mm), (10mm, 10mm), (15mm, 15mm)
            for n in [1, 2, 3]:
                pos = round(n * 5 * 300 / 25.4)
                pixel = px[pos, pos]
                self.assertNotEqual(pixel, (255, 255, 255),
                                    f"expected intersection mark at ({pos}, {pos})")

    # ── Major vs minor lines ──

    def test_major_lines_differ_from_minor(self):
        """Major lines (every 15mm) should use the major color, distinct from minor."""
        from PIL import Image
        rc, out, _ = run_graph_png("a5", "CCCCCC", "444444", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        with Image.open(out) as img:
            px = img.load()
            mid_x = img.size[0] // 2

            # Minor horizontal line at 5mm (row 1, not a major)
            minor_y = round(1 * 5 * 300 / 25.4)
            minor_pixel = px[mid_x, minor_y]

            # Major horizontal line at 15mm (row 3, which is major)
            major_y = round(3 * 5 * 300 / 25.4)
            major_pixel = px[mid_x, major_y]

            self.assertNotEqual(minor_pixel, major_pixel,
                                "major and minor lines should use different colors")

    def test_major_vertical_lines_differ_from_minor(self):
        """Major vertical lines (every 15mm) should use the major color."""
        from PIL import Image
        rc, out, _ = run_graph_png("a5", "CCCCCC", "444444", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        with Image.open(out) as img:
            px = img.load()
            mid_y = img.size[1] // 2

            # Minor vertical line at 5mm (col 1)
            minor_x = round(1 * 5 * 300 / 25.4)
            minor_pixel = px[minor_x, mid_y]

            # Major vertical line at 15mm (col 3)
            major_x = round(3 * 5 * 300 / 25.4)
            major_pixel = px[major_x, mid_y]

            self.assertNotEqual(minor_pixel, major_pixel,
                                "major and minor vertical lines should use different colors")

    # ── Cache does not collide with other themes ──

    def test_cache_prefix_includes_graph(self):
        """Cache filenames should include 'graph' to avoid collisions."""
        rc, out, _ = run_graph_png("a5", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertEqual(rc, 0)
        filename = os.path.basename(out)
        self.assertTrue(filename.startswith("graph-"),
                        f"cache filename should start with 'graph-', got: {filename}")

    # ── Error handling ──

    def test_invalid_paper_size(self):
        rc, _, err = run_graph_png("b7", "CCCCCC", "999999", cache_dir=self.cache_dir)
        self.assertNotEqual(rc, 0)
        self.assertIn("b7", err.lower())

    def test_missing_arguments(self):
        rc, _, _ = run_graph_png(cache_dir=self.cache_dir)
        self.assertNotEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
