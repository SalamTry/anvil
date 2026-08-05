# 02 — Swap template from TikZ to PNG background

**What to build:** anvil calls the grid PNG generator with the current paper size and scheme colors before rendering, then the LaTeX template uses the resulting PNG as a full-page background image instead of the TikZ dot grid. The old TikZ block is removed. End-to-end: `echo "# test" | anvil` produces a PDF that prints in seconds instead of minutes on the HP Tank 581.

**Blocked by:** 01 — Grid PNG generator script

**Status:** ready-for-agent

- [ ] anvil invokes the generator with the active paper size and scheme grid colors
- [ ] The LaTeX template uses the PNG as a background image instead of TikZ circles
- [ ] The TikZ dot grid code is removed from the template
- [ ] PDF output is valid and visually matches the old grid appearance
- [ ] A single-page A5 text note prints in under 30 seconds on the HP Tank 581
- [ ] All paper sizes (A5, A6, A4, letter) and schemes still work
