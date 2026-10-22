---
description: Install the hey-shell key binding and optional short aliases into your bash, zsh or fish config
argument-hint: [key, e.g. ctrl+g or alt+o]
allowed-tools: Bash
---

Run `bash "${CLAUDE_PLUGIN_ROOT}/install.sh" --key <key> --aliases` (or `--no-alias`, or `--alias`, `--alias-explain`, `--alias-risk`, `--alias-check`, `--alias-fix`, `--alias-what` with custom names) and report its output. The installer cannot prompt from here, so ask the user first, in one message: which key (default `ctrl+g`; format `ctrl+<letter|digit>` or `alt+<letter|digit>`; use the one in $ARGUMENTS if given) and whether they want the short aliases `hs` (`hey-shell`), `hse` (`hey-shell --explain`), `hsr` (`--risk`), `hsc` (`--check`), `hsf` (`--fix`) and `hsw` (`--what`): all, none, or custom names. Do not run anything until they answer. If the user's shell is not bash, zsh or fish, or they name one, also pass `--shell bash|zsh|fish`. Then tell them to run `source` on the rc file named in the output, or open a new terminal.
