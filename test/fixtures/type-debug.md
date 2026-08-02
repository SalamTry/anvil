# Table Baselines Off Grid

Text in table rows lands between dot rows, not on them.
Body text aligns fine but tables drift.

## Hypotheses

- [ ] arraystretch creates non-5mm row heights
- [ ] \small uses 4.23mm baselineskip, not 5mm
- [ ] tabular internal struts override baselineskip
- [ ] table vbox hides rows from grid-snap callback

---

## Root cause:

## Fix:

## Prevent next time:
