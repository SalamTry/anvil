# 08 — Grid-snap Lua callback

**What to build:** A standalone LuaLaTeX module (`grid-snap.lua`) that automatically snaps every text baseline to the 5mm dot grid. Once loaded by the template, body paragraphs, list items, and any future content types align with the dot grid without manual `\fontsize` or strut hacks. The module reads the grid pitch from the template's `\gridunit` length, registers an `append_to_vlist_filter` callback, and adjusts interline glue so each baseline lands on an exact 5mm multiple. Logs a warning to the LaTeX `.log` file when an element's natural height isn't a strict 5mm multiple.

**Blocked by:** 07 — Switch engine to LuaLaTeX.

**Status:** done

**Approach:** Use `luatexbase.add_to_callback("append_to_vlist_filter", ...)` to intercept lines as they join the vertical list. Read grid pitch via `tex.dimen["gridunit"]`. For each line, compute the cumulative vertical position and adjust glue to the next grid-aligned position.

- [x] Create `grid-snap.lua` as a LuaLaTeX module (loaded via `\directlua`, NOT a pandoc filter)
- [x] Load the module in `sketch-page.tex` via `\directlua{require("grid-snap")}` after `\gridunit` is defined
- [x] Body text baselines land on exact 5mm multiples in the output PDF
- [x] List item baselines land on exact 5mm multiples
- [x] Warnings appear in the `.log` file for elements whose natural height isn't a 5mm multiple
- [x] Add a new test: render a mixed-content fixture (body + list + heading + table), extract baseline Y-positions from the PDF, assert all are at `top_margin + N * 5mm`
- [x] All 15 existing tests still pass
