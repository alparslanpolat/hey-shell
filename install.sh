#!/usr/bin/env bash
# Adds (or with --uninstall removes) the hey-shell block in your shell rc file.
#   ./install.sh [--shell bash|zsh] [--uninstall]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
begin="# >>> hey-shell >>>"
end="# <<< hey-shell <<<"
target="$(basename "${SHELL:-bash}")"
uninstall=0

while [ $# -gt 0 ]; do
  case "$1" in
    --shell) target="${2:?--shell needs bash or zsh}"; shift 2 ;;
    --uninstall) uninstall=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

case "$target" in
  zsh)  rc="$HOME/.zshrc" ;;
  bash) if [ "$(uname -s)" = Darwin ]; then rc="$HOME/.bash_profile"; else rc="$HOME/.bashrc"; fi ;;
  *) echo "unsupported shell: $target (use --shell bash|zsh)" >&2; exit 1 ;;
esac

if [ "$uninstall" = 1 ]; then
  [ -f "$rc" ] && grep -qF "$begin" "$rc" || { echo "not installed in $rc"; exit 0; }
  tmp="$(mktemp)"
  awk -v b="$begin" -v e="$end" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$rc" > "$tmp"
  cat "$tmp" > "$rc" && rm -f "$tmp"
  echo "removed from $rc"
  exit 0
fi

command -v claude >/dev/null || echo "warning: 'claude' CLI not found in PATH; install Claude Code first" >&2

if [ -f "$rc" ] && grep -qF "$begin" "$rc"; then
  echo "already installed in $rc"
  exit 0
fi

{
  echo ""
  echo "$begin"
  echo "source \"$root/shell/hey-shell.$target\""
  echo "$end"
} >> "$rc"
echo "installed in $rc. Run: source $rc   then type a request and press Ctrl+G"
