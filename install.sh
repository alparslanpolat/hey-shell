#!/usr/bin/env bash
# Adds (or with --uninstall removes) the hey-shell block in your shell rc file.
#   ./install.sh [--shell bash|zsh] [--key ctrl+g|alt+o|...] [--uninstall]
#                [--aliases | --no-alias | --alias NAME --alias-explain NAME --alias-risk NAME --alias-check NAME
#                 --alias-fix NAME --alias-what NAME]
# Without flags it asks for the key (default ctrl+g) and for short aliases (default: hs, hse, hsr, hsc, hsf, hsw).
# Re-run with flags to change them; a run without flags on an existing install changes nothing.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
begin="# >>> hey-shell >>>"
end="# <<< hey-shell <<<"
target="$(basename "${SHELL:-bash}")"
uninstall=0
key=""
no_alias=0
alias_flags=0
a_main="" a_explain="" a_risk="" a_check="" a_fix="" a_what=""   # alias names; "" = none
ALIAS_KEYS="main explain risk check fix what"

default_for() { case $1 in main) echo hs ;; explain) echo hse ;; risk) echo hsr ;; check) echo hsc ;; fix) echo hsf ;; what) echo hsw ;; esac; }
command_for() { case $1 in main) echo "hey-shell" ;; explain) echo "hey-shell --explain" ;; risk) echo "hey-shell --risk" ;; check) echo "hey-shell --check" ;; fix) echo "hey-shell --fix" ;; what) echo "hey-shell --what" ;; esac; }
get_alias() { case $1 in main) echo "$a_main" ;; explain) echo "$a_explain" ;; risk) echo "$a_risk" ;; check) echo "$a_check" ;; fix) echo "$a_fix" ;; what) echo "$a_what" ;; esac; }
set_alias() { case $1 in main) a_main=$2 ;; explain) a_explain=$2 ;; risk) a_risk=$2 ;; check) a_check=$2 ;; fix) a_fix=$2 ;; what) a_what=$2 ;; esac; }

while [ $# -gt 0 ]; do
  case "$1" in
    --shell) target="${2:?--shell needs bash or zsh}"; shift 2 ;;
    --key) key="${2:?--key needs a value like ctrl+g or alt+o}"; shift 2 ;;
    --alias) a_main="${2:?--alias needs a name like hs}"; alias_flags=1; shift 2 ;;
    --alias-explain) a_explain="${2:?--alias-explain needs a name like hse}"; alias_flags=1; shift 2 ;;
    --alias-risk) a_risk="${2:?--alias-risk needs a name like hsr}"; alias_flags=1; shift 2 ;;
    --alias-check) a_check="${2:?--alias-check needs a name like hsc}"; alias_flags=1; shift 2 ;;
    --alias-fix) a_fix="${2:?--alias-fix needs a name like hsf}"; alias_flags=1; shift 2 ;;
    --alias-what) a_what="${2:?--alias-what needs a name like hsw}"; alias_flags=1; shift 2 ;;
    --aliases) for k in $ALIAS_KEYS; do set_alias "$k" "$(default_for "$k")"; done; alias_flags=1; shift ;;
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

# the rc file without the hey-shell block and the blank lines just before it (the install adds one back), so
# re-running the installer does not pile up blank lines
outside_block() {
  awk -v b="$begin" -v e="$end" '
    $0==b {skip=1; blanks=0; next}
    $0==e {skip=0; next}
    skip {next}
    $0=="" {blanks++; next}
    {for (; blanks > 0; blanks--) print ""; print}
    END {for (; blanks > 0; blanks--) print ""}' "$rc"
}

# the name of the alias in the hey-shell block whose command is $1, if any
block_alias_for() {
  awk -v b="$begin" -v e="$end" -v c="$1" '
    $0==b{inb=1;next} $0==e{inb=0}
    inb && /^alias /{line=$0; sub(/^alias /,"",line); n=index(line,"="); name=substr(line,1,n-1); val=substr(line,n+1); gsub("^\047|\047$","",val); if (val==c) {print name; exit}}' "$rc"
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

if is_installed && [ -z "$key" ] && [ "$alias_flags" = 0 ] && [ "$no_alias" = 0 ]; then
  echo "already installed in $rc (re-run with --key, --aliases or --alias* to change them, or --uninstall)"
  exit 0
fi

# aliases already in the block (kept when this run does not change them)
ex_main="" ex_explain="" ex_risk="" ex_check="" ex_fix="" ex_what=""
if is_installed; then
  ex_main="$(block_alias_for "$(command_for main)")"
  ex_explain="$(block_alias_for "$(command_for explain)")"
  ex_risk="$(block_alias_for "$(command_for risk)")"
  ex_check="$(block_alias_for "$(command_for check)")"
  ex_fix="$(block_alias_for "$(command_for fix)")"
  ex_what="$(block_alias_for "$(command_for what)")"
fi
existing_for() { case $1 in main) echo "$ex_main" ;; explain) echo "$ex_explain" ;; risk) echo "$ex_risk" ;; check) echo "$ex_check" ;; fix) echo "$ex_fix" ;; what) echo "$ex_what" ;; esac; }

