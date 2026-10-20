# hey-shell

Type what you want in plain language, press **Ctrl+G**, and your prompt line is replaced with the shell command. It is **never executed for you**: you review, edit and press Enter.

```
$ grep the container ids of working docker   <Ctrl+G>
$ docker ps -q
```

Works in bash and zsh on Linux, WSL2 and macOS. Uses the [Claude Code](https://claude.com/claude-code) CLI (`claude -p`), so it must be installed and logged in.

## Install

```bash
git clone https://github.com/alparslanpolat/hey-shell ~/hey-shell
~/hey-shell/install.sh          # detects bash/zsh; add --shell zsh to force
source ~/.zshrc                    # or ~/.bashrc, or open a new terminal
```

The installer appends one marked `source` block to your rc file and is safe to run twice. Remove it with `./install.sh --uninstall`.

### As a Claude Code plugin

```
/plugin marketplace add alparslanpolat/hey-shell
/plugin install hey-shell@hey-shell
/hey-shell:install
```

A plugin cannot bind keys in your shell by itself, so `/hey-shell:install` runs the installer above. The plugin also adds `/hey-shell:sh <request>` to get a command inside Claude Code.

## Configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `HEY_SHELL_MODEL` | `haiku` | model passed to `claude --model` |
| `HEY_SHELL_KEY` | `^G` (zsh) / `\C-g` (bash) | key binding, in `bindkey` / `bind` syntax |

Set them before the installer's `source` line in your rc file.

## Safety

Commands are only placed on the prompt. If one matches a destructive pattern (`sudo`, `rm -rf`, `dd`, `mkfs`, `docker system prune`, writes to block devices, ...) you get a warning. This is a heuristic, not a guarantee: always read the command before pressing Enter. Your request and current directory path are sent to the model.

## License

MIT
