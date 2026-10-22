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

# The labeled box and "Risk: ... · Check: ..." for the command. The check is on by default (turn off with HEY_SHELL_CHECK=0)
# and never runs the command.
_hey_shell_status() {
  local names=''
  [ "${HEY_SHELL_CHECK:-1}" = 0 ] || names=$(compgen -A alias -A function)
  printf '%s\n' "$(COLUMNS=${COLUMNS:-} HEY_SHELL_COLOR=always HEY_SHELL_TARGET=bash HEY_SHELL_KNOWN_NAMES=$names "$_hey_shell_bin" --status "$1")"
}

# _hey_shell_generate <request>: sets _hey_shell_cmd to the generated command, or prints the error and fails
_hey_shell_generate() {
  local errf
  _hey_shell_cmd=''
  errf=$(mktemp)
  printf '\n\033[2m[hey-shell] thinking...\033[0m'   # replaced below by the result or the error
  _hey_shell_cmd=$(HEY_SHELL_TARGET=bash "$_hey_shell_bin" "$1" 2>"$errf") || {
    printf '\r\033[K\033[31m%s\033[0m\n' "$(cat "$errf")"
    rm -f "$errf"
    return 1
  }
  printf '\r\033[K'
  rm -f "$errf"
  [ -n "$_hey_shell_cmd" ]
}

_hey_shell_fill() {
  [ -n "$READLINE_LINE" ] || return
  _hey_shell_generate "$READLINE_LINE" || return
  READLINE_LINE=$_hey_shell_cmd
  READLINE_POINT=${#_hey_shell_cmd}
  _hey_shell_status "$_hey_shell_cmd"
}

# bash 3.2 (macOS's /bin/bash) has no READLINE_LINE, so a key binding can neither read nor replace the line.
# There the key is a macro instead: insert-comment (M-#) turns the request into a comment and accepts it, so it
# is saved to history but never run; then \C-x\C-^ calls this, which reads the request back from history,
# removes it again, and puts the command on the new prompt the way `hse` does.
_hey_shell_fill_legacy() {
  local num entry
  read -r num entry <<< "$(HISTTIMEFORMAT='' history 1)"
  case $entry in
    '#'*) history -d "$num" ;;
    *) printf 'hey-shell: could not read your request back from history (is history turned off?)\n'; return ;;
  esac
  entry=${entry#\#}
  entry=${entry#"${entry%%[![:space:]]*}"}
  [ -n "$entry" ] || return
  _hey_shell_generate "$entry" || return
  _hey_shell_status "$_hey_shell_cmd"
  _hey_shell_prefill "$_hey_shell_cmd"
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
# `hey-shell --fix` does the same for a corrected version of your last command (taken from history, with its
# exit status), unless you pass a command.
hey-shell() {
  local last_status=$? last='' line
  case "${1:-}" in
    -e|--explain|--fix)
      local out names='' color=never cmdfile
      if [ "$1" = --fix ] && [ $# = 1 ]; then
        while IFS= read -r line; do
          line=${line#"${line%%[![:space:]]*}"}
          case $line in *--fix*|'#'*|'') continue ;; esac   # '#...': a request the key put in history
          case $(alias "${line%% *}" 2>/dev/null) in *--fix*) continue ;; esac   # an alias such as hsf
          last=$line
        done <<< "$(fc -ln -10 -1 2>/dev/null)"
      fi
      [ -t 1 ] && color=always
      [ "${HEY_SHELL_CHECK:-1}" = 0 ] || names=$(compgen -A alias -A function)
      cmdfile=$(mktemp)
      out=$(HEY_SHELL_LAST_CMD=$last HEY_SHELL_LAST_STATUS=${last:+$last_status} HEY_SHELL_COLOR=$color \
        HEY_SHELL_CMD_FILE=$cmdfile HEY_SHELL_KNOWN_NAMES=$names "$_hey_shell_bin" "$@") || { local st=$?; rm -f "$cmdfile"; return $st; }
      printf '%s\n' "$out"
      _hey_shell_prefill "$(cat "$cmdfile")"
      rm -f "$cmdfile" ;;
    *) "$_hey_shell_bin" "$@" ;;
  esac
}

if [[ $- == *i* ]]; then
  if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
    bind -x "\"$(_hey_shell_keyseq)\": _hey_shell_fill"
  else
    bind -x '"\C-x\C-^": _hey_shell_fill_legacy'
    bind "\"$(_hey_shell_keyseq)\": \"\\e#\\C-x\\C-^\""
  fi
fi
