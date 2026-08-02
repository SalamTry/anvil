# 10 — Remove manual table struts

**What to build:** With grid-snap handling baseline alignment at the engine level, the manual alignment hacks in the pandoc table filter are no longer needed. Remove the explicit `\rule[-\gridunit]{0pt}{2\gridunit}` struts and forced `\fontsize{10pt}{\gridunit}\selectfont` from table cells in the Lua filter. Table cells go back to simple `{\bfseries\small content}` for headers and `{\small content}` for body rows. The grid-snap callback ensures table row baselines still land on 5mm dot rows. This simplifies the filter so future table features (multi-line cells, colored rows) don't need to carry strut logic.

**Blocked by:** 08 — Grid-snap Lua callback.

**Status:** done

- [x] Remove `\rule` strut from header cell construction in the pandoc Lua filter
- [x] Remove `\rule` strut from body cell construction in the pandoc Lua filter
- [x] Remove forced `\fontsize{10pt}{\gridunit}\selectfont` from cell construction — use `\small` instead
- [x] Table row baselines still land on 5mm dot rows (verified by baseline extraction test)
- [x] Rich table cells (bold, italic, code) still render correctly
- [x] Empty table cells still render without crash
- [x] All existing tests still pass
