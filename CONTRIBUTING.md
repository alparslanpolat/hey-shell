# Contributing

## How it fits together

```
your prompt ──Ctrl+G──▶ shell/hey-shell.{bash,zsh}   key binding, the hey-shell -e wrapper, the prefill
                          │
                          ▼
                       bin/hey-shell                  flags, the prompt, calls `claude -p` with a timeout
                          ├── lib/risk.sh             low / medium / high, by pattern
                          ├── lib/check.sh            would it fail? parses, never runs the command
                          ├── lib/render.sh           colors, wrapping, the "Risk: … · Check: …" line
                          └── lib/banner.sh + logo.txt  logo and help
install.sh                adds or removes the marked block in ~/.bashrc / ~/.zshrc
commands/, .claude-plugin/  the Claude Code plugin
docs/                     the GitHub Pages site and images
```

The key binding calls `bin/hey-shell "<request>"`, puts the printed command on your prompt line, then calls `bin/hey-shell --status "<command>"` for the status line. `hey-shell -e` prints the explanation; the shell function around it reads the plain command from `HEY_SHELL_CMD_FILE` and prefills your next prompt with it.

The one rule that does not bend: **hey-shell never runs a generated command.** It only places it on the prompt.

## Tests

```bash
./test/run.sh    # every suite
./test/lint.sh   # shellcheck, and zsh -n for the zsh file (needs shellcheck installed)
```

The suites never call the real Claude: `HEY_SHELL_CLAUDE` points them at a fake. Run both before you push; nothing runs them automatically.

- Changing a risk rule in `lib/risk.sh`? Add a case to `test/risk.test.sh`.
- The failure check flagged a command that works? Add it as one line to `test/valid-commands.txt`, then fix `lib/check.sh` until `./test/check.test.sh` passes.
- A test should fail when the feature breaks: break it on purpose once and watch the suite go red.

## Style

Plain bash that also runs on macOS's bash 3.2 (no associative arrays, no `${var,,}`), BSD and GNU tools alike. Keep functions small and comment the why, not the what.

## Releasing

Bump `version` in `.claude-plugin/plugin.json`, add a section to `CHANGELOG.md`, and tag the commit `vX.Y.Z`. Users see an "Update available" line once the bumped `plugin.json` is on `main`.
