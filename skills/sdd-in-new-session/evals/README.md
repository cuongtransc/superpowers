# sdd-in-new-session evals

These evals use test doubles for `herdr` and `cta` (`fixtures/bin/herdr` and
`fixtures/bin/cta`) that log calls and simulate relevant CLI results. No real
Herdr server or cta store is involved.

## Files

- `evals.json` — ten cases with prompts and expectations
- `fixtures/repo/` — a small Python project with a committed plan
- `fixtures/bin/herdr`, `fixtures/bin/cta` — CLI test doubles
- `setup-case.sh <case> DEST` — materializes a git repo, both shims and env file
- `grade.sh <case> DEST [final-message.md]` — mechanical PASS/FAIL over artifacts

## Running a case

```bash
evals/setup-case.sh cta-lane /tmp/sdd-cta-lane
# executor: source /tmp/sdd-cta-lane/env.sh before each shell command
# perform the handoff as the skill says
evals/grade.sh cta-lane /tmp/sdd-cta-lane /tmp/sdd-cta-lane/final.md
```

The legacy cases retain regression checks for the Herdr worker path. Cases
`cta-lane`, `cta-nolane`, `cta-collision`, `cta-agent-collision`,
`cta-unrelated-exists` and `cta-pi` cover capability detection, safe fallback,
both pre-dispatch collision classes, stopping on partial dispatch errors, and
the pi override. Artifacts include `DEST/herdr-calls.log`,
`DEST/cta-calls.log`, the shim state directories, and the executor final message.

Waits that block until the worker turn ends are undesirable; the handoff must
return after the worker is confirmed working.
