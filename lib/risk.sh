# Risk classification for generated commands. Sourced by bin/hey-shell.
#   hey_shell_risk "<command>"  sets HEY_SHELL_RISK_LEVEL (low|medium|high) and HEY_SHELL_RISK_REASON.
# Pattern matching only: it can miss things and can flag harmless text. It is a prompt to read, not a guarantee.

_hs_rule() { # level regex reason; the first matching high rule wins, medium never overrides high
  [ "$HEY_SHELL_RISK_LEVEL" = high ] && return
  [ "$1" = medium ] && [ "$HEY_SHELL_RISK_LEVEL" != low ] && return
  if printf '%s' "$_hs_cmd" | grep -Eiq -- "$2"; then
    HEY_SHELL_RISK_LEVEL=$1
    HEY_SHELL_RISK_REASON=$3
  fi
}

hey_shell_risk() {
  _hs_cmd=$1
  HEY_SHELL_RISK_LEVEL=low
  HEY_SHELL_RISK_REASON=""

  # high: destructive, irreversible, or runs code fetched from the network
  _hs_rule high '(curl|wget)[^|;&]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da|k)?sh([[:space:]]|$)' 'downloads and runs a script'
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
  _hs_rule medium '\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh([[:space:]]|$)' 'pipes text into a shell'
}
