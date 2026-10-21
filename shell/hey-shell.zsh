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

# "Risk: ... · Check: ..." under the command. The check is on by default (turn off with HEY_SHELL_CHECK=0)
# and never runs the command.
_hey_shell_status_msg() {
  local names=''
  [[ ${HEY_SHELL_CHECK:-1} == 0 ]] || names="$(print -l -- ${(k)aliases} ${(k)functions})"
  HEY_SHELL_COLOR=never HEY_SHELL_TARGET=zsh HEY_SHELL_KNOWN_NAMES=$names "$_hey_shell_bin" --status "$1"
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
  zle -M "$(_hey_shell_status_msg "$cmd")"
}

# `hey-shell -e ...` explains, then leaves the command on the next prompt, ready to edit or run.
hey-shell() {
  case "${1:-}" in
    -e|--explain)
      local out names='' color=never cmdfile
      [[ -t 1 ]] && color=always
      [[ ${HEY_SHELL_CHECK:-1} == 0 ]] || names="$(print -l -- ${(k)aliases} ${(k)functions})"
      cmdfile=$(mktemp)
      out=$(HEY_SHELL_COLOR=$color HEY_SHELL_CMD_FILE=$cmdfile HEY_SHELL_KNOWN_NAMES=$names command hey-shell "$@") || { local st=$?; rm -f "$cmdfile"; return $st }
      print -r -- "$out"
      print -rz -- "$(<$cmdfile)"
      rm -f "$cmdfile" ;;
    *) command hey-shell "$@" ;;
  esac
}

zle -N _hey_shell_fill
bindkey "$(_hey_shell_keyseq)" _hey_shell_fill
