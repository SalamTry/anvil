---
name: anvil
description: "Anvil conversation knowledge into a printed study page. Use when a concept, decision, or tradeoff crystallizes that the user would study better on paper — or when the user asks to print, forge, or anvil something."
---

Forge sparse **seeds** on a dot grid — the user does the real work with a pen.

## Steps

### 1. Identify the seed and pick the page type

Scan the conversation for what belongs on paper. Match it to a page type:

| Type | When to use | Seeds (AI) | Open space (user) |
|------|-------------|------------|--------------------|
| LEARN | A concept to internalize | Definition, 2-3 key facts | Own words, connections, questions |
| DECIDE | Choosing between options | Option names, criteria labels | Scores, winner, reasoning |
| TRADEOFF | Weighing two sides | What's compared, key dimensions | Where they land on each scale |
| EXPLORE | Open-ended options | Option names, 1-liner each | Pros, cons, gut feeling |
| DEBUG | Something broke | Symptom, initial hypotheses | Root cause, fix, prevention |
| ENHANCE | Improving something | Current state, desired state | Steps, risks, effort |

If the user passed a file path or topic as an argument, use that as the source.

**Done when:** the page type is named and a one-sentence summary would make sense to someone outside this conversation.

### 2. Write the markdown

Follow the template in [PAGE-TYPES.md](PAGE-TYPES.md) for the chosen type. AI fills the seeds — the minimum the user needs to start thinking.

**Density:** ~20% page fill. One line per idea — each earns its ink by provoking a handwritten response.

**Visual blocks** — use when content has natural structure, at most one or two per page:

| Block | Syntax | Use when | Format |
|-------|--------|----------|--------|
| `flow` | ` ```flow ` | Processes, sequences, pipelines | Each line → numbered step with connectors |
| `table` | ` ```table ` | Comparisons, feature matrices | Pipe-delimited rows; first row is header |
| `d2` | ` ```d2 ` | Relationships, architecture | [D2 syntax](https://d2lang.com/); renders as hand-drawn sketch |
| Plain | `##`, `-`, `>` | Everything else | Default — most of the page should be this |

Standard Markdown tables (`| Col |` with `|---|`) render with the same enhanced styling as ` ```table ` blocks.

**Done when:** the markdown has AI-filled seeds AND open zones where the user knows to write.

### 3. Preview and approve

Render without printing — always preview first:
```
anvil --no-print --preview --paper=<size> [--theme=<name>] <file.md>
```

Ask the user with AskUserQuestion:
- **Print** → send via `lp -o media=<paper-media> <path-to-pdf>`
- **Edit** → take feedback, rewrite, re-preview (loop)
- **Cancel** → done

**Done when:** the user has printed or cancelled.
