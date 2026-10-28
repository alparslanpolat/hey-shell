# Changelog

The version lives in `.claude-plugin/plugin.json`; `hey-shell --version` prints it.

## Unreleased

- Risk: the agent now rates each command too, in the same answer (no extra call), as a second opinion on top of the built-in rules. It can raise the level but never lower it, and a level it raised is shown as `risk (agent): <reason>`. `hsr --ai "<command>"` asks it for a command you already have; `HEY_SHELL_AI_RISK=0` turns it off. The shell integrations pass the rating to the status line through `HEY_SHELL_RISK_FILE`.
- Evaluation: an `agent_risk` column and a `false_low_ai` metric show how many of the rules' blind spots the agent's rating catches.

## 0.7.0

Safety and trust fixes from an external audit:

- Agents: Codex now runs with `--sandbox read-only --ignore-user-config`, so your Codex config cannot loosen the read-only sandbox. Gemini is marked experimental: its CLI documents no way to turn its tools off. The README states what is enforced for each agent.
- Risk: `curl … | /bin/bash`, `| /usr/bin/env bash`, `| sudo -E bash`, `| python3` and other interpreters behind a path, `env` or `sudo` options are rated high (they were low or medium). `git reset` without `--hard` is medium. A low rating now reads `Risk: none recognized`: no known risky pattern matched, which is not the same as safe.
- Installer: it refuses to touch an rc file whose hey-shell block is damaged (a missing end marker used to delete everything after the start marker), keeps the previous file as `<rc>.hey-shell-backup`, writes the new one atomically, and keeps symlinked rc files and file permissions.
- Privacy: history is off by default (`HEY_SHELL_HISTORY=1` turns it on); when on, the file is private to you, keeps the last 500 answers, and `hey-shell --history --clear` deletes it. The current folder is sent relative to your home, without your user name.
- The one-line installer installs the newest release tag instead of the development branch and refuses a `~/hey-shell` that is a checkout of another repository; `hey-shell --update` moves a release install to the newest release.
- A timed-out agent's child processes are stopped too.
- Evaluation: safety is now judged by a rule independent of hey-shell's own risk check, plus per-request forbidden patterns, and a `false_low` metric counts destructive answers the risk check rated low. Requests run inside a fresh git repository.

Also new:

- fish support: Ctrl+G, `hse`, refine, `hsf` and the aliases work in fish (`shell/hey-shell.fish`). The installer writes fish syntax to `~/.config/fish/config.fish`, generated commands are fish commands, and the failure check parses with `fish --no-execute` and knows fish builtins. Tested in real fish sessions and in CI on Linux (fish 3.7) and macOS (fish 4.9).
- The demo GIF shows the new risk wording and bash / zsh / fish.

## 0.6.0

- One-line install: `curl -fsSL https://alparslanpolat.github.io/hey-shell/install | bash` downloads hey-shell into `~/hey-shell` (or updates it) and runs the installer, which still asks its questions.
- Choose your agent: `HEY_SHELL_AGENT=codex` or `gemini` (or `install.sh --agent codex`) uses the Codex CLI or the Gemini CLI instead of Claude Code. Errors, the install hint and the login hint follow the agent.
- The website and README show agent choice, the one-line install and the newer features; a new demo GIF with real output.
- Evaluation: a run on a subset of requests no longer replaces the full results file; two patterns accept more correct answers.

## 0.5.0

- `hse` and `hsf` no longer need hey-shell on your `PATH`: the shell integration calls its own copy.
- Re-running the installer no longer piles up blank lines in your rc file.
- Ctrl+G now works in macOS's built-in bash 3.2, which has no `READLINE_LINE` (it silently did nothing before).
- `Check: OK` is now `Check: No known issues`: it means no known problem was found, not that the command was tested.
- Replies are validated before they reach your prompt: terminal control characters are removed, a `$ ` prompt and backticks are stripped, and prose, several commands or very long replies are refused with a message.
- Risk rules catch in-place edits (`sed -i`, `perl -pi`, `truncate`), `> file` overwrites, `mv`, `git push`, publishing, global installs, cloud deletes (`aws s3 rm --recursive`, `gcloud … delete`, `helm uninstall`), `rsync --delete`, `eval "$(curl …)"`, `base64 -d | sh`, and SQL `DELETE`/`UPDATE` without `WHERE`. The README lists what the checks cannot detect.
- The failure check no longer mistakes a redirection after `$(...)` for a program (`kill $(lsof -ti :3000) 2>/dev/null`).
- Help and README lead with the main flow; the other options are grouped under "when you need more".
- CI on Linux and macOS (bash 3.2 and 5, zsh), new tests that drive real interactive shells, bash install/uninstall tests, and an evaluation suite of 61 requests for the model's commands (`test/eval/`).
- Short aliases `hsf` (`hey-shell --fix`) and `hsw` (`hey-shell --what`), offered by the installer (`--alias-fix`, `--alias-what`); `hsf` skips itself when it looks up your last command.

## 0.4.0

- Fits your setup: Claude is told which modern tools you have (`rg`, `fd`, `jq`, ...) and what the folder is (package manager, Makefile targets, npm scripts, docker compose, git branch). Names only; `HEY_SHELL_CONTEXT=0` turns it off.
- Refine: `<command> # <change>` and the key, or `hey-shell "<command> # <change>"`.
- `hey-shell --fix`: a corrected version of your last failed command, left on your next prompt.
- `hey-shell -w` / `--what`: explains a command you already have.
- `hey-shell --history [text]`: your recent requests, logged locally (`HEY_SHELL_HISTORY=0` turns it off).
- Explanations come in the language of your request; `--what` and `--fix` follow your locale.
- The version is shown in the banner.

## 0.3.0

- The command is shown in a labeled box (`SUGGESTED COMMAND · REVIEW BEFORE RUNNING`), after `hse` and under the prompt on the key binding.
- In zsh the box and the risk line under the prompt are now in color; they disappear once you edit or run the line.
- Update notice: an `Update available` line when a newer version is published, checked at most once a day in the background (`HEY_SHELL_UPDATE_CHECK=0` turns it off).
- `hey-shell --update` (`-U`) updates hey-shell in place.
- `hse`, `hsr` and `hsc` accept `-h`, `-V` and `-U`.
- Claude is called without tools or MCP servers, and requests are no longer saved in your Claude Code session history.
- Animated demo in the README; smaller images.

## 0.2.0

- `hse` / `hey-shell -e`: the command, a short explanation and its risk, then the command is left on your next prompt.
- Risk rating (low, medium, high) for every generated command.
- Failure prediction (`hsc` / `hey-shell -c`), on by default: syntax, missing programs, and git, tmux and docker preconditions, without running anything.
- One status line, `Risk: … · Check: …`, under the command on the key binding and after `hse`.
- Choose the trigger key at install; optional short aliases `hs`, `hse`, `hsr`, `hsc`.
- `hey-shell` is put on your `PATH` by the installer.
- Clear one-line errors (not installed, not logged in, rate limited, unreachable) and a timeout (`HEY_SHELL_TIMEOUT`, default 30s).
- "thinking..." while bash waits for Claude.
- ASCII logo on `hey-shell` and `--help`; `--version`.

## 0.1.0

- First release: type a request, press Ctrl+G, and the prompt line becomes the command. Never executed for you.
- bash and zsh; Claude Code plugin with `/hey-shell:install` and `/hey-shell:sh`.
