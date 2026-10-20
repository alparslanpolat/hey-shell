# hey-shell for bash: press Ctrl+G (override with HEY_SHELL_KEY) to replace the
# typed request with a generated command. The command is never executed.
_hey_shell_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/hey-shell"

_hey_shell_fill() {
  local request=$READLINE_LINE cmd
  [ -z "$request" ] && return
  cmd=$(HEY_SHELL_TARGET=bash "$_hey_shell_bin" "$request") || return
  [ -z "$cmd" ] && return
  READLINE_LINE=$cmd
  READLINE_POINT=${#cmd}
  if "$_hey_shell_bin" --danger "$cmd"; then
    printf '\n[hey-shell] this command looks destructive, review before running\n'
  fi
}

[[ $- == *i* ]] && bind -x "\"${HEY_SHELL_KEY:-\C-g}\": _hey_shell_fill"
