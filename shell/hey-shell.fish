# hey-shell for fish: press your key (default ctrl+g, set HEY_SHELL_KEY="alt+o" etc.)
# to replace the typed request with a generated command. The command is never executed.
set -g _hey_shell_bin (path resolve (status dirname)/../bin/hey-shell)

# The bytes the key sends: ctrl+<letter> is that letter's control code, alt+<x> is ESC then x. Raw bytes
# work in fish 3 and 4 alike.
function _hey_shell_keyseq
    set -l k (string lower -- (set -q HEY_SHELL_KEY; and echo $HEY_SHELL_KEY; or echo ctrl+g))
    if string match -qr '^ctrl\+[a-z]$' -- $k
        set -l i (contains -i -- (string sub -s 6 -- $k) a b c d e f g h i j k l m n o p q r s t u v w x y z)
        printf \\x(printf %02x $i)
    else if string match -qr '^alt\+.$' -- $k
        printf '\e%s' (string sub -s 5 -- $k)
    else
        printf '%s' $k
    end
end

# The labeled box and "Risk: ... · Check: ..." for the command, printed above the prompt. The check is on by
# default (turn off with HEY_SHELL_CHECK=0) and never runs the command.
function _hey_shell_status
    set -l names
    test "$HEY_SHELL_CHECK" = 0; or set names (string join \n -- (functions -n) (abbr --list))
    COLUMNS=$COLUMNS HEY_SHELL_COLOR=always HEY_SHELL_TARGET=fish HEY_SHELL_KNOWN_NAMES="$names" $_hey_shell_bin --status $argv[1]
end

function _hey_shell_fill
    set -l request (commandline)
    test -n "$request"; or return
    set -l errf (mktemp)
    printf '\n\e[2m[hey-shell] thinking...\e[0m'   # replaced below by the result or the error
    set -l cmd (HEY_SHELL_TARGET=fish $_hey_shell_bin "$request" 2>$errf | string collect)
    if test $pipestatus[1] -ne 0
        printf '\r\e[K\e[31m%s\e[0m\n' (cat $errf)
        rm -f $errf
        commandline -f repaint
        return
    end
    printf '\r\e[K'
    rm -f $errf
    test -n "$cmd"; or begin; commandline -f repaint; return; end
    commandline -r -- $cmd
    commandline -C (string length -- $cmd)
    _hey_shell_status $cmd
    commandline -f repaint
end

# Put a command on the next prompt. fish has no `print -z`: fish 4 lets a fish_prompt handler fill the line,
# but fish 3 clears it again after that event, so there hey-shell asks the terminal for its status (ESC[5n)
# and fills the line when the reply (ESC[0n) arrives as input, as the bash integration does.
function _hey_shell_prefill
    test -n "$argv[1]"; or return 0
    set -g _hey_shell_next $argv[1]
    if string match -qr '^[0-3]\.' -- $version
        bind \e'[0n' _hey_shell_prefill_now
        printf '\e[5n'
    else
        function _hey_shell_prefill_once --on-event fish_prompt
            functions -e _hey_shell_prefill_once
            _hey_shell_prefill_now
        end
    end
end

function _hey_shell_prefill_now
    bind -e \e'[0n'
    set -q _hey_shell_next; or return
    commandline -r -- $_hey_shell_next
    set -e _hey_shell_next
end

# `hey-shell -e ...` explains, then leaves the command on the next prompt, ready to edit or run.
# `hey-shell --fix` does the same for a corrected version of your last command (taken from history, with its
# exit status), unless you pass a command.
function hey-shell
    set -l last_status $status
    switch "$argv[1]"
        case -e --explain --fix
            set -l last ''
            if test "$argv[1]" = --fix; and test (count $argv) -eq 1
                # the current line is not in $history yet; skip earlier calls, also through an alias like hsf
                for line in $history[1..10]
                    set -l first (string split -m1 ' ' -- $line)[1]
                    string match -q -- '*--fix*' $line; and continue
                    functions -q -- $first; and string match -q -- '*--fix*' (functions -- $first | string collect); and continue
                    set last $line
                    break
                end
            end
            set -l names
            test "$HEY_SHELL_CHECK" = 0; or set names (string join \n -- (functions -n) (abbr --list))
            set -l color never
            isatty stdout; and set color always
            set -l cmdfile (mktemp)
            set -l lstatus
            test -n "$last"; and set lstatus $last_status
            HEY_SHELL_LAST_CMD="$last" HEY_SHELL_LAST_STATUS="$lstatus" HEY_SHELL_COLOR=$color HEY_SHELL_TARGET=fish \
                HEY_SHELL_CMD_FILE=$cmdfile HEY_SHELL_KNOWN_NAMES="$names" $_hey_shell_bin $argv
            set -l st $status
            if test $st -eq 0
                _hey_shell_prefill (cat $cmdfile)
            end
            rm -f $cmdfile
            return $st
        case '*'
            HEY_SHELL_TARGET=fish $_hey_shell_bin $argv
    end
end

if status is-interactive
    bind (_hey_shell_keyseq) _hey_shell_fill
end
