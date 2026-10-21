#!/usr/bin/env bash
# Runs every test suite: ./test/run.sh   (exit 1 if any suite fails; a failing suite prints its full output)
set -u
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
status=0
for suite in risk cli check install; do
  printf '%-8s ' "$suite"
  if out=$("$dir/$suite.test.sh" 2>&1); then
    printf '%s\n' "$out" | tail -1
  else
    status=1
    printf 'FAILED\n%s\n' "$out"
  fi
done
exit "$status"
