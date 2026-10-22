# shellcheck shell=bash
# Project awareness for the prompt. Sourced by bin/hey-shell.
#   hey_shell_context  prints one line about the current directory for Claude: the modern tools installed, the
#                      project type, npm script and make target names, and the git branch. Names only: no file
#                      contents are sent. HEY_SHELL_CONTEXT=0 turns it off.

# _hs_names <text>: the first 15 non-empty lines of text, joined with ", "
_hs_names() { printf '%s\n' "$1" | sed '/^$/d' | head -15 | paste -sd, - | sed 's/,/, /g'; }

hey_shell_context() {
  [ "${HEY_SHELL_CONTEXT:-1}" != 0 ] || return 0
  local t tools='' project='' scripts='' targets='' branch='' f
  for t in rg fd bat eza jq yq fzf gh podman docker kubectl gsed gawk; do
    command -v "$t" >/dev/null 2>&1 && tools="${tools:+$tools, }$t"
  done

  add() { project="${project:+$project, }$1"; }
  if [ -f pnpm-lock.yaml ]; then add pnpm
  elif [ -f yarn.lock ]; then add yarn
  elif [ -f bun.lockb ] || [ -f bun.lock ]; then add bun
  elif [ -f package.json ]; then add npm; fi
  [ -f Cargo.toml ] && add cargo
  [ -f go.mod ] && add "go modules"
  if [ -f uv.lock ]; then add uv
  elif [ -f poetry.lock ]; then add poetry
  elif [ -f pyproject.toml ]; then add "python (pyproject.toml)"
  elif [ -f requirements.txt ]; then add "pip (requirements.txt)"; fi
  [ -f Gemfile ] && add bundler
  [ -f pom.xml ] && add maven
  { [ -f build.gradle ] || [ -f build.gradle.kts ]; } && add gradle
  for f in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do [ -f "$f" ] && { add "docker compose ($f)"; break; }; done
  [ -f Dockerfile ] && add Dockerfile
  if [ -f Makefile ]; then
    add Makefile
    targets="$(_hs_names "$(grep -E '^[A-Za-z0-9][A-Za-z0-9_.-]*:([^=]|$)' Makefile | cut -d: -f1)")"
  fi
  unset -f add
  if [ -f package.json ] && command -v jq >/dev/null 2>&1; then
    scripts="$(_hs_names "$(jq -r '.scripts // {} | keys[]' package.json 2>/dev/null)")"
  fi
  branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"

  [ -z "$tools" ] || printf 'Installed tools: %s (prefer them when they fit). ' "$tools"
  [ -z "$project" ] || printf 'Project here: %s. ' "$project"
  [ -z "$scripts" ] || printf 'npm scripts: %s. ' "$scripts"
  [ -z "$targets" ] || printf 'make targets: %s. ' "$targets"
  [ -z "$branch" ] || printf 'Git branch: %s. ' "$branch"
  return 0
}
