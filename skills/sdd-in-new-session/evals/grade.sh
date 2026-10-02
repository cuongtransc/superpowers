#!/usr/bin/env bash
set -uo pipefail
case_name=${1:?usage: grade.sh CASE DIR [FINAL]}
case_dir=${2:?usage: grade.sh CASE DIR [FINAL]}
final=${3:-}
herdr_log="$case_dir/herdr-calls.log"
cta_log="$case_dir/cta-calls.log"
state="$case_dir/.herdr-shim"
repo="$(cd "$case_dir/repo" && pwd -P)"
plan_abs="$repo/$(cat "$case_dir/plan-path.txt")"
pass=0; fail=0
ok() { pass=$((pass+1)); printf 'PASS  %s\n      %s\n' "$1" "${2:-}"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "${2:-}"; }
check() { if [ "$2" -eq 0 ]; then ok "$1" "$3"; else bad "$1" "$3"; fi; }
count() { grep -c -E "$1" "$herdr_log" 2>/dev/null || true; }
line() { grep -E "$1" "$herdr_log" 2>/dev/null | head -n "${2:-1}"; }

case "$case_name" in
  cta-lane|cta-nolane|cta-collision|cta-agent-collision|cta-unrelated-exists|cta-pi)
    probes=$(grep -c '^cta lane dispatch --help$' "$cta_log" 2>/dev/null || true)
    if [ "$case_name" = cta-nolane ]; then
      [ "$probes" = 1 ]; check "exactly one capability probe" $? "probes=$probes"
      [ "$(grep -c '^herdr agent start ' "$herdr_log" || true)" = 1 ] && [ "$(grep -c '^herdr agent prompt ' "$herdr_log" || true)" = 1 ]; check "legacy cta uses Herdr handoff" $? "$(cat "$herdr_log")"
      # Fall through to common Herdr checks.
    else
      [ "$probes" = 1 ]; check "exactly one capability probe" $? "probes=$probes"
      real=$(grep -v '^cta lane dispatch --help$' "$cta_log" | grep -c '^cta lane dispatch ' || true)
      case "$case_name" in
        cta-lane)
          [ "$real" = 1 ] && grep -q '^cta lane dispatch sdd-' "$cta_log" && grep -q -- '--class code-wiring' "$cta_log"; check "one lane dispatch with class" $? "real=$real"
          grep -q '^cta lane dispatch --help$' "$cta_log" && grep -q '^cta lane dispatch sdd-' "$cta_log"; check "probe and real dispatch recorded" $? "$(cat "$cta_log")"
          first_real=$(grep -n '^cta lane dispatch sdd-' "$cta_log" | head -1 | cut -d: -f1)
          probe_line=$(grep -n '^cta lane dispatch --help$' "$cta_log" | head -1 | cut -d: -f1)
          [ "$probe_line" -lt "$first_real" ]; check "probe precedes real dispatch" $? "$probe_line < $first_real"
          route_calls=$(grep -c '^cta lane route ' "$cta_log" || true)
          [ "$route_calls" -le 1 ] && { [ "$route_calls" = 0 ] || grep -q '^cta lane route code-wiring$' "$cta_log"; }; check "optional class lookup is valid and at most once" $? "route_calls=$route_calls"
          worktree_arg=$(grep -v '^cta lane dispatch --help$' "$cta_log" | awk '{for(i=1;i<=NF;i++) if($i=="--worktree") print $(i+1)}')
          other_calls=$(grep -v -E '^cta lane dispatch --help$|^cta lane route( |$)|^cta lane dispatch ' "$cta_log" | wc -l | tr -d ' ')
          dispatch_args=$(grep '^cta lane dispatch sdd-' "$cta_log" | wc -l | tr -d ' ')
          [ "$other_calls" = 0 ] && [ "$dispatch_args" = 1 ] && grep -q -F "$repo/.worktrees/" <<<"$worktree_arg" && [ "${worktree_arg#/}" != "$worktree_arg" ] && grep -q '^cta lane dispatch .*--brief /' "$cta_log"; check "only probe/optional route/dispatch; worktree and brief valid" $? "$worktree_arg :: $(tail -1 "$cta_log")"
          rel_plan=${plan_abs#"$repo"/}
          expected_plan="$worktree_arg/$rel_plan"
          [ -f "$expected_plan" ] && grep -q -F "$expected_plan" "$case_dir/.cta-shim/brief.md" && grep -q 'create no other worktree or branch' "$case_dir/.cta-shim/brief.md" && ! grep -q 'create a new git worktree' "$case_dir/.cta-shim/brief.md" && grep -q 'subagent-driven-development' "$case_dir/.cta-shim/brief.md"; check "copied brief names plan in worktree and is in-place" $? "expected=$expected_plan"
          [ "$(grep -c '^herdr ' "$herdr_log" || true)" = 0 ]; check "no Herdr calls in lane path" $? "$(cat "$herdr_log")"
          [ -n "$final" ] && grep -q 'lane-sdd-' "$final" && grep -q 'cta lane wait lane-sdd-' "$final"; check "final names lane and wait command" $? "$final"
          ;;
        cta-collision|cta-agent-collision)
          [ "$real" = 2 ]; check "two real dispatch attempts" $? "real=$real"
          first=$(grep -v '^cta lane dispatch --help$' "$cta_log" | grep '^cta lane dispatch sdd-' | sed -n '1p' | awk '{print $4}')
          second=$(grep -v '^cta lane dispatch --help$' "$cta_log" | grep '^cta lane dispatch sdd-' | sed -n '2p' | awk '{print $4}')
          [ "$second" = "$first-2" ] && [ "${#first}" -le 27 ] && [ "${#second}" -le 27 ]; check "retry slug suffix and length" $? "$first -> $second"
          [ -n "$final" ] && grep -q -F "lane-$second" "$final"; check "final names retry lane" $? "$final"
          if [ "$case_name" = cta-agent-collision ]; then [ -f "$case_dir/.cta-shim/agent-existing-seen" ]; check "first failure is agent collision" $? "$(cat "$case_dir/cta-calls.log")"; fi
          ;;
        cta-unrelated-exists)
          [ "$real" = 1 ] && ! grep -Eq '^herdr (tab create|pane split|agent start|agent prompt) ' "$herdr_log"; check "no retry or fallback" $? "real=$real"
          [ -n "$final" ] && grep -q -F 'prompt was not confirmed' "$final"; check "final quotes partial dispatch error" $? "$final"
          ;;
        cta-pi)
          [ "$real" = 1 ] && grep -q -- '--kind pi --model alias:mid-model --reason' "$cta_log" && ! grep -q '^herdr agent start' "$herdr_log"; check "pi dispatch arguments and no Herdr start" $? "real=$real"
          [ -n "$final" ] && grep -q 'pi' "$final" && grep -q 'mid-model' "$final"; check "final reports pi kind and model" $? "$final"
          ;;
      esac
      printf '\n%s: %d passed, %d failed\n' "$case_name" "$pass" "$fail"
      [ "$fail" -eq 0 ]
      exit
    fi
    ;;
