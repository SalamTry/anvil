# 05 — Preserve table cell formatting

**What to build:** Replace `pandoc.utils.stringify()` in the Lua filter with `pandoc.write()` so that bold, italic, code spans, and links in table cells render correctly in the PDF instead of being silently stripped to plain text.

**Blocked by:** 03 — Config-driven pipeline.

**Status:** done

**Approach:** /tdd — test 7 (`rich-table.md`) already renders a table with bold/italic/code cells. Snapshot the before state, fix the filter, snapshot after, visually compare.

- [ ] Snapshot current `rich-table` baseline as "before" reference (formatting currently stripped)
- [ ] Replace `pandoc.utils.stringify(cell.contents)` with `pandoc.write(pandoc.Pandoc(cell.contents), "latex")` in both header and body cell loops
- [ ] Strip trailing newlines from pandoc.write output to avoid breaking tabularx row breaks
- [ ] Run test 7 — render `rich-table.md`, convert to PNG
- [ ] Visual check: bold cell is actually bold, italic is italic, code is monospaced
- [ ] Add test: table with all-empty cells renders without crash
- [ ] Add test: table with plain-text-only cells produces same dimensions as before
- [ ] Run `test/run-tests.sh` — all 12+ tests green
- [ ] Update baselines: `test/run-tests.sh --update-baselines`
