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
  cta-lane|cta-nolane|cta-collision|cta-agent-collision|cta-unrelated-exists|cta-pi|cta-state-c-uncommitted)
    probes=$(grep -c '^cta lane dispatch --help$' "$cta_log" 2>/dev/null || true)
    if [ "$case_name" = cta-state-c-uncommitted ]; then
      if grep -q 'intentionally uncommitted' "$plan_abs"; then dirty_plan=1; else dirty_plan=0; fi
      probe_ok=0; [ "$probes" = 1 ] || probe_ok=1; check "one capability probe" "$probe_ok" "probes=$probes"
      state_c_dispatch_count=$(grep -c '^cta lane dispatch ' "$cta_log" || true)
      state_c_dispatch_ok=0; [ "$state_c_dispatch_count" = 1 ] || state_c_dispatch_ok=1; check "no real cta dispatch occurred" "$state_c_dispatch_ok" "$state_c_dispatch_count"
      dirty_plan_ok=0; [ "$dirty_plan" = 1 ] || dirty_plan_ok=1; check "fixture plan is uncommitted" "$dirty_plan_ok" "$plan_abs"
      herdr_count=$(grep -c '^herdr ' "$herdr_log" || true)
      no_herdr=0; [ "$herdr_count" = 0 ] || no_herdr=1; check "no Herdr calls" "$no_herdr" "$(cat "$herdr_log")"
      no_wt=0; { [ ! -e "$repo/.worktrees" ] && [ "$(git -C "$repo" worktree list | wc -l | tr -d " ")" = 1 ] && [ "$(git -C "$repo" rev-list --count HEAD)" = 1 ]; } || no_wt=1; check "no worktree created and no commit made" "$no_wt" "$(git -C "$repo" worktree list)"
      commit_msg=0; { [ -n "$final" ] && [ -f "$final" ] && grep -qi 'commit' "$final"; } || commit_msg=1; check "clear commit-required message" "$commit_msg" "$final"
      printf '\n%s: %d passed, %d failed\n' "$case_name" "$pass" "$fail"; [ "$fail" -eq 0 ]; exit
    elif [ "$case_name" = cta-nolane ]; then
      probe_ok=0; [ "$probes" = 1 ] || probe_ok=1; check "one capability probe" "$probe_ok" "probes=$probes"
      fallback_ok=0; { [ "$(grep -c '^herdr agent start ' "$herdr_log" || true)" = 1 ] && [ "$(grep -c '^herdr agent prompt ' "$herdr_log" || true)" = 1 ]; } || fallback_ok=1; check "legacy cta uses Herdr handoff" "$fallback_ok" "$(cat "$herdr_log")"
    else
      probe_ok=0; [ "$probes" = 1 ] || probe_ok=1; check "one capability probe" "$probe_ok" "probes=$probes"
      real=$(grep -v '^cta lane dispatch --help$' "$cta_log" | grep -c '^cta lane dispatch ' || true)
      case "$case_name" in
        cta-lane)
          dispatch_ok=0; { [ "$real" = 1 ] && grep -q '^cta lane dispatch sdd-' "$cta_log" && grep -q -- '--class code-wiring' "$cta_log"; } || dispatch_ok=1; check "one lane dispatch with class" "$dispatch_ok" "real=$real"
          route_calls=$(grep -c '^cta lane route ' "$cta_log" || true)
          route_ok=0; { [ "$route_calls" -le 1 ] && { [ "$route_calls" = 0 ] || grep -q '^cta lane route code-wiring$' "$cta_log"; }; } || route_ok=1; check "optional class lookup valid and at most once" "$route_ok" "route_calls=$route_calls"
          call_count_ok=0; { [ "$(grep -c '^cta lane dispatch --help$' "$cta_log")" = 1 ] && [ "$real" = 1 ]; } || call_count_ok=1; check "exactly one probe and one dispatch" "$call_count_ok" "probe/dispatch counts"
          worktree_arg=$(grep -v '^cta lane dispatch --help$' "$cta_log" | awk '{for(i=1;i<=NF;i++) if($i=="--worktree") print $(i+1)}')
          dispatch_args=$(grep '^cta lane dispatch sdd-' "$cta_log" | grep -c . || true)
          other_calls=$(grep -v -E '^cta lane dispatch --help$|^cta lane route( |$)|^cta lane dispatch ' "$cta_log" | grep -c . || true)
          brief_arg=$(grep -v '^cta lane dispatch --help$' "$cta_log" | awk '{for(i=1;i<=NF;i++) if($i=="--brief") print $(i+1)}')
          args_ok=0; { [ "$other_calls" = 0 ] && [ "$dispatch_args" = 1 ] && grep -q -F "$repo/.worktrees/" <<<"$worktree_arg" && [ "${worktree_arg#/}" != "$worktree_arg" ] && [ "${brief_arg#/}" != "$brief_arg" ] && [ -f "$brief_arg" ]; } || args_ok=1; check "only allowed cta calls; worktree and brief valid" "$args_ok" "$worktree_arg :: $brief_arg"
          rel_plan=${plan_abs#"$repo"/}; expected_plan="$worktree_arg/$rel_plan"
          brief_ok=0; { [ -f "$expected_plan" ] && grep -q -F "$expected_plan" "$case_dir/.cta-shim/brief.md" && grep -q 'create no other worktree or branch' "$case_dir/.cta-shim/brief.md" && ! grep -q 'create a new git worktree' "$case_dir/.cta-shim/brief.md" && grep -q 'subagent-driven-development' "$case_dir/.cta-shim/brief.md"; } || brief_ok=1; check "brief plan is in worktree and isolation is in-place" "$brief_ok" "$expected_plan"
          herdr_count=$(grep -c '^herdr ' "$herdr_log" || true)
          no_herdr=0; [ "$herdr_count" = 0 ] || no_herdr=1; check "no Herdr calls in lane path" "$no_herdr" "$(cat "$herdr_log")"
          final_ok=0; { [ -n "$final" ] && [ -f "$final" ] && grep -q 'lane-sdd-' "$final" && grep -q 'cta lane wait lane-sdd-' "$final" && grep -q 'cta lane status' "$final"; } || final_ok=1; check "final reports lane and check-ins" "$final_ok" "$final"
          ;;
        cta-collision|cta-agent-collision)
          attempts_ok=0; [ "$real" = 2 ] || attempts_ok=1; check "two real dispatch attempts" "$attempts_ok" "real=$real"
          first=$(grep -v '^cta lane dispatch --help$' "$cta_log" | grep '^cta lane dispatch sdd-' | sed -n '1p' | awk '{print $4}')
          second=$(grep -v '^cta lane dispatch --help$' "$cta_log" | grep '^cta lane dispatch sdd-' | sed -n '2p' | awk '{print $4}')
          retry_ok=0; { [ "$second" = "$first-2" ] && [ "${#first}" -le 27 ] && [ "${#second}" -le 27 ]; } || retry_ok=1; check "retry suffix and length" "$retry_ok" "$first -> $second"
          final_ok=0; { [ -n "$final" ] && [ -f "$final" ] && grep -q -F "lane-$second" "$final"; } || final_ok=1; check "final names retry lane" "$final_ok" "$final"
          if [ "$case_name" = cta-agent-collision ]; then agent_collision=0; [ -f "$case_dir/.cta-shim/agent-existing-seen" ] || agent_collision=1; check "first failure is agent collision" "$agent_collision" "$(cat "$cta_log")"; fi
          ;;
        cta-unrelated-exists)
          herdr_count=$(grep -c '^herdr ' "$herdr_log" || true)
          stop_ok=0; { [ "$real" = 1 ] && [ "$herdr_count" = 0 ]; } || stop_ok=1; check "no retry or Herdr fallback" "$stop_ok" "real=$real herdr=$herdr_count"
          error_ok=0; { [ -n "$final" ] && [ -f "$final" ] && grep -q -F 'prompt was not confirmed' "$final"; } || error_ok=1; check "final quotes partial-dispatch error" "$error_ok" "$final"
          ;;
        cta-pi)
          pi_ok=0; { [ "$real" = 1 ] && grep -q -- '--kind pi --model alias:mid-model --reason' "$cta_log" && ! grep -q '^herdr agent start' "$herdr_log"; } || pi_ok=1; check "pi arguments and no Herdr worker" "$pi_ok" "real=$real"
          final_ok=0; { [ -n "$final" ] && [ -f "$final" ] && grep -q 'pi' "$final" && grep -q 'mid-model' "$final"; } || final_ok=1; check "final reports pi kind and model" "$final_ok" "$final"
          ;;
      esac
      printf '\n%s: %d passed, %d failed\n' "$case_name" "$pass" "$fail"
      [ "$fail" -eq 0 ]; exit
    fi
    ;;
