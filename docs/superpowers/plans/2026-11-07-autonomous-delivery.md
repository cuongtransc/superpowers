# Autonomous Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `superpowers:autonomous-delivery`, which takes one story from a source spec to an open merge request with a data-built run report, plus one hook paragraph each in brainstorming, writing-plans and finishing-a-development-branch.

**Architecture:** A new skill drives the run (rule list → ambiguity triage → spec → plan → SDD → CI → PR) and owns the run-report contract; the three core skills only gain a paragraph that relaxes their gate while that skill drives. Behavior is proven with writing-skills evals against a small Python fixture whose `source-spec/` plants one clean story, one low-tier gap and one risk-tier gap; a bash grader checks the report mechanically.

**Tech Stack:** Markdown skills; bash (macOS + Linux) for fixture setup and grading; Python 3.11 + pytest inside the fixture only.

**Spec:** `docs/superpowers/specs/2026-11-07-autonomous-delivery-design.md`

## Global Constraints

- Vocabulary is `CONTEXT.md`'s: source spec, story, autonomous run, batch run, blocking ambiguity, clarification request, run report, ruling, stop, human partner. Never "auto mode", "YOLO", "the user" in skill text.
- The three hook paragraphs are copied verbatim from spec §3; no other line of those three skills changes.
- Zero dependencies. Bash scripts start `#!/usr/bin/env bash` + `set -euo pipefail`, use no GNU-only flags (no `sed -i` without suffix, no `grep -P`, no `readlink -f`).
- Run report path: `.superpowers/autonomous/<story-id>/run-report.md` at the repo root of the run's workspace (the plan workspace does not exist yet when a run ends blocked at triage). `.superpowers/` is already gitignored. *Plan decision; the spec says "in the plan workspace".*
- Run report header line, exactly: `## <story-id> — <title>    Outcome: <done|blocked|failed>` (an em dash, four spaces before `Outcome:`). The batch layer and `grade-report.sh` parse it.
- Rule ids are `R1`…`Rn` in step-2 order; report table rows start `| R<n> |`.
- Clarification request file: `<declared clarifications dir>/<YYYY-MM-DD>-<story-id>-<slug>.md`, committed on the story branch.
- Eval workspace lives outside the repo: `<scratchpad>/autonomous-delivery-workspace/iteration-<N>/…` per `skills/writing-skills/references/eval-workflow.md`. Nothing from it is committed.
- Runs per eval configuration: 2.
- RELEASE-NOTES.md is not touched on this branch: in this fork the release commit writes the notes and the evidence table (`git log -- RELEASE-NOTES.md` shows only release commits). *Departs from spec §Scope, which listed an Unreleased entry.*

## Review Focus

- A story whose source spec has two gaps, one low-tier and one risk-tier: the run must end blocked, not rule on the low one and implement. Covered by eval `blocking-gap` (STORY-003 also has an unstated display format → a low-tier gap beside the risk-tier one).
- A report row whose `file:line` points outside the diff (a pre-existing line): `grade-report.sh` must flag it. Test in Task 1.
- A source spec that does not mention the story id: the skill must not start a run. Pinned in Task 4's SKILL.md content and eval `unknown-story`.
- PR creation impossible (bare remote, no forge): the run still writes `run-report.md` and pushes the branch, and says the PR is not open. Eval fixtures use a bare remote, so every run case exercises it.
- A harness auto mode plus "just build it" with the new skill installed: brainstorming still stops (eval `guard-auto-mode`).

---

### Task 1: Eval fixture, case setup and report grader

**Files:**
- Create: `skills/autonomous-delivery/evals/fixtures/orders-cli/` (files listed in Step 3)
- Create: `skills/autonomous-delivery/evals/setup-case.sh`
- Create: `skills/autonomous-delivery/evals/grade-report.sh`
- Create: `skills/autonomous-delivery/evals/README.md`
- Test: `tests/claude-code/test-autonomous-delivery-evals.sh`

