# shellcheck shell=bash
# ASCII logo and usage text. Sourced by bin/hey-shell.
#   hey_shell_banner  prints lib/logo.txt in the brand colors and the version (needs hey_shell_colors and lib/update.sh)
#   hey_shell_usage   prints the usage lines

_hs_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_hs_logo_split=15 # columns of lib/logo.txt that belong to the speech-bubble icon

hey_shell_banner() {
  local line
  echo
  while IFS= read -r line; do
    printf '%s%s%s%s%s%s\n' "$C_BRAND" "${line:0:_hs_logo_split}" "$C_OFF" "$C_WORD" "${line:_hs_logo_split}" "$C_OFF"
  done < "$_hs_lib_dir/logo.txt"
  printf '\n  %shey-shell%s %s %s· your words, shell commands%s\n\n' "$C_BRAND" "$C_OFF" "v$(hey_shell_version)" "$C_MUTED" "$C_OFF"
}

# Needs hey_shell_colors to have run (hints are gray).
hey_shell_usage() {
  printf 'usage: hey-shell [options] <request>\n\n'
  printf '  -e, --explain   explain the command, then leave it on your next prompt\n'
  printf '  -r, --risk      rate a command: low, medium or high\n'
  printf '  -c, --check     predict whether a command would fail\n'
  printf '  -h, --help      show this help\n'
  printf '  -V, --version   show the version\n'
  printf '  -U, --update    update to the latest version\n\n'
  printf '%s  %-15s type a request at your prompt, then press it%s\n' "$C_MUTED" "${HEY_SHELL_KEY:-ctrl+g}" "$C_OFF"
  printf '%s  %-15s generated commands are never run for you%s\n' "$C_MUTED" "nothing runs" "$C_OFF"
}
