# 01 — Wait for print job completion

**What to build:** After anvil sends a print job via `lp`, it captures the job ID from `lp` output, polls `lpstat` until the job disappears from the queue (meaning it completed), then prints a `✓ Printed on <printer>` confirmation line before exiting. If printing is skipped (`--no-print`), behaviour is unchanged. Include a reasonable timeout (e.g. 120s) so anvil doesn't hang forever on a stalled job — if the timeout is hit, warn and exit non-zero.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `lp` output is captured and the job ID (e.g. `HP_Smart_Tank_581-3`) is parsed
- [ ] anvil polls `lpstat` in a loop until the job ID is no longer listed
- [ ] On completion, anvil prints `✓ Printed on <printer>` to stdout
- [ ] A timeout (≥60s) prevents infinite hang; on timeout prints a warning and exits with a non-zero code
- [ ] `--no-print` skips the wait entirely (no behaviour change)
- [ ] Poll interval is reasonable (1–2s) and doesn't spam the system
