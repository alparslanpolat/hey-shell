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
[ -z "${FAKE_SLEEP:-}" ] || sleep "$FAKE_SLEEP"
printf '%s' "$last" > "$FAKE_PROMPT_FILE"
[ -z "${FAKE_OUT:-}" ] || printf '%b\n' "$FAKE_OUT"
[ -z "${FAKE_ERR:-}" ] || printf '%b\n' "$FAKE_ERR" >&2
exit "${FAKE_STATUS:-0}"
FAKE
chmod +x "$tmp/claude"
export HEY_SHELL_CLAUDE="$tmp/claude" FAKE_PROMPT_FILE="$tmp/prompt" HEY_SHELL_UPDATE_CHECK=0

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
FAKE_SLEEP=4 FAKE_OUT="ls" HEY_SHELL_TIMEOUT=1 expect "timeout" "did not answer within 1s" list files
HEY_SHELL_TIMEOUT=soon expect "bad timeout" "HEY_SHELL_TIMEOUT must be a whole number" list files
total=$((total + 1))
SECONDS=0; FAKE_OUT="ls" "$bin" list files >/dev/null 2>&1
[ "$SECONDS" -le 1 ] || { echo "FAIL a fast reply was held back by the timeout watchdog (${SECONDS}s)"; fail=$((fail + 1)); }
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

# layout: label and boxed command after a blank line, wrapped explanation, separate warning, then the status line
LONG='Removes every stopped container on this machine, so nothing that has already exited is kept around. Replace the filter if you only want some of them gone.'
out=$(FAKE_OUT="docker ps -aq\n\n$LONG\nWarning: removal is permanent." "$bin" -e clean up 2>&1)
total=$((total + 1))
[ "$(printf '%s\n' "$out" | sed -n '1p')" = "" ] && [ "$(printf '%s\n' "$out" | sed -n '2p')" = "SUGGESTED COMMAND · REVIEW BEFORE RUNNING" ] \
  && printf '%s\n' "$out" | sed -n '4p' | grep -q '^│ \$ docker ps -aq  *│$' && [ "$(printf '%s\n' "$out" | sed -n '6p')" = "" ] \
  || { echo "FAIL the command should sit in a labeled box after a blank line"; fail=$((fail + 1)); }
total=$((total + 1))
[ "$(printf '%s\n' "$out" | grep -v '^[│╭╰]' | awk '{ if (length($0) > m) m = length($0) } END { print m }')" -le 78 ] \
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

# version comes from the plugin manifest, so it has one source
want_version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$(dirname "$bin")/../.claude-plugin/plugin.json")
expect "--version" "hey-shell $want_version" --version
expect "-V" "hey-shell $want_version" -V

# --status: the key binding's boxed command and one-line summary
expect "--status box" "│ \$ ls -la" --status "ls -la"
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

# update notice after --explain: read from a cache that is refreshed in the background (file:// stands in for GitHub)
export XDG_CACHE_HOME="$tmp/cache"
mkdir -p "$tmp/cache/hey-shell"
echo 99.0.0 > "$tmp/cache/hey-shell/latest-version"
FAKE_OUT='ls\n\nLists files.' HEY_SHELL_UPDATE_CHECK=1 expect "update notice" "Update available: $("$bin" -V | cut -d' ' -f2) → 99.0.0" -e list files
HEY_SHELL_UPDATE_CHECK=1 expect "update notice on the key binding" "Update available:" --status "ls"
total=$((total + 1))
case $(FAKE_OUT='ls' HEY_SHELL_UPDATE_CHECK=1 "$bin" list files 2>/dev/null) in
  *"Update available"*) echo "FAIL the notice must stay out of a captured command"; fail=$((fail + 1)) ;;
esac
echo 0.0.1 > "$tmp/cache/hey-shell/latest-version"
total=$((total + 1))
case $(FAKE_OUT='ls\n\nLists files.' HEY_SHELL_UPDATE_CHECK=1 "$bin" -e list files 2>&1) in
  *"Update available"*) echo "FAIL no update notice when the published version is older"; fail=$((fail + 1)) ;;
esac
rm -f "$tmp/cache/hey-shell/latest-version"
printf '{ "version": "98.1.0" }\n' > "$tmp/remote.json"
FAKE_OUT='ls\n\nLists files.' HEY_SHELL_UPDATE_CHECK=1 HEY_SHELL_UPDATE_URL="file://$tmp/remote.json" "$bin" -e list files >/dev/null 2>&1
i=0; while [ "$i" -lt 20 ] && [ "$(cat "$tmp/cache/hey-shell/latest-version" 2>/dev/null)" != 98.1.0 ]; do sleep 0.1; i=$((i + 1)); done
total=$((total + 1))
[ "$(cat "$tmp/cache/hey-shell/latest-version" 2>/dev/null)" = 98.1.0 ] || { echo "FAIL the background refresh should cache the published version"; fail=$((fail + 1)); }

# --update: fast-forwards a git checkout; "up to date" when nothing is new, an error outside a checkout
git init -q "$tmp/origin" && cp -R "$(dirname "$bin")/.." "$tmp/origin.src" && rm -rf "$tmp/origin.src/.git" \
  && cp -R "$tmp/origin.src/." "$tmp/origin" && git -C "$tmp/origin" add -A \
  && git -C "$tmp/origin" -c user.name=t -c user.email=t@t commit -qm base && git clone -q "$tmp/origin" "$tmp/clone"
got=$("$tmp/clone/bin/hey-shell" --update 2>&1); total=$((total + 1))
case $got in *"is up to date"*) ;; *) echo "FAIL --update with nothing new: $got"; fail=$((fail + 1)) ;; esac
sed -i.bak 's/"version": *"[^"]*"/"version": "9.9.9"/' "$tmp/origin/.claude-plugin/plugin.json" && rm "$tmp/origin/.claude-plugin/plugin.json.bak"
git -C "$tmp/origin" -c user.name=t -c user.email=t@t commit -qam bump
got=$("$tmp/clone/bin/hey-shell" -U 2>&1); total=$((total + 1))
case $got in *"updated: "*" → 9.9.9"*) ;; *) echo "FAIL --update should pull the new version: $got"; fail=$((fail + 1)) ;; esac
got=$("$tmp/origin.src/bin/hey-shell" --update 2>&1); total=$((total + 1))
case $got in *"is not a git checkout"*) ;; *) echo "FAIL --update outside a checkout: $got"; fail=$((fail + 1)) ;; esac
expect "help lists update" "-U, --update    update to the latest version" --help
expect "hse -h" "usage: hey-shell [options] <request>" --explain -h
expect "hsr -V" "hey-shell " -r -V
got=$("$tmp/clone/bin/hey-shell" -e -U 2>&1); total=$((total + 1))
case $got in *"is up to date"*) ;; *) echo "FAIL hse -U should update: $got"; fail=$((fail + 1)) ;; esac

echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
