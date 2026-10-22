#!/usr/bin/env bash
# Drives real interactive bash and zsh with the hey-shell integration loaded, against a fake `claude`:
#   ./test/shell.test.sh   (exit 1 on any mismatch)
# Each check types into the shell and looks for the file that the command it ends up running creates, so it covers
# the key binding replacing the line, `hse` leaving the command on the next prompt, and `hsf` finding the
# failed command in history.
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0 total=0

# Fake CLI: answers with a command that creates $tmp/ran-fixed, $tmp/ran-explained or $tmp/ran-generated,
# depending on the kind of prompt; the prompt is kept in $tmp/prompt.
cat > "$tmp/claude" <<FAKE
#!/bin/sh
for last; do :; done
printf '%s' "\$last" > "$tmp/prompt"
case \$last in
  *"This command failed"*) printf 'touch $tmp/ran-fixed\n\nFixed it.\n' ;;
  *"Reply in this exact format"*) printf 'touch $tmp/ran-explained\n\nSays something.\n' ;;
  *) printf 'touch $tmp/ran-generated\n' ;;
esac
FAKE
chmod +x "$tmp/claude"

ok() { total=$((total + 1)); if ! eval "$1"; then printf 'FAIL %s\n' "$2"; fail=$((fail + 1)); fi; }
ran() { [ -e "$tmp/ran-$1" ]; } # the command the fake answered with was run

# session <shell path> <lines to type...>: an interactive shell with hey-shell loaded; what it printed is in
# $tmp/session.log
session() {
  local sh=$1 cmd
  shift
  rm -f "$tmp"/ran-*
  case $sh in
    *bash) cmd=("$sh" --norc --noprofile -i) ;;
    *zsh)  cmd=("$sh" -f -i) ;;
  esac
  { printf "source '%s/shell/hey-shell.%s'; PS1='> '\n" "$root" "${sh##*/}"; printf '%s\n' "$@" exit; } \
    | env TERM=xterm-256color HISTFILE="$tmp/history" HEY_SHELL_CLAUDE="$tmp/claude" HEY_SHELL_UPDATE_CHECK=0 \
        HEY_SHELL_HISTORY=0 HEY_SHELL_CONTEXT=0 PTY_STEP_DELAY="${PTY_STEP_DELAY:-1.5}" \
        python3 -I "$root/test/pty_run.py" "${cmd[@]}" > "$tmp/session.log" 2>&1
}

# every bash on the machine (macOS ships 3.2, which has no READLINE_LINE and uses a fallback) and zsh
shells=$( { command -v bash; ls /bin/bash /usr/bin/bash /usr/local/bin/bash /opt/homebrew/bin/bash 2>/dev/null; command -v zsh; } | awk '!seen[$0]++')
for sh in $shells; do
  [ -x "$sh" ] || continue
  name="$sh $("$sh" -c 'echo ${BASH_VERSION:-$ZSH_VERSION}')"

  # the request itself is valid shell that would leave a file behind: the key must never run it
  session "$sh" "touch $tmp/ran-request"$'\a\x1f'   # \x1f: pause before Enter, so the command can land first
  ok 'ran generated' "$name: the key replaces the request with the command, and Enter runs it"
  ok '! ran request' "$name: the key never runs the request itself"

  session "$sh" 'hey-shell -e say hi' ''
  ok 'ran explained' "$name: hey-shell -e leaves the command on the next prompt"

  session "$sh" "alias hsf='hey-shell --fix'" 'gti status' 'hsf' ''
  ok 'ran fixed' "$name: hsf leaves the fix on the next prompt"
  ok 'grep -q "This command failed: gti status It exited with status 127" "$tmp/prompt"' "$name: hsf sends the failed command and its exit status"
done

echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
