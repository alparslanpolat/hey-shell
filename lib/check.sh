# shellcheck shell=bash
# shellcheck disable=SC2034  # the results are globals read by bin/hey-shell
# Predicts whether a generated command would fail, without running it. Sourced by bin/hey-shell.
#   hey_shell_check "<command>"  sets HEY_SHELL_CHECK_LEVEL (ok|fail) and HEY_SHELL_CHECK_REASON.
# The command is only parsed (`bash -n` / `zsh -n`). A few read-only probes look at the environment
# (`tmux list-sessions`, `git rev-parse`, the docker socket). It is a prediction, not a guarantee:
# it cannot know about missing files, permissions, or what a program does with its arguments.
# Env: HEY_SHELL_TARGET (bash|zsh), HEY_SHELL_KNOWN_NAMES (newline list of the caller's aliases and functions)

_hs_word='' _hs_have=0 _hs_at_cmd=1 _hs_skip_seg=0 _hs_defined=''

# Finish the word being read; print it when it is the program name of a simple command.
_hs_emit_word() {
  [ "$_hs_have" = 1 ] || return 0
  local w=$_hs_word
  _hs_word='' _hs_have=0
  [ "$_hs_at_cmd" = 1 ] || return 0
  if [ "$_hs_skip_seg" = 1 ]; then # after a wrapper such as sudo: options make the real command hard to find
    case $w in -*) _hs_at_cmd=0; return 0 ;; esac
    _hs_skip_seg=0
  fi
  case $w in
    *=*) return 0 ;;                                  # VAR=value prefix
    sudo|env|time|nohup|command|exec|nice) _hs_skip_seg=1; return 0 ;; # wrapper: the next word is the program
    if|then|else|elif|do|while|until|'!'|'{') return 0 ;;   # keyword: the next word is the command
  esac
  printf '%s\n' "$w"
  _hs_at_cmd=0
}

# $1 = string, $2 = index of an opening parenthesis; sets _hs_end to the index of its matching close.
_hs_skip_parens() {
  local s=$1 j=$2 depth=0 n=${#1} c
  while [ "$j" -lt "$n" ]; do
    c=${s:$j:1}
    case $c in
      '(') depth=$((depth + 1)) ;;
      ')') depth=$((depth - 1)); [ "$depth" -gt 0 ] || break ;;
    esac
    j=$((j + 1))
  done
  _hs_end=$j
}

# Print the program name of every simple command in $1, one per line.
# Arithmetic ($((...)), ((...)), for ((...))) and array literals (a=(...)) are skipped as opaque text:
# their contents are not commands.
_hs_command_words() {
  local s=$1 n=${#1} i=0 c prev='' next='' q=''
  _hs_word='' _hs_have=0 _hs_at_cmd=1 _hs_skip_seg=0
  while [ "$i" -lt "$n" ]; do
    c=${s:$i:1}
    next=${s:$((i + 1)):1}
    if [ -n "$q" ]; then
      if [ "$c" = "$q" ]; then q=''
      elif [ "$q" = '"' ] && [ "$c" = '\' ]; then i=$((i + 1)); _hs_word="$_hs_word${s:$i:1}"
      elif [ "$q" = '"' ] && [ "$c" = '$' ] && [ "$next" = '(' ]; then   # "$(cmd "arg")": opaque, not checked
        _hs_skip_parens "$s" "$((i + 1))"; i=$_hs_end; _hs_word="$_hs_word\$(..)"
      else _hs_word="$_hs_word$c"; fi
    else
      case $c in
        '\') i=$((i + 1)); _hs_word="$_hs_word${s:$i:1}"; _hs_have=1 ;;
        "'"|'"') q=$c; _hs_have=1 ;;
        '$') if [ "$next" = '(' ] && [ "${s:$((i + 2)):1}" = '(' ]; then
               _hs_skip_parens "$s" "$((i + 1))"; i=$_hs_end; _hs_word="$_hs_word\$((..))"; _hs_have=1
             else _hs_word="$_hs_word$c"; _hs_have=1; fi ;;
        '(') if [ "$next" = '(' ] || [ "$prev" = '=' ]; then
               _hs_skip_parens "$s" "$i"; i=$_hs_end
               if [ "$prev" = '=' ]; then _hs_word="$_hs_word(..)"; _hs_have=1   # a=(1 2 3)
               else _hs_have=0; _hs_word=''; _hs_at_cmd=0; fi                    # (( n++ )), for ((...))
             elif [ "$prev" = '<' ] || [ "$prev" = '>' ]; then                  # <(cmd) and >(cmd)
               _hs_word=${_hs_word%[<>]}; [ -n "$_hs_word" ] || _hs_have=0
               _hs_emit_word; _hs_at_cmd=1; _hs_skip_seg=0
             else _hs_emit_word; _hs_at_cmd=1; _hs_skip_seg=0; fi ;;
        ' '|$'\t') _hs_emit_word ;;
        '&') if [ "$prev" = '>' ] || [ "$prev" = '<' ] || [ "$next" = '>' ]; then
               _hs_word="$_hs_word$c"; _hs_have=1       # redirection such as 2>&1 or &>file
             else _hs_emit_word; _hs_at_cmd=1; _hs_skip_seg=0; fi ;;
        '|'|';'|$'\n'|')'|'`') _hs_emit_word; _hs_at_cmd=1; _hs_skip_seg=0 ;;
        *) _hs_word="$_hs_word$c"; _hs_have=1 ;;
      esac
    fi
    prev=$c
    i=$((i + 1))
  done
  _hs_emit_word
}

