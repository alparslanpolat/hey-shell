# shellcheck shell=bash
# hey-shell for bash: press your key (default ctrl+g, set HEY_SHELL_KEY="alt+o" etc.)
# to replace the typed request with a generated command. The command is never executed.
_hey_shell_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/hey-shell"

_hey_shell_keyseq() {
  local k=${HEY_SHELL_KEY:-ctrl+g} l
  l=$(printf '%s' "$k" | tr '[:upper:]' '[:lower:]')
  case $l in
    ctrl+?) printf '\\C-%s' "${l#ctrl+}" ;;
    alt+?)  printf '\\e%s' "${l#alt+}" ;;
    *)      printf '%s' "$k" ;;
  esac
}

# "Risk: ... · Check: ..." under the command. The check is on by default (turn off with HEY_SHELL_CHECK=0)
# and never runs the command.
_hey_shell_status() {
  local names=''
  [ "${HEY_SHELL_CHECK:-1}" = 0 ] || names=$(compgen -A alias -A function)
  printf '%s\n' "$(HEY_SHELL_COLOR=always HEY_SHELL_TARGET=bash HEY_SHELL_KNOWN_NAMES=$names "$_hey_shell_bin" --status "$1")"
}

_hey_shell_fill() {
  local request=$READLINE_LINE cmd
  [ -z "$request" ] && return
  local errf
  errf=$(mktemp)
  printf '\n\033[2m[hey-shell] thinking...\033[0m'   # replaced below by the result or the error
  cmd=$(HEY_SHELL_TARGET=bash "$_hey_shell_bin" "$request" 2>"$errf") || {
    printf '\r\033[K\033[31m%s\033[0m\n' "$(cat "$errf")"
    rm -f "$errf"
    return
  }
  printf '\r\033[K'
  rm -f "$errf"
  [ -z "$cmd" ] && return
  READLINE_LINE=$cmd
  READLINE_POINT=${#cmd}
  _hey_shell_status "$cmd"
}

# Put a single-line command on the next prompt. Readline has no `print -z`, so bind the reply the
# terminal sends to a status query (ESC[5n -> ESC[0n) to a macro that types the command.
_hey_shell_prefill() {
  local cmd=$1
  [[ $- == *i* ]] || return 0
  case $cmd in ''|*$'\n'*) return 0 ;; esac
  cmd=${cmd//\\/\\\\}
  cmd=${cmd//\"/\\\"}
  bind "\"\\e[0n\": \"$cmd\""
  printf '\e[5n'
}

# `hey-shell -e ...` explains, then leaves the command on the next prompt, ready to edit or run.
hey-shell() {
  case "${1:-}" in
    -e|--explain)
      local out names='' color=never cmdfile
      [ -t 1 ] && color=always
      [ "${HEY_SHELL_CHECK:-1}" = 0 ] || names=$(compgen -A alias -A function)
      cmdfile=$(mktemp)
      out=$(HEY_SHELL_COLOR=$color HEY_SHELL_CMD_FILE=$cmdfile HEY_SHELL_KNOWN_NAMES=$names command hey-shell "$@") || { local st=$?; rm -f "$cmdfile"; return $st; }
      printf '%s\n' "$out"
      _hey_shell_prefill "$(cat "$cmdfile")"
      rm -f "$cmdfile" ;;
    *) command hey-shell "$@" ;;
  esac
}

[[ $- == *i* ]] && bind -x "\"$(_hey_shell_keyseq)\": _hey_shell_fill"
