# Changelog

The version lives in `.claude-plugin/plugin.json`; `hey-shell --version` prints it.

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
