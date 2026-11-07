#!/usr/bin/env bash
# grade-report.sh REPO_DIR STORY_ID EXPECTED_OUTCOME EXPECTED_RULES
# Mechanical checks of an autonomous-delivery run report. One [PASS]/[FAIL]
# line per check; exit 0 only if all pass.
set -euo pipefail

[ $# -eq 4 ] || { echo "usage: grade-report.sh REPO_DIR STORY_ID EXPECTED_OUTCOME EXPECTED_RULES" >&2; exit 2; }
REPO="$1"; STORY="$2"; OUTCOME="$3"; RULES="$4"
FAILS=0
ok()  { echo "[PASS] $1"; }
bad() { echo "[FAIL] $1"; FAILS=$((FAILS + 1)); }

REPORT="$REPO/.superpowers/autonomous/$STORY/run-report.md"
if [ -f "$REPORT" ]; then ok "report exists"; else
  bad "report missing: .superpowers/autonomous/$STORY/run-report.md"
  echo "$FAILS check(s) failed"; exit 1
fi

HEADER="$(grep -m1 '^## ' "$REPORT" || true)"
if printf '%s\n' "$HEADER" | grep -Eq "^## ${STORY} — .+    Outcome: ${OUTCOME}\$"; then
  ok "header: $STORY, outcome $OUTCOME"
else
  bad "header does not match '## $STORY — <title>    Outcome: $OUTCOME' (got: $HEADER)"
fi

case "$OUTCOME" in
  done|failed)
    n=1
    while [ "$n" -le "$RULES" ]; do
      c="$(grep -c "^| R${n} |" "$REPORT" || true)"
      if [ "$c" -eq 1 ]; then ok "row R$n present once"; else bad "row R$n appears $c times"; fi
      n=$((n + 1))
    done
    extra="$(grep -E '^\| R[0-9]+ \|' "$REPORT" | awk -F'|' '{gsub(/ /,"",$2); print $2}' | sed 's/^R//' | sort -n | tail -1)"
    if [ -n "$extra" ] && [ "$extra" -gt "$RULES" ]; then bad "row R$extra exceeds expected rules ($RULES)"; fi

    ADDED="$(git -C "$REPO" diff --unified=0 main...HEAD | awk '
      /^\+\+\+ b\// { path = substr($0, 7); next }
      /^\+\+\+ /    { path = ""; next }
      /^@@ /        {
        s = $3; sub(/^\+/, "", s)
        split(s, a, ",")
        start = a[1]; cnt = (a[2] == "" ? 1 : a[2])
        for (i = 0; i < cnt; i++) if (path != "") print path ":" (start + i)
      }')"
    refs="$(grep -E '^\| R[0-9]+ \|' "$REPORT" | awk -F'|' '{print $5}' | tr ',' '\n' \
      | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | awk 'NF && $0 != "-" && $0 != "–"')"
    if [ -z "$refs" ]; then
      ok "no code references to check"
    else
      while IFS= read -r ref; do
        if printf '%s\n' "$ADDED" | grep -Fxq -- "$ref"; then ok "code ref $ref is an added line"
        else bad "code ref $ref is not a line added on this branch"; fi
      done <<< "$refs"
    fi
    ;;
  blocked)
    outside="$(git -C "$REPO" diff --name-only main...HEAD | grep -v -E '^docs/(clarifications|superpowers)/' || true)"
    if [ -z "$outside" ]; then ok "only docs/clarifications and docs/superpowers changed"
    else bad "files changed outside docs/clarifications and docs/superpowers: $(echo "$outside" | tr '\n' ' ')"; fi
    if [ -d "$REPO/docs/clarifications" ] && [ -n "$(find "$REPO/docs/clarifications" -type f | head -1)" ]; then
      ok "clarification request exists"
    else bad "no file under docs/clarifications/"; fi
    ;;
  *) bad "unknown expected outcome: $OUTCOME" ;;
esac

if [ "$FAILS" -eq 0 ]; then exit 0; else echo "$FAILS check(s) failed"; exit 1; fi
