# sdd-in-new-session evals

These evals use test doubles for `herdr` and `cta` (`fixtures/bin/herdr` and
`fixtures/bin/cta`) that log calls and simulate relevant CLI results. No real
Herdr server or cta store is involved.

## Files

- `evals.json` — eleven cases with prompts and expectations
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
`cta-unrelated-exists`, `cta-state-c-uncommitted` and `cta-pi` cover capability
detection, safe fallback, both pre-dispatch collision classes,
uncommitted-plan refusal, stopping on partial-dispatch errors, and the pi
override. Artifacts include `DEST/herdr-calls.log`,
`DEST/cta-calls.log`, the shim state directories, and the executor final message.

Waits that block until the worker turn ends are undesirable *in the handoff*:
the prompt is confirmed with `--until working`, never bare `--wait`. After the
handoff the skill starts exactly ONE harness-tracked background wait, and the
grader allows exactly that and nothing else:

- Herdr fallback: one `herdr agent wait NAME --until done` for the started
  agent, issued after the `agent prompt`. `grade.sh` still FAILs a bare
  `--wait` on the prompt, any `pane wait-output`, a second `agent wait`, and
  any `agent read`/`agent get`/`pane read` after the prompt.
- cta path (`cta-lane`, `cta-pi`): one `cta lane wait lane-sdd-...` after the
  real dispatch, and no other `cta lane wait`.

The `herdr agent wait --until done` double sleeps `HERDR_SHIM_TURN_SECONDS`
(default 25) to model the turn; it is logged before it sleeps, so a foreground
run shows up as latency, and the executor runs it in the background as the
skill says. The `cta lane wait` double returns at once.
