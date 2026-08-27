#!/usr/bin/env bash
# Добавить участников хакатона в репозитории (запускает Дмитрий со своей машины).
#
#   bash admin/invite.sh ivan-petrov-mf anna-smirnova ...
#   bash admin/invite.sh -f nicks.txt        # по нику в строке
#
# Права: push (можно создавать ветки и открывать pull request).
# Мерджить в main нельзя - это защищено, см. protect.sh
# Репозиторий applications-moderator НЕ выдаётся.
set -euo pipefail
OWNER="dimazaharov72-beep"
REPOS=("MosForum-DayTrack" "MosForum-ERP" "MosForum-Tasker")

NICKS=()
if [ "${1:-}" = "-f" ]; then
  [ -f "${2:-}" ] || { echo "Нет файла ${2:-}"; exit 1; }
  while read -r n; do n="${n//[[:space:]]/}"; [ -n "$n" ] && NICKS+=("$n"); done < "$2"
else NICKS=("$@"); fi
[ ${#NICKS[@]} -gt 0 ] || { echo "Укажи ники: bash admin/invite.sh ник1 ник2"; exit 1; }

for n in "${NICKS[@]}"; do
  if ! gh api "users/$n" >/dev/null 2>&1; then echo "✗ $n — такого пользователя на GitHub нет, проверь ник"; continue; fi
  for r in "${REPOS[@]}"; do
    if gh api -X PUT "repos/$OWNER/$r/collaborators/$n" -f permission=push >/dev/null 2>&1; then
      echo "✓ $n → $r (push)"
    else
      echo "✗ $n → $r не добавился"
    fi
  done
done
echo
echo "Участникам придёт приглашение на почту GitHub — им надо его принять."
