# shellcheck shell=bash
# shellcheck disable=SC2034  # the results are globals read by bin/hey-shell
# Risk classification for generated commands. Sourced by bin/hey-shell.
#   hey_shell_risk "<command>"  sets HEY_SHELL_RISK_LEVEL (low|medium|high), HEY_SHELL_RISK_REASON and
#                               HEY_SHELL_RISK_SOURCE=rules; hey_shell_risk_agent (below) can raise it afterwards.
# Pattern matching only: it can miss things and can flag harmless text. It is a prompt to read, not a guarantee.
# It cannot see through indirection: a command built at run time ($(echo rm) -rf, x=rm; $x ..., eval of a
# variable), aliases and functions defined elsewhere, or what a script it runs will do. README "Safety" lists
# these limits.

_hs_rule() { # level regex reason; the first matching high rule wins, medium never overrides high
  [ "$HEY_SHELL_RISK_LEVEL" = high ] && return
  [ "$1" = medium ] && [ "$HEY_SHELL_RISK_LEVEL" != low ] && return
  if printf '%s' "$_hs_cmd" | grep -Eiq -- "$2"; then
    HEY_SHELL_RISK_LEVEL=$1
    HEY_SHELL_RISK_REASON=$3
  fi
}

# After a pipe: the program that reads the piped text as code. Any path (/bin/bash), `env`, and `sudo` with its
# options in front, then a shell or a script interpreter reading its program from stdin.
_hs_into='\|[[:space:]]*(sudo([[:space:]]+-[[:alnum:]-]+)*[[:space:]]+)?([^[:space:]|;&]*/)?(env([[:space:]]+-[[:alnum:]-]+)*[[:space:]]+)?([^[:space:]|;&]*/)?((ba|z|da|k|fi)?sh|python[0-9.]*|perl|ruby|node|php)([[:space:]]+-[[:alnum:]-]*)*([[:space:];|&)]|$)'

