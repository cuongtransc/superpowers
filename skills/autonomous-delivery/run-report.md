# Run report template

The run report is the pull request body of an autonomous run, and the file the batch layer reads. It lives at `.superpowers/autonomous/<story-id>/run-report.md` at the repo root of the run's workspace.

## Template

The header line is exact: an em dash after the story id, four spaces before `Outcome:`. The outcome is one of `done`, `blocked`, `failed`.

```
## <story-id> — <title>    Outcome: <done|blocked|failed>
Source: <source spec link/path> · Spec: <path> · Plan: <path>

### 1. Rules → evidence
| # | Rule (verbatim, source location) | Status | Code | Test |
|---|---|---|---|---|
| R1 | "…" (FD-xx §3.2) | implemented | src/a.ts:42, src/a.ts:57 | a.spec.ts › rejects X |
| R2 | "…" (FD-xx §3.3) | not implemented — <reason> | – | – |
| R3 | "…" (FD-xx §4.1) | departs — see ruling 2 | src/b.ts:9 | b.spec.ts › handles Y |

### 2. Rulings (highest cost-if-wrong first)
1. <decision> — <why> — <cost if wrong>

### 3. Clarification requests
- <path> — <one-line summary>

### 4. Human-only steps
| Step | Tools tried | Left for a person |
|---|---|---|

### 5. Verification
`<full CI command>` → exit <code>, <counts> (quoted from the real output)

### 6. Review first
<high-cost rulings, departing rules, risk-tier files touched>
```

## Rules

- **One row per rule.** Every rule from the step-2 rule list has exactly one row, ids `R1`…`Rn` in rule-list order, each row starting `| R<n> |`. No evidence means `not implemented — <reason>`; never drop a row.
- **Code cell.** Bare `path:line` entries, comma-separated, no backticks, no ranges (`a.py:3-9` is wrong; write each line you cite). `–` when there is none. Every entry must be a line added in `git diff <base>...HEAD`, where `<base>` is the base branch recorded at step 1. Check each entry against the diff when you write the report.
- **Test cell.** Every test id appears in the output of this run's test suite (re-run it verbosely if the CI gate prints no ids). Check it when you write the report.
- **Rulings** are the union of the spec's Rulings section and the ledger's `Ruling:` lines, including `departs from spec` rulings, ordered by cost if wrong.
- **Human-at-screen steps** are first attempted with the next available tool (built-in or automated browser, event logging). List only what truly needs a person, never as a "known limitation".
- **Build the report from data**, not memory: the rule list, `git diff <base>...HEAD`, the ledger, the spec's Rulings section, the CI output.

## Sections by outcome

| Outcome | Sections |
|---|---|
| done | header, source line, 1 to 6 |
| failed | header, source line, 1 to 6, with the work done so far; section 6 names the stop or the red CI |
| blocked | header, source line, 3 and 6 only (no section 1; no implementation exists) |
