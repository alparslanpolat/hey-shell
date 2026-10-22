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

# The labeled box and "Risk: ... · Check: ..." for the command. The check is on by default (turn off with
# HEY_SHELL_CHECK=0) and never runs the command. One column narrower than the terminal, so lines never wrap.
_hey_shell_status_msg() {
  local names=''
  [[ ${HEY_SHELL_CHECK:-1} == 0 ]] || names="$(print -l -- ${(k)aliases} ${(k)functions})"
  COLUMNS=$((COLUMNS - 1)) HEY_SHELL_COLOR=never HEY_SHELL_TARGET=zsh HEY_SHELL_KNOWN_NAMES=$names "$_hey_shell_bin" --status "$1"
}

# Show the status under the prompt line, in color. zle -M cannot color, so the text goes in POSTDISPLAY and is
# colored with region_highlight entries tagged memo=hey-shell (the colors of lib/render.sh, as 256-color numbers).
# It disappears once the line is edited or run.
_hey_shell_shown_for=''
_hey_shell_show() {
  local text=$'\n'$1 line word i s e o=0 base=${#BUFFER}
  local -a hl
  for line in "${(@f)text}"; do
    s=$((base + o)) e=$((base + o + ${#line}))
    case $line in
      'SUGGESTED COMMAND'*) hl+=("$s $e fg=155,bold") ;;
      ['╭╰']*) hl+=("$s $e fg=245") ;;
      '│'*) hl+=("$s $e fg=255,bold" "$s $((s + 1)) fg=245" "$((e - 1)) $e fg=245")
            [[ ${line[3]} == '$' ]] && hl+=("$((s + 2)) $((s + 3)) fg=155,bold") ;;
      'Risk: '*)
        hl+=("$s $e fg=245")
        word=${${line#Risk: }%% *}
        case $word in HIGH) hl+=("$((s + 6)) $((s + 6 + ${#word})) fg=203") ;; MEDIUM) hl+=("$((s + 6)) $((s + 12)) fg=214") ;; esac
        i=${line[(i)Check: ]}
        if (( i <= ${#line} )); then
          [[ ${line[i+7,-1]} == 'No known issues' ]] && hl+=("$((s + i + 6)) $e fg=114") || hl+=("$((s + i + 6)) $e fg=203")
        fi ;;
      'Update available:'*) hl+=("$s $e fg=245" "$s $((s + 17)) fg=155") ;;
      ' '*) hl+=("$s $e fg=245") ;;
    esac
    o=$((o + ${#line} + 1))
  done
  _hey_shell_clear force
  POSTDISPLAY=$text
  region_highlight+=("${hl[@]/%/ memo=hey-shell}")
  _hey_shell_shown_for=$BUFFER
}

# $1 = force: always remove the status; otherwise only once the line no longer holds the command it describes
_hey_shell_clear() {
  [[ -n $_hey_shell_shown_for ]] || return 0
  [[ $1 == force || $BUFFER != "$_hey_shell_shown_for" ]] || return 0
  POSTDISPLAY=''
  region_highlight=("${(@)region_highlight:#*memo=hey-shell}")
  _hey_shell_shown_for=''
}
_hey_shell_on_redraw() { _hey_shell_clear }
_hey_shell_on_finish() { _hey_shell_clear force }

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
  _hey_shell_show "$(_hey_shell_status_msg "$cmd")"
}

# `hey-shell -e ...` explains, then leaves the command on the next prompt, ready to edit or run.
# `hey-shell --fix` does the same for a corrected version of your last command (taken from history, with its
# exit status), unless you pass a command.
hey-shell() {
  local last_status=$? last='' i
  case "${1:-}" in
    -e|--explain|--fix)
      local out names='' color=never cmdfile
      if [[ $1 == --fix && $# == 1 ]]; then
        local -a recent=("${(@f)$(fc -ln -10 -1 2>/dev/null)}")
        for (( i = ${#recent}; i > 0; i-- )); do   # skip the line that called us, also through an alias like hsf
          [[ ${recent[i]} == *--fix* || ${aliases[${recent[i]%% *}]} == *--fix* ]] || { last=${recent[i]}; break }
        done
      fi
      [[ -t 1 ]] && color=always
      [[ ${HEY_SHELL_CHECK:-1} == 0 ]] || names="$(print -l -- ${(k)aliases} ${(k)functions})"
      cmdfile=$(mktemp)
      out=$(HEY_SHELL_LAST_CMD=$last HEY_SHELL_LAST_STATUS=${last:+$last_status} HEY_SHELL_COLOR=$color \
        HEY_SHELL_CMD_FILE=$cmdfile HEY_SHELL_KNOWN_NAMES=$names command hey-shell "$@") || { local st=$?; rm -f "$cmdfile"; return $st }
      print -r -- "$out"
      [[ -s $cmdfile ]] && print -rz -- "$(<$cmdfile)"
      rm -f "$cmdfile" ;;
    *) command hey-shell "$@" ;;
  esac
}

zle -N _hey_shell_fill
autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-pre-redraw _hey_shell_on_redraw
add-zle-hook-widget line-finish _hey_shell_on_finish
# zsh-autosuggestions also draws in POSTDISPLAY: keep it from replacing the status right after the key
typeset -ga ZSH_AUTOSUGGEST_IGNORE_WIDGETS
ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(_hey_shell_fill)
bindkey "$(_hey_shell_keyseq)" _hey_shell_fill
