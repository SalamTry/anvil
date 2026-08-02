# 06 — LuaLaTeX Grid-Snap Engine

## Problem Statement

Deepprint generates blueprint-style study pages with a 5mm dot grid background. Text baselines must land exactly on dot rows so users can handwrite between lines. Currently this is done with manual hacks: forced `\fontsize{10pt}{5mm}`, zeroed elastic spacing, and explicit `\rule` struts in tables. Every new content type (code blocks, callout boxes, footnotes) will need its own manual alignment work. The approach doesn't scale as deepprint grows in features.

## Solution

Switch from XeLaTeX to LuaLaTeX and introduce a `grid-snap.lua` module that hooks into LuaTeX's typesetting engine via `append_to_vlist_filter`. The callback enforces that every line's baseline lands on an exact multiple of 5mm — automatically, for all content types. The existing manual struts and forced font sizes in `grid-tables.lua` and `sketch-page.tex` can then be removed, because the engine handles alignment globally.

## User Stories

1. As a deepprint user, I want body text baselines to land exactly on dot rows, so that I can write notes between printed lines
2. As a deepprint user, I want table row text to sit on dot rows, so that tables look aligned with the rest of the page
3. As a deepprint user, I want section headings to sit on dot rows, so that the page has consistent vertical rhythm
4. As a deepprint user, I want list items to sit on dot rows, so that bullet points align with the grid
5. As a deepprint user, I want blockquote text to sit on dot rows, so that quotes don't break the grid
6. As a deepprint user, I want the title to sit on a dot row, so that the first line of the page is aligned
7. As a deepprint user, I want to see a warning when an element's natural height isn't a strict multiple of 5mm, so that I can fix the template rather than silently drift
8. As a deepprint user, I want the grid-snap behavior to work across all paper sizes (A5, A6, A4, letter), so that alignment is universal
9. As a deepprint user, I want new content types I add in the future (code blocks, footnotes, diagrams) to automatically align without additional manual work
10. As a deepprint user, I want the existing visual style (dot grid, colors, fonts) to remain unchanged after the engine switch

## Implementation Decisions

1. **Engine switch**: Change `--pdf-engine=xelatex` to `--pdf-engine=lualatex` in the `deepprint` shell script. LuaLaTeX is a superset of XeLaTeX — same `fontspec`, same OpenType font support, same template syntax. One-line change.

2. **New module `grid-snap.lua`**: A LuaLaTeX callback module (NOT a pandoc Lua filter — those are different runtimes). Loaded in the template via `\directlua{require("grid-snap")}`. Registers an `append_to_vlist_filter` callback that:
   - Reads the current grid pitch from `\gridunit` (5mm)
   - For each line added to the vertical list, calculates where the baseline would land
   - Adjusts interline glue so the baseline snaps to the nearest grid multiple
   - Logs a warning to the `.log` file when an element's natural height isn't a strict 5mm multiple

3. **Strict multiples, not snap-to-nearest**: The callback enforces that every vertical space is an exact multiple of 5mm. When something is off-grid, it warns rather than silently nudging. This makes drift visible so it can be fixed at the source (heading font size, table row height) rather than papered over.

4. **Heading font sizes as grid multiples**: Update `sketch-page.tex` so heading commands produce heights that are exact multiples of 5mm:
   - `\Large` title: `\fontsize{14pt}{10mm}` (2 grid units)
   - `\section`: `\fontsize{10pt}{5mm}` (1 grid unit) — same as body
   - `\subsection` / `\subsubsection`: `\fontsize{10pt}{5mm}` (1 grid unit)

5. **Remove manual struts from `grid-tables.lua`**: Once grid-snap handles row alignment at the engine level, the explicit `\rule[-\gridunit]{0pt}{2\gridunit}` struts and forced `\fontsize` in table cells can be removed. Table cells go back to `{\small content}` and the engine takes care of baseline positioning.

6. **Separate concerns**:
   - `grid-snap.lua` — engine-level baseline enforcement (LuaLaTeX callback)
   - `grid-tables.lua` — pandoc AST transformation (table → tabularx, horizontal rules → dot separators)
   - `sketch-page.tex` — document template (layout, colors, fonts, grid background)
   - `deepprint` — shell orchestrator (config, argument parsing, pandoc invocation)

7. **`luatexbase` for callback registration**: Use `luatexbase.add_to_callback()` which is the standard LuaLaTeX way to register callbacks. Available by default in LuaLaTeX — no extra package needed.

8. **Grid unit passed from TeX to Lua**: The callback reads `\gridunit` via `tex.dimen["gridunit"]` (after allocating it with `\newlength`). This keeps the 5mm value defined once in the template, not duplicated in Lua.

## Testing Decisions

A good test for grid-snap verifies externally observable behavior: "do baselines land on 5mm multiples in the output PDF?" — not internal implementation details like "did the callback fire" or "was glue adjusted by X pt."

**Test seam**: the existing pipeline boundary — markdown fixtures in, PDF out, validated by visual regression and baseline measurement. Same pattern as tests 1-3, 11-12.

**New tests**:
- **Grid alignment verification**: Render a mixed-content fixture (body paragraphs + section heading + table + bullet list + blockquote) and extract baseline Y-positions from the PDF. Assert every baseline is at `top_margin + N * 5mm` for some integer N.
- **Engine switch smoke test**: All existing test fixtures (1-15) must still render and pass after switching from XeLaTeX to LuaLaTeX. Same dimensions, same visual output.
- **Warning on off-grid element**: Render a fixture with a deliberately off-grid element. Verify a warning appears in the LaTeX log.
- **Cross-paper grid alignment**: Verify baselines align on A5, A6, A4, and letter sizes (extends tests 11-12 with baseline checks).

**Prior art**: Tests 1-3 and 11-12 in `run-tests.sh` already render fixtures, convert to PNG via `sips`, and compare dimensions against baselines. The new tests follow the same pattern, adding PDF baseline extraction (via `pdftotext -layout` or a small Lua script that reads PDF text positions).

**Baseline extraction method**: Use `pdftotext -bbox` (from poppler-utils) which outputs XML with exact glyph Y-coordinates, or `mutool draw -F text` from mupdf. Either gives sub-point precision on baseline positions. The test asserts `(page_height - y_position - top_margin) % 5mm < tolerance` where tolerance is < 0.1mm.

## Out of Scope

- **New content types** (code blocks, callout boxes, footnotes, diagrams): grid-snap will handle them automatically when they're added later, but this spec doesn't add them.
- **Grid pitch configurability**: The 5mm grid pitch stays hardcoded. Making it a CLI flag is a future feature.
- **ConTeXt or SILE migration**: We evaluated these and decided to stay on the LaTeX/pandoc pipeline.
- **Pandoc filter for grid alignment**: The grid-snap happens at the engine level, not in the pandoc filter.
- **HP Tank 581 printer setup**: Separate concern — printer configuration is independent of the engine switch.

## Further Notes

- LuaLaTeX is ~20-30% slower than XeLaTeX on first run due to font caching. Subsequent runs are comparable. For a CLI that generates one page at a time, this is negligible.
- The `grid-snap.lua` module is engine-level Lua (runs inside LuaTeX), NOT a pandoc Lua filter (runs inside pandoc). These are completely separate Lua runtimes. The module lives in the same directory but is loaded via `\directlua{require(...)}` in the template, not via `--lua-filter` in pandoc.
- `fontspec` works identically in LuaLaTeX and XeLaTeX. No font configuration changes needed.
- The `eso-pic` + TikZ dot grid background works unchanged in LuaLaTeX.
