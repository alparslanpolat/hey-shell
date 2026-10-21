#!/usr/bin/env bash
# Checks install.sh against a throwaway HOME: ./test/install.test.sh   (exit 1 on any mismatch)
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
installer="$root/install.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0 total=0

new_home() { H="$tmp/home-$total"; mkdir -p "$H"; : > "$H/.zshrc"; rc="$H/.zshrc"; }
run() { HOME="$H" SHELL=/bin/zsh "$installer" --shell zsh "$@" </dev/null 2>&1; }
ok() { total=$((total + 1)); if ! eval "$1"; then printf 'FAIL %s\n  check: %s\n' "$2" "$1"; fail=$((fail + 1)); fi; }
count() { grep -c -- "$1" "$rc" || true; }

new_home; run >/dev/null
ok '[ "$(count "export HEY_SHELL_KEY=\"ctrl+g\"")" = 1 ]'      "default key is written"
ok '[ "$(count "export PATH=.*bin:")" = 1 ]'                   "bin is added to PATH"
ok '[ "$(count "^alias ")" = 0 ]'                              "no alias without a flag when not interactive"

new_home; run --alias hs >/dev/null
ok '[ "$(count "^alias hs=.hey-shell.")" = 1 ]'                "--alias hs writes the alias"
run --alias hs >/dev/null
ok '[ "$(count "^alias hs=")" = 1 ] && [ "$(count ">>> hey-shell")" = 1 ]' "re-running does not duplicate"
run --key alt+o >/dev/null
ok '[ "$(count "^alias hs=")" = 1 ] && [ "$(count "alt+o")" = 1 ]' "changing the key keeps the current alias"
run --alias go >/dev/null
ok '[ "$(count "^alias go=")" = 1 ] && [ "$(count "^alias hs=")" = 0 ]' "--alias renames it"
run --no-alias >/dev/null
ok '[ "$(count "^alias ")" = 0 ]'                              "--no-alias removes it"

new_home; printf "alias hs='something-else'\nexport KEEP=1\n" > "$rc"
out=$(run --alias hs)
ok '[[ $out == *"already defined"* ]]'                         "reports an existing manual alias"
ok '[ "$(count "^alias hs=")" = 1 ] && [ "$(count "KEEP=1")" = 1 ]' "leaves the manual alias and other lines alone"

new_home
out=$(run --alias "bad name"); status=$?
ok '[[ $out == *"invalid alias"* ]] && [ ! -s "$rc" ]'         "rejects an invalid alias and writes nothing"
out=$(run --alias ls)
ok '[[ $out == *"already exists"* ]] && [ "$(count "^alias ls=")" = 1 ]' "warns when the alias shadows a command"

new_home; printf 'export KEEP=1\n' > "$rc"; run --alias hs >/dev/null; run --uninstall >/dev/null
ok '[ "$(count "hey-shell")" = 0 ] && [ "$(count "^alias hs")" = 0 ] && [ "$(count "KEEP=1")" = 1 ]' "uninstall removes the block and the alias only"

new_home; run >/dev/null; out=$(run)
ok '[[ $out == *"already installed"* ]]'                       "plain re-run says already installed"

if command -v script >/dev/null; then
  new_home
  printf 'alt+o\nhs\n' | HOME="$H" SHELL=/bin/zsh script -qec "$installer --shell zsh" /dev/null >/dev/null 2>&1
  ok '[ "$(count "^alias hs=")" = 1 ] && [ "$(count "alt+o")" = 1 ]' "interactive: key and alias are asked"
  new_home
  printf '\nn\n' | HOME="$H" SHELL=/bin/zsh script -qec "$installer --shell zsh" /dev/null >/dev/null 2>&1
  ok '[ "$(count "^alias ")" = 0 ] && [ "$(count "ctrl+g")" = 1 ]' "interactive: n skips the alias, Enter keeps ctrl+g"
  new_home
  printf '\n\n' | HOME="$H" SHELL=/bin/zsh script -qec "$installer --shell zsh" /dev/null >/dev/null 2>&1
  ok '[ "$(count "^alias hs=")" = 1 ]'                          "interactive: Enter accepts the default alias hs"
fi

echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
