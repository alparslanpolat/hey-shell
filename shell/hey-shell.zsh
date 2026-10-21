# hey-shell for zsh: press your key (default ctrl+g, set HEY_SHELL_KEY="alt+o" etc.)
# to replace the typed request with a generated command. The command is never executed.
_hey_shell_bin="${${(%):-%x}:A:h:h}/bin/hey-shell"

_hey_shell_keyseq() {
  local k=${HEY_SHELL_KEY:-ctrl+g}
  local l=${(L)k}
  case $l in
    ctrl+?) print -r -- "^${l#ctrl+}" ;;
    alt+?)  print -r -- "^[${l#alt+}" ;;
    *)      print -r -- "$k" ;;
  esac
}

_hey_shell_risk_msg() {
  local risk=$("$_hey_shell_bin" --risk "$1")
  local level=${risk%%$'\n'*} reason=${risk#*$'\n'}
  case $level in
    high)   print -r -- "hey-shell: HIGH RISK: $reason. Read it carefully before pressing Enter." ;;
    medium) print -r -- "hey-shell: caution: $reason." ;;
  esac
}

# Opt-in (HEY_SHELL_CHECK=1): predict whether the command would fail. Never runs the command.
_hey_shell_check_msg() {
  [[ ${HEY_SHELL_CHECK:-0} == 1 ]] || return 0
  local names="$(print -l -- ${(k)aliases} ${(k)functions})"
  local res=$(HEY_SHELL_TARGET=zsh HEY_SHELL_KNOWN_NAMES=$names "$_hey_shell_bin" --check "$1")
  local level=${res%%$'\n'*} reason=${res#*$'\n'}
  if [[ $level == ok ]]; then
    print -r -- "hey-shell: check ok"
  else
    print -r -- "hey-shell: check: would likely fail: $reason"
  fi
}

_hey_shell_fill() {
  local request=$BUFFER cmd
  [[ -z $request ]] && return
  zle -R "hey-shell: thinking..."
  local errf=$(mktemp)
  cmd=$(HEY_SHELL_TARGET=zsh "$_hey_shell_bin" "$request" 2>"$errf") || {
    zle -M "$(<$errf)"
    rm -f "$errf"
    return
  }
  rm -f "$errf"
  [[ -z $cmd ]] && return
  BUFFER=$cmd
  CURSOR=${#BUFFER}
  local note="$(_hey_shell_risk_msg "$cmd")" chk="$(_hey_shell_check_msg "$cmd")"
  [[ -n $chk ]] && note="${note:+$note$'\n'}$chk"
  [[ -n $note ]] && zle -M "$note"
}

# `hey-shell -e ...` explains, then leaves the command on the next prompt, ready to edit or run.
hey-shell() {
  case "${1:-}" in
    -e|--explain)
      local out names=''
      [[ ${HEY_SHELL_CHECK:-0} == 1 ]] && names="$(print -l -- ${(k)aliases} ${(k)functions})"
      out=$(HEY_SHELL_KNOWN_NAMES=$names command hey-shell "$@") || return $?
      print -r -- "$out"
      print -rz -- "${out%%$'\n'*}" ;;
    *) command hey-shell "$@" ;;
  esac
}

zle -N _hey_shell_fill
bindkey "$(_hey_shell_keyseq)" _hey_shell_fill