# the alias already installed for a command, else the default name
name_or_default() { local e; e="$(existing_for "$1")"; echo "${e:-$(default_for "$1")}"; }

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

# short aliases: --no-alias, flags, or ask; a run without flags that cannot ask keeps the current ones
interactive_aliases=0
if [ "$no_alias" = 1 ]; then
  for k in $ALIAS_KEYS; do set_alias "$k" ""; done
elif [ "$alias_flags" = 1 ]; then
  for k in $ALIAS_KEYS; do [ -n "$(get_alias "$k")" ] || set_alias "$k" "$(existing_for "$k")"; done
elif [ -t 0 ]; then
  interactive_aliases=1
  echo "Short aliases (typed instead of the full command):"
  for k in $ALIAS_KEYS; do
    printf '  %-5s -> %s\n' "$(name_or_default "$k")" "$(command_for "$k")"
  done
  read -r -p "Add them? [Y]es / [n]o / [c]ustomize names: " reply
  case "${reply:-y}" in
    n|N|no) for k in $ALIAS_KEYS; do set_alias "$k" ""; done ;;
    c|C|custom*)
      for k in $ALIAS_KEYS; do
        default="$(name_or_default "$k")"
        read -r -p "  name for '$(command_for "$k")' [$default] (n to skip): " reply
        case "${reply:-$default}" in n|N|no|none) set_alias "$k" "" ;; *) set_alias "$k" "${reply:-$default}" ;; esac
      done ;;
    *) for k in $ALIAS_KEYS; do set_alias "$k" "$(name_or_default "$k")"; done ;;
  esac
else
  for k in $ALIAS_KEYS; do set_alias "$k" "$(existing_for "$k")"; done
fi

# vet every chosen name: valid, not already defined by hand, and confirm before shadowing a command
for k in $ALIAS_KEYS; do
  name="$(get_alias "$k")"
  [ -n "$name" ] || continue
  if ! printf '%s' "$name" | grep -Eq '^[A-Za-z_][A-Za-z0-9_-]*$'; then
    echo "invalid alias '$name': use letters, digits, _ or -" >&2
    exit 1
  fi
  if [ -f "$rc" ] && outside_block | grep -Eq "^[[:space:]]*alias[[:space:]]+$name="; then
    echo "alias '$name' is already defined in $rc; leaving it as it is"
    set_alias "$k" ""
  elif [ "$name" != "$(existing_for "$k")" ] && found="$(command -v "$name" 2>/dev/null)"; then
    if [ "$interactive_aliases" = 1 ]; then
      read -r -p "'$name' already exists ($found). Shadow it with an alias? [y/N] " reply
      case "$reply" in y|Y|yes) ;; *) set_alias "$k" ""; echo "skipping the alias '$name'" ;; esac
    else
      echo "warning: '$name' already exists ($found); the alias will shadow it" >&2
    fi
  fi
done

is_installed && remove_block

{
  echo ""
  echo "$begin"
  echo "export HEY_SHELL_KEY=\"$key\""
  echo "export PATH=\"$root/bin:\$PATH\""
  for k in $ALIAS_KEYS; do
    name="$(get_alias "$k")"
    [ -z "$name" ] || echo "alias $name='$(command_for "$k")'"
  done
  echo "source \"$root/shell/hey-shell.$target\""
  echo "$end"
} >> "$rc"

names=""
for k in $ALIAS_KEYS; do name="$(get_alias "$k")"; [ -z "$name" ] || names="${names:+$names, }$name"; done
echo "installed in $rc with key $key${names:+ and aliases $names}. Run: source $rc   then type a request and press $key (or run: ${a_explain:-hey-shell --explain} \"<request>\")"
[ "$(uname -s)" = Darwin ] && case "$key" in
  alt+*) echo "note: on macOS enable 'Use Option as Meta key' in your terminal, or alt+<key> types a symbol" ;;
esac
exit 0
