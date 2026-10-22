#!/usr/bin/env bash
# Lints the shell code: ./test/lint.sh   (needs shellcheck: https://www.shellcheck.net)
# Note: zsh is not supported by shellcheck, so shell/hey-shell.zsh is only parsed with `zsh -n`.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
command -v shellcheck >/dev/null || { echo "shellcheck is not installed: https://www.shellcheck.net" >&2; exit 2; }
status=0
shellcheck -x -S warning bin/hey-shell install.sh docs/install lib/*.sh shell/hey-shell.bash test/*.sh test/eval/run.sh || status=1
if command -v zsh >/dev/null; then zsh -n shell/hey-shell.zsh || status=1; fi
exit "$status"
