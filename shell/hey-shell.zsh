# hey-shell for zsh: press Ctrl+G (override with HEY_SHELL_KEY) to replace the
# typed request with a generated command. The command is never executed.
_hey_shell_bin="${${(%):-%x}:A:h:h}/bin/hey-shell"

_hey_shell_fill() {
  local request=$BUFFER cmd
  [[ -z $request ]] && return
  zle -R "hey-shell: thinking..."
  cmd=$(HEY_SHELL_TARGET=zsh "$_hey_shell_bin" "$request") || { zle -M "hey-shell: failed"; return }
  [[ -z $cmd ]] && return
  BUFFER=$cmd
  CURSOR=${#BUFFER}
  if "$_hey_shell_bin" --danger "$cmd"; then
    zle -M "hey-shell: this command looks destructive, review before running"
  fi
}

zle -N _hey_shell_fill
bindkey "${HEY_SHELL_KEY:-^G}" _hey_shell_fill
