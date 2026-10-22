# shellcheck shell=bash
# shellcheck disable=SC2034  # the results are globals read by bin/hey-shell
# Terminal output for bin/hey-shell: color by purpose, wrapping, and the status line. Sourced by bin/hey-shell.
#   hey_shell_colors          sets C_CMD C_MUTED C_AMBER C_RED C_GREEN C_BRAND C_WORD C_OFF (empty when color is off)
#   hey_shell_status          prints "Risk: MEDIUM · Check: No known issues" (or "Risk: none recognized") plus the reasons; run hey_shell_risk (and
#                             hey_shell_check unless HEY_SHELL_CHECK=0) first
#   hey_shell_render_explain  prints the command in a labeled box, the wrapped explanation, a separate warning
# Color is on when stdout is a terminal, or when HEY_SHELL_COLOR=always (the shell integration sets it because
# it captures our output); HEY_SHELL_COLOR=never and NO_COLOR turn it off.
# Palette: warm white = the command, amber = risk, red = danger, green = a passed check, gray = labels, hints
# and the box, lime = the logo and the suggested-command label and prompt.

hey_shell_colors() {
  C_CMD='' C_MUTED='' C_AMBER='' C_RED='' C_GREEN='' C_BRAND='' C_WORD='' C_OFF=''
  [ -z "${NO_COLOR:-}" ] || return 0
  case "${HEY_SHELL_COLOR:-auto}" in
    never) return 0 ;;
    always) ;;
    *) [ -t 1 ] || return 0 ;;
  esac
  C_MUTED=$'\033[38;5;245m'
  C_AMBER=$'\033[38;5;214m'
  C_RED=$'\033[38;5;203m'
  C_GREEN=$'\033[38;5;114m'
  case "${COLORTERM:-}" in   # the logo's lime and warm white, exact when the terminal has 24-bit color
    truecolor|24bit) C_BRAND=$'\033[38;2;198;245;107m'; C_WORD=$'\033[38;2;241;242;234m' ;;
    *)               C_BRAND=$'\033[38;5;155m';         C_WORD=$'\033[38;5;255m' ;;
  esac
  C_CMD=$'\033[1m'$C_WORD
  C_OFF=$'\033[0m'
}

hey_shell_status() {
  local rcol="$C_MUTED" ccol word
  case $HEY_SHELL_RISK_LEVEL in medium) rcol=$C_AMBER ;; high) rcol=$C_RED ;; esac
  # "low" only means no known risky pattern matched, so it is not shown as a verdict
  word="$(printf '%s' "$HEY_SHELL_RISK_LEVEL" | tr '[:lower:]' '[:upper:]')"
  [ "$HEY_SHELL_RISK_LEVEL" != low ] || word="none recognized"
  printf '%sRisk:%s %s%s%s' "$C_MUTED" "$C_OFF" "$rcol" "$word" "$C_OFF"
  if [ "${HEY_SHELL_CHECK:-1}" != 0 ]; then
    ccol=$C_GREEN word="No known issues"
    [ "$HEY_SHELL_CHECK_LEVEL" = ok ] || { ccol=$C_RED; word="LIKELY FAIL"; }
    printf ' %s·%s %sCheck:%s %s%s%s' "$C_MUTED" "$C_OFF" "$C_MUTED" "$C_OFF" "$ccol" "$word" "$C_OFF"
  fi
  printf '\n'
  [ "$HEY_SHELL_RISK_LEVEL" = low ] || printf '  %srisk: %s%s\n' "$C_MUTED" "$HEY_SHELL_RISK_REASON" "$C_OFF"
  if [ "${HEY_SHELL_CHECK:-1}" != 0 ] && [ "$HEY_SHELL_CHECK_LEVEL" != ok ]; then
    printf '  %scheck: %s%s\n' "$C_MUTED" "$HEY_SHELL_CHECK_REASON" "$C_OFF"
  fi
}

# hey_shell_render_command <command> [label] [note]: "label · note" (default SUGGESTED COMMAND · REVIEW BEFORE
# RUNNING; an empty note leaves it out), then the command after a "$ " in a rounded box. The box is 78 columns wide, or the terminal width
# ($COLUMNS) when that is narrower; long commands wrap inside it.
hey_shell_render_command() {
  local width=78 inner line bar='' pre='$ ' i=2 h label=${2:-SUGGESTED COMMAND} note='REVIEW BEFORE RUNNING'
  [ $# -lt 3 ] || note=$3
  case ${COLUMNS:-} in ''|*[!0-9]*) ;; *) [ "$COLUMNS" -ge 78 ] || width=$COLUMNS ;; esac
  [ "$width" -ge 24 ] || width=24
  inner=$((width - 6))
  h=$(printf '\342\224\200') # "─" as bytes: bash 3.2 mangles multibyte literals in some locales
  while [ "$i" -lt "$width" ]; do bar="$bar$h"; i=$((i + 1)); done
  printf '%s%s%s' "$C_BRAND" "$label" "$C_OFF"
  [ -z "$note" ] || printf ' %s·%s %s%s%s' "$C_MUTED" "$C_OFF" "$C_BRAND" "$note" "$C_OFF"
  printf '\n'
  printf '%s╭%s╮%s\n' "$C_MUTED" "$bar" "$C_OFF"
  while IFS= read -r line; do
    printf '%s│%s %s%s%s%s%*s %s│%s\n' "$C_MUTED" "$C_OFF" "$C_BRAND" "$pre" "$C_CMD" "$line$C_OFF" $((inner - ${#line})) '' "$C_MUTED" "$C_OFF"
    pre='  '
  done <<< "$(printf '%s\n' "$1" | fold -s -w "$inner")"
  printf '%s╰%s╯%s\n' "$C_MUTED" "$bar" "$C_OFF"
}

# hey_shell_render_explain <command> <explanation> <warning> [label] [note]
hey_shell_render_explain() {
  printf '\n'
  hey_shell_render_command "$1" "${4:-SUGGESTED COMMAND}" "${5:-}"
  printf '\n'
  [ -z "$2" ] || printf '%s\n' "$2" | fold -s -w 78 | sed 's/[[:space:]]*$//'
  [ -z "$3" ] || printf '%sWarning: %s%s\n' "$C_AMBER" "$(printf '%s' "$3" | fold -s -w 69 | sed 's/[[:space:]]*$//')" "$C_OFF"
  printf '\n'
  hey_shell_status
}
