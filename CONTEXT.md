# Superpowers

A zero-dependency library of skills that shapes how a coding agent designs, plans, builds and ships
work with a human. This glossary fixes the words the skills, specs and plans use for that workflow.

## People and roles

**Human partner**:
The person the agent works for; owns intent, approvals and integration decisions.
_Avoid_: user, operator, customer

**Controller**:
The agent session that runs a plan, dispatches subagents and makes rulings.
_Avoid_: orchestrator, main agent

**Implementer**:
A subagent dispatched to build one task of a plan.
_Avoid_: worker, coder

**Reviewer**:
A subagent that judges a task or a whole branch against the spec and the plan; never the implementer of that work.
_Avoid_: checker, verifier

## Skills and harnesses

**Skill**:
A `SKILL.md` instruction set the agent loads to follow a tested workflow; behavior-shaping content, not documentation.
_Avoid_: prompt, rule file, command

**Harness**:
The agent runtime that loads skills and runs tools (Claude Code, Codex, Cursor, OpenCode, Gemini CLI).
_Avoid_: IDE, client, platform

**Bootstrap**:
The `using-superpowers` content injected at session start that makes skills trigger on their own.
_Avoid_: preamble, system prompt

## Design and planning

**Path**:
The weight of process a request gets in brainstorming: spike, bounded or architectural.
_Avoid_: mode, track, tier

**Approval gate**:
A point where the agent presents an artifact and waits for the human partner's explicit yes before the next stage.
_Avoid_: checkpoint, sign-off

**Spec**:
The approved design for one feature, written under `docs/superpowers/specs/`; the binding authority while a plan runs.
_Avoid_: design doc, requirements, PRD

**Plan**:
A task-by-task implementation document derived from a spec, written under `docs/superpowers/plans/`.
_Avoid_: todo list, roadmap

**Workspace**:
Where a feature's commits land: a worktree, a new branch in the current checkout, or the current branch.
_Avoid_: sandbox, environment

**Plan workspace**:
The per-plan directory under `.superpowers/sdd/` holding the ledger, task briefs, reports and review packages.
_Avoid_: SDD dir, scratch dir (and never just "workspace", which is the feature's branch or worktree)

## Execution

**Ledger**:
The plan workspace's `progress.md`: the controller's durable record of completed tasks, commits and rulings.
_Avoid_: log, progress notes

**Ruling**:
A decision the controller makes instead of asking, recorded with its reason and its cost if wrong in the ledger or, in an autonomous run, the spec's Rulings section.
_Avoid_: assumption, judgment call, decision log entry

**Stop**:
One of the four conditions that halt a running plan for the human partner: an irreversible operation, a security-sensitive action, an outside side effect norms say to ask about, or a plan broken beyond any non-guess path.
_Avoid_: blocker, pause, escalation

## Autonomous delivery

**Source spec**:
Requirements that come from outside this workflow (for example an external requirements site synced into a specs repo) and stand as already-approved intent.
_Avoid_: upstream spec, external doc, customer spec

**Story**:
One deliverable unit named in a source spec (a backlog story, a ticket, a functional-design section); one autonomous run delivers one story.
_Avoid_: task (a task is one step of a plan), feature, issue

**Autonomous run**:
One story taken from its source spec to an open pull request with no approval gate in between; the human partner reviews afterwards.
_Avoid_: auto mode, YOLO mode, unattended mode

**Batch run**:
Several autonomous runs dispatched together, one per story, summarised as a list of pull requests and their outcomes.
_Avoid_: sprint run, bulk mode

**Blocking ambiguity**:
A gap or conflict in the source spec about a business rule in a declared risk tier (by default money, stock, permissions, tenancy, migrations); it ends the autonomous run for that story instead of becoming a ruling.
_Avoid_: open question, spec bug

**Clarification request**:
A drafted question to the source spec's owner that records a blocking ambiguity and the options seen.
_Avoid_: Q, ticket, query

**Run report**:
The pull request (merge request on GitLab) body of an autonomous run: spec rules mapped to diff and tests, rulings, clarification requests, and human-only steps not done.
_Avoid_: summary, completion report, status update