esac

# Existing Herdr-path evals and cta-nolane share these checks.
tabs=$(count '^herdr tab create '); splits=$(count '^herdr pane split '); tab_line=$(line '^herdr tab create ')
case "$case_name" in branch-pi) want_kind=pi ;; *) want_kind=claude ;; esac
if [ "$case_name" = pane ]; then
  split_line=$(line '^herdr pane split ')
  [ "$splits" = 1 ] && [ "$tabs" = 0 ] && grep -q -- '--direction right' <<<"$split_line" && grep -q -- "--cwd $repo" <<<"$split_line" && grep -q -- '--no-focus' <<<"$split_line"
  check "pane layout splits right, cwd repo, no focus" $? "$split_line"
else
  [ "$tabs" = 1 ] && [ "$splits" = 0 ] && grep -q -- "--cwd $repo" <<<"$tab_line" && grep -q -- '--label sdd-' <<<"$tab_line" && ! grep -q -- '--focus' <<<"$tab_line"
  check "one unfocused tab at repo root" $? "$tab_line"
fi
started_name=$(tail -1 "$state/agents" 2>/dev/null | cut -f1)
starts=$(count '^herdr agent start '); start_names=$(grep -E '^herdr agent start ' "$herdr_log" | awk '{print $4}')
bad_names=$(printf '%s\n' "$start_names" | grep -v -E '^[a-z][a-z0-9_-]{0,31}$' || true)
if [ "$case_name" = collision ]; then
  [ "$starts" = 2 ] && [ -n "$started_name" ] && [ -z "$bad_names" ] && [ "$(sed -n '1p' <<<"$start_names")" != "$(sed -n '2p' <<<"$start_names")" ]
  check "collision retries with valid suffixed name" $? "starts=$starts started=$started_name"
else
  [ -n "$started_name" ] && [ "$starts" = 1 ] && [ -z "$bad_names" ] && grep -q '^sdd-' <<<"$started_name"
  check "one valid sdd agent started" $? "$started_name"