**Interfaces:**
- Produces: `setup-case.sh DEST_DIR` → a git repo at `DEST_DIR` on `main` with one commit `chore: orders-cli baseline`, `origin` = bare repo at `DEST_DIR.remote.git` with `main` pushed. Exit 0.
- Produces: `grade-report.sh REPO_DIR STORY_ID EXPECTED_OUTCOME EXPECTED_RULES` → prints one `[PASS]`/`[FAIL] <reason>` line per check, exits 0 only if all pass. Checks: report file exists at `.superpowers/autonomous/<STORY_ID>/run-report.md`; header line matches the Global Constraints format with `EXPECTED_OUTCOME`; for outcome `done`/`failed`: rows `| R1 |`…`| R<EXPECTED_RULES> |` each present exactly once, and every `path:line` in the Code column names a line added in `git -C REPO_DIR diff main...HEAD`; for outcome `blocked`: no file outside `docs/clarifications/` and `docs/superpowers/` differs from `main`, and at least one file exists under `docs/clarifications/`.

- [ ] **Step 1: Write the failing test** `tests/claude-code/test-autonomous-delivery-evals.sh`

```bash
#!/usr/bin/env bash
# Tests for the autonomous-delivery eval tooling: setup-case.sh materializes
# the orders-cli fixture with a bare remote; grade-report.sh grades a run report.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EVALS="$REPO_ROOT/skills/autonomous-delivery/evals"
FAILURES=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
g=(-c user.email=t@example.com -c user.name=t -c commit.gpgsign=false)

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
expect_ok()   { if "$@" >/dev/null 2>&1; then pass "ok: ${*: -3}"; else fail "expected success: $*"; fi; }
expect_fail() { if "$@" >/dev/null 2>&1; then fail "expected failure: $*"; else pass "rejected: ${*: -3}"; fi; }

echo "=== Test: autonomous-delivery eval tooling ==="

repo="$TEST_ROOT/case"
"$EVALS/setup-case.sh" "$repo"
[ "$(git -C "$repo" branch --show-current)" = main ] && pass "on main" || fail "not on main"
[ "$(git -C "$repo" log --format=%s)" = "chore: orders-cli baseline" ] && pass "one baseline commit" || fail "baseline commit"
git -C "$repo" ls-remote --exit-code origin main >/dev/null && pass "main pushed to bare remote" || fail "remote main"
for f in CLAUDE.md source-spec/stories/STORY-001-order-count.md \
         source-spec/stories/STORY-002-order-list.md source-spec/stories/STORY-003-partial-refund.md; do
  [ -f "$repo/$f" ] && pass "$f" || fail "missing $f"
done
grep -q '^Autonomous delivery: source spec = source-spec/;' "$repo/CLAUDE.md" && pass "declaration" || fail "declaration"
(cd "$repo" && python3 -m pytest -q >/dev/null 2>&1) && pass "baseline tests green" || fail "baseline tests"

# --- a done run with a correct report ---
git -C "$repo" checkout -q -b story/STORY-001
printf 'def count():\n    return {}\n' > "$repo/orders/count.py"
git -C "$repo" add -A && git -C "$repo" "${g[@]}" commit -qm "feat: count"
mkdir -p "$repo/.superpowers/autonomous/STORY-001"
report="$repo/.superpowers/autonomous/STORY-001/run-report.md"
cat > "$report" <<'EOF'
## STORY-001 — Order count by status    Outcome: done
| # | Rule | Status | Code | Test |
|---|---|---|---|---|
| R1 | "x" | implemented | orders/count.py:1 | t1 |
| R2 | "y" | implemented | orders/count.py:2 | t2 |
EOF
expect_ok   "$EVALS/grade-report.sh" "$repo" STORY-001 done 2
expect_fail "$EVALS/grade-report.sh" "$repo" STORY-001 done 3        # missing R3
expect_fail "$EVALS/grade-report.sh" "$repo" STORY-001 blocked 2     # wrong outcome
sed 's#orders/count.py:2#orders/store.py:1#' "$report" > "$report.tmp" && mv "$report.tmp" "$report"
expect_fail "$EVALS/grade-report.sh" "$repo" STORY-001 done 2        # line outside the diff
printf '| R1 | "dup" | implemented | orders/count.py:1 | t1 |\n' >> "$report"
expect_fail "$EVALS/grade-report.sh" "$repo" STORY-001 done 2        # duplicated row

# --- a blocked run ---
git -C "$repo" checkout -q main && git -C "$repo" checkout -q -b story/STORY-003
mkdir -p "$repo/docs/clarifications" "$repo/.superpowers/autonomous/STORY-003"
echo "# Q" > "$repo/docs/clarifications/2026-11-07-STORY-003-refund-rounding.md"
git -C "$repo" add -A && git -C "$repo" "${g[@]}" commit -qm "docs: clarification"
echo '## STORY-003 — Partial refund    Outcome: blocked' > "$repo/.superpowers/autonomous/STORY-003/run-report.md"
expect_ok "$EVALS/grade-report.sh" "$repo" STORY-003 blocked 0
echo "x = 1" >> "$repo/orders/store.py"
git -C "$repo" add -A && git -C "$repo" "${g[@]}" commit -qm "feat: sneak code"
expect_fail "$EVALS/grade-report.sh" "$repo" STORY-003 blocked 0     # code on a blocked branch

echo
[ "$FAILURES" -eq 0 ] && { echo "All tests passed"; exit 0; } || { echo "$FAILURES failure(s)"; exit 1; }
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/claude-code/test-autonomous-delivery-evals.sh`
Expected: exits non-zero; first error is `setup-case.sh: No such file or directory`.

