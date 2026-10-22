"""Run a command on a pseudo-terminal, typing this script's stdin into it.

  printf 'answer\n' | python3 -I test/pty_run.py ./install.sh --shell zsh

Used by the installer and shell tests: the installer only asks its questions on a terminal, and the key
binding only exists in an interactive shell. Unlike `script`, this works when stdin is a pipe or socket (CI
runners, editors), on Linux and macOS alike.

PTY_STEP_DELAY=<seconds> types one line at a time and waits that long after each, for interactive shells
that would drop type-ahead or need time to answer a key; a \x1f byte in the input is a pause that types nothing. The output is copied to stdout either way. The
command is killed if it is still running PTY_TIMEOUT seconds (default 30) after the last line.
"""
import os
import pty
import re
import select
import sys
import time

typed = sys.stdin.buffer.read()
delay = float(os.environ.get("PTY_STEP_DELAY", "0"))
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], sys.argv[1:])


def pump(seconds):
    """Copy the terminal's output to stdout for up to `seconds`; False once the terminal closes."""
    end = time.time() + seconds
    while time.time() < end:
        ready, _, _ = select.select([fd], [], [], 0.05)
        if not ready:
            continue
        try:
            chunk = os.read(fd, 65536)
        except OSError:  # the child closed the terminal
            return False
        if not chunk:
            return False
        sys.stdout.buffer.write(chunk)
        if b"\x1b[5n" in chunk:  # answer a status query like a real terminal (bash's prefill relies on it)
            os.write(fd, b"\x1b[0n")
    return True


if delay:
    pump(delay)
    for step in re.split(rb"(?<=\n)|\x1f", typed):
        if step:
            os.write(fd, step)
        if not pump(delay):
            break
else:
    os.write(fd, typed)
if pump(float(os.environ.get("PTY_TIMEOUT", "30"))):  # still open: the command hangs
    os.kill(pid, 9)
    sys.stderr.write("pty_run: timed out\n")
_, status = os.waitpid(pid, 0)
sys.exit(os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1)
