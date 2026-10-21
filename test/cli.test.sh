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
FAKE_STATUS=0 FAKE_OUT='docker ps -q\n\nLists the IDs of running containers.' expect "explain low risk" "risk: low" --explain list containers
FAKE_STATUS=0 FAKE_OUT='rm -rf build\n\nDeletes the build directory.' expect "explain high risk" "risk: high (force or recursive delete)" --explain clean build
FAKE_STATUS=0 FAKE_OUT='docker ps -q\n\nLists the IDs of running containers.' expect "-e short flag" "risk: low" -e list containers
expect "-r short flag" "force or recursive delete" -r "rm -rf x"

# opt-in failure check after --explain
FAKE_OUT='nonexistent-prog-xyz --flag\n\nDoes a thing.' HEY_SHELL_CHECK=1 expect "explain check fails" "check: would likely fail: 'nonexistent-prog-xyz' not found" --explain do thing
FAKE_OUT='ls -la\n\nLists files.' HEY_SHELL_CHECK=1 expect "explain check ok" "check: ok" --explain list files
total=$((total + 1))
case $(FAKE_OUT='nonexistent-prog-xyz\n\nDoes a thing.' "$bin" --explain do thing 2>&1) in
  *"check:"*) echo "FAIL the check must be off unless HEY_SHELL_CHECK=1"; fail=$((fail + 1)) ;;
esac

# prompt rules reach the model
FAKE_OUT="ls" "$bin" list files >/dev/null 2>&1
for want in "read-only" "sudo" "unless the task explicitly asks"; do
  total=$((total + 1))
  grep -q -- "$want" "$tmp/prompt" || { printf 'FAIL prompt is missing: %s\n' "$want"; fail=$((fail + 1)); }
done

# no request -> logo + usage on stderr, exit 2; --help -> same on stdout, exit 0
total=$((total + 1))
"$bin" >/dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL no-arg exit code should be 2"; fail=$((fail + 1)); }
expect "no-arg usage" "usage:  hey-shell [-e | --explain] <request>"
expect "help usage" "usage:  hey-shell [-e | --explain] <request>" --help
expect "help logo" "your words, shell commands" -h
expect "help logo art" "'---.  .-----'  | | | |  __/ |_| |_____" --help
total=$((total + 1))
"$bin" --help >/dev/null 2>&1; [ $? -eq 0 ] || { echo "FAIL --help exit code should be 0"; fail=$((fail + 1)); }
total=$((total + 1))
case $("$bin" --help) in *$'\033'*) echo "FAIL logo emits color codes when not on a terminal"; fail=$((fail + 1)) ;; esac

echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
