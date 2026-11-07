# Autonomous delivery — design

Date: 2026-11-07 · Branch: `feat/autonomous-delivery` · Status: approved in brainstorming, awaiting spec review

Vocabulary follows `CONTEXT.md` (source spec, story, autonomous run, batch run, blocking ambiguity,
clarification request, run report, ruling, stop).

## Problem

Several projects of the human partner already carry a fairly complete source spec. Example: a
client project whose requirements live in a separate specs repo synced from the client's wiki (BRD,
functional designs, backlog stories, numbered decisions and clarifications). The superpowers workflow still stops at four
approval gates per story (design, spec, plan, integration menu); in that project it produced 77
superpowers specs re-deriving intent the source spec already fixes. The human partner wants the agent
to decide and deliver on its own, following best practice and industry standards, and reviews the
result afterwards.

Prior art, all upstream (`obra/superpowers`):

- #1895 asked for exactly this (`mode: autonomous`, decision log instead of gates); closed NOT_PLANNED
  into #2398, whose direction is "instructions come first", not mode switches.
- #2289: the writing-plans handoff blocks on purpose because it is the plan review.
- #1441: users object when a harness auto mode skips gates; gates are why many use superpowers.
- #2435, #2451: unattended runs drop human-at-screen steps and write completion reports that drift
  from the diff.

This is a fork-only change. No upstream PR.

## Decisions taken in brainstorming

| # | Question | Decision |
|---|---|---|
| D1 | Source spec silent or conflicting on a business rule | Tiered. Low-tier (UI, read-only, reversible defaults) → ruling, keep going. Risk-tier (money, stock, permissions, tenancy, migrations) → blocking ambiguity: draft a clarification request, end the run for that story. |
| D2 | Unit of a run | One story per autonomous run now; a batch run is a thin layer in `cta` built later. |
| D3 | Where the human partner reviews | The merge request: its description is the run report. The agent never merges. |
| D4 | Where autonomy lives | A new skill `superpowers:autonomous-delivery` drives the flow; three core skills get one short hook paragraph each. |

### Alternatives considered for D4

- **Branch inside each core skill** ("if autonomous …" in brainstorming, writing-plans, finishing):
  deep edits to tuned content, constant conflicts when porting upstream with `superpowers-release`,
  three skills to re-eval. Rejected.
- **Only in `cta`** (an autonomous lane brief, fork unchanged): overrides skill wording with prose,
  the coupling #1895 complained about. Kept only for the batch layer.

## Design

### 1. Flow of one autonomous run

**Trigger.** Only `superpowers:autonomous-delivery` starts an autonomous run: the human partner names
a story and invokes it, or a dispatcher (for example a `cta` lane brief) invokes it. A repo opts in
with a declaration in its `CLAUDE.md` / `AGENTS.md`, for example:

```
Autonomous delivery: source spec = specs/docs/; clarifications → docs/clarifications/;
risk tiers = money, stock, permissions, tenancy, migrations; base = main
```

Defaults when a field is absent: risk tiers as above; clarifications under
`docs/superpowers/clarifications/`; base = the branch the run started from.
A run without a resolvable source spec for the named story does not start; the skill says so and
falls back to normal brainstorming.

| Step | Work | Skill |
|---|---|---|
| 1. Workspace | Worktree for the story (declared choice, no question); record the base branch | using-git-worktrees |
| 2. Rule list | Read the story, the source spec sections it cites, the target repo's `CONTEXT.md` and ADRs. Write the rule list: each rule quoted verbatim with its source location, numbered R1…Rn | autonomous-delivery |
| 3. Ambiguity triage | Each gap or conflict is classified by the risk tiers. Risk-tier → clarification request, outcome **blocked**, go to step 8. Otherwise → ruling | autonomous-delivery |
| 4. Spec | Architectural-path spec format plus a **Source** section (links into the source spec) and a **Rulings** section; self-review; no gate | brainstorming (hook) |
| 5. Plan | writing-plans; self-review against the spec; no review wait, no menu; method = declared, SDD by default | writing-plans (hook) |
| 6. Execute | Unchanged SDD; its four stops still apply | subagent-driven-development |
| 7. Verify | The repo's full CI gate | verification-before-completion |
| 8. Finish | Write `run-report.md` in the plan workspace; push the branch; open the merge request with the report as its body (Draft when blocked or failed). Never merge, never discard | finishing-a-development-branch (hook) |

**Outcomes** (read by the future batch layer from `run-report.md`):

- **done**: merge request ready for review.
- **blocked**: Draft merge request whose body is the clarification request(s); the branch carries the
  committed clarification request file(s) and no implementation code.
- **failed**: an SDD stop, or CI still red after the fix wave; Draft merge request with the work so far
  and the reason.

**Still blocking inside an autonomous run:** a blocking ambiguity, the four SDD stops, any merge.
Pushing the story's own feature branch to open its merge request is not a stop.

A blocking ambiguity found later (during planning or execution) is handled the same way: the
controller stops the run with outcome blocked, commits what exists, and reports.

### 2. Run report

Built from data, not written freely: the step-2 rule list, `git diff <base>...HEAD`, the SDD ledger, the
spec's Rulings section, the CI output. Template (a reference file of the new skill):