hey_shell_risk() {
  _hs_cmd=$1
  HEY_SHELL_RISK_LEVEL=low
  HEY_SHELL_RISK_REASON=""
  HEY_SHELL_RISK_SOURCE=rules

  # high: destructive, irreversible, or runs code fetched from the network
  _hs_rule high "(curl|wget|fetch|http|aria2c)[^|;&]*$_hs_into" 'downloads and runs a script'
  _hs_rule high '(ba|z|da)?sh[[:space:]]+(-c[[:space:]]+)?["'"'"']?(<\(|\$\()[[:space:]]*(curl|wget)' 'downloads and runs a script'
  _hs_rule high '(^|[^[:alnum:]_])rm[[:space:]]+(-[[:alnum:]]*[rf]|--(recursive|force))' 'force or recursive delete'
  _hs_rule high 'find[[:space:]].*(-delete|-exec[[:space:]]+rm)' 'find that deletes files'
  _hs_rule high '(^|[^[:alnum:]_])(dd|mkfs[.[:alnum:]]*|shred|wipefs|fdisk|parted)([^[:alnum:]_]|$)' 'writes to or wipes disks'
  _hs_rule high '>[[:space:]]*/dev/(sd|nvme|disk|hd|vd)' 'writes to a disk device'
  _hs_rule high 'chmod[[:space:]]+(-[[:alnum:]]*R[[:alnum:]]*|--recursive)[[:space:]]+[0-7]*777' 'recursive world-writable permissions'
  _hs_rule high 'git[[:space:]]+push[^|;&]*([[:space:]]-f|[[:space:]]--force)([[:space:]]|$)' 'force-pushes and can overwrite remote history'
  _hs_rule high 'git[[:space:]]+reset[[:space:]]+--hard' 'discards uncommitted changes'
  _hs_rule high 'git[[:space:]]+clean[[:space:]]+-[[:alnum:]]*f' 'deletes untracked files'
  _hs_rule high 'docker[[:space:]]+(system[[:space:]]+prune|volume[[:space:]]+(rm|prune))|docker([[:space:]]+|-)compose[[:space:]]+down[^|;&]*(-v|--volumes)' 'deletes docker data'
  _hs_rule high 'docker[[:space:]]+([[:alnum:]]+[[:space:]]+)?prune[^|;&]*([[:space:]]-[[:alnum:]]*f|--force)' 'deletes docker data without asking'
  _hs_rule high 'kubectl[[:space:]]+delete|terraform[[:space:]]+destroy' 'deletes infrastructure'
  _hs_rule high '(drop|truncate)[[:space:]]+(database|table|schema)' 'drops database objects'
  _hs_rule high 'crontab[[:space:]]+-r' 'removes all cron jobs'
  _hs_rule high '(^|[^[:alnum:]_])(shutdown|reboot|halt|poweroff)([^[:alnum:]_]|$)' 'shuts down or restarts the machine'
  _hs_rule high ':[(][)][[:space:]]*[{]' 'looks like a fork bomb'
  _hs_rule high '(eval|source|\.)[[:space:]]+["'"'"']?(<\(|\$\()[[:space:]]*(curl|wget)' 'downloads and runs a script'
  _hs_rule high '(base64|xxd|openssl)[^|]*(-d|--decode|-r)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da|k)?sh([[:space:]]|$)' 'decodes hidden text and runs it'
  _hs_rule high 'rsync[^|;&]*[[:space:]]--delete' 'deletes files at the destination'
  _hs_rule high 'aws[[:space:]]+s3[[:space:]]+(rm|rb)[^|;&]*(--recursive|--force)|gsutil[[:space:]]+(-m[[:space:]]+)?rm[[:space:]]+-[[:alnum:]]*r|gcloud[[:space:]].*[[:space:]]delete([[:space:]]|$)|az[[:space:]].*[[:space:]]delete([[:space:]]|$)|helm[[:space:]]+(uninstall|delete)' 'deletes cloud resources'
  _hs_rule high 'redis-cli[^|;&]*[[:space:]](flushall|flushdb)|dropDatabase[(]' 'deletes database data'
  _hs_rule high 'diskutil[[:space:]]+(erase|zero|secureErase|partition)' 'writes to or wipes disks'
  if [ "$HEY_SHELL_RISK_LEVEL" != high ] && printf '%s' "$_hs_cmd" | grep -Eiq '(^|[^[:alnum:]_])(delete[[:space:]]+from|update[[:space:]]+[[:alnum:]_."]+[[:space:]]+set)[[:space:]]' \
     && ! printf '%s' "$_hs_cmd" | grep -Eiq '[[:space:]]where[[:space:]]'; then
    HEY_SHELL_RISK_LEVEL=high HEY_SHELL_RISK_REASON='changes every row (no WHERE clause)'
  fi

  # medium: changes state or needs privileges, usually fine once read
  _hs_rule medium '(^|[^[:alnum:]_])sudo([^[:alnum:]_]|$)' 'runs with root privileges'
  _hs_rule medium '(^|[^[:alnum:]_/-])rm[[:space:]]' 'deletes files'
  _hs_rule medium '(chmod|chown)[[:space:]]+(-[[:alnum:]]*R|--recursive)' 'recursive permission or ownership change'
  _hs_rule medium '(^|[^[:alnum:]_])(kill|killall|pkill)([^[:alnum:]_]|$)' 'terminates processes'
  _hs_rule medium 'docker[[:space:]]+([[:alnum:]]+[[:space:]]+)?prune' 'deletes unused docker data'
  _hs_rule medium 'docker[[:space:]]+((container|image)[[:space:]]+)?(rm|rmi|kill|stop|restart)' 'stops or removes containers'
  _hs_rule medium 'systemctl[[:space:]]+(stop|disable|restart|mask)' 'changes system services'
  _hs_rule medium '(^|[^[:alnum:]_])(iptables|ufw|nft)([^[:alnum:]_]|$)' 'changes firewall rules'
  _hs_rule medium 'git[[:space:]]+(checkout|restore)[^|;&]*[[:space:]]\.([[:space:]]|$)' 'discards local changes'
  _hs_rule medium '>>?[[:space:]]*/(etc|boot|usr|bin|sbin)/' 'writes to a system directory'
  _hs_rule medium "$_hs_into" 'pipes text into a shell or interpreter'
  _hs_rule medium '(^|[^[:alnum:]_])(delete[[:space:]]+from|update[[:space:]]+[[:alnum:]_."]+[[:space:]]+set)[[:space:]]' 'changes database rows'
  _hs_rule medium '(^|[^[:alnum:]_])(sed|gsed)[[:space:]]+(-[[:alnum:]]*i|--in-place)|perl[[:space:]]+-[[:alnum:]]*i|(^|[^[:alnum:]_])truncate[[:space:]]' 'edits files in place'
  _hs_rule medium '(^|[^[:alnum:]_])mv[[:space:]]' 'moves files and can overwrite the target'
  _hs_rule medium 'git[[:space:]]+(push|reset|branch[[:space:]]+-D|stash[[:space:]]+(drop|clear)|rebase|commit[^|;&]*--amend)' 'changes git history or a remote'
  _hs_rule medium '(npm|pnpm|yarn|cargo|gem|poetry)[[:space:]]+publish|twine[[:space:]]+upload|docker[[:space:]]+push|gh[[:space:]]+release[[:space:]]+create' 'publishes to the outside world'
  _hs_rule medium '(npm|pnpm|yarn)[[:space:]]+(i|install|add|remove|uninstall)[^|;&]*([[:space:]]-g|--global)|(brew|apt|apt-get|dnf|yum|pacman|port)[[:space:]]+(install|uninstall|remove|purge|upgrade|-S|-R)|pip3?[[:space:]]+(install|uninstall)' 'changes installed software'
  _hs_rule medium 'docker([[:space:]]+|-)compose[[:space:]]+(down|rm|stop)' 'stops or removes containers'
  _hs_rule medium '(systemctl|launchctl)[[:space:]]+(enable|load|bootstrap|unload|bootout)' 'changes what runs at startup'
  _hs_rule medium 'kubectl[[:space:]]+(apply|scale|rollout|patch|edit|drain|cordon)|terraform[[:space:]]+apply' 'changes infrastructure'
  # "> file" replaces the file; >>, 2>&1 and writes to /dev/null or the terminal do not
  if [ "$HEY_SHELL_RISK_LEVEL" = low ] && printf '%s' "$_hs_cmd" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" \
       | grep -Eo '(^|[^>&0-9])[0-9]?>[|]?[[:space:]]*[^&>[:space:]]+' | grep -Ev '>[|]?[[:space:]]*/dev/(null|stdout|stderr|tty)$' | grep -q .; then
    HEY_SHELL_RISK_LEVEL=medium HEY_SHELL_RISK_REASON='overwrites a file with >'
  fi
}