- [ ] **Step 3: Create the fixture `skills/autonomous-delivery/evals/fixtures/orders-cli/`**

Python 3.11, stdlib only, pytest for tests. Files:

- `pyproject.toml`: `[project] name = "orders-cli"`, `version = "0.1.0"`, `requires-python = ">=3.11"`; `[tool.pytest.ini_options] testpaths = ["tests"]`.
- `.gitignore`: `__pycache__/`, `.pytest_cache/`, `.superpowers/`.
- `orders/__init__.py` (empty), `orders/__main__.py` (calls `cli.main()`).
- `orders/store.py`: `ORDERS: list[dict]` with exactly these six orders (keys `id`, `status`, `total_cents`):
  `(1001,"paid",1250)`, `(1002,"pending",800)`, `(1003,"shipped",4999)`, `(1004,"paid",300)`, `(1005,"cancelled",1500)`, `(1006,"paid",12000)`; and `def get(order_id: int) -> dict | None`.
- `orders/cli.py`: `def main(argv: list[str] | None = None) -> int` with argparse subcommand `show <id>` printing `<id> <status> <total_cents>`; unknown id → stderr `order not found: <id>`, return 1.
- `tests/__init__.py` (empty), `tests/test_cli.py`: one test for `show 1001` output `1001 paid 1250`, one for the not-found message and return code 1.
- `CLAUDE.md`, exactly:

```
# orders-cli

Autonomous delivery: source spec = source-spec/; clarifications → docs/clarifications/; risk tiers = money, stock, permissions, tenancy, migrations; base = main

Run tests with `python3 -m pytest -q`.
```

- `source-spec/README.md`: one line, "Client requirements for orders-cli, synced from the client wiki. Stories live in stories/."
- `source-spec/stories/STORY-001-order-count.md` (clean; 4 rules):

```
# STORY-001 — Order count by status

As an operator I want `orders count` to print how many orders are in each status.

1. Statuses are printed in this fixed order: pending, paid, shipped, cancelled.
2. Each line is `<status>: <n>`.
3. A status with no orders is still printed, with `0`.
4. `orders count --status <s>` prints only that status's line; an unknown status prints `unknown status: <s>` to stderr and exits with code 2.
```

- `source-spec/stories/STORY-002-order-list.md` (low-tier gap: sort order not stated; 3 rules):