fi
start_line=$(line '^herdr agent start ' 9 | tail -1)
grep -q -- "--kind $want_kind" <<<"$start_line" && grep -q -- '--pane w1:p2' <<<"$start_line"
check "agent kind and pane" $? "$start_line"
pf="$state/prompt-$started_name.txt"
[ -f "$pf" ] && grep -q -F "$plan_abs" "$pf" && grep -q 'subagent-driven-development' "$pf"
check "prompt has absolute plan and SDD skill" $? "$pf"
prompt_line=$(line '^herdr agent prompt ')
[ "$(count '^herdr agent prompt ')" = 1 ] && grep -q -- '--until working' <<<"$prompt_line" && grep -q -E "^herdr agent prompt ($started_name|w1:p2) " <<<"$prompt_line"
check "one prompt to started agent, until working" $? "$prompt_line"
if [ "$case_name" = collision ]; then printf '%s\n' "$prompt_line" | grep -F "$started_name" >/dev/null; check "collision prompt targets successful agent" $? "$started_name"; fi
bare=$(grep -E '^herdr agent prompt ' "$herdr_log" | grep -- '--wait' | grep -v -- '--until' | wc -l | tr -d ' ')
waits=$(count '^herdr (agent wait|pane wait-output) ')
[ "$bare" = 0 ] && [ "$waits" = 0 ]; check "no bare wait or follow-up polling" $? "bare=$bare waits=$waits"
after=$(awk '/^herdr agent prompt /{f=1; next} f && /^herdr (agent (read|get|wait)|pane (read|wait-output)) /{n++} END{print n+0}' "$herdr_log")
[ "$after" = 0 ]; check "no polling after prompt" $? "polling_after_prompt=$after"
[ "$(cat "$state/prompt_count" 2>/dev/null || echo 0)" = 1 ]; check "prompt sent once" $? "$(cat "$state/prompt_count" 2>/dev/null || echo 0)"
! grep -qi -E 'dangerously|skip-permissions|--yes|auto-approve|yolo' <<<"$start_line"; check "no permission bypass flag" $? "$start_line"
if [ "$case_name" = branch-pi ]; then
  grep -q -- '-- --model alias/mid-model --thinking medium' <<<"$start_line"; check "pi starts at mid tier" $? "$start_line"
  [ "$(wc -l < "$pf" | tr -d ' ')" = 0 ]; check "pi prompt is a single line" $? "lines=$(wc -l < "$pf" | tr -d ' ')"
  grep -qi 'do NOT create a worktree\|not create a worktree' "$pf" && grep -qi 'branch' "$pf" && grep -q -F "$repo" "$pf"; check "pi prompt specifies shared-checkout branch isolation" $? "$(cat "$pf")"
else
  ! grep -Eq '^herdr worktree |^herdr pane close ' "$herdr_log"; check "no worktree operation or pane close" $? "$(cat "$herdr_log")"
  ! grep -q -E '<ABS_PLAN_PATH>|<ROOT>|<ISOLATION>|\$PLAN|\$ROOT|\$ISOLATION' "$pf"; check "prompt has no unfilled placeholders" $? "$pf"
fi
rename_line=$(grep '^herdr pane rename w1:p2 ' "$herdr_log" | tail -1)
[ -n "$rename_line" ] && [ "$(awk '{print $5}' <<<"$rename_line")" = "$started_name" ]; check "last pane rename matches started agent" $? "$rename_line"
if [ "$case_name" != pane ]; then tab_label=$(tail -1 "$state/tab_labels" 2>/dev/null | cut -f2); [ "$tab_label" = "$started_name" ]; check "last tab label matches started agent" $? "tab_label=$tab_label agent=$started_name"; fi
if [ "$case_name" = collision ]; then
  first_name=$(sed -n '1p' <<<"$start_names"); second_name=$(sed -n '2p' <<<"$start_names")
  [ "$second_name" = "$first_name-2" ] && [ -n "$started_name" ] && [ "$started_name" = "$second_name" ]; check "second collision name has suffix and starts" $? "$first_name -> $second_name"
fi
if [ "$case_name" = cta-nolane ]; then
  if [ -n "$final" ] && [ -f "$final" ]; then
    grep -q 'w1:p2' "$final" && grep -q -F "$started_name" "$final" && grep -q -E 'herdr agent (get|read)' "$final"; check "fallback final reports pane, agent and check-in" $? "$final"
    grep -q -F "$plan_abs" "$final" && grep -qi 'worktree' "$final"; check "fallback final names plan and workspace" $? "$final"
  fi
  printf '\n%s: %d passed, %d failed\n' "$case_name" "$pass" "$fail"; [ "$fail" -eq 0 ]; exit
fi
if [ -n "$final" ] && [ -f "$final" ]; then
  grep -q 'w1:p2' "$final" && grep -q -F "$started_name" "$final" && grep -q -E 'herdr agent (get|read)' "$final"; check "final reports pane, name, check-in" $? "$final"
  if [ "$case_name" = branch-pi ]; then grep -q -i -E 'shared|collide|conflict' "$final"; check "final warns about shared checkout" $? "$final"; fi
  ! grep -q -i -E 'plan (is )?(complete|finished|done)|all tasks (complete|done)' "$final"; check "final does not claim plan completion" $? "$final"
fi
printf '\n%s: %d passed, %d failed\n' "$case_name" "$pass" "$fail"
[ "$fail" -eq 0 ]
