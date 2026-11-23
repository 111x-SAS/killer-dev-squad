#!/usr/bin/env bash
# Prints one step's self-contained spec: role, rubric, brief and run details pasted in,
# because a worker cannot read outside its workspace.
#
#   compose-spec.sh <run_id> <pipeline> <step> <role> <brief_file> <range> [focus] [reports_csv] [work_order_file]
#
# Pass "" for an optional argument you skip.
set -euo pipefail

if [ $# -lt 6 ]; then
  sed -n '2,7p' "$0" >&2
  exit 2
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
run=$1 pipeline=$2 step=$3 role=$4 brief=$5 range=$6 focus=${7:-} reports=${8:-} order=${9:-}
dir=".kds/runs/$run/reports"

[ -f "$here/roles/$role.md" ] || { echo "unknown role: $role" >&2; exit 1; }
[ -f "$brief" ] || { echo "brief not found: $brief" >&2; exit 1; }
[ -z "$order" ] || [ -f "$order" ] || { echo "work order not found: $order" >&2; exit 1; }

echo "You are step \`$step\` of the \`$pipeline\` pipeline, Killer Dev Squad run $run. Everything you need is in this task and in your workspace; read nothing outside it."
echo
cat "$here/roles/$role.md"
[ -z "$focus" ] || printf '\nYour focus: **%s**.\n' "$focus"

case $role in
  scorer | consensus | auditor) printf '\n---\n\n'; cat "$here/rubric.md" ;;
  profiler) printf '\n---\n\n# Profile template\n\n'; cat "$here/project-template.md" ;;
esac

printf '\n---\n\n# Brief\n\n'
cat "$brief"
if [ -n "$order" ]; then
  printf '\n---\n\n# Work order\n\n'
  cat "$order"
fi

printf '\n---\n\n# This run\n\n- Run id: %s\n- Step: %s\n- Range: %s\n' "$run" "$step" "$range"
if [ -n "$reports" ]; then
  echo "- Reports you may read, and no others: $(echo "$reports" | sed "s|[^,][^,]*|\`$dir/&.md\`|g; s|,|, |g")"
else
  echo "- Do not read any file in \`$dir/\`."
fi
echo "- Write your report at \`$dir/$step.md\` (relative to the workspace root)."
if [ "$role" != profiler ]; then
  echo "- If \`.kds/project.md\` does not exist, stop and report the task as failed: the project needs the \`onboard\` pipeline first."
  echo "- This may be a fresh workspace: before you run a check command, run the profile's setup commands if they have not been run here. Never run anything the profile lists under Do not touch."
fi
echo "- If this step was started before and interrupted, the workspace may hold its unfinished work (uncommitted changes, a partial report). Look first, and continue from it instead of starting over."
echo

case $role in
  scorer | consensus)
    echo "You are done when that file exists and ends in a valid \`quality-score\` block. A check command that fails is evidence to report, not a failed task. In your worker_done pass the report path with --report-path and put in the body the full \`quality-score\` block, fenced, and one line saying whether the score meets the profile target score." ;;
  implementer | test-engineer | reproducer | fixer | profiler | spec-writer)
    echo "You are done when that file exists and your commit is on the branch. In your worker_done pass the report path with --report-path and put in the body: the commit hash, the branch, and everything your coordinator must pass on to the owner (open questions, what you left out and why). Your coordinator cannot open the report." ;;
  *)
    echo "You are done when that file exists. In your worker_done pass the report path with --report-path and put the report itself in the body: your coordinator cannot open the file. If it runs past 150 lines, send its first line, every critical, major or blocking finding with its evidence, and its last line." ;;
esac
