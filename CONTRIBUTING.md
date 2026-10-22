# Contributing

## How it fits together

```
your prompt ──Ctrl+G──▶ shell/hey-shell.{bash,zsh}   key binding, the hey-shell -e wrapper, the prefill
                          │
                          ▼
                       bin/hey-shell                  flags, the prompt, calls the agent CLI with a timeout
                          ├── lib/risk.sh             low / medium / high, by pattern
                          ├── lib/check.sh            would it fail? parses, never runs the command
                          ├── lib/context.sh          installed tools and project type, names only
                          ├── lib/update.sh           version, update notice, --update
                          ├── lib/render.sh           colors, wrapping, the "Risk: … · Check: …" line
                          └── lib/banner.sh + logo.txt  logo and help
install.sh                adds or removes the marked block in ~/.bashrc / ~/.zshrc
commands/, .claude-plugin/  the Claude Code plugin
docs/                     the GitHub Pages site and images; docs/install is the one-line installer
```

The key binding calls `bin/hey-shell "<request>"`, puts the printed command on your prompt line, then calls `bin/hey-shell --status "<command>"` for the status line. `hey-shell -e` prints the explanation; the shell function around it reads the plain command from `HEY_SHELL_CMD_FILE` and prefills your next prompt with it.

The one rule that does not bend: **hey-shell never runs a generated command.** It only places it on the prompt.

## Tests

```bash
./test/run.sh    # every suite: risk, cli, check, install, shell
./test/lint.sh   # shellcheck, and zsh -n for the zsh file (needs shellcheck installed)
```

The suites never call a real agent: `HEY_SHELL_CLI` (or `HEY_SHELL_CLAUDE`) points them at a fake. A new agent needs a case in `agent_command` and the error texts at the top of `bin/hey-shell`, a `--agent` value in `install.sh`, and a test of its command line in `test/cli.test.sh`. GitHub Actions runs both on Linux and macOS for every push to `main` and every pull request (`.github/workflows/test.yml`).

- `test/shell.test.sh` drives real interactive bash and zsh through a pseudo-terminal (`test/pty_run.py`, needs `python3`): the key binding, `hse`'s prefill and `hsf`. It tests every bash it finds, so on macOS both the system bash 3.2 (which has no `READLINE_LINE` and uses the history fallback) and Homebrew's bash 5.

- Changing a risk rule in `lib/risk.sh`? Add a case to `test/risk.test.sh`.
- The failure check flagged a command that works? Add it as one line to `test/valid-commands.txt`, then fix `lib/check.sh` until `./test/check.test.sh` passes.
- A test should fail when the feature breaks: break it on purpose once and watch the suite go red.

## Evaluating the model's commands

The tests above check hey-shell's own code. Whether the commands are any good depends on the model, so `test/eval/` holds about 60 realistic requests, each with the essential tool or flag a correct answer uses and the highest risk the request justifies:

```bash
./test/eval/run.sh                        # all of them, default model (calls Claude: costs usage, ~1 minute)
HEY_SHELL_MODEL=sonnet ./test/eval/run.sh # compare another model
HEY_SHELL_AGENT=codex ./test/eval/run.sh  # or another agent
./test/eval/run.sh net- git-              # only some ids
```

It reports how many came back valid, parse, match the pattern, avoid GNU-only flags on macOS, stay within their risk ceiling, and pass the failure check, then lists every miss. Results are kept in `test/eval/results/<date>-<model>.tsv`; commit the run you compare against. Run it when you change the prompt in `bin/hey-shell` or the default model, and before a release. The "no issues" column depends on the machine too (docker not running, npm not installed), so compare it on the same machine. Add a request when you find one the model gets wrong.

## Style

Plain bash that also runs on macOS's bash 3.2 (no associative arrays, no `${var,,}`), BSD and GNU tools alike. Keep functions small and comment the why, not the what.

## Releasing

Run the evaluation and compare it with the last results. Bump `version` in `.claude-plugin/plugin.json`, turn `Unreleased` in `CHANGELOG.md` into the version, wait for CI to pass on that commit, and tag it `vX.Y.Z`. Users see an "Update available" line once the bumped `plugin.json` is on `main`.
