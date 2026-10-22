# shellcheck shell=bash
# Version and update notice. Sourced by bin/hey-shell.
#   hey_shell_version        prints the version from .claude-plugin/plugin.json
#   hey_shell_update_notice  prints one line when a newer version is published (needs hey_shell_colors to have run)
#   hey_shell_update         moves this checkout to the newest release tag (installs from the one-line installer
#                            sit on a tag); a checkout on a branch (development) is pulled instead
# The notice reads a cached answer and refreshes it in the background at most once a day, so it never slows a
# command down; a new release shows up on the run after the refresh. HEY_SHELL_UPDATE_CHECK=0 turns it off.

_hs_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_hs_update_url="${HEY_SHELL_UPDATE_URL:-https://raw.githubusercontent.com/alparslanpolat/hey-shell/main/.claude-plugin/plugin.json}"

hey_shell_version() {
  sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$_hs_root/.claude-plugin/plugin.json"
}

# _hs_newer <a> <b>: true when version a is newer than b (major.minor.patch)
_hs_newer() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 }
    exit 1 }'
}

hey_shell_update_notice() {
  [ "${HEY_SHELL_UPDATE_CHECK:-1}" != 0 ] || return 0
  local dir="${XDG_CACHE_HOME:-$HOME/.cache}/hey-shell" cache latest current
  cache="$dir/latest-version"
  if [ ! -f "$cache" ] || [ -n "$(find "$cache" -mmin +1440 2>/dev/null)" ]; then
    mkdir -p "$dir" 2>/dev/null && touch "$cache" 2>/dev/null || return 0 # touch first: one refresh a day, even offline
    ( v="$(curl -fsSL --max-time 5 "$_hs_update_url" | sed -n 's/.*"version": *"\([^"]*\)".*/\1/p')"
      [ -z "$v" ] || printf '%s\n' "$v" > "$cache" ) >/dev/null 2>&1 &
  fi
  latest="$(head -1 "$cache" 2>/dev/null)" current="$(hey_shell_version)"
  [ -n "$latest" ] && _hs_newer "$latest" "$current" || return 0
  printf '\n%sUpdate available:%s %s → %s%s%s %s· run: hey-shell --update%s\n' \
    "$C_BRAND" "$C_OFF" "$current" "$C_BRAND" "$latest" "$C_OFF" "$C_MUTED" "$C_OFF"
}

hey_shell_update() {
  local before after
  command -v git >/dev/null || { echo "hey-shell: git is not installed, so hey-shell cannot update itself" >&2; return 1; }
  git -C "$_hs_root" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "hey-shell: $_hs_root is not a git checkout; reinstall it with git clone (see the README)" >&2; return 1; }
  before="$(hey_shell_version)"
  if git -C "$_hs_root" symbolic-ref -q HEAD >/dev/null; then # on a branch: a development checkout
    git -C "$_hs_root" pull --ff-only --quiet \
      || { echo "hey-shell: update failed; local changes in $_hs_root may be in the way (git -C $_hs_root status)" >&2; return 1; }
  else # on a release tag: move to the newest one
    local ref
    ref="$(git -C "$_hs_root" ls-remote --tags --refs origin 'v*' | sed 's|.*refs/tags/||' \
      | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1.2,1n -k2,2n -k3,3n | tail -1)"
    [ -n "$ref" ] || { echo "hey-shell: could not find a release to update to" >&2; return 1; }
    { git -C "$_hs_root" fetch --quiet --depth 1 origin "refs/tags/$ref:refs/tags/$ref" 2>/dev/null \
        || git -C "$_hs_root" fetch --quiet origin "refs/tags/$ref:refs/tags/$ref"; } \
      && git -C "$_hs_root" -c advice.detachedHead=false checkout --quiet "$ref" \
      || { echo "hey-shell: update to $ref failed; local changes in $_hs_root may be in the way (git -C $_hs_root status)" >&2; return 1; }
  fi
  after="$(hey_shell_version)"
  rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/hey-shell/latest-version"
  if [ "$before" = "$after" ]; then
    printf 'hey-shell %s is up to date\n' "$after"
  else
    printf 'hey-shell updated: %s → %s\nOpen a new terminal (or source your rc file) to use it.\n' "$before" "$after"
  fi
}
