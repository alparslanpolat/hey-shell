# Terminal output for bin/hey-shell: color by purpose, wrapping, and the status line. Sourced by bin/hey-shell.
#   hey_shell_colors          sets C_CMD C_MUTED C_AMBER C_RED C_GREEN C_OFF (empty when color is off)
#   hey_shell_status          prints "Risk: MEDIUM · Check: OK" plus the reasons; run hey_shell_risk (and
#                             hey_shell_check unless HEY_SHELL_CHECK=0) first
#   hey_shell_render_explain  prints the command on its own lines, the wrapped explanation, a separate warning
# Color is on when stdout is a terminal, or when HEY_SHELL_COLOR=always (the shell integration sets it because
# it captures our output); HEY_SHELL_COLOR=never and NO_COLOR turn it off.
# Palette: cyan = the command, amber = risk, red = danger, green = a passed check, gray = labels and hints.
# Lime stays reserved for the logo.

hey_shell_colors() {
  C_CMD='' C_MUTED='' C_AMBER='' C_RED='' C_GREEN='' C_OFF=''
  [ -z "${NO_COLOR:-}" ] || return 0
  case "${HEY_SHELL_COLOR:-auto}" in
    never) return 0 ;;
    always) ;;
    *) [ -t 1 ] || return 0 ;;
  esac
  C_CMD=$'\033[1;38;5;81m'
  C_MUTED=$'\033[38;5;245m'
  C_AMBER=$'\033[38;5;214m'
  C_RED=$'\033[38;5;203m'
  C_GREEN=$'\033[38;5;114m'
  C_OFF=$'\033[0m'
}

hey_shell_status() {
  local rcol="$C_MUTED" ccol word
  case $HEY_SHELL_RISK_LEVEL in medium) rcol=$C_AMBER ;; high) rcol=$C_RED ;; esac
  printf '%sRisk:%s %s%s%s' "$C_MUTED" "$C_OFF" "$rcol" "$(printf '%s' "$HEY_SHELL_RISK_LEVEL" | tr '[:lower:]' '[:upper:]')" "$C_OFF"
  if [ "${HEY_SHELL_CHECK:-1}" != 0 ]; then
    ccol=$C_GREEN word=OK
    [ "$HEY_SHELL_CHECK_LEVEL" = ok ] || { ccol=$C_RED; word="LIKELY FAIL"; }
    printf ' %s·%s %sCheck:%s %s%s%s' "$C_MUTED" "$C_OFF" "$C_MUTED" "$C_OFF" "$ccol" "$word" "$C_OFF"
  fi
  printf '\n'
  [ "$HEY_SHELL_RISK_LEVEL" = low ] || printf '  %srisk: %s%s\n' "$C_MUTED" "$HEY_SHELL_RISK_REASON" "$C_OFF"
  if [ "${HEY_SHELL_CHECK:-1}" != 0 ] && [ "$HEY_SHELL_CHECK_LEVEL" != ok ]; then
    printf '  %scheck: %s%s\n' "$C_MUTED" "$HEY_SHELL_CHECK_REASON" "$C_OFF"
  fi
}

# hey_shell_render_explain <command> <explanation> <warning>
hey_shell_render_explain() {
  printf '\n%s%s%s\n\n' "$C_CMD" "$1" "$C_OFF"
  [ -z "$2" ] || printf '%s\n' "$2" | fold -s -w 78 | sed 's/[[:space:]]*$//'
  [ -z "$3" ] || printf '%sWarning: %s%s\n' "$C_AMBER" "$(printf '%s' "$3" | fold -s -w 69 | sed 's/[[:space:]]*$//')" "$C_OFF"
  printf '\n'
  hey_shell_status
}
