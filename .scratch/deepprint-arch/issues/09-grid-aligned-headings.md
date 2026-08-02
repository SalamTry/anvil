# 09 — Grid-aligned headings and title

**What to build:** Section headings and the document title use font sizes whose leading is a strict multiple of 5mm, so the grid-snap callback doesn't need to warn or nudge them. The title uses `\fontsize{14pt}{10mm}` (2 grid units). Sections, subsections, and subsubsections use `\fontsize{10pt}{5mm}` (1 grid unit, matching body text). Title spacing after (`\vspace`) remains at `\gridunit`. This makes headings first-class grid citizens instead of elements that rely on the callback to fix.

**Blocked by:** 08 — Grid-snap Lua callback.

**Status:** ready-for-agent

- [ ] Title uses `\fontsize{14pt}{10mm}\selectfont` instead of `\Large`
- [ ] Section format uses `\fontsize{10pt}{5mm}\selectfont` instead of `\normalsize`
- [ ] Subsection and subsubsection formats use `\fontsize{10pt}{5mm}\selectfont` instead of `\small`
- [ ] Title spacing (`\titlespacing`, `\vspace`) values are exact 5mm multiples
- [ ] No grid-snap warnings in the LaTeX log for headings
- [ ] Baseline extraction test passes with headings on-grid
- [ ] All existing tests still pass
