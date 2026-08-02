# 02 — Fix title extraction

**What to build:** Replace the two-pass title extraction (grep finds H1 anywhere, awk strips line 1 only) with a single awk pass that finds the first H1 at any position, extracts the title, and emits the remaining body. No more duplicate titles.

**Blocked by:** None — can start immediately.

**Status:** done

**Approach:** /tdd — existing test fixtures cover the edge cases (tests 4-6 in `test/run-tests.sh`). Add visual checks for title duplication, then fix extraction to pass them.

- [ ] Add test: render `blank-before-h1.md`, convert to PNG, verify title appears only once (currently FAILS — title is duplicated because awk only strips line 1)
- [ ] Add test: render `multi-h1.md`, verify first H1 is in header, second H1 remains in body
- [ ] Add test: render `no-h1.md`, verify filename appears as title, no crash
- [ ] Replace grep + awk two-pass with single awk: `awk '/^# / && !found {title=substr($0,3); found=1; next} {print}'`
- [ ] Capture title from awk (e.g. write to temp file or use process substitution)
- [ ] Run `test/run-tests.sh` — all tests green, including the new visual title checks
- [ ] Update baselines: `test/run-tests.sh --update-baselines`
