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
~/hey-shell/install.sh          # asks for a key (default ctrl+g) and a short alias (default hs); detects bash/zsh, add --shell zsh to force
~/hey-shell/install.sh --key alt+o --alias hs # or pass them directly (--no-alias for none); re-run to change either
source ~/.zshrc                    # or ~/.bashrc, or open a new terminal
```

The installer appends one marked block to your rc file. It sets your key, adds the repo's `bin/` to your `PATH` so `hey-shell` works as a command, optionally adds a short alias (such as `hs`), and loads the key binding. An alias you already defined yourself is left alone, and a name that would shadow an existing command asks first. Keys are `ctrl+<letter|digit>` or `alt+<letter|digit>`; terminal-reserved ones (`ctrl+c`, `ctrl+d`, `ctrl+z`, ...) are refused. On macOS, `alt+` keys need "Use Option as Meta key" enabled in your terminal. Remove everything with `./install.sh --uninstall`.

### As a Claude Code plugin

```
/plugin marketplace add alparslanpolat/hey-shell
/plugin install hey-shell@hey-shell
/hey-shell:install
```

A plugin cannot bind keys in your shell by itself, so `/hey-shell:install` runs the installer above. The plugin also adds `/hey-shell:sh <request>` to get a command inside Claude Code.

## Explain a command first

`hey-shell -e "<request>"` (or `--explain`) prints the command, a short plain-language explanation, and its risk rating. The command is then left on your next prompt line, ready to edit and run with Enter (it is never run for you). The installer puts `hey-shell` on your `PATH` and loads this behavior; if you installed an older version, re-run `./install.sh --key <your key>` to add it.

```
$ hey-shell -e "delete all stopped docker containers"
docker ps -aq -f status=exited | xargs -r docker rm

Lists all exited containers and removes them. Removal is permanent, but images and named volumes are kept.

risk: medium (stops or removes containers)
```

Placeholders such as `<branch-name>` are left in the prefilled line for you to replace. In zsh the prefill uses `print -z`. In bash it relies on the terminal answering a status query (`ESC[5n`), which most terminals do; if yours doesn't, you just get the printed output without the prefill.

Generated commands favor portable, read-only forms and avoid `sudo` and destructive flags unless you ask for them in the request.

If something goes wrong you get one actionable line instead of a stack trace: Claude Code missing (with the install link), not logged in, rate limited, or unreachable.

## Predict failures (on by default)

`hey-shell -c "<command>"` (or `--check`) predicts whether a command would fail, without running it. The same prediction runs automatically after `-e` and on the key binding; set `HEY_SHELL_CHECK=0` in your rc file to turn that off. Example, from inside a shell that is not in a tmux session:

```
$ hey-shell -e how to split terminal into 4
tmux split-window -h \; split-window -v \; select-pane -t 0 \; split-window -v

This splits the current tmux window into a 2x2 grid of four panes.

risk: low
check: would likely fail: no tmux server is running; start tmux first
```

What it looks at:

- **Syntax:** the command is parsed with `bash -n` or `zsh -n`, which never executes it.
- **Programs:** every program in a pipeline or `&&` chain must exist as an executable, builtin, keyword, or one of your own aliases and functions.
- **Environment:** `git` needs a repository, `tmux` needs a running server, `docker` needs its socket. These use read-only probes (`git rev-parse`, `tmux list-sessions`, a socket test).

It is a prediction, not a guarantee. It cannot know whether a file exists, whether you have permission, or what a program does with its arguments, and it skips commands behind `sudo -u ...` or other wrapper options. The only way to be sure a command works is to run it, which hey-shell will never do for you.

## Configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `HEY_SHELL_MODEL` | `haiku` | model passed to `claude --model` |
| `HEY_SHELL_CHECK` | on | `0` turns off the failure prediction after `-e` and on the key binding (see above) |
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

This is pattern matching, not a guarantee: it can miss risky commands and flag harmless ones, so always read the command before pressing Enter. The rules live in `lib/risk.sh`; run `./test/risk.test.sh` (plus `./test/cli.test.sh`, `./test/check.test.sh` and `./test/install.test.sh`) after changing them, and `hey-shell --risk "<command>"` to check one by hand. Your request and current directory path are sent to the model.

## License

MIT