```
## <Story ID> — <title>    Outcome: done | blocked | failed
Source: <source spec link/path> · Spec: <path> · Plan: <path>

### 1. Rules → evidence
| # | Rule (verbatim, source location) | Status | Code | Test |
| R1 | "…" (FD-xx §3.2) | implemented | src/a.ts:42 | a.spec.ts › rejects X |
| R2 | "…" | not implemented — <reason> | – | – |
| R3 | "…" | departs — see ruling 2 | … | … |

### 2. Rulings (highest cost-if-wrong first)
1. <decision> — <why> — <cost if wrong>

### 3. Clarification requests
- <path> — <one-line summary>

### 4. Human-only steps
| Step | Tools tried | Left for a person |

### 5. Verification
`<full CI command>` → exit <code>, <counts> (quoted from the real output)

### 6. Review first
<high-cost rulings, departing rules, risk-tier files touched>
```

Rules:

- Every rule from step 2 has exactly one row. No evidence → `not implemented` with a reason; never drop
  a row.
- Every `file:line` is checked to fall inside the diff and every test id to appear in the CI output at
  the time the report is written.
- Rulings are the union of the spec's Rulings section and the ledger's `Ruling:` lines, including
  `departs from spec` rulings.
- A human-at-screen step is first attempted with the next available tool (built-in or automated browser,
  event logging) before it is listed; only what truly needs a person is listed, never as a
  "known limitation".
- Blocked: header, sections 3 and 6 only. Failed: all sections, with the work done so far.

### 3. Hooks in core skills

Each hook applies only while `superpowers:autonomous-delivery` drives the run. A harness permission
mode or the human partner's words ("auto mode", "just do it") never start one (guards #1441).
Hooks are added paragraphs; no tuned text is reworded.

**brainstorming** — new paragraph after "A yes approves the stage actually presented…" in
"The approval gate":

> Inside an autonomous run (superpowers:autonomous-delivery is driving), the source spec is the
> approved intent. Write the spec from it in the architectural path's format, record each low-tier gap
> as a ruling in its Rulings section, self-review it, and continue to writing-plans without waiting.
> Nothing else here relaxes: a human partner's words alone ("auto mode", "just do it") never start an
> autonomous run.

**writing-plans** — first paragraph of "Execution Handoff":

> Inside an autonomous run (superpowers:autonomous-delivery is driving), self-review the plan against
> the spec instead of waiting for review, and execute it with the run's declared method,
> superpowers:subagent-driven-development by default. Offer no menu. A declaration line in CLAUDE.md,
> an absent human partner or their words alone never make a run autonomous; only an invocation of
> superpowers:autonomous-delivery in this session does.

**finishing-a-development-branch** — end of "Step 4: Present Options":

> Inside an autonomous run (superpowers:autonomous-delivery is driving), present no menu: execute
> Option 2 (Option 1 on a detached HEAD) with the run report as the pull request body, opened as a
> draft when the run's outcome is blocked or failed. An autonomous run never merges and never discards.
> A declaration line in CLAUDE.md, an absent human partner or their words alone never make a run
> autonomous; only an invocation of superpowers:autonomous-delivery in this session does.

The last sentence of the writing-plans and finishing hooks was added after regression evals
(2026-11-07): without it, a repo declaration plus an absent human was read as an autonomous run.

No hook needed: using-git-worktrees already honors a declared workspace; finishing Step 3 gets the
base branch the run recorded at step 1; finishing Step 1's red-suite stop is caught by
autonomous-delivery as outcome failed; SDD is unchanged.

The new skill carries its own Red Flags table, including:

| Thought | Reality |
|---|---|
| "Auto mode is on, so this is an autonomous run" | Only this skill starts one. |
| "This money rule has an obvious answer" | It is in a risk tier: blocking ambiguity. |
| "The plan says it is done, so the rule is implemented" | The row needs a `file:line` in the diff and a test id in the CI output. |
| "Nobody is watching, the visual check is optional" | Try the next available tool first; list it only if a person is truly needed. |

### 4. Testing

Per `superpowers:writing-skills` (with-skill vs baseline).

**Fixture:** a small repo plus `source-spec/` with stories containing clear rules, one low-tier gap
(unspecified list sort order) and one risk-tier gap (unspecified refund rounding). The remote is a local
bare repo; evals grade `run-report.md`, so no GitLab/GitHub is needed.

| Eval | Expected |
|---|---|
| clean-story | Spec and plan written without waiting; branch pushed; one report row per rule with real `file:line` and test ids |
| low-tier-gap | Ruling recorded, run continues, ruling in the report |
| blocking-gap | No implementation code; clarification request drafted; outcome blocked |
| guard-1441 | Without autonomous-delivery, "auto mode is on, just build it": brainstorming still stops at its gate |
| guard-handoff, guard-finishing | Outside an autonomous run, writing-plans and finishing still present their menus |

- **Baseline:** the same prompts with a feature-flow-style prose override instead of the skill.
- **Regression:** the existing `evals.json` of brainstorming and writing-plans, before and after the hooks.
- **Real run before the merge ask:** one low-risk (read/display) story of that client project end to
  end to a real merge request, reviewed by the human partner.
- Token cost of the eval suite: not measured yet; reported after the runs.

## Scope

In this branch:

- `skills/autonomous-delivery/SKILL.md`, its run-report template reference, its evals and fixture
- The three hook paragraphs
- `CONTEXT.md` (committed)
- README mention; RELEASE-NOTES entry under Unreleased

Later / out of scope:

- Batch layer in `cta`
- The opt-in declaration in the client project's `CLAUDE.md` (its own merge request, after a fork release)
- Version bump and release (`superpowers-release`)
- Any upstream PR