# The agent's own rating, a second opinion on top of the rules above. The agent that wrote the command is asked to
# end its reply with "Risk: <low|medium|high>: <reason>"; bin/hey-shell passes that line here.
#   hey_shell_risk_agent "<line>"  after hey_shell_risk: raises HEY_SHELL_RISK_LEVEL to the agent's level when that
#                                  is higher, and sets HEY_SHELL_RISK_SOURCE=agent. It never lowers a level, so a reply
#                                  talked into "low" (by the request, or text pasted into it) changes nothing.
# The reason is the model's text: control characters are dropped and it is cut to 80 characters before it is shown.
_hs_rank() { case $1 in high) echo 2 ;; medium) echo 1 ;; *) echo 0 ;; esac; }

hey_shell_risk_agent() {
  local line level reason
  line=$(printf '%s' "$1" | head -1 | LC_ALL=C tr -d '\000-\037\177' | sed 's/^[[:space:]]*[Rr][Ii][Ss][Kk]:[[:space:]]*//')
  level=$(printf '%s' "$line" | sed -E 's/^([[:alpha:]]+).*/\1/' | tr '[:upper:]' '[:lower:]')
  case $level in low|medium|high) ;; *) return 0 ;; esac
  [ "$(_hs_rank "$level")" -gt "$(_hs_rank "$HEY_SHELL_RISK_LEVEL")" ] || return 0
  reason=$(printf '%s' "${line:${#level}}" | sed -E 's/^[[:space:]]*[-:]*[[:space:]]*//; s/[[:space:]]+/ /g; s/[[:space:].]*$//' | cut -c1-80)
  HEY_SHELL_RISK_LEVEL=$level
  HEY_SHELL_RISK_REASON=${reason:-rated $level by the agent}
  HEY_SHELL_RISK_SOURCE=agent
}
