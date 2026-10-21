#!/usr/bin/env bash
# Adds (or with --uninstall removes) the hey-shell block in your shell rc file.
#   ./install.sh [--shell bash|zsh] [--key ctrl+g|alt+o|...] [--alias hs | --no-alias] [--uninstall]
# Without --key / --alias it asks (default key ctrl+g, default alias hs). Re-run with them to change.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
begin="# >>> hey-shell >>>"
end="# <<< hey-shell <<<"
target="$(basename "${SHELL:-bash}")"
uninstall=0
key=""
alias_name=""
no_alias=0
alias_from_flag=0

while [ $# -gt 0 ]; do
  case "$1" in
    --shell) target="${2:?--shell needs bash or zsh}"; shift 2 ;;
    --key) key="${2:?--key needs a value like ctrl+g or alt+o}"; shift 2 ;;
    --alias) alias_name="${2:?--alias needs a name like hs}"; alias_from_flag=1; shift 2 ;;
    --no-alias) no_alias=1; shift ;;
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

# the rc file without the hey-shell block
outside_block() { awk -v b="$begin" -v e="$end" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$rc"; }

# the alias name inside the hey-shell block, if any
block_alias() {
  awk -v b="$begin" -v e="$end" '$0==b{inb=1;next} $0==e{inb=0} inb && /^alias /{sub(/^alias /,""); sub(/=.*/,""); print; exit}' "$rc"
}

remove_block() {
  local tmp
  tmp="$(mktemp)"
  outside_block > "$tmp"
  cat "$tmp" > "$rc" && rm -f "$tmp"
}

if [ "$uninstall" = 1 ]; then
  is_installed || { echo "not installed in $rc"; exit 0; }
  remove_block
  echo "removed from $rc"
  exit 0
fi

command -v claude >/dev/null || echo "warning: 'claude' CLI not found in PATH; install Claude Code first" >&2

if is_installed && [ -z "$key" ] && [ "$alias_from_flag" = 0 ] && [ "$no_alias" = 0 ]; then
  echo "already installed in $rc (re-run with --key <key> or --alias <name> to change them, or --uninstall)"
  exit 0
fi

existing_alias=""
is_installed && existing_alias="$(block_alias)"

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

# short alias: --alias NAME, --no-alias, or ask (default hs); a non-interactive run keeps the current one
if [ "$no_alias" = 1 ]; then
  alias_name=""
elif [ "$alias_from_flag" = 0 ]; then
  if [ -t 0 ]; then
    default="${existing_alias:-hs}"
    read -r -p "Short alias for hey-shell [$default] (type a name, or n for none): " reply
    case "${reply:-$default}" in
      n|N|no|none) alias_name="" ;;
      *) alias_name="${reply:-$default}" ;;
    esac
  else
    alias_name="$existing_alias"
  fi
fi

if [ -n "$alias_name" ]; then
  if ! printf '%s' "$alias_name" | grep -Eq '^[A-Za-z_][A-Za-z0-9_-]*$'; then
    echo "invalid alias '$alias_name': use letters, digits, _ or -" >&2
    exit 1
  fi
  if [ -f "$rc" ] && outside_block | grep -Eq "^[[:space:]]*alias[[:space:]]+$alias_name="; then
    echo "alias '$alias_name' is already defined in $rc; leaving it as it is"
    alias_name=""
  elif [ "$alias_name" != "$existing_alias" ] && found="$(command -v "$alias_name" 2>/dev/null)"; then
    if [ "$alias_from_flag" = 0 ] && [ -t 0 ]; then
      read -r -p "'$alias_name' already exists ($found). Shadow it with an alias? [y/N] " reply
      case "$reply" in y|Y|yes) ;; *) alias_name=""; echo "skipping the alias" ;; esac
    else
      echo "warning: '$alias_name' already exists ($found); the alias will shadow it" >&2
    fi
  fi
fi

is_installed && remove_block

{
  echo ""
  echo "$begin"
  echo "export HEY_SHELL_KEY=\"$key\""
  echo "export PATH=\"$root/bin:\$PATH\""
  [ -z "$alias_name" ] || echo "alias $alias_name='hey-shell'"
  echo "source \"$root/shell/hey-shell.$target\""
  echo "$end"
} >> "$rc"
echo "installed in $rc with key $key${alias_name:+ and alias $alias_name}. Run: source $rc   then type a request and press $key (or run: ${alias_name:-hey-shell} --explain \"<request>\")"
[ "$(uname -s)" = Darwin ] && case "$key" in
  alt+*) echo "note: on macOS enable 'Use Option as Meta key' in your terminal, or alt+<key> types a symbol" ;;
esac
exit 0
