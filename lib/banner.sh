# ASCII logo and usage text. Sourced by bin/hey-shell.
#   hey_shell_banner  prints lib/logo.txt; colors only when stdout is a terminal and NO_COLOR is unset
#   hey_shell_usage   prints the usage lines

_hs_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_hs_logo_split=15 # columns of lib/logo.txt that belong to the speech-bubble icon

hey_shell_banner() {
  local lime='' white='' off='' line
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    off=$'\033[0m'
    case "${COLORTERM:-}" in
      truecolor|24bit) lime=$'\033[38;2;198;245;107m'; white=$'\033[38;2;241;242;234m' ;;
      *)               lime=$'\033[38;5;155m';         white=$'\033[38;5;255m' ;;
    esac
  fi
  echo
  while IFS= read -r line; do
    printf '%s%s%s%s%s%s\n' "$lime" "${line:0:_hs_logo_split}" "$off" "$white" "${line:_hs_logo_split}" "$off"
  done < "$_hs_lib_dir/logo.txt"
  printf '\n  your words, shell commands\n\n'
}

hey_shell_usage() {
  cat <<USAGE
usage:  hey-shell [-e | --explain] <request>
        hey-shell [-r | --risk] "<command>"
        hey-shell [-c | --check] "<command>"
        hey-shell [-h | --help]

At your prompt, type a request and press ${HEY_SHELL_KEY:-ctrl+g}.
Nothing is ever run for you.
USAGE
}
