#!/usr/bin/env bash
# Checks the failure predictor: ./test/check.test.sh   (exit 1 on any mismatch)
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin="$root/bin/hey-shell"
nonrepo="$(mktemp -d)"
trap 'rm -rf "$nonrepo"' EXIT
fail=0 total=0

check() { # expected-level reason-substring command [dir]
  local want=$1 reason=$2 cmd=$3 dir=${4:-$nonrepo} out level
  out=$(cd "$dir" && "$bin" --check "$cmd")
  level=${out%%$'\n'*}
  total=$((total + 1))
  if [ "$level" != "$want" ]; then
    printf 'FAIL expected %-4s got %-4s : %s\n' "$want" "$level" "$cmd"; fail=$((fail + 1))
  elif [ -n "$reason" ] && [[ $out != *"$reason"* ]]; then
    printf 'FAIL reason should contain "%s" : %s\n  got: %s\n' "$reason" "$cmd" "$out"; fail=$((fail + 1))
  fi
}

check ok   ''                        'ls | grep foo && echo done'
check ok   ''                        'ls 2>&1 | head -2'
check ok   ''                        'ls &>/dev/null'
check ok   ''                        'sudo ls'
check ok   ''                        'for f in a b; do echo "$f"; done'
check ok   ''                        'echo "a;b" | cat'
check ok   ''                        'FOO=1 BAR=2 ls'
check ok   ''                        'cd /tmp && ls'
check ok   ''                        '/bin/ls'
check ok   ''                        'cat <(echo hi)'
check fail 'syntax error'            'echo "unclosed'
check fail 'syntax error'            'ls | | grep x'
check fail "'definitely-not-a-cmd'"  'definitely-not-a-cmd --flag'
check fail "'nonexistent-after-pipe'" 'ls | nonexistent-after-pipe'
check fail "'nonexistent-env'"       'FOO=1 nonexistent-env'
check fail "'nonexistent-sudo'"      'sudo nonexistent-sudo'
check fail "'nonexistent-subshell'"  'echo $(nonexistent-subshell)'
check fail "'/no/such/bin'"          '/no/such/bin --x'

# every line of test/valid-commands.txt is a working command and must not be flagged
while IFS= read -r line; do
  [ -n "$line" ] || continue
  check ok '' "$line"
done < "$root/test/valid-commands.txt"
check fail "'nonexistent-fn'"        'f() { nonexistent-fn; }; f'
check fail "'nonexistent-if'"        'if true; then nonexistent-if; fi'
check fail "'nonexistent-loop'"      'while false; do nonexistent-loop; done'
check fail "'nonexistent-psub'"      'diff <(nonexistent-psub) <(echo b)'

# the caller's aliases and functions count as existing
total=$((total + 1))
[ "$(HEY_SHELL_KNOWN_NAMES=$'hs\nlzd' "$bin" --check 'hs foo' | head -1)" = ok ] || { echo "FAIL known alias not accepted"; fail=$((fail + 1)); }
check fail "'hs'"                    'hs foo'

# environment: git needs a repository, tmux needs a server, escaped ; is an argument
check fail 'not inside a git repository' 'git status'
check ok   ''                        'git status' "$root"
check ok   ''                        'git clone https://example.com/x.git'
check ok   ''                        'git -C /tmp status'
if command -v tmux >/dev/null && ! tmux list-sessions >/dev/null 2>&1; then
  check fail 'no tmux server' 'tmux split-window -h \; split-window -v'
  check ok   ''               'tmux new-session -d'
fi

# after a $(...), (...) or `...` the outer command's arguments and redirections follow, not a new command
check ok '' 'kill $(lsof -ti tcp:3000) 2>/dev/null'
check ok '' 'echo `date` 2>/dev/null'
check ok '' 'diff <(ls) <(ls) 2>&1'
check ok '' '(cd / && ls) > /dev/null'
check fail "'nosuchprog-zz' not found" '2>/dev/null nosuchprog-zz'
check fail "'nosuchprog-zz' not found" 'echo $(nosuchprog-zz) > /dev/null'

# the check never runs the command
marker="$nonrepo/ran"
check ok '' "touch $marker"
total=$((total + 1))
[ ! -e "$marker" ] || { echo "FAIL the checked command was executed"; fail=$((fail + 1)); }

echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
