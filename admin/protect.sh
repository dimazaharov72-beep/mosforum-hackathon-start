#!/usr/bin/env bash
# Включить согласование выката: в главную ветку — только через pull request
# с одобрением владельца. Запускает Дмитрий один раз перед хакатоном.
#
#   bash admin/protect.sh            # показать, что будет сделано
#   bash admin/protect.sh --apply    # применить
#
# enforce_admins=false — владелец может при необходимости смерджить сам
# (`gh pr merge --admin`), участники — нет.
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
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
)
  echo "── $repo / $branch"
  if [ "$APPLY" = 1 ]; then
    if echo "$body" | gh api -X PUT "repos/$OWNER/$repo/branches/$branch/protection" --input - >/dev/null 2>&1; then
      echo "   ✓ защита включена: нужен pull request + 1 одобрение"
    else
      echo "   ✗ не удалось (проверь, что ветка существует и план GitHub позволяет защиту)"
    fi
  else
    echo "   будет: нужен pull request + 1 одобрение, force push и удаление ветки запрещены"
    [ -n "$checks" ] && echo "   обязательные проверки сохраняются: $checks"
  fi
done
[ "$APPLY" = 1 ] || echo -e "\nЭто был показ. Чтобы применить: bash admin/protect.sh --apply"
