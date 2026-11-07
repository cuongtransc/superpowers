---
name: autonomous-delivery
description: Delivers one story from an external source spec to an open pull request with no approval gate, and writes a run report built from the diff for the human partner to review afterwards. Use when the human partner or a dispatcher asks to deliver a named story autonomously from a repo that declares "Autonomous delivery:" in its CLAUDE.md or AGENTS.md, or with that declaration in the invoking prompt or a dispatcher's brief. Not for ideas without a source spec, and never started by a harness auto mode or "just do it" alone.
---

# Autonomous Delivery

One story, from a source spec the human partner already approved to an open pull request. No approval gate in between; the human partner reviews the run report afterwards.

**Announce at start:** "I'm using the autonomous-delivery skill to deliver <story-id>."

## When a run starts

Only this skill starts an autonomous run, when your human partner (or a dispatcher such as a lane brief) names a story and invokes it. A harness permission mode, "auto mode" or "just do it" never does: go through brainstorming normally.

The repo opts in with a line in `CLAUDE.md` / `AGENTS.md`:

```
Autonomous delivery: source spec = specs/docs/; clarifications → docs/clarifications/;
risk tiers = money, stock, permissions, tenancy, migrations; base = main
```

The same declaration given in the invoking prompt or a dispatcher's brief counts the same as one in `CLAUDE.md` / `AGENTS.md`. It only supplies the settings; the run still starts only by invoking this skill.

Defaults for an absent field: risk tiers as above; clarifications under `docs/superpowers/clarifications/`; base = the branch the run started from.

If the story id is not in the source spec, or there is no resolvable source spec, no run starts. Change nothing, say the story is not in the source spec, and offer normal brainstorming.

## The flow

| Step | Work | Skill |
|---|---|---|
| 1. Workspace | Worktree for the story, declared not asked; record the base branch | using-git-worktrees |
| 2. Rule list | Read the story, the source spec sections it cites, the repo's `CONTEXT.md` and ADRs. Write rules R1…Rn, each quoted verbatim with its source location | this skill |
| 3. Triage | Classify each gap or conflict (below) | this skill |
| 4. Spec | Architectural-path format plus a **Source** section (links into the source spec, and the step-2 rule list written into it so the report can be built from it) and a **Rulings** section; self-review; no gate | brainstorming (hook: "superpowers:autonomous-delivery is driving") |
| 5. Plan | See below | writing-plans |
| 6. Execute | Unchanged; its four stops still apply | subagent-driven-development |
| 7. Verify | The repo's full CI gate, run for real | verification-before-completion |
| 8. Finish | Write the run report, push the branch, open the pull request with the report as its body. Never merge, never discard | done: finishing-a-development-branch (hook: "superpowers:autonomous-delivery is driving"); blocked or failed: this skill |

**Step 5.** Invoke writing-plans. When it asks your human partner to review the plan and choose an execution method, this run answers that ask itself: self-review the plan against the spec, then execute with the declared method (superpowers:subagent-driven-development by default; superpowers:executing-plans when subagents are unavailable) and continue without waiting. This waiver exists only inside an autonomous run this skill started; writing-plans itself never changes.

## Triage

Risk tiers: the declared ones, default money, stock, permissions, tenancy, migrations.

- **Risk-tier gap or conflict** (a blocking ambiguity): write a clarification request at `<clarifications dir>/<YYYY-MM-DD>-<story-id>-<slug>.md` with the gap, the quoted source lines, and at least two options with their consequences. Commit it on the story branch, set the outcome to blocked, go to step 8. One risk-tier gap blocks the whole story, even when the other gaps are low-tier. No implementation code is written.
- **Any other gap:** record `Ruling: <decision> — <why> — <cost if wrong>` in the spec's Rulings section and keep going.

A risk-tier gap that surfaces during planning or execution is handled the same way: stop, commit what exists, outcome blocked, step 8.

## Outcomes

The run report's header carries exactly one:

- **Outcome: done** - pull request ready for review.
- **Outcome: blocked** - Draft pull request whose body is the clarification request(s); the branch holds the committed clarification file(s) and no implementation code.
- **Outcome: failed** - an SDD stop, or CI still red after the fix wave; Draft pull request with the work so far and the reason.

Only outcome done reaches finishing-a-development-branch. On blocked or failed, never invoke finishing-a-development-branch: this skill writes the run report, pushes the story branch and opens the Draft pull request itself (with no forge, it says so, as below).

## Run report

Path: `.superpowers/autonomous/<story-id>/run-report.md` at the repo root of the run's workspace (the plan workspace may not exist yet when a run blocks at triage). Before writing it, create `.superpowers/autonomous/.gitignore` containing `*` if it is absent, so the report never lands in a commit. Build it with `run-report.md` in this skill's directory, from data: the rule list, `git diff <base>...HEAD`, the ledger, the spec's Rulings section, the CI output. Code cells are bare `path:line` entries, comma-separated, each an added line in the diff; `–` when none. Use the report as the pull request body.

When no pull request can be opened (no forge or no credentials), push the story branch anyway, keep `run-report.md`, and say in the final message that no pull request is open and why. The final message always names the run report's path, whether or not a pull request is open. Pushing the story branch is not a stop.

## What still stops a run

A blocking ambiguity, the four SDD stops, any merge. Nothing else.

## Red Flags

| Thought | Reality |
|---|---|
| "Auto mode is on, so this is an autonomous run" | Only this skill starts one. |
| "This money rule has an obvious answer" | It is in a risk tier: blocking ambiguity. |
| "The plan says it is done, so the rule is implemented" | The row needs a `file:line` in the diff, and every test id appears in the output of this run's test suite (re-run it verbosely if the CI gate prints no ids). |
| "Nobody is watching, the visual check is optional" | Try the next available tool first; list it only if a person is truly needed. |
| "I'll write the report from the plan" | Rows come from the rule list, cells from the diff and the CI output. |
