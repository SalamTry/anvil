# 02 — macOS notification on print complete

**What to build:** After confirming the print job completed, anvil fires a native macOS notification showing the entry number and printer name (e.g. "anvil #006 printed on HP_Smart_Tank_581"). On Linux, fall back to `notify-send` if available; otherwise skip silently. The notification is suppressed when `--no-print` is active.

**Blocked by:** 01 — Wait for print job completion

**Status:** ready-for-agent

- [ ] On macOS, a notification fires via `osascript` with entry number and printer name
- [ ] On Linux, `notify-send` is used if available; if not, no error is raised
- [ ] Notification is skipped when `--no-print` is set
- [ ] Notification is skipped on timeout (only fires on successful completion)