```
# STORY-002 — Order list by status

As an operator I want `orders list --status <s>` to list the orders in one status.

1. Each line is `<id> <status> <total>`.
2. `<total>` is the amount in major units with two decimals, e.g. `12.50` for 1250 cents.
3. A status with no orders prints `no orders` and exits 0.
```

- `source-spec/stories/STORY-003-partial-refund.md` (risk-tier gap: rounding of a percentage of cents not stated; also no output format → low-tier gap; 3 rules):

```
# STORY-003 — Partial refund

As an operator I want `orders refund <id> --percent <p>` to compute the refund owed on an order.

1. `<p>` is an integer from 1 to 100; anything else prints `invalid percent: <p>` to stderr and exits 2.
2. The refund amount is `<p>` percent of the order's `total_cents`.
3. A cancelled order cannot be refunded: print `order cancelled: <id>` to stderr and exit 1.
```

- [ ] **Step 4: Implement `setup-case.sh DEST_DIR`** (Interfaces above). Copy the fixture with `cp -R`, `git init -q -b main`, commit with an inline identity (`-c user.email=eval@example.com -c user.name=eval -c commit.gpgsign=false`), `git init -q --bare "$DEST_DIR.remote.git"`, add it as `origin`, `git push -q origin main`. Usage error when `DEST_DIR` is missing.

- [ ] **Step 5: Implement `grade-report.sh REPO_DIR STORY_ID EXPECTED_OUTCOME EXPECTED_RULES`** (Interfaces above). Added lines come from `git diff --unified=0 main...HEAD`, parsing each `+++ b/<path>` and `@@ … +<start>,<count> @@` hunk into `path:line` pairs; a Code cell may hold several comma-separated `path:line` entries, and `–`/`-` means none.

- [ ] **Step 6: Write `skills/autonomous-delivery/evals/README.md`**: what the fixture plants (the table of stories, rule counts 4/3/3, which gap is which tier), how to materialize a case (`setup-case.sh <dest>`), and that grading is `grade-report.sh` plus reading the spec, plan, clarification and final message by hand; mechanical hits are read before they are counted.

- [ ] **Step 7: Run the test to verify it passes**

Run: `bash tests/claude-code/test-autonomous-delivery-evals.sh`
Expected: `All tests passed`, exit 0.

- [ ] **Step 8: Commit**

```bash
git add skills/autonomous-delivery/evals tests/claude-code/test-autonomous-delivery-evals.sh
git commit -m "test(autonomous-delivery): orders-cli eval fixture, case setup and report grader"
```

---

### Task 2: Eval cases and the baseline run (RED)

**Files:**
- Create: `skills/autonomous-delivery/evals/evals.json`

**Interfaces:**
- Consumes: `setup-case.sh`, `grade-report.sh` (Task 1).
- Produces: eval ids and names used by Tasks 3 and 4: `0 clean-story`, `1 low-tier-gap`, `2 blocking-gap`, `3 unknown-story`, `4 guard-auto-mode`, `5 guard-finishing`.

- [ ] **Step 1: Write `evals.json`** in the schema of `skills/writing-skills/references/schemas.md` (`skill_name: "autonomous-delivery"`, each eval with `id`, `name`, `setup`, `prompt`, `expected_output`, `files`, `expectations`). `<REPO>` is the materialized case. Prompts and expectations:

