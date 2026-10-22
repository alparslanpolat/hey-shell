#!/usr/bin/env bash
# Checks install.sh against a throwaway HOME: ./test/install.test.sh   (exit 1 on any mismatch)
# shellcheck disable=SC2034  # ok() evaluates its checks as strings, so shellcheck cannot see $out being read
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

# Run "$@" on a pseudo-terminal (the installer only asks its questions on one), fed by this function's stdin.
in_pty() { python3 -I "$root/test/pty_run.py" "$@"; }

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
out=$(run --alias "bad name")
ok '[[ $out == *"invalid alias"* ]] && [ ! -s "$rc" ]'         "rejects an invalid alias and writes nothing"
out=$(run --alias ls)
ok '[[ $out == *"already exists"* ]] && [ "$(count "^alias ls=")" = 1 ]' "warns when the alias shadows a command"

new_home; printf 'export KEEP=1\n' > "$rc"; run --alias hs >/dev/null; run --uninstall >/dev/null
ok '[ "$(count "hey-shell")" = 0 ] && [ "$(count "^alias hs")" = 0 ] && [ "$(count "KEEP=1")" = 1 ]' "uninstall removes the block and the alias only"

new_home; printf 'export A=1\n' > "$rc"; run --aliases >/dev/null; run --key alt+o >/dev/null; run --key ctrl+o >/dev/null
ok '[ "$(count "^$")" = 1 ]'                                   "re-installing does not pile up blank lines"
run --uninstall >/dev/null
ok '[ "$(cat "$rc")" = "export A=1" ]'                         "uninstall leaves the rc file as it was"

# bash: the rc file is ~/.bash_profile on macOS (Terminal opens login shells) and ~/.bashrc elsewhere
new_home
[ "$(uname -s)" = Darwin ] && brc="$H/.bash_profile" || brc="$H/.bashrc"
printf 'export B=1\n' > "$brc"
HOME="$H" SHELL=/bin/bash "$installer" --shell bash --aliases </dev/null >/dev/null 2>&1
ok 'grep -q "source \".*/shell/hey-shell.bash\"" "$brc" && [ "$(grep -c "^alias " "$brc")" = 6 ]' "bash: installs into the bash rc file"
ok 'bash -n "$brc"'                                            "bash: the rc file still parses"
HOME="$H" SHELL=/bin/bash "$installer" --shell bash --uninstall </dev/null >/dev/null 2>&1
ok '[ "$(cat "$brc")" = "export B=1" ]'                        "bash: uninstall leaves the rc file as it was"

# the agent: written only when not claude, kept on re-runs that do not name one
new_home; run >/dev/null
ok '[ "$(count "HEY_SHELL_AGENT")" = 0 ]'                      "claude is the default and needs no line"
run --agent codex >/dev/null
ok '[ "$(count "^export HEY_SHELL_AGENT=\"codex\"")" = 1 ]'     "--agent codex is written"
run --key alt+o >/dev/null
ok '[ "$(count "^export HEY_SHELL_AGENT=\"codex\"")" = 1 ] && [ "$(count "alt+o")" = 1 ]' "changing the key keeps the agent"
run --agent gemini >/dev/null
ok '[ "$(count "HEY_SHELL_AGENT")" = 1 ] && [ "$(count "^export HEY_SHELL_AGENT=\"gemini\"")" = 1 ]' "--agent gemini replaces it"
run --agent claude >/dev/null
ok '[ "$(count "HEY_SHELL_AGENT")" = 0 ]'                      "--agent claude removes the line"
out=$(run --agent gpt)
ok '[[ $out == *"unknown agent"* ]]'                           "an unknown agent is refused"

new_home; run >/dev/null; out=$(run)
ok '[[ $out == *"already installed"* ]]'                       "plain re-run says already installed"

new_home; run --aliases >/dev/null
ok '[ "$(count "^alias ")" = 6 ] && [ "$(count "^alias hse=.hey-shell --explain.")" = 1 ] && [ "$(count "^alias hsr=.hey-shell --risk.")" = 1 ] && [ "$(count "^alias hsc=.hey-shell --check.")" = 1 ] && [ "$(count "^alias hsf=.hey-shell --fix.")" = 1 ] && [ "$(count "^alias hsw=.hey-shell --what.")" = 1 ]' "--aliases writes hs, hse, hsr, hsc, hsf and hsw"
run --key alt+o >/dev/null
ok '[ "$(count "^alias ")" = 6 ] && [ "$(count "alt+o")" = 1 ]' "changing the key keeps all six aliases"
run --alias-fix fixit >/dev/null
ok '[ "$(count "^alias fixit=.hey-shell --fix.")" = 1 ] && [ "$(count "^alias hsf=")" = 0 ] && [ "$(count "^alias hsw=")" = 1 ]' "--alias-fix renames only that alias"
run --alias-explain ex >/dev/null
ok '[ "$(count "^alias ex=.hey-shell --explain.")" = 1 ] && [ "$(count "^alias hse=")" = 0 ] && [ "$(count "^alias hs=")" = 1 ]' "--alias-explain renames only that alias"
run --no-alias >/dev/null
ok '[ "$(count "^alias ")" = 0 ]' "--no-alias removes them all"

new_home; printf "alias hse='mine'\n" > "$rc"
out=$(run --aliases)
ok '[[ $out == *"alias '"'"'hse'"'"' is already defined"* ]] && [ "$(count "^alias hse=")" = 1 ] && [ "$(count "^alias hsr=")" = 1 ]' "a hand-made hse is kept, the others are still added"
out=$(run --alias-risk cat)
ok '[[ $out == *"already exists"* ]] && [ "$(count "^alias cat=.hey-shell --risk.")" = 1 ]' "warns when an alias shadows a command"

if command -v python3 >/dev/null; then
  new_home
  printf 'alt+o\n\n' | in_pty env HOME="$H" SHELL=/bin/zsh "$installer" --shell zsh >/dev/null 2>&1
  ok '[ "$(count "^alias ")" = 6 ] && [ "$(count "alt+o")" = 1 ]' "interactive: Enter accepts the key and all six aliases"
  new_home
  printf '\nn\n' | in_pty env HOME="$H" SHELL=/bin/zsh "$installer" --shell zsh >/dev/null 2>&1
  ok '[ "$(count "^alias ")" = 0 ] && [ "$(count "ctrl+g")" = 1 ]' "interactive: n skips every alias"
  new_home; run --aliases >/dev/null
  printf 'n\n' | in_pty env HOME="$H" SHELL=/bin/zsh "$installer" --shell zsh --key ctrl+g >/dev/null 2>&1
  ok '[ "$(count "^alias ")" = 0 ]' "interactive: n on a re-install removes the existing aliases"
  new_home
  printf '\nc\n\nx\nn\nmycheck\n\n\n' | in_pty env HOME="$H" SHELL=/bin/zsh "$installer" --shell zsh >/dev/null 2>&1
  ok '[ "$(count "^alias hs=.hey-shell.")" = 1 ] && [ "$(count "^alias x=.hey-shell --explain.")" = 1 ] && [ "$(count "--risk")" = 0 ] && [ "$(count "^alias mycheck=.hey-shell --check.")" = 1 ]' "interactive: c customizes each name, n skips one"
fi

echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