esac

tabs=$(count '^herdr tab create '); splits=$(count '^herdr pane split '); tab_line=$(line '^herdr tab create ')
case "$case_name" in branch-pi) want_kind=pi ;; *) want_kind=claude ;; esac
if [ "$case_name" = pane ]; then
  split_line=$(line '^herdr pane split ')
  pane_ok=0; { [ "$splits" = 1 ] && [ "$tabs" = 0 ] && grep -q -- '--direction right' <<<"$split_line" && grep -q -- "--cwd $repo\( \|$\)" <<<"$split_line" && grep -q -- '--no-focus' <<<"$split_line"; } || pane_ok=1; check "one split right at repo root, no focus" "$pane_ok" "$split_line"
else
  tab_ok=0; { [ "$tabs" = 1 ] && [ "$splits" = 0 ] && grep -q -- "--cwd $repo\( \|$\)" <<<"$tab_line" && grep -q -- '--label sdd-' <<<"$tab_line" && ! grep -q -- '--focus' <<<"$tab_line"; } || tab_ok=1; check "one unfocused tab at repo root" "$tab_ok" "$tab_line"
fi
started_name=$(tail -1 "$state/agents" 2>/dev/null | cut -f1)
starts=$(count '^herdr agent start '); start_names=$(grep -E '^herdr agent start ' "$herdr_log" | awk '{print $4}')
bad_names=$(printf '%s\n' "$start_names" | grep -v -E '^[a-z][a-z0-9_-]{0,31}$' || true)
if [ "$case_name" = collision ]; then
  collision_ok=0; { [ "$starts" = 2 ] && [ -n "$started_name" ] && [ -z "$bad_names" ] && [ "$(sed -n '1p' <<<"$start_names")" != "$(sed -n '2p' <<<"$start_names")" ]; } || collision_ok=1; check "two valid collision names" "$collision_ok" "starts=$starts started=$started_name"
