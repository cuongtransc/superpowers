#!/usr/bin/env bash
# Materialize one eval case: a real git repo with a committed plan, a `herdr`
# test double on PATH, and an env.sh that makes a shell look like a Herdr pane.
# Nothing here talks to a real Herdr server.
#
#   worktree   wide pane, plan 2026-09-05-notes-tags.md, no flags
#   branch-pi  tall pane, same plan, invoked with --branch --pi
#   pane       wide pane, same plan, SUPERPOWERS_SDD_LAYOUT=pane in the env
#   collision  wide pane, long plan slug, first `agent start` is rejected as
#              name_taken so the caller must retry with a suffix that still fits
#
# Usage: setup-case.sh worktree|branch-pi|pane|collision|cta-lane|cta-nolane|cta-collision|cta-unrelated-exists|cta-agent-collision|cta-pi DEST_DIR
set -euo pipefail

case_name=${1:?usage: setup-case.sh worktree|branch-pi|pane|collision|cta-lane|cta-nolane|cta-collision|cta-unrelated-exists|cta-agent-collision|cta-pi DEST_DIR}
dest=${2:?usage: setup-case.sh CASE DEST_DIR}
here="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$dest/repo" "$dest/bin"
cp -R "$here/fixtures/repo/." "$dest/repo/"
cp "$here/fixtures/bin/herdr" "$dest/bin/herdr"
cp "$here/fixtures/bin/cta" "$dest/bin/cta"
chmod +x "$dest/bin/herdr" "$dest/bin/cta"

layout=wide
reject_first=0
layout_env=
cta_mode=nolane
cta_exists=0
cta_unrelated=0
cta_agent_exists=0
cta_pi=0
plan="docs/superpowers/plans/2026-09-05-notes-tags.md"
case "$case_name" in
  worktree) ;;
  branch-pi) layout=tall ;;
  pane) layout_env='export SUPERPOWERS_SDD_LAYOUT=pane' ;;
  collision)
    reject_first=1
    long="docs/superpowers/plans/2026-09-05-add-tag-based-filtering-and-search-to-notes-cli.md"
    mv "$dest/repo/$plan" "$dest/repo/$long"
    plan=$long ;;
  cta-lane|cta-pi) cta_mode=lane; [ "$case_name" = cta-pi ] && cta_pi=1 ;;
  cta-nolane) ;;
  cta-collision) cta_mode=lane; cta_exists=1; long="docs/superpowers/plans/2026-09-05-add-tag-based-filtering-and-search-to-notes-cli.md"; mv "$dest/repo/$plan" "$dest/repo/$long"; plan=$long ;;
  cta-agent-collision) cta_mode=lane; cta_agent_exists=1 ;;
  cta-unrelated-exists) cta_mode=lane; cta_unrelated=1 ;;
  *) echo "unknown case: $case_name" >&2; exit 2 ;;
esac

cd "$dest/repo"
git init -q -b main .
git -c user.email=eval@example.com -c user.name=eval -c commit.gpgsign=false add -A
git -c user.email=eval@example.com -c user.name=eval -c commit.gpgsign=false commit -qm "chore: notes-cli baseline with plan"

dest_abs="$(cd "$dest" && pwd -P)"
cat > "$dest_abs/env.sh" <<EOF
# Source this at the start of every shell command to be "inside Herdr", in the repo.
cd "$dest_abs/repo"
export HERDR_ENV=1
export HERDR_SESSION=s1
export HERDR_WORKSPACE_ID=w1
export HERDR_TAB_ID=w1:t1
export HERDR_PANE_ID=w1:p1
export PATH="$dest_abs/bin:\$PATH"
export HERDR_SHIM_LOG="$dest_abs/herdr-calls.log"
export HERDR_SHIM_STATE="$dest_abs/.herdr-shim"
export HERDR_SHIM_LAYOUT=$layout
export HERDR_SHIM_REJECT_FIRST_START=$reject_first
export CTA_SHIM_LOG="$dest_abs/cta-calls.log"
export CTA_SHIM_STATE="$dest_abs/.cta-shim"
export CTA_SHIM_MODE=$cta_mode
export CTA_SHIM_EXISTS=$cta_exists
export CTA_SHIM_UNRELATED_EXISTS=$cta_unrelated
export CTA_SHIM_AGENT_EXISTS=$cta_agent_exists
export CTA_SHIM_PI=$cta_pi
$layout_env
EOF
: > "$dest_abs/herdr-calls.log"
: > "$dest_abs/cta-calls.log"
printf '%s\n' "$plan" > "$dest_abs/plan-path.txt"
echo "case=$case_name repo=$dest_abs/repo plan=$plan env=$dest_abs/env.sh"
