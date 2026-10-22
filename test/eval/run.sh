#!/usr/bin/env bash
# Evaluates the commands the model generates for test/eval/requests.tsv. Calls the real agent, so it costs
# usage and takes a few minutes; it is not part of test/run.sh or CI.
#   ./test/eval/run.sh                  all requests with the default model
#   HEY_SHELL_MODEL=sonnet ./test/eval/run.sh
#   HEY_SHELL_AGENT=codex ./test/eval/run.sh   (results are named <date>-<agent>-<model>.tsv for other agents)
#   ./test/eval/run.sh net- git-        only the requests whose id starts with one of these
# Each command is scored on:
#   valid     a single command came back (hey-shell exited 0)
#   parses    the target shell parses it
#   correct   it matches the request's pattern (the essential tool or flag)
#   portable  on macOS, no GNU-only flags (sed -i without a suffix, grep -P, date -d, find -printf, ...)
#   safe      its risk is no higher than the request's ceiling
#   no issues the failure check finds no known problem (a missing program usually means a wrong tool)
# Requests run in an empty folder with project context off, so results compare across machines and models.
# Results go to test/eval/results/<date>-<model>.tsv; the summary is printed.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bin="$root/bin/hey-shell"
agent="${HEY_SHELL_AGENT:-claude}"
if [ "$agent" = claude ]; then model="${HEY_SHELL_MODEL:-haiku}"; else model="$agent-${HEY_SHELL_MODEL:-default}"; fi
shell_name="${HEY_SHELL_TARGET:-bash}"

# GNU-only spellings that fail or behave differently with the BSD tools on macOS
gnu_only='sed[[:space:]]+-i[[:space:]]+(-e[[:space:]]|["'"'"']?s[/|#])|grep[[:space:]]+(-[[:alnum:]]*P|--perl)|date[[:space:]].*-d[[:space:]]|date[[:space:]].*--date|find[[:space:]].*-printf|stat[[:space:]]+-c|du[[:space:]].*--max-depth|ps[[:space:]].*--sort|(^|[^[:alnum:]_])(free|nproc|lscpu|ss|ip)[[:space:]]|readlink[[:space:]]+-f[[:space:]].*-m|xargs[[:space:]]+-[[:alnum:]]*d'

# one <id> <request> <pattern> <max risk>: prints one tab-separated result line
one() {
  local id=$1 request=$2 pattern=$3 max=$4 work cmd status=0 parses=no correct=no portable=yes safe=no risk check
  work="$(mktemp -d)"
  cmd="$(cd "$work" && HEY_SHELL_CONTEXT=0 HEY_SHELL_HISTORY=0 HEY_SHELL_UPDATE_CHECK=0 HEY_SHELL_TARGET="$shell_name" \
    "$bin" "$request" 2>&1)" || status=$?
  rm -rf "$work"
  cmd="$(printf '%s' "$cmd" | tr '\t\n' '  ')"
  if [ "$status" -ne 0 ]; then
    printf '%s\tno\tno\tno\tno\tno\tno\t-\t%s\n' "$id" "$cmd"
    return
  fi
  "$shell_name" -n -c "$cmd" 2>/dev/null && parses=yes
  printf '%s' "$cmd" | grep -Eiq -- "$pattern" && correct=yes
  [ "$(uname -s)" != Darwin ] || ! printf '%s' "$cmd" | grep -Eq -- "$gnu_only" || portable=no
  risk="$("$bin" --risk "$cmd" | head -1)"
  rank() { case $1 in low) echo 0 ;; medium) echo 1 ;; *) echo 2 ;; esac; }
  [ "$(rank "$risk")" -le "$(rank "$max")" ] && safe=yes
  check="$(HEY_SHELL_TARGET="$shell_name" "$bin" --check "$cmd" | head -1)"
  printf '%s\tyes\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$parses" "$correct" "$portable" "$safe" \
    "$([ "$check" = ok ] && echo yes || echo no)" "$risk" "$cmd"
}

if [ "${1:-}" = --one ]; then # worker for the parallel run below
  shift
  one "$@"
  exit 0
fi

prefixes=("$@")
mkdir -p "$root/test/eval/results"
out="$root/test/eval/results/$(date +%Y-%m-%d)-$model.tsv"
printf 'id\tvalid\tparses\tcorrect\tportable\tsafe\tno_issues\trisk\tcommand\n' > "$out"

grep -v '^#' "$root/test/eval/requests.tsv" | sed '/^$/d' | while IFS=$'\t' read -r id request pattern max; do
  if [ ${#prefixes[@]} -gt 0 ]; then
    keep=0
    for p in "${prefixes[@]}"; do case $id in "$p"*) keep=1 ;; esac; done
    [ "$keep" = 1 ] || continue
  fi
  printf '%s\0%s\0%s\0%s\0' "$id" "$request" "$pattern" "$max"
done | xargs -0 -n 4 -P "${EVAL_JOBS:-4}" "$0" --one | sort >> "$out"

total=$(($(wc -l < "$out") - 1))
[ "$total" -gt 0 ] || { echo "no requests matched"; exit 1; }
printf 'model %s, shell %s, %s on %s: %d requests\n\n' "$model" "$shell_name" "$(uname -s)" "$(date +%Y-%m-%d)" "$total"
for col in 2 3 4 5 6 7; do
  awk -F'\t' -v c="$col" 'NR == 1 { name = $c; next } $c == "yes" { n++ } END { printf "  %-10s %3d/%d  %3.0f%%\n", name, n, NR - 1, 100 * n / (NR - 1) }' "$out"
done
printf '\nmisses (%s):\n' "${out#"$root"/}"
awk -F'\t' 'NR > 1 { miss = ""; for (c = 2; c <= 7; c++) if ($c != "yes") { split("x valid parses correct portable safe no_issues", h, " "); miss = miss " " h[c] }
  if (miss != "") printf "  %-22s%s\n      %s\n", $1, miss, $9 }' "$out"