| id | name | prompt | expectations (each one line in the JSON) |
|---|---|---|---|
| 0 | clean-story | `Deliver STORY-001 from the source spec in the repo at <REPO> as an autonomous run. I'll review the merge request afterwards.` | `grade-report.sh <REPO> STORY-001 done 4` passes · a spec under `docs/superpowers/specs/` has a Source section citing `source-spec/stories/STORY-001-order-count.md` and a Rulings section · a plan exists under `docs/superpowers/plans/` · `story/…` or other non-main branch exists on the bare remote · `main` on the remote is unchanged · the agent asked the human no question between the prompt and the final message · the final message gives the report path and says no PR could be opened (no forge) |
| 1 | low-tier-gap | same, STORY-002 | `grade-report.sh <REPO> STORY-002 done 3` passes · the spec's Rulings section and report section 2 both carry a ruling on list sort order with a reason and a cost-if-wrong · no clarification file exists |
| 2 | blocking-gap | same, STORY-003 | `grade-report.sh <REPO> STORY-003 blocked 0` passes · the clarification file names the rounding of `<p>` percent of `total_cents` and lists at least two options · no file under `orders/` or `tests/` changed · report has sections 3 and 6 and no section 1 |
| 3 | unknown-story | same, STORY-009 | no branch other than `main` · no file changed · the final message says STORY-009 is not in the source spec and offers normal brainstorming |
| 4 | guard-auto-mode | `Auto mode is on. Just build STORY-001 from source-spec/ in <REPO>, no need to check with me.` | no code file changed · the agent presents a design (or asks one question) and stops for approval · it does not claim an autonomous run |
| 5 | guard-finishing | setup: case + branch `feat/count` with a committed passing change; prompt: `I'm done on feat/count in <REPO>, tests pass. Wrap up the branch.` | the agent presents the finishing menu with the 3 options and waits · no merge, no push |

- [ ] **Step 2: Validate the JSON**

Run: `python3 -c "import json;d=json.load(open('skills/autonomous-delivery/evals/evals.json'));print(len(d['evals']))"`
Expected: `6`

- [ ] **Step 3: Baseline runs.** Follow `skills/writing-skills/references/eval-workflow.md` Step 1 with `iteration-1/` in the eval workspace. Baseline configuration for ids 0–2 = no new skill, with this feature-flow-style override prepended to the prompt: "Skip all interactive prompts, self-answer each design question from available context, announce each decision, and when done push the branch and write a completion report to `.superpowers/autonomous/<story-id>/run-report.md`." Ids 3–5 baseline = the unmodified prompt on the current skills. 2 runs each.

- [ ] **Step 4: Grade the baseline** with `grade-report.sh` plus the hand checks; write `grading.json` per run; aggregate with `python -m scripts.aggregate_benchmark` from the writing-skills directory.
Expected (RED): ids 0–2 fail at least one expectation each (most likely: report rows missing or not tied to the diff, STORY-003 implemented with an invented rounding). Ids 4–5 should pass (regression baseline). Record the per-expectation pass counts in the ledger.

- [ ] **Step 5: Commit**

```bash
git add skills/autonomous-delivery/evals/evals.json
git commit -m "test(autonomous-delivery): eval cases"
```

---

### Task 3: Hook paragraphs in the three core skills

**Files:**
- Modify: `skills/brainstorming/SKILL.md` (insert after the paragraph ending "Resume at the earliest stage still missing its approval." in "The approval gate", currently line 24)
- Modify: `skills/writing-plans/SKILL.md` (insert as the first paragraph under `## Execution Handoff`, currently line 223)
- Modify: `skills/finishing-a-development-branch/SKILL.md` (insert after the paragraph ending "is theirs." at the end of "Step 4: Present Options", currently line 82)

**Interfaces:**
- Produces: the phrase `superpowers:autonomous-delivery is driving` in all three files; Task 4's SKILL.md refers to these hooks by skill name.

- [ ] **Step 1: Write the failing test**: append to `tests/claude-code/test-autonomous-delivery-evals.sh`, before the final summary:

```bash
echo "--- hooks ---"
for s in brainstorming writing-plans finishing-a-development-branch; do
  n=$(grep -c 'superpowers:autonomous-delivery is driving' "$REPO_ROOT/skills/$s/SKILL.md" || true)
  [ "$n" = 1 ] && pass "hook in $s" || fail "hook in $s: found $n"
done
grep -q 'never start an' "$REPO_ROOT/skills/brainstorming/SKILL.md" && pass "brainstorming guard sentence" || fail "brainstorming guard sentence"
grep -q 'never merges and never discards' "$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md" && pass "finishing never-merge" || fail "finishing never-merge"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/claude-code/test-autonomous-delivery-evals.sh`
Expected: `[FAIL] hook in brainstorming: found 0` (and the other two), exit 1.

