<h1 align="center"><img src="docs/assets/banner.png" alt="hey-shell" width="640"></h1>

![hey-shell demo: plain-English requests turned into shell commands](docs/assets/demo.gif)

Type what you want in plain language, press a key (**Ctrl+G** by default, configurable), and your prompt line is replaced with the shell command. It is **never executed for you**: you review, edit and press Enter.

```
$ grep the container ids of working docker   <Ctrl+G>
$ docker ps -q
```

Works in bash and zsh on Linux, WSL2 and macOS. Uses the [Claude Code](https://claude.com/claude-code) CLI (`claude -p`), so it must be installed and logged in.

## At a glance

| You type | What happens |
| --- | --- |
| a request, then **Ctrl+G** | the line becomes the command; read it, edit it, press Enter |
| `hse <request>` | the command, a short explanation, its risk and a failure check; the command is left on your next prompt |
| `hsr <command>` | rates a command: low, medium or high |
| `hsc <command>` | predicts whether a command would fail, without running it |
| `hs` | the logo and the help |

`hs`, `hse`, `hsr` and `hsc` are the short aliases the installer offers for `hey-shell`, `hey-shell -e`, `hey-shell -r` and `hey-shell -c`. The long forms always work.

## Install

```bash
git clone https://github.com/alparslanpolat/hey-shell ~/hey-shell
~/hey-shell/install.sh
source ~/.bashrc        # or ~/.zshrc, or open a new terminal
```

The installer asks two things:

- **The key** that turns your request into a command (default `ctrl+g`). Keys are `ctrl+<letter|digit>` or `alt+<letter|digit>`; ones the terminal needs (`ctrl+c`, `ctrl+d`, `ctrl+z`, ...) are refused. On macOS, `alt+` keys need "Use Option as Meta key" enabled in your terminal.
- **Short aliases**: `hs`, `hse`, `hsr`, `hsc`. Press Enter for all of them, `n` for none, or `c` to pick each name. An alias you already defined yourself is left alone, and a name that would hide an existing command asks first.

It then adds one marked block to your rc file that sets the key, puts `hey-shell` on your `PATH`, adds the aliases and loads the key binding. To skip the questions, pass the answers: `~/hey-shell/install.sh --key alt+o --aliases` (or `--no-alias`; `--alias`, `--alias-explain`, `--alias-risk` and `--alias-check` set single names; `--shell zsh` forces the shell).

### As a Claude Code plugin

```
/plugin marketplace add alparslanpolat/hey-shell
/plugin install hey-shell@hey-shell
/hey-shell:install
```

A plugin cannot bind keys in your shell by itself, so `/hey-shell:install` runs the installer above. The plugin also adds `/hey-shell:sh <request>` to get a command inside Claude Code.

## Update

```bash
git -C ~/hey-shell pull
```

Then open a new terminal (or `source` your rc file) so the shell picks up the new version. To change the key or aliases later, re-run the installer with the flags above.

## Uninstall

```bash
~/hey-shell/install.sh --uninstall   # removes the block from your rc file
rm -rf ~/hey-shell
```

## Explain a command first

`hse "<request>"` (`hey-shell -e`) prints the command on its own lines, a short explanation wrapped to 78 columns, an optional separate warning, and one status line with the risk and the failure check. The command is then left on your next prompt line, ready to edit and run with Enter (it is never run for you).

```
$ hse delete all stopped docker containers

docker ps -aq -f status=exited | xargs -r docker rm

Removes every container that has exited. Replace the filter to remove only some.
Warning: removal is permanent and also deletes the containers' writable data.

Risk: MEDIUM · Check: OK
  risk: stops or removes containers
```

Colors follow purpose: cyan for the command, amber for risk, red for danger, green only for a passed check, gray for labels and hints. They appear on a terminal only; `NO_COLOR=1` turns them off.

Placeholders such as `<branch-name>` are left in the prefilled line for you to replace. In zsh the prefill uses `print -z`. In bash it relies on the terminal answering a status query (`ESC[5n`), which most terminals do; if yours doesn't, you just get the printed output without the prefill.

Generated commands favor portable, read-only forms and avoid `sudo` and destructive flags unless you ask for them in the request.

If something goes wrong you get one actionable line instead of a stack trace: Claude Code missing (with the install link), not logged in, rate limited, unreachable, or too slow to answer.

## Predict failures (on by default)

`hsc "<command>"` (`hey-shell -c`) predicts whether a command would fail, without running it. The same prediction runs automatically after `hse` and on the key binding; set `HEY_SHELL_CHECK=0` in your rc file to turn that off. Example, from a shell that is not in a tmux session:

```
$ hse how to split terminal into 4

tmux split-window -h \; split-window -v \; select-pane -t 0 \; split-window -v

Splits the current tmux window into a 2x2 grid of four panes.

Risk: LOW · Check: LIKELY FAIL
  check: no tmux server is running; start tmux first
```

What it looks at:

- **Syntax:** the command is parsed with `bash -n` or `zsh -n`, which never executes it.
- **Programs:** every program in a pipeline or `&&` chain must exist as an executable, builtin, keyword, or one of your own aliases and functions.
- **Environment:** `git` needs a repository, `tmux` needs a running server, `docker` needs its socket. These use read-only probes (`git rev-parse`, `tmux list-sessions`, a socket test).

It is a prediction, not a guarantee. It cannot know whether a file exists, whether you have permission, or what a program does with its arguments. It skips commands behind `sudo -u ...` or other wrapper options, does not look inside `$((...))`, array literals or `case` patterns, and leaves out anything it cannot tell for sure: a wrong "likely fail" on a working command is worse than a missed one. The only way to be sure a command works is to run it, which hey-shell will never do for you.

## Configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `HEY_SHELL_MODEL` | `haiku` | model passed to `claude --model` |
| `HEY_SHELL_TIMEOUT` | `30` | seconds to wait for Claude before giving up |
| `HEY_SHELL_CHECK` | on | `0` turns off the failure prediction after `hse` and on the key binding |
| `HEY_SHELL_COLOR` | `auto` | `always` or `never` overrides the terminal detection; `NO_COLOR` always wins |
| `HEY_SHELL_KEY` | `ctrl+g` | trigger key: `ctrl+x`, `alt+x`, or a raw `bindkey` / `bind` sequence. The installer sets this for you |
| `HEY_SHELL_CLAUDE` | `claude` | the CLI to call; set it for a custom path (the tests use it to inject a fake) |

Set them with `export` before the hey-shell block in your rc file.

## Safety

Commands are only placed on the prompt, never executed. Each generated command is also rated, and the rating is shown on the status line under it:

| Level | Shown as | Examples |
| --- | --- | --- |
| high | `Risk: HIGH` in red, with the reason | `curl … \| bash`, `rm -rf`, `find … -delete`, `git push --force`, `git reset --hard`, `docker volume rm`, `terraform destroy`, `dd`, `mkfs` |
| medium | `Risk: MEDIUM` in amber, with the reason | `sudo`, `rm`, `kill`, `docker stop`, `systemctl restart`, `chown -R`, writes to `/etc` |
| low | `Risk: LOW` | everything else |

This is pattern matching, not a guarantee: it can miss risky commands and flag harmless ones, so always read the command before pressing Enter. `hsr "<command>"` rates one by hand.

## Privacy

Each request goes to Claude through your own Claude Code CLI, under your Claude Code account. hey-shell sends the text of your request, your OS, your shell name and the path of your current directory. It does not send your shell history, environment variables or files. Claude Code itself may add context of its own, such as your Claude Code settings or memory, which is why answers sometimes mention tools you use.

The risk rating and the failure check run locally and send nothing.

## Troubleshooting

**`hey-shell: command not found` or `hs: command not found` right after installing.** The installer edits your rc file, and only new shells read it. Open a new terminal or run `source ~/.bashrc` (`~/.zshrc` in zsh). The file name is `.bashrc`, with no dot in the middle.

**Ctrl+G does nothing.** Check the key is bound: `bind -X | grep hey_shell` in bash, `bindkey | grep hey_shell` in zsh. If nothing is listed, open a new terminal. If another tool uses the key, pick a different one with `~/hey-shell/install.sh --key ctrl+o`.

**"thinking..." and then an error.** Claude Code must be installed and logged in: run `claude` once and complete `/login`. A slow network can hit the timeout; raise `HEY_SHELL_TIMEOUT`.

**`hse` prints the command but does not leave it on the next prompt (bash).** Your terminal does not answer the status query the prefill uses. Copy the command from the output; in zsh this always works.

**`alt+` keys type symbols on macOS.** Enable "Use Option as Meta key" in your terminal's settings, or use a `ctrl+` key.

**The check says LIKELY FAIL but the command works.** The check is a prediction. Please open an issue with the command; contributors add such commands to `test/valid-commands.txt` so they are never flagged again. `HEY_SHELL_CHECK=0` turns the check off.

**The command is wrong or not what you meant.** Name the tool you use ("in tmux", "with herdr"), use `hse` to read what the command does, or try a larger model with `HEY_SHELL_MODEL=sonnet`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how the code fits together and how to run the tests.

## License

MIT