else
  start_ok=0; { [ -n "$started_name" ] && [ "$starts" = 1 ] && [ -z "$bad_names" ] && grep -q '^sdd-' <<<"$started_name"; } || start_ok=1; check "one valid sdd agent started" "$start_ok" "$started_name"
fi
start_line=$(line '^herdr agent start ' 9 | tail -1)
kind_ok=0; { grep -q -- "--kind $want_kind" <<<"$start_line" && grep -q -- '--pane w1:p2' <<<"$start_line"; } || kind_ok=1; check "agent kind and pane" "$kind_ok" "$start_line"
pf="$state/prompt-$started_name.txt"
prompt_file_ok=0; { [ -f "$pf" ] && grep -q -F "$plan_abs" "$pf" && grep -q 'subagent-driven-development' "$pf"; } || prompt_file_ok=1; check "prompt has absolute plan and SDD skill" "$prompt_file_ok" "$pf"
prompt_line=$(line '^herdr agent prompt ')
prompt_ok=0; { [ "$(count '^herdr agent prompt ')" = 1 ] && grep -q -- '--until working' <<<"$prompt_line" && grep -q -E "^herdr agent prompt ($started_name|w1:p2) " <<<"$prompt_line"; } || prompt_ok=1; check "one prompt to started agent until working" "$prompt_ok" "$prompt_line"
if [ "$case_name" = collision ]; then target_ok=0; printf '%s\n' "$prompt_line" | grep -F "$started_name" >/dev/null || target_ok=1; check "collision prompt targets successful agent" "$target_ok" "$started_name"; fi
bare=$(grep -E '^herdr agent prompt ' "$herdr_log" | grep -- '--wait' | grep -vc -- '--until' || true); waits=$(count '^herdr (agent wait|pane wait-output) ')
waits_ok=0; { [ "$bare" = 0 ] && [ "$waits" = 0 ]; } || waits_ok=1; check "no bare wait or follow-up wait" "$waits_ok" "bare=$bare waits=$waits"
after=$(awk '/^herdr agent prompt /{f=1; next} f && /^herdr (agent (read|get|wait)|pane (read|wait-output)) /{n++} END{print n+0}' "$herdr_log")
polling_ok=0; [ "$after" = 0 ] || polling_ok=1; check "no polling after prompt" "$polling_ok" "polling_after_prompt=$after"
count_ok=0; [ "$(cat "$state/prompt_count" 2>/dev/null || echo 0)" = 1 ] || count_ok=1; check "prompt sent once" "$count_ok" "$(cat "$state/prompt_count" 2>/dev/null || echo 0)"
! grep -qi -E 'dangerously|skip-permissions|--yes|auto-approve|yolo' <<<"$start_line"; bypass_ok=$?; check "no permission-bypass flag" "$bypass_ok" "$start_line"
if [ "$case_name" = branch-pi ]; then
  grep -q -- '-- --model alias/mid-model --thinking medium' <<<"$start_line"; tier_ok=$?; check "pi mid-tier arguments" "$tier_ok" "$start_line"
  single_line_ok=0; [ "$(wc -l < "$pf" | tr -d ' ')" = 0 ] || single_line_ok=1; check "pi prompt is one line" "$single_line_ok" "lines=$(wc -l < "$pf" | tr -d ' ')"
  isolation_ok=0; { grep -qi 'do NOT create a worktree\|not create a worktree' "$pf" && grep -qi 'branch' "$pf" && grep -q -F "$repo" "$pf"; } || isolation_ok=1; check "pi prompt specifies checkout branch" "$isolation_ok" "$(cat "$pf")"