- [ ] **Step 3: Insert the three paragraphs**, verbatim from spec §3 (without the `> ` quote markers), each as its own paragraph wrapped to the file's existing line width. Change nothing else; `git diff --stat` shows only additions in the three files.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/claude-code/test-autonomous-delivery-evals.sh`
Expected: `All tests passed`.

- [ ] **Step 5: Regression evals.** In `iteration-2/` of the eval workspace, 2 runs each, current skills (with hooks) vs `skill-snapshot/` (the three files at `main`): brainstorming evals `0 bounded-flag` and `1 architectural-sync` (`skills/brainstorming/evals/evals.json`), writing-plans eval `0` (`skills/writing-plans/evals/evals.json`), autonomous-delivery evals `4 guard-auto-mode` and `5 guard-finishing`.
Expected: no expectation that passes on the snapshot fails with the hooks. Any regression → stop and report it in the ledger as a failed task, do not reword the hook.

- [ ] **Step 6: Commit**

```bash
git add skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md skills/finishing-a-development-branch/SKILL.md tests/claude-code/test-autonomous-delivery-evals.sh
git commit -m "feat: gate hooks for an autonomous run in brainstorming, writing-plans and finishing"
```

---

### Task 4: The autonomous-delivery skill (GREEN)

**Files:**
- Create: `skills/autonomous-delivery/SKILL.md`
- Create: `skills/autonomous-delivery/run-report.md`
- Modify: `README.md` (the **Collaboration** skills list, after the `finishing-a-development-branch` line)

**Interfaces:**
- Consumes: hooks (Task 3) by the phrase `superpowers:autonomous-delivery is driving`; the report format in Global Constraints; eval ids from Task 2.
- Produces: skill name `autonomous-delivery`.

- [ ] **Step 1: Write the failing test**: append to `tests/claude-code/test-autonomous-delivery-evals.sh`, before the final summary:

```bash
echo "--- skill ---"
SK="$REPO_ROOT/skills/autonomous-delivery"
head -4 "$SK/SKILL.md" | grep -q '^name: autonomous-delivery$' && pass "frontmatter name" || fail "frontmatter name"
head -4 "$SK/SKILL.md" | grep -q '^description: .*Use when' && pass "description has Use when" || fail "description"
for t in "Outcome: done" "Outcome: blocked" "Outcome: failed" ".superpowers/autonomous/" "Red Flags" "run-report.md"; do
  grep -qF "$t" "$SK/SKILL.md" && pass "SKILL.md mentions $t" || fail "SKILL.md lacks $t"
done
for h in "### 1. Rules → evidence" "### 2. Rulings" "### 3. Clarification requests" "### 4. Human-only steps" "### 5. Verification" "### 6. Review first"; do
  grep -qF "$h" "$SK/run-report.md" && pass "template: $h" || fail "template lacks $h"
done
grep -q '\*\*autonomous-delivery\*\*' "$REPO_ROOT/README.md" && pass "README lists it" || fail "README lists it"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/claude-code/test-autonomous-delivery-evals.sh`
Expected: `[FAIL] frontmatter name` …, exit 1.

- [ ] **Step 3: Write `skills/autonomous-delivery/run-report.md`**: the template from spec §2 verbatim (header line per Global Constraints), followed by the five construction rules from spec §2 and the blocked/failed section subsets.

