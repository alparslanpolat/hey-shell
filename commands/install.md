---
description: Install the hey-shell key binding and optional short alias into your bash or zsh rc file
argument-hint: [key, e.g. ctrl+g or alt+o]
allowed-tools: Bash
---

Run `bash "${CLAUDE_PLUGIN_ROOT}/install.sh" --key <key> --alias <name>` (or `--no-alias`) and report its output. The installer cannot prompt from here, so ask the user first, in one message: which key (default `ctrl+g`; format `ctrl+<letter|digit>` or `alt+<letter|digit>`; use the one in $ARGUMENTS if given) and whether they want a short alias for `hey-shell` (suggest `hs`, or none). Do not run anything until they answer. If the user's shell is not bash or zsh, or they name one, also pass `--shell bash|zsh`. Then tell them to run `source` on the rc file named in the output, or open a new terminal.