else
  operations_ok=0; ! grep -Eq '^herdr worktree |^herdr pane close ' "$herdr_log" || operations_ok=1; check "no worktree operation or pane close" "$operations_ok" "$(cat "$herdr_log")"
  placeholders_ok=0; ! grep -q -E '<ABS_PLAN_PATH>|<ROOT>|<ISOLATION>|\$PLAN|\$ROOT|\$ISOLATION' "$pf" || placeholders_ok=1; check "no unresolved prompt placeholders" "$placeholders_ok" "$pf"
  worktree_prompt_ok=0; grep -qi 'worktree' "$pf" || worktree_prompt_ok=1; check "fallback prompt requests worktree" "$worktree_prompt_ok" "$(grep -i -o '.\{0,30\}worktree.\{0,40\}' "$pf" | head -1)"
fi
rename_line=$(grep '^herdr pane rename w1:p2 ' "$herdr_log" | tail -1)
rename_ok=0; { [ -n "$rename_line" ] && [ "$(awk '{print $5}' <<<"$rename_line")" = "$started_name" ]; } || rename_ok=1; check "last pane rename matches agent" "$rename_ok" "$rename_line"
if [ "$case_name" != pane ]; then tab_label=$(tail -1 "$state/tab_labels" 2>/dev/null | cut -f2); label_ok=0; { [ -n "$tab_label" ] && [ "$tab_label" = "$started_name" ]; } || label_ok=1; check "last tab label matches agent" "$label_ok" "tab_label=$tab_label agent=$started_name"; fi
if [ "$case_name" = collision ]; then first_name=$(sed -n '1p' <<<"$start_names"); second_name=$(sed -n '2p' <<<"$start_names"); suffix_ok=0; { [ "$second_name" = "$first_name-2" ] && [ "$started_name" = "$second_name" ]; } || suffix_ok=1; check "collision uses -2 suffix" "$suffix_ok" "$first_name -> $second_name"; fi
if [ -z "$final" ] || [ ! -f "$final" ]; then final_exists=1; else final_exists=0; fi
final_exists_ok=0; [ "$final_exists" = 0 ] || final_exists_ok=1; check "final message exists" "$final_exists_ok" "$final"
if [ "$final_exists" = 0 ]; then
  final_ok=0; { grep -q 'w1:p2' "$final" && grep -q -F "$started_name" "$final" && grep -q -E 'herdr agent (get|read)' "$final"; } || final_ok=1; check "final reports pane, agent and check-in" "$final_ok" "$final"
  plan_report_ok=0; grep -q -F "$plan_abs" "$final" || plan_report_ok=1; check "final reports absolute plan path" "$plan_report_ok" "$final"
  isolation_report_ok=0; grep -qi 'worktree\|branch' "$final" || isolation_report_ok=1; check "final reports workspace isolation" "$isolation_report_ok" "$final"
fi
if [ "$case_name" = branch-pi ]; then shared_ok=0; grep -qi -E 'shared|collide|conflict' "$final" || shared_ok=1; check "final warns shared checkout" "$shared_ok" "$final"; fi
completion_ok=0; ! grep -qi -E 'plan (is )?(complete|finished|done)|all tasks (complete|done)' "$final" || completion_ok=1; check "final does not claim plan completion" "$completion_ok" "$final"
printf '\n%s: %d passed, %d failed\n' "$case_name" "$pass" "$fail"
[ "$fail" -eq 0 ]
