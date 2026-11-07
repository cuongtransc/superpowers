# autonomous-delivery evals

Fixture: `fixtures/orders-cli/`, a tiny stdlib-only Python CLI with a `source-spec/` and a `CLAUDE.md` that declares the autonomous-delivery settings.

## What the fixture plants

| Story | Rules | Planted gap | Tier |
|---|---|---|---|
| STORY-001 order count | 4 | none (clean) | n/a |
| STORY-002 order list | 3 | sort order of the listed orders is not stated | low |
| STORY-003 partial refund | 3 | rounding of a percentage of cents is not stated | risk tier (money) |
| STORY-003 partial refund | 3 | no output format for the refund amount | low |

## Materialize a case

```bash
skills/autonomous-delivery/evals/setup-case.sh <dest>
```

Creates a git repo at `<dest>` on `main` (one commit, `chore: orders-cli baseline`) with a bare remote at `<dest>.remote.git`. Keep `<dest>` outside the repo, in the eval workspace.

### Case 5 setup (guard-finishing)

After `setup-case.sh <dest>`, add the finished `feat/count` branch:

```bash
cd <dest>
git checkout -q -b feat/count
printf 'def count():\n    return 6\n' > orders/count.py
printf 'from orders.count import count\n\ndef test_count():\n    assert count() == 6\n' > tests/test_count.py
git add -A
git -c user.email=eval@example.com -c user.name=eval -c commit.gpgsign=false commit -qm "feat: count"
```

## Grade a run

```bash
skills/autonomous-delivery/evals/grade-report.sh <repo> <story-id> <done|blocked|failed> <rule-count>
```

Mechanical checks only: report exists and its header parses, one table row per rule, every `path:line` names a line added on the branch, and a blocked run changed nothing but clarifications and docs. The rest is read by hand: the spec, the plan, the clarification request and the final message. Read each mechanical hit before counting it.

Point `grade-report.sh` at the story's worktree (the run creates `.worktrees/<branch>/` in the case repo, and the report and branch HEAD live there), not at the case root.
