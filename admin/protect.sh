#!/usr/bin/env bash
# Включить согласование выката: в главную ветку — только через pull request
# с одобрением ВЛАДЕЛЬЦА КОДА (CODEOWNERS). Запускает Дмитрий перед хакатоном.
#
#   bash admin/protect.sh            # показать, что будет сделано
#   bash admin/protect.sh --apply    # применить
#
# Почему одобрений 0, а не 1:
#   «1 одобрение» принимает апрув ЛЮБОГО, у кого есть доступ — двое участников
#   могут одобрить друг друга и смерджить мимо владельца. Требование ревью
#   владельца кода такого обхода не даёт: одобрить обязан тот, кто указан в
#   CODEOWNERS. Ровно эта пара (0 + code owners) и стоит в DayTrack с 04.08,
#   она же оставляет участки, отданные кому-то в CODEOWNERS, под самостоятельный
#   мердж. Ставить сюда 1 — значит и ослабить защиту, и сломать те участки.
#
# enforce_admins=false — владелец может при необходимости смерджить сам
# (`gh pr merge --admin`), участники — нет.
#
# ТРЕБУЕТ файла CODEOWNERS в репозитории, иначе владельцев кода нет и
# требование ни к чему не привязано. Скрипт это проверяет.
set -euo pipefail
OWNER="dimazaharov72-beep"
APPLY=0; [ "${1:-}" = "--apply" ] && APPLY=1

# репозиторий:ветка:обязательные проверки (через запятую, пусто = нет)
TARGETS=(
  "MosForum-DayTrack:main:checks"
  "MosForum-ERP:main:"
  "MosForum-Tasker:corp-master:"
)

for t in "${TARGETS[@]}"; do
  IFS=: read -r repo branch checks <<< "$t"
  if [ -n "$checks" ]; then
    ctx=$(printf '%s\n' "$checks" | tr ',' '\n' | jq -R . | jq -sc .)
    rsc="{\"strict\":false,\"contexts\":$ctx}"
  else rsc="null"; fi
  body=$(cat <<JSON
{
  "required_status_checks": $rsc,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
)
  echo "── $repo / $branch"
  if gh api "repos/$OWNER/$repo/contents/.github/CODEOWNERS?ref=$branch" >/dev/null 2>&1 \
     || gh api "repos/$OWNER/$repo/contents/CODEOWNERS?ref=$branch" >/dev/null 2>&1; then
    echo "   CODEOWNERS на месте"
  else
    echo "   ✗ НЕТ CODEOWNERS — защита была бы пустой, пропускаю репозиторий"
    echo "     создай файл с строкой '\''*  @$OWNER'\'' и запусти снова"
    continue
  fi
  if [ "$APPLY" = 1 ]; then
    if echo "$body" | gh api -X PUT "repos/$OWNER/$repo/branches/$branch/protection" --input - >/dev/null 2>&1; then
      echo "   ✓ защита включена: pull request + одобрение владельца кода"
    else
      echo "   ✗ не удалось (проверь, что ветка существует и план GitHub позволяет защиту)"
    fi
  else
    echo "   будет: pull request + одобрение владельца кода, force push и удаление ветки запрещены"
    [ -n "$checks" ] && echo "   обязательные проверки сохраняются: $checks"
  fi
done
[ "$APPLY" = 1 ] || echo -e "\nЭто был показ. Чтобы применить: bash admin/protect.sh --apply"