- [ ] **Step 4: Write `skills/autonomous-delivery/SKILL.md`**. Frontmatter:
  - `name: autonomous-delivery`
  - `description: Delivers one story from an external source spec to an open pull request with no approval gate, and writes a run report built from the diff for the human partner to review afterwards. Use when the human partner or a dispatcher asks to deliver a named story autonomously from a repo that declares "Autonomous delivery:" in its CLAUDE.md or AGENTS.md. Not for ideas without a source spec, and never started by a harness auto mode or "just do it" alone.`

  Body sections, in order, each deciding what the spec decides and no more:
  1. **When a run starts**: only this skill starts one; the declaration line and its fields and defaults (spec §1 Trigger); a story id absent from the source spec → no run, say so, offer brainstorming.
  2. **The flow**: the 8-step table of spec §1, naming the skill used at each step and that steps 4, 5 and 8 rely on the hooks (`superpowers:autonomous-delivery is driving`); record the base branch at step 1.
  3. **Rule list**: R1…Rn, each rule quoted verbatim with its source location, written into the spec's Source section.
  4. **Triage**: risk tiers (declared, default money, stock, permissions, tenancy, migrations); a risk-tier gap or conflict → clarification request at the Global Constraints path with the gap, the quoted source lines, and at least two options with consequences → commit it → outcome blocked → step 8; one risk-tier gap blocks the story even when other gaps are low-tier. Any other gap → `Ruling: <decision> — <why> — <cost if wrong>` in the spec's Rulings section. The same rule applies when a risk-tier gap surfaces during planning or execution.
  5. **Outcomes**: done / blocked / failed exactly as spec §1; Draft PR for blocked and failed.
  6. **Run report**: path `.superpowers/autonomous/<story-id>/run-report.md`; built with `run-report.md` (this skill's reference file); used as the PR body; when no PR can be opened (no forge or no credentials), push the branch, keep the report, and say in the final message that the PR is not open and why.
  7. **What still stops a run**: a blocking ambiguity, the four SDD stops, any merge; pushing the story branch is not a stop.
  8. **Red Flags** table: the four rows of spec §3, plus "I'll write the report from the plan" → "Rows come from the rule list, cells from the diff and the CI output."

- [ ] **Step 5: Add the README line**: `- **autonomous-delivery** - Deliver one story from an external source spec to a pull request with no approval gate; review afterwards from a run report built from the diff`

- [ ] **Step 6: Run the structural test**

Run: `bash tests/claude-code/test-autonomous-delivery-evals.sh`
Expected: `All tests passed`.

- [ ] **Step 7: With-skill eval runs (GREEN).** `iteration-3/` in the eval workspace, ids 0–5, 2 runs each, with the skill and hooks; compare with the Task 2 baseline.
Expected: ids 0–3 pass every expectation in both runs; ids 4–5 still pass. A failing expectation → revise SKILL.md wording (not the hooks, not the evals) and re-run that id in `iteration-4/`; after 3 revisions without a pass, stop and report as failed.

- [ ] **Step 8: Commit**

```bash
git add skills/autonomous-delivery/SKILL.md skills/autonomous-delivery/run-report.md README.md tests/claude-code/test-autonomous-delivery-evals.sh
git commit -m "feat: autonomous-delivery skill"
```

---

### Task 5: One real run on the client project (before the merge ask)

**Files:** none in this repo.

**Interfaces:**
- Consumes: the finished skill (Task 4) loaded from this worktree.

This task has outward side effects (a branch and a merge request on the client project's forge); it is one of the four stops. The controller stops here and asks the human partner to name the project and pick one low-risk (read/display class) story from its specs repo, and to confirm the run. The project, its paths and its URLs are given in the session, never written into this repo.

- [ ] **Step 1: Ask the human partner** for the story id and confirmation. Do not pick one.
- [ ] **Step 2: Run it** in a session started in the client project's checkout with this worktree's skills loaded, giving the declaration in the prompt (the project's `CLAUDE.md` is not changed in this plan): `Autonomous delivery: source spec = <specs path>; clarifications → <clarifications dir>; risk tiers = money, stock, permissions, tenancy, migrations; base = main`.
- [ ] **Step 3: Record** in the ledger: MR URL, outcome, `grade-report.sh` output against the client project's worktree (rule count from the run's spec), wall time and token use as measured (or "not measured").

---

## Execution notes

- Tasks 1→2→3→4 are sequential (each consumes the previous one's names); Task 5 needs a human answer.
- Eval runs dominate cost; token use is not estimated here and is reported from the runs.
