# 01 — Grid PNG generator script

**What to build:** A standalone script that generates a dot grid PNG for a given paper size and color pair at 300 DPI. The grid matches the current spec: minor dots every 5mm (0.45pt radius), major dots every 15mm (0.85pt radius). The script accepts paper size and two hex colors as arguments, outputs a PNG, and caches results by size + colors so repeated runs with the same inputs skip regeneration. Supported paper sizes: A5, A6, A4, letter.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] Script generates a dot grid PNG at 300 DPI for each supported paper size (A5, A6, A4, letter)
- [x] Minor dots at 5mm spacing and major dots at 15mm spacing match the current TikZ grid
- [x] Accepts hex color arguments for minor and major dot colors
- [x] Caches output by paper size + colors — skips regeneration on cache hit
- [x] Output PNG is under 50KB for A5 (22KB)
- [x] Script is runnable standalone for inspection
