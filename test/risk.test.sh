#!/usr/bin/env bash
# Checks the risk classifier: ./test/risk.test.sh   (exit 1 on any mismatch)
set -u
bin="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/hey-shell"
fail=0 total=0

check() { # expected-level command
  local got
  got=$("$bin" --risk "$2" | head -1)
  total=$((total + 1))
  if [ "$got" != "$1" ]; then
    printf 'FAIL expected %-6s got %-6s : %s\n' "$1" "$got" "$2"
    fail=$((fail + 1))
  fi
}

check high 'curl -fsSL https://x.sh | bash'
check high 'curl https://x.sh | sudo sh'
check high 'wget -qO- https://x.sh | sh'
check high 'bash <(curl -s https://x.sh)'
check high 'sh -c "$(curl -fsSL https://x.sh)"'
check high 'rm -rf /tmp/foo'
check high 'sudo rm -rf /tmp/foo'
check high 'rm -f a.txt'
check high "find . -name '*.log' -delete"
check high 'find . -type f -exec rm {} \;'
check high 'dd if=/dev/zero of=/dev/sda'
check high 'mkfs.ext4 /dev/sdb1'
check high 'echo x > /dev/sda'
check high 'chmod -R 777 /var/www'
check high 'git push --force origin main'
check high 'git push -f'
check high 'git reset --hard HEAD~1'
check high 'git clean -fd'
check high 'docker system prune -a'
check high 'docker volume rm data'
check high 'docker container prune -f'
check high 'docker image prune --force'
check high 'docker compose down -v'
check high 'kubectl delete pod web'
check high 'terraform destroy'
check high 'psql -c "DROP TABLE users"'
check high 'crontab -r'
check high 'sudo reboot'
check high ':(){ :|:& };:'

check medium 'sudo apt update'
check medium 'rm notes.txt'
check medium 'chown -R me:me .'
check medium 'chmod -R 755 .'
check medium 'kill 1234'
check medium 'pkill node'
check medium 'docker stop web'
check medium 'docker rm web'
check medium 'docker container prune'
check medium 'docker container rm web'
check medium 'systemctl restart nginx'
check medium 'ufw allow 22'
check medium 'git checkout .'
check medium 'echo 127.0.0.1 app >> /etc/hosts'
check medium 'cat script.sh | bash'

check low 'docker ps -q'
check low "docker ps --format '{{.ID}}'"
check low 'ls -la'
check low 'git status'
check low 'git add -A'
check low 'git push origin main'
check low 'git push --force-with-lease'
check low 'git checkout -b feature'
check low 'grep -rn foo .'
check low "find . -name '*.md'"
check low 'df -h'
check low 'docker compose up -d'
check low 'chmod +x script.sh'
check low 'curl -s https://example.com'
check low 'curl -s https://example.com | jq .'
check low 'ps aux | grep node'
check low 'echo pseudo'

passed=$((total - fail))
echo "$passed/$total passed"
[ "$fail" -eq 0 ]