# 0 when $1 is something the caller's shell can run: program, builtin, keyword, alias or function.
_hs_word_exists() {
  local w=$1
  case $w in *'$'*|*'*'*|*'?'*|*'~'*) return 0 ;; esac # expanded at run time, cannot judge
  case $w in */*) [ -x "$w" ]; return ;; esac
  if [ "${HEY_SHELL_TARGET:-bash}" = zsh ] && command -v zsh >/dev/null 2>&1; then
    zsh -fc 'whence -w -- "$1" >/dev/null 2>&1' _ "$w" && return 0
  else
    [ -n "$(type -t -- "$w" 2>/dev/null || true)" ] && return 0
  fi
  [ -n "$_hs_defined" ] && printf '%s\n' "$_hs_defined" | grep -Fxq -- "$w" && return 0
  [ -n "${HEY_SHELL_KNOWN_NAMES:-}" ] && printf '%s\n' "$HEY_SHELL_KNOWN_NAMES" | grep -Fxq -- "$w"
}

_hs_fail() {
  HEY_SHELL_CHECK_LEVEL=fail
  HEY_SHELL_CHECK_REASON=$1
}

hey_shell_check() {
  local cmd=$1 words w err shell_name="${HEY_SHELL_TARGET:-bash}"
  HEY_SHELL_CHECK_LEVEL=ok
  HEY_SHELL_CHECK_REASON=""

  # 1. does it parse?
  if [ "$shell_name" = zsh ] && command -v zsh >/dev/null 2>&1; then
    err=$(zsh -n -c "$cmd" 2>&1 >/dev/null) || { _hs_fail "syntax error: $(printf '%s' "$err" | head -1)"; return 0; }
  else
    err=$(bash -n -c "$cmd" 2>&1 >/dev/null) || { _hs_fail "syntax error: $(printf '%s' "$err" | head -1 | sed 's/^bash: -c: //')"; return 0; }
  fi

  # 2. do the programs exist? (not judged for `case`, whose patterns look like commands)
  words=$(_hs_command_words "$cmd")
  _hs_defined=$({ printf '%s' "$cmd" | grep -Eo '[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*\(\)' | sed -E 's/[[:space:]]*\(\)$//'
                  printf '%s' "$cmd" | grep -Eo 'function[[:space:]]+[A-Za-z_][A-Za-z0-9_-]*' | sed -E 's/^function[[:space:]]+//'; } || true)
  if ! printf '%s' "$cmd" | grep -Eq '(^|[;&|({[:space:]])case[[:space:]]'; then
    while IFS= read -r w; do
      [ -n "$w" ] || continue
      _hs_word_exists "$w" || { _hs_fail "'$w' not found (not in PATH, not an alias or function)"; return 0; }
    done <<< "$words"
  fi

  # 3. is the environment right for the tools it uses?
  if printf '%s\n' "$words" | grep -qx tmux && [ -z "${TMUX:-}" ] \
     && ! printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_-])(new|new-session|attach|attach-session|start-server|-V)([^[:alnum:]_-]|$)' \
     && ! tmux list-sessions >/dev/null 2>&1; then
    _hs_fail "no tmux server is running; start tmux first"; return 0
  fi
  if printf '%s\n' "$words" | grep -qx git \
     && ! printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+(-C|clone|init|--version|version|help|config[[:space:]]+--global|ls-remote)([[:space:]]|$)' \
     && ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _hs_fail "not inside a git repository ($PWD)"; return 0
  fi
  if printf '%s\n' "$words" | grep -Eqx 'docker|docker-compose' \
     && [ -z "${DOCKER_HOST:-}" ] && [ -z "${DOCKER_CONTEXT:-}" ] \
     && [ ! -S /var/run/docker.sock ] && [ ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/docker.sock" ]; then
    _hs_fail "docker daemon socket not found (is docker running?)"; return 0
  fi
  return 0
}
