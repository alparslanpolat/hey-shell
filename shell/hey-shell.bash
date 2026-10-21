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

_hey_shell_warn() {
  local risk level reason
  risk=$("$_hey_shell_bin" --risk "$1")
  level=${risk%%$'\n'*}
  reason=${risk#*$'\n'}
  case $level in
    high)   printf '\n\033[1;31m[hey-shell] HIGH RISK: %s. Read it carefully before pressing Enter.\033[0m\n' "$reason" ;;
    medium) printf '\n\033[33m[hey-shell] Caution: %s.\033[0m\n' "$reason" ;;
  esac
}

_hey_shell_fill() {
  local request=$READLINE_LINE cmd
  [ -z "$request" ] && return
  local errf
  errf=$(mktemp)
  cmd=$(HEY_SHELL_TARGET=bash "$_hey_shell_bin" "$request" 2>"$errf") || {
    printf '\n\033[31m%s\033[0m\n' "$(cat "$errf")"
    rm -f "$errf"
    return
  }
  rm -f "$errf"
  [ -z "$cmd" ] && return
  READLINE_LINE=$cmd
  READLINE_POINT=${#cmd}
  _hey_shell_warn "$cmd"
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
      local out
      out=$(command hey-shell "$@") || return $?
      printf '%s\n' "$out"
      _hey_shell_prefill "${out%%$'\n'*}" ;;
    *) command hey-shell "$@" ;;
  esac
}

[[ $- == *i* ]] && bind -x "\"$(_hey_shell_keyseq)\": _hey_shell_fill"
