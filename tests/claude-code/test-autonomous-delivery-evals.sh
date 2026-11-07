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

# --- relative DEST ---
(cd "$TEST_ROOT" && "$EVALS/setup-case.sh" rel-case >/dev/null 2>&1 \
  && git -C rel-case ls-remote --exit-code origin main >/dev/null 2>&1) \
  && pass "relative DEST: origin main exists" || fail "relative DEST"

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

echo "--- hooks ---"
for s in brainstorming finishing-a-development-branch; do
  n=$(grep -c 'superpowers:autonomous-delivery is driving' "$REPO_ROOT/skills/$s/SKILL.md" || true)
  [ "$n" = 1 ] && pass "hook in $s" || fail "hook in $s: found $n"
done
n=$(grep -c 'only an invocation of superpowers:autonomous-delivery' "$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md" || true)
[ "$n" = 1 ] && pass "guard sentence in finishing" || fail "guard sentence in finishing: found $n"
n=$(grep -c 'autonomous' "$REPO_ROOT/skills/writing-plans/SKILL.md" || true)
[ "$n" = 0 ] && pass "writing-plans has no autonomous hook" || fail "writing-plans mentions autonomous: $n"
grep -q 'never start an' "$REPO_ROOT/skills/brainstorming/SKILL.md" && pass "brainstorming guard sentence" || fail "brainstorming guard sentence"
grep -q 'never merges and never discards' "$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md" && pass "finishing never-merge" || fail "finishing never-merge"

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
grep -qF "final message always names the run report's path" "$SK/SKILL.md" && pass "final message names report path" || fail "final message names report path"
grep -q '\*\*autonomous-delivery\*\*' "$REPO_ROOT/README.md" && pass "README lists it" || fail "README lists it"

echo
[ "$FAILURES" -eq 0 ] && { echo "All tests passed"; exit 0; } || { echo "$FAILURES failure(s)"; exit 1; }
