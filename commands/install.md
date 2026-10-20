---
description: Install the hey-shell key binding into your bash or zsh rc file
argument-hint: [key, e.g. ctrl+g or alt+o]
allowed-tools: Bash
---

Run `bash "${CLAUDE_PLUGIN_ROOT}/install.sh" --key <key>` and report its output. Use the key from $ARGUMENTS; if none was given, ask the user which key they want (default `ctrl+g`; format `ctrl+<letter|digit>` or `alt+<letter|digit>`) before running, because the installer cannot prompt from here. If the user's shell is not bash or zsh, or they name one, also pass `--shell bash|zsh`. Then tell them to run `source` on the rc file named in the output, or open a new terminal.
