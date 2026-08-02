# 07 — Switch engine to LuaLaTeX

**What to build:** Change the PDF engine from XeLaTeX to LuaLaTeX so that the pipeline can use LuaTeX callbacks for automatic grid alignment. Everything else stays the same — same template, same fonts, same pandoc filter, same visual output. This is a safe, zero-feature-change engine swap that proves compatibility before adding grid-snap.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] Change `--pdf-engine=xelatex` to `--pdf-engine=lualatex` in the deepprint shell script
- [x] Verify `lualatex` is available on the system (TeX Live includes it alongside `xelatex`)
- [x] Run all 15 existing tests — all must pass with no dimension changes
- [x] Render the CRM concepts fixture and visually confirm output is identical to XeLaTeX output
- [x] Update test baselines if PNG dimensions shift due to engine differences (acceptable only if visual output is equivalent)
