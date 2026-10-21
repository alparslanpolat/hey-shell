#!/usr/bin/env bash
# Checks bin/hey-shell error handling, --explain and the prompt, using a fake `claude`.
#   ./test/cli.test.sh   (exit 1 on any mismatch)
set -u
bin="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/hey-shell"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0 total=0

# Fake CLI: prints $FAKE_OUT / $FAKE_ERR, exits $FAKE_STATUS, records the prompt (last argument).
cat > "$tmp/claude" <<'FAKE'
#!/usr/bin/env bash
for last; do :; done
printf '%s' "$last" > "$FAKE_PROMPT_FILE"
[ -z "${FAKE_OUT:-}" ] || printf '%b\n' "$FAKE_OUT"
[ -z "${FAKE_ERR:-}" ] || printf '%b\n' "$FAKE_ERR" >&2
exit "${FAKE_STATUS:-0}"
FAKE
chmod +x "$tmp/claude"
export HEY_SHELL_CLAUDE="$tmp/claude" FAKE_PROMPT_FILE="$tmp/prompt"

# expect <name> <substring> <args...>: runs hey-shell with the FAKE_* env already set, checks stdout+stderr
expect() {
  local name=$1 want=$2 got
  shift 2
  got=$("$bin" "$@" 2>&1)
  total=$((total + 1))
  case $got in
    *"$want"*) ;;
    *) printf 'FAIL %s\n  wanted: %s\n  got:    %s\n' "$name" "$want" "$got"; fail=$((fail + 1)) ;;
  esac
}

HEY_SHELL_CLAUDE="$tmp/does-not-exist" expect "missing cli" "Install it: https://claude.com/claude-code" list files
FAKE_STATUS=1 FAKE_OUT="Invalid API key · Please run /login" expect "not logged in" "not logged in" list files
FAKE_STATUS=1 FAKE_ERR="Error 429: rate limit exceeded" expect "rate limit" "rate limited or overloaded" list files
FAKE_STATUS=1 FAKE_ERR="getaddrinfo ENOTFOUND api.anthropic.com" expect "network" "Could not reach the Claude API" list files
FAKE_STATUS=1 FAKE_ERR="boom" expect "other failure" "claude failed: boom" list files
FAKE_STATUS=0 FAKE_OUT="" expect "empty reply" "empty reply" list files
FAKE_STATUS=0 FAKE_OUT='```bash\ndocker ps -q\n```' expect "strips fences" "docker ps -q" list containers
FAKE_STATUS=0 FAKE_OUT='docker ps -q\n\nLists the IDs of running containers.' expect "explain text" "Lists the IDs of running containers." --explain list containers
FAKE_STATUS=0 FAKE_OUT='docker ps -q\n\nLists the IDs of running containers.' expect "explain low risk" "Risk: LOW" --explain list containers
FAKE_STATUS=0 FAKE_OUT='rm -rf build\n\nDeletes the build directory.' expect "explain high risk" "Risk: HIGH" --explain clean build
FAKE_STATUS=0 FAKE_OUT='rm -rf build\n\nDeletes the build directory.' expect "explain risk reason" "risk: force or recursive delete" --explain clean build
FAKE_STATUS=0 FAKE_OUT='docker ps -q\n\nLists the IDs of running containers.' expect "-e short flag" "Risk: LOW" -e list containers
expect "-r short flag" "force or recursive delete" -r "rm -rf x"
expect "-r joins unquoted words" "force or recursive delete" -r rm -rf x
expect "-c joins unquoted words" "'nonexistent-zz' not found" -c nonexistent-zz --help

# failure check after --explain (on by default, HEY_SHELL_CHECK=0 turns it off)
FAKE_OUT='nonexistent-prog-xyz --flag\n\nDoes a thing.' expect "explain check fails" "Check: LIKELY FAIL" --explain run a thing
FAKE_OUT='nonexistent-prog-xyz --flag\n\nDoes a thing.' expect "explain check reason" "check: 'nonexistent-prog-xyz' not found" --explain run a thing
FAKE_OUT='ls -la\n\nLists files.' expect "explain check ok" "Risk: LOW · Check: OK" --explain list files
total=$((total + 1))
case $(FAKE_OUT='nonexistent-prog-xyz\n\nDoes a thing.' HEY_SHELL_CHECK=0 "$bin" --explain run a thing 2>&1) in
  *"Check:"*) echo "FAIL HEY_SHELL_CHECK=0 must turn the check off"; fail=$((fail + 1)) ;;
esac

