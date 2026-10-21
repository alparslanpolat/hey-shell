<h1 align="center"><img src="docs/assets/banner.png" alt="hey-shell" width="640"></h1>

![hey-shell: your words, shell commands](docs/assets/preview.png)

Type what you want in plain language, press a key (**Ctrl+G** by default, configurable), and your prompt line is replaced with the shell command. It is **never executed for you**: you review, edit and press Enter.

```
$ grep the container ids of working docker   <Ctrl+G>
$ docker ps -q
```

Works in bash and zsh on Linux, WSL2 and macOS. Uses the [Claude Code](https://claude.com/claude-code) CLI (`claude -p`), so it must be installed and logged in.

## Install

```bash
git clone https://github.com/alparslanpolat/hey-shell ~/hey-shell
~/hey-shell/install.sh          # asks which key to use (default ctrl+g); detects bash/zsh, add --shell zsh to force
~/hey-shell/install.sh --key alt+o # or pass the key directly; re-run with a new --key to change it
source ~/.zshrc                    # or ~/.bashrc, or open a new terminal
```

The installer appends one marked block to your rc file. Keys are `ctrl+<letter|digit>` or `alt+<letter|digit>`; terminal-reserved ones (`ctrl+c`, `ctrl+d`, `ctrl+z`, ...) are refused. On macOS, `alt+` keys need "Use Option as Meta key" enabled in your terminal. Remove everything with `./install.sh --uninstall`.

### As a Claude Code plugin

```
/plugin marketplace add alparslanpolat/hey-shell
/plugin install hey-shell@hey-shell
/hey-shell:install
```

A plugin cannot bind keys in your shell by itself, so `/hey-shell:install` runs the installer above. The plugin also adds `/hey-shell:sh <request>` to get a command inside Claude Code.

## Explain a command first

`bin/hey-shell --explain "<request>"` prints the command, a short plain-language explanation, and its risk rating, without touching your prompt. Put `bin/` on your `PATH` or call it by full path.

```
$ hey-shell --explain "delete all stopped docker containers"
docker ps -aq -f status=exited | xargs -r docker rm

Lists all exited containers and removes them. Removal is permanent, but images and named volumes are kept.

risk: medium (stops or removes containers)
```

Generated commands favor portable, read-only forms and avoid `sudo` and destructive flags unless you ask for them in the request.

If something goes wrong you get one actionable line instead of a stack trace: Claude Code missing (with the install link), not logged in, rate limited, or unreachable.

## Configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `HEY_SHELL_MODEL` | `haiku` | model passed to `claude --model` |
| `HEY_SHELL_CLAUDE` | `claude` | the CLI to call; set it for a custom path (the tests use it to inject a fake) |
| `HEY_SHELL_KEY` | `ctrl+g` | trigger key: `ctrl+x`, `alt+x`, or a raw `bindkey` / `bind` sequence. The installer sets this for you |

Set `HEY_SHELL_MODEL` before the `source` line in your rc file; `HEY_SHELL_KEY` is written there by the installer.

## Safety

Commands are only placed on the prompt, never executed. Each generated command is also rated:

| Level | Warning | Examples |
| --- | --- | --- |
| high | red banner with the reason | `curl … \| bash`, `rm -rf`, `find … -delete`, `git push --force`, `git reset --hard`, `docker volume rm`, `terraform destroy`, `dd`, `mkfs` |
| medium | yellow caution | `sudo`, `rm`, `kill`, `docker stop`, `systemctl restart`, `chown -R`, writes to `/etc` |
| low | none | everything else |

This is pattern matching, not a guarantee: it can miss risky commands and flag harmless ones, so always read the command before pressing Enter. The rules live in `lib/risk.sh`; run `./test/risk.test.sh` (and `./test/cli.test.sh` for the CLI behavior) after changing them, and `bin/hey-shell --risk "<command>"` to check one by hand. Your request and current directory path are sent to the model.

## License

MIT
