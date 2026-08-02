# 03 — Config-driven pipeline

**What to build:** Extract shared values (color names, font names, paper geometry presets, platform paths) into a single config section at the top of the deepprint script. The template and lua filter reference only names that exist in this config — no implicit contracts across files. Adding a new color or paper size means editing one place.

**Blocked by:** 01 — Clean template foundation, 02 — Fix title extraction.

**Status:** done

**Approach:** /tdd — test 8 (color contract) already validates cross-file coupling. Add contract tests for variables, then refactor while keeping all tests green.

- [ ] Add test: every `-V` variable passed by deepprint is referenced in sketch-page.tex (no orphan variables)
- [ ] Add test: every `$variable$` in sketch-page.tex is passed via `-V` by deepprint (no undefined variables)
- [ ] Extract color definitions into config block (associative array) at top of deepprint
- [ ] Pass colors to template via `-V` variables; template reads from variables instead of hardcoding
- [ ] Pass color names to lua filter via pandoc metadata so the filter never hardcodes a color name
- [ ] Extract platform paths (TeX bin, `open` vs `xdg-open`) into config block with `uname` detection
- [ ] Run `test/run-tests.sh` — all tests green including new contract checks
- [ ] Add test: add a new color to config only, reference in template via variable — compilation succeeds
- [ ] Update baselines: `test/run-tests.sh --update-baselines`
