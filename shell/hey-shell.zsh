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

_hey_shell_warn() {
  local risk=$("$_hey_shell_bin" --risk "$1")
  local level=${risk%%$'\n'*} reason=${risk#*$'\n'}
  case $level in
    high)   zle -M "hey-shell: HIGH RISK: $reason. Read it carefully before pressing Enter." ;;
    medium) zle -M "hey-shell: caution: $reason." ;;
  esac
}

_hey_shell_fill() {
  local request=$BUFFER cmd
  [[ -z $request ]] && return
  zle -R "hey-shell: thinking..."
  cmd=$(HEY_SHELL_TARGET=zsh "$_hey_shell_bin" "$request") || { zle -M "hey-shell: failed"; return }
  [[ -z $cmd ]] && return
  BUFFER=$cmd
  CURSOR=${#BUFFER}
  _hey_shell_warn "$cmd"
}

zle -N _hey_shell_fill
bindkey "$(_hey_shell_keyseq)" _hey_shell_fill