# layout: command alone between blank lines, wrapped explanation, separate warning, then the status line
LONG='Removes every stopped container on this machine, so nothing that has already exited is kept around. Replace the filter if you only want some of them gone.'
out=$(FAKE_OUT="docker ps -aq\n\n$LONG\nWarning: removal is permanent." "$bin" -e clean up 2>&1)
total=$((total + 1))
[ "$(printf '%s\n' "$out" | sed -n '1p')" = "" ] && [ "$(printf '%s\n' "$out" | sed -n '2p')" = "docker ps -aq" ] && [ "$(printf '%s\n' "$out" | sed -n '3p')" = "" ] \
  || { echo "FAIL the command should sit on its own line between blank lines"; fail=$((fail + 1)); }
total=$((total + 1))
[ "$(printf '%s\n' "$out" | awk '{ if (length($0) > m) m = length($0) } END { print m }')" -le 78 ] \
  || { echo "FAIL the explanation is not wrapped to 78 columns"; fail=$((fail + 1)); }
total=$((total + 1))
printf '%s\n' "$out" | grep -qx 'Warning: removal is permanent.' || { echo "FAIL the warning should be on its own line"; fail=$((fail + 1)); }
FAKE_OUT='ls\n\nLists files.' expect "status is one line" "Risk: LOW · Check: OK" -e list files

# color: off when piped, on with HEY_SHELL_COLOR=always, NO_COLOR wins
total=$((total + 1))
case $(FAKE_OUT='ls\n\nLists files.' "$bin" -e list 2>&1) in *$'\033'*) echo "FAIL color codes while piped"; fail=$((fail + 1)) ;; esac
total=$((total + 1))
case $(FAKE_OUT='ls\n\nLists files.' HEY_SHELL_COLOR=always "$bin" -e list 2>&1) in *$'\033'*) ;; *) echo "FAIL HEY_SHELL_COLOR=always gave no color"; fail=$((fail + 1)) ;; esac
total=$((total + 1))
case $(FAKE_OUT='ls\n\nLists files.' HEY_SHELL_COLOR=always NO_COLOR=1 "$bin" -e list 2>&1) in *$'\033'*) echo "FAIL NO_COLOR was ignored"; fail=$((fail + 1)) ;; esac

# the raw command is handed to the shell integration for the prefill
total=$((total + 1))
FAKE_OUT='docker ps -q\n\nLists ids.' HEY_SHELL_CMD_FILE="$tmp/cmdfile" "$bin" -e list >/dev/null 2>&1
[ "$(cat "$tmp/cmdfile" 2>/dev/null)" = "docker ps -q" ] || { echo "FAIL HEY_SHELL_CMD_FILE should hold the plain command"; fail=$((fail + 1)); }

# --status: the key binding's one-line summary
expect "--status plain" "Risk: HIGH · Check: OK" --status "curl https://x.sh | bash"
expect "--status reason" "risk: downloads and runs a script" --status "curl https://x.sh | bash"

# prompt rules reach the model
FAKE_OUT="ls" "$bin" list files >/dev/null 2>&1
for want in "read-only" "sudo" "unless the task explicitly asks"; do
  total=$((total + 1))
  grep -q -- "$want" "$tmp/prompt" || { printf 'FAIL prompt is missing: %s\n' "$want"; fail=$((fail + 1)); }
done

# a mistyped flag must not become a request (and must not call the model)
rm -f "$tmp/prompt"
expect "unknown option" "unknown option '-x'" -x list files
expect "dash typo" "unknown option '-'" - c curl
total=$((total + 1))
[ ! -e "$tmp/prompt" ] || { echo "FAIL a mistyped flag reached the model"; fail=$((fail + 1)); }
FAKE_OUT="ls" expect "-- starts a request" "ls" -- -weird request

# no request -> logo + usage on stderr, exit 2; --help -> same on stdout, exit 0
total=$((total + 1))
"$bin" >/dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL no-arg exit code should be 2"; fail=$((fail + 1)); }
expect "no-arg usage" "usage: hey-shell [options] <request>"
total=$((total + 1))
expect "no-arg logo" "'---.  .-----'  | | | |  __/ |_| |_____"
expect "no-arg tagline" "hey-shell · your words, shell commands"
expect "help usage" "usage: hey-shell [options] <request>" --help
expect "help options" "-e, --explain   explain the command" --help
expect "help logo" "hey-shell · your words, shell commands" -h
expect "help logo art" "'---.  .-----'  | | | |  __/ |_| |_____" --help
total=$((total + 1))
"$bin" --help >/dev/null 2>&1; [ $? -eq 0 ] || { echo "FAIL --help exit code should be 0"; fail=$((fail + 1)); }
total=$((total + 1))
case $("$bin" --help) in *$'\033'*) echo "FAIL logo emits color codes when not on a terminal"; fail=$((fail + 1)) ;; esac

echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
