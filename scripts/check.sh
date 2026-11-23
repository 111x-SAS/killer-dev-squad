#!/usr/bin/env bash
# Checks the pipeline engine for broken references before a bot runs into them:
# every step's role and tier, its deps and reports, `use:` and the goal loop,
# and that compose-spec.sh builds every step. Exits 1 if anything is wrong.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill="$root/skills/kds-pipeline"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
: > "$tmp/errors"
# Errors go to a file: some are found inside pipes, which run in subshells.
fail() { echo "$*" >> "$tmp/errors"; }

tiers=$(awk '/^tiers:/ { t = 1; next } t && /^[^ #]/ { t = 0 } t && /^  [a-z]+:/ { sub(/^  /, ""); sub(/:.*/, ""); print }' "$skill/agent.yaml")
has_tier() { echo "$tiers" | grep -qx "$1"; }

# One line per step: name|role|tier|deps|reports|focus|workOrder, or use|<pipeline>.
steps() {
  awk '
    function flush() { if (n != "") print n "|" r "|" t "|" d "|" p "|" f "|" w; n = r = t = d = p = f = w = "" }
    function list(s) { sub(/^[^[]*\[/, "", s); sub(/\].*/, "", s); gsub(/ /, "", s); return s }
    /^goal:/          { flush(); exit }
    /^  - use:/       { flush(); s = $0; sub(/.*use: */, "", s); sub(/ *#.*/, "", s); print "use|" s; next }
    /^  - name:/      { flush(); n = $3; next }
    /^    role:/      { r = $2 }
    /^    tier:/      { t = $2 }
    /^    focus:/     { f = $2 }
    /^    deps:/      { d = list($0) }
    /^    reports:/   { p = list($0) }
    /^    workOrder:/ { w = "yes" }
    END { flush() }' "$1"
}

# A pipeline's steps, with each `use:` replaced in place by the steps of the pipeline it names.
expand() {
  local file="$skill/pipelines/$1.yaml" line
  [ -f "$file" ] || { fail "$2: uses unknown pipeline '$1'"; return 0; }
  steps "$file" | while IFS= read -r line; do
    case $line in
      use\|*) expand "${line#use|}" "$1" ;;
      *) echo "$line" ;;
    esac
  done
}

echo "Test brief." > "$tmp/brief.md"
echo "Test work order." > "$tmp/order.md"
count=0

for file in "$skill"/pipelines/*.yaml; do
  p=$(basename "$file" .yaml)
  grep -qx "name: $p" "$file" || fail "$p: its name does not match its file name"
  expand "$p" "$p" > "$tmp/steps"
  names=$(cut -d'|' -f1 "$tmp/steps")
  [ -n "$names" ] || fail "$p: has no steps"
  dup=$(echo "$names" | sort | uniq -d | tr '\n' ' ')
  [ -z "$dup" ] || fail "$p: step names repeat: $dup"

  while IFS='|' read -r name role tier deps reports focus order; do
    count=$((count + 1))
    [ -f "$skill/roles/$role.md" ] || { fail "$p/$name: unknown role '$role'"; continue; }
    has_tier "$tier" || fail "$p/$name: unknown tier '$tier'"
    for ref in ${deps//,/ } ${reports//,/ }; do
      echo "$names" | grep -qx "$ref" || fail "$p/$name: refers to unknown step '$ref'"
    done
    work=""
    [ -z "$order" ] || work="$tmp/order.md"
    if "$skill/compose-spec.sh" run_check "$p" "$name" "$role" "$tmp/brief.md" main "$focus" "$reports" "$work" > "$tmp/spec" 2> "$tmp/stderr"; then
      grep -qF "$(head -1 "$skill/roles/$role.md")" "$tmp/spec" || fail "$p/$name: the spec is missing its role"
      grep -qF "Test brief." "$tmp/spec" || fail "$p/$name: the spec is missing its brief"
    else
      fail "$p/$name: compose-spec.sh failed: $(cat "$tmp/stderr")"
    fi
  done < "$tmp/steps"

  if grep -q '^goal:' "$file"; then
    fix_role=$(sed -n 's/^  fix:.*role: *\([a-z-]*\).*/\1/p' "$file")
    fix_tier=$(sed -n 's/^  fix:.*tier: *\([a-z]*\).*/\1/p' "$file")
    measure=$(sed -n 's/^  measure: *\([a-z-]*\).*/\1/p' "$file")
    [ -f "$skill/roles/$fix_role.md" ] || fail "$p/goal: unknown fix role '$fix_role'"
    has_tier "$fix_tier" || fail "$p/goal: unknown fix tier '$fix_tier'"
    [ -f "$skill/pipelines/$measure.yaml" ] || fail "$p/goal: unknown measure pipeline '$measure'"
    grep -q '^  maxIterations: *[0-9]' "$file" || fail "$p/goal: maxIterations is missing or not a number"
    grep -q '^  plateau: *[0-9]' "$file" || fail "$p/goal: plateau is missing or not a number"
  fi
done

if [ -s "$tmp/errors" ]; then
  echo "Pipeline check failed:" >&2
  sed 's/^/- /' "$tmp/errors" >&2
  exit 1
fi
echo "Pipeline check passed: $(ls "$skill"/pipelines/*.yaml | wc -l | tr -d ' ') pipelines, $count steps."
