# Page Type Templates

Markdown structures for each page type. AI fills the `«bracketed»` parts. Everything else prints as-is — section headers become writing prompts, empty space becomes dot-grid workspace.

Use `---` (horizontal rule) between zones to create visual dot separators.

Use ` ```d2 ` fenced code blocks for diagrams — they render as hand-drawn sketches automatically. Prefer a diagram over text whenever the concept involves relationships, flows, comparisons, or structure.

## LEARN

```markdown
# «Concept Name»

«Brief definition — one or two lines max»

```d2
«Diagram showing the concept — relationships, structure, or before/after»
```

---

## In my own words...

## Connects to...

## Still unclear...
```

## DECIDE

```markdown
# «Decision Title»

| «Criteria» | «Option A» | «Option B» | «Option C» |
|-------------|------------|------------|------------|
| «criteria 1» | | | |
| «criteria 2» | | | |
| «criteria 3» | | | |
| «criteria 4» | | | |

---

## Winner:

## Why:
```

## TRADEOFF

```markdown
# «What's being weighed»

```d2
«Side A» <-> «Side B»: {style.stroke-dash: 3}
«Dimension 1 label»
«Dimension 2 label»
«Dimension 3 label»
```

---

## I land here:

## Because:
```

## EXPLORE

```markdown
# «Topic to explore»

## «Option 1» — «one-liner»

- Good:
- Bad:
- Gut:

## «Option 2» — «one-liner»

- Good:
- Bad:
- Gut:

## «Option 3» — «one-liner»

- Good:
- Bad:
- Gut:

---

## Leaning toward:
```

## DEBUG

```markdown
# «What broke / symptom»

«What happened — one or two lines»

## Hypotheses

- [ ] «hypothesis 1»
- [ ] «hypothesis 2»
- [ ] «hypothesis 3»
- [ ] «hypothesis 4»

---

## Root cause:

## Fix:

## Prevent next time:
```

## ENHANCE

```markdown
# «What to improve»

## Now
«Current state — 2-3 lines»

## Goal
«Desired state — 2-3 lines»

---

## Gap:

## Steps
1.
2.
3.
4.

## Risks:
```
