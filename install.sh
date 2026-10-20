#!/usr/bin/env bash
# Adds (or with --uninstall removes) the hey-shell block in your shell rc file.
#   ./install.sh [--shell bash|zsh] [--key ctrl+g|alt+o|...] [--uninstall]
# Without --key, asks which key to use (default ctrl+g). Re-run with --key to change it.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
begin="# >>> hey-shell >>>"
end="# <<< hey-shell <<<"
target="$(basename "${SHELL:-bash}")"
uninstall=0
key=""

while [ $# -gt 0 ]; do
  case "$1" in
    --shell) target="${2:?--shell needs bash or zsh}"; shift 2 ;;
    --key) key="${2:?--key needs a value like ctrl+g or alt+o}"; shift 2 ;;
    --uninstall) uninstall=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

case "$target" in
  zsh)  rc="$HOME/.zshrc" ;;
  bash) if [ "$(uname -s)" = Darwin ]; then rc="$HOME/.bash_profile"; else rc="$HOME/.bashrc"; fi ;;
  *) echo "unsupported shell: $target (use --shell bash|zsh)" >&2; exit 1 ;;
esac

is_installed() { [ -f "$rc" ] && grep -qF "$begin" "$rc"; }

remove_block() {
  local tmp
  tmp="$(mktemp)"
  awk -v b="$begin" -v e="$end" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$rc" > "$tmp"
  cat "$tmp" > "$rc" && rm -f "$tmp"
}

if [ "$uninstall" = 1 ]; then
  is_installed || { echo "not installed in $rc"; exit 0; }
  remove_block
  echo "removed from $rc"
  exit 0
fi

command -v claude >/dev/null || echo "warning: 'claude' CLI not found in PATH; install Claude Code first" >&2

if is_installed && [ -z "$key" ]; then
  echo "already installed in $rc (re-run with --key <key> to change the key, or --uninstall)"
  exit 0
fi

if [ -z "$key" ] && [ -t 0 ]; then
  read -r -p "Key that triggers hey-shell [ctrl+g] (examples: alt+g, ctrl+o): " key
fi
key="$(printf '%s' "${key:-ctrl+g}" | tr '[:upper:]' '[:lower:]')"

if ! printf '%s' "$key" | grep -Eq '^(ctrl|alt)\+[a-z0-9]$'; then
  echo "invalid key '$key': use ctrl+<letter|digit> or alt+<letter|digit>" >&2
  exit 1
fi
case "$key" in
  ctrl+[cdzmijhsq])
    echo "'$key' is reserved by the terminal or shell; pick another" >&2
    exit 1 ;;
esac

is_installed && remove_block

{
  echo ""
  echo "$begin"
  echo "export HEY_SHELL_KEY=\"$key\""
  echo "source \"$root/shell/hey-shell.$target\""
  echo "$end"
} >> "$rc"
echo "installed in $rc with key $key. Run: source $rc   then type a request and press $key"
[ "$(uname -s)" = Darwin ] && case "$key" in
  alt+*) echo "note: on macOS enable 'Use Option as Meta key' in your terminal, or alt+<key> types a symbol" ;;
esac
exit 0
