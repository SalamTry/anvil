# 04 — Generalize paper sizes

**What to build:** Replace the `--a6` boolean toggle with `--paper=<size>` that maps to a geometry preset (margins, font scale, dot spacing) via the config block. Adding A4 or letter means adding one preset — zero template edits.

**Blocked by:** 03 — Config-driven pipeline.

**Status:** done

**Approach:** /tdd — add a red test for `--paper=a4` first (should fail), then implement the preset map to make it green.

- [ ] Add test (red): `deepprint --paper=a4 basic.md` — should render a valid PDF (currently fails)
- [ ] Add test (red): `deepprint --paper=letter basic.md` — should render (currently fails)
- [ ] Add test: `deepprint --paper=nonsense` exits with error listing valid sizes
- [ ] Replace `--a6` boolean with `--paper=<size>` in argument parsing
- [ ] Build paper preset map in config: `a5=(148mm 210mm 12mm ...) a6=(...) a4=(...) letter=(...)`
- [ ] Template reads geometry from `-V paperwidth`, `-V margin`, etc. — no `$if(a6)$`
- [ ] CUPS `lp -o media=` reads from the same preset
- [ ] Keep `--a6` as alias for `--paper=a6`
- [ ] Run `test/run-tests.sh` — all existing tests green + new A4/letter tests green
- [ ] Visual test: render basic.md on A5, A6, A4 — snapshot all three, verify proportions
- [ ] Update baselines: `test/run-tests.sh --update-baselines`
