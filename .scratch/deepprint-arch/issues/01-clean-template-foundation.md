# 01 — Clean template foundation

**What to build:** Remove all dead LaTeX package imports and workarounds from sketch-page.tex so every `\usepackage` is load-bearing. The template should compile identically before and after — same PDF output, fewer dependencies.

**Blocked by:** None — can start immediately.

**Status:** done

**Approach:** /tdd — baselines already exist in `~/.claude/print/test/baselines/`. Run `test/run-tests.sh` before and after each removal to confirm zero visual regression.

- [ ] Run `test/run-tests.sh` — all 12 tests green (baseline confirmed)
- [ ] Remove `\usepackage{graphicx}` — run tests, confirm green
- [ ] Remove `\usepackage{caption}` and `\newcounter{none}` — run tests, confirm green
- [ ] Remove `\usepackage{lastpage}` — run tests, confirm green
- [ ] Remove `\usepackage{longtable}` — run tests, confirm green
- [ ] Remove `\usepackage{booktabs}` — run tests, confirm green
- [ ] Remove `\usepackage{colortbl}` — run tests, confirm green
- [ ] Final: all 12 tests green, every remaining `\usepackage` is load-bearing
