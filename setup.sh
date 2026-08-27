#!/usr/bin/env bash
# =============================================================================
# Хакатон МосФорум — настройка рабочего места (macOS)
# Запуск:  bash setup.sh
# Флаги:   --full        поставить и дополнительные плагины (figma, codex, кибербез)
#          --no-docker   не ставить Docker Desktop (это ~2 ГБ и долго)
#          --no-cursor   не ставить редактор Cursor
#          --no-clone    не скачивать репозитории
# Скрипт можно запускать повторно — он ничего не ломает и доделывает пропущенное.
# =============================================================================
set -uo pipefail

FULL=0; DO_DOCKER=1; DO_CURSOR=1; DO_CLONE=1
for a in "$@"; do case "$a" in
  --full) FULL=1;; --no-docker) DO_DOCKER=0;; --no-cursor) DO_CURSOR=0;; --no-clone) DO_CLONE=0;;
  *) echo "Неизвестный флаг: $a"; exit 1;;
esac; done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OWNER="dimazaharov72-beep"
REPOS=("MosForum-DayTrack" "MosForum-ERP" "MosForum-Tasker")
WORKDIR="$HOME/hackathon"
PROBLEMS=()

say()  { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; PROBLEMS+=("$*"); }
have() { command -v "$1" >/dev/null 2>&1; }

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Это скрипт для Mac. На Windows запускай setup.ps1"; exit 1
fi

say "Шаг 1/9. Инструменты командной строки Apple"
if xcode-select -p >/dev/null 2>&1; then ok "уже стоят"
else
  echo "  Сейчас откроется окно установки — нажми «Установить» и дождись конца."
  xcode-select --install >/dev/null 2>&1 || true
  until xcode-select -p >/dev/null 2>&1; do sleep 10; done
  ok "поставлены"
fi

say "Шаг 2/9. Homebrew (менеджер программ)"
if have brew; then ok "уже стоит"
else
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    && ok "поставлен" || { warn "Homebrew не поставился"; }
fi
for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [ -x "$p" ] && eval "$("$p" shellenv)" && break
done
if have brew && ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
  echo "eval \"\$($(command -v brew) shellenv)\"" >> "$HOME/.zprofile"
fi

say "Шаг 3/9. git, gh, Node.js 22, jq"
have brew && brew install --quiet git gh jq node@22 >/dev/null 2>&1
if have brew; then brew link --overwrite --force node@22 >/dev/null 2>&1 || true; fi
export PATH="$(brew --prefix 2>/dev/null)/opt/node@22/bin:$PATH"
if ! grep -q 'opt/node@22/bin' "$HOME/.zprofile" 2>/dev/null && have brew; then
  echo "export PATH=\"$(brew --prefix)/opt/node@22/bin:\$PATH\"" >> "$HOME/.zprofile"
fi
have git  && ok "git $(git --version | awk '{print $3}')"       || warn "git не установился"
have gh   && ok "gh $(gh --version | head -1 | awk '{print $3}')" || warn "gh не установился"
have node && ok "node $(node -v)"                                 || warn "Node.js не установился"
case "$(node -v 2>/dev/null)" in v22.*) : ;; *) warn "нужна Node.js 22, а стоит $(node -v 2>/dev/null || echo 'ничего')";; esac

say "Шаг 4/9. Редактор Cursor"
if [ "$DO_CURSOR" = 0 ]; then ok "пропущено по флагу"
elif [ -d "/Applications/Cursor.app" ]; then ok "уже стоит"
else have brew && brew install --quiet --cask cursor >/dev/null 2>&1 && ok "поставлен" || warn "Cursor не поставился — поставь вручную с cursor.com"
fi

say "Шаг 5/9. Docker Desktop (нужен для базы данных DayTrack)"
if [ "$DO_DOCKER" = 0 ]; then ok "пропущено по флагу"
elif [ -d "/Applications/Docker.app" ]; then ok "уже стоит"
else
  echo "  Это большая загрузка (~2 ГБ), может занять 10-20 минут."
  have brew && brew install --quiet --cask docker >/dev/null 2>&1 && ok "поставлен" || warn "Docker не поставился — поставь вручную с docker.com"
fi

say "Шаг 6/9. Claude Code"
if have claude; then ok "уже стоит ($(claude --version 2>/dev/null | head -1))"
else
  curl -fsSL https://claude.ai/install.sh | bash && ok "поставлен" || warn "Claude Code не поставился"
  export PATH="$HOME/.local/bin:$PATH"
fi
have claude || export PATH="$HOME/.local/bin:$PATH"

say "Шаг 7/9. Общий профиль: правила, скиллы, настройки"
mkdir -p "$HOME/.claude/skills"
STAMP="$(date +%Y%m%d-%H%M%S)"
for f in CLAUDE.md settings.json; do
  [ -f "$HOME/.claude/$f" ] && cp "$HOME/.claude/$f" "$HOME/.claude/$f.бэкап-$STAMP" && ok "старый $f сохранён рядом как $f.бэкап-$STAMP"
done
cp "$HERE/profile/CLAUDE.md"        "$HOME/.claude/CLAUDE.md"
cp "$HERE/profile/settings.mac.json" "$HOME/.claude/settings.json"
cp "$HERE/profile/statusline.sh" "$HERE/profile/statusline.py" "$HOME/.claude/"
chmod +x "$HOME/.claude/statusline.sh"
cp -R "$HERE/profile/skills/." "$HOME/.claude/skills/"
ok "правила установлены (~/.claude/CLAUDE.md)"
# Проверяем не «сколько папок легло», а сколько скиллов реально читаются
GOOD=0; BAD=0
for e in "$HOME/.claude/skills"/*; do
  if [ -f "$e/SKILL.md" ]; then GOOD=$((GOOD+1)); else BAD=$((BAD+1)); fi
done
ok "скиллов рабочих: $GOOD"
[ "$BAD" -gt 0 ] && warn "скиллов повреждено: $BAD (скачай пакет заново и запусти скрипт ещё раз)"

say "Шаг 8/9. Плагины Claude Code"
add_market() { claude plugin marketplace add "$1" >/dev/null 2>&1 && ok "маркетплейс $1" || warn "маркетплейс $1 не добавился"; }
inst()       { claude plugin install "$1" -y --scope user >/dev/null 2>&1 && ok "плагин $1" || warn "плагин $1 не встал (можно доставить командой /plugin в Claude Code)"; }
if have claude; then
  add_market "obra/superpowers-marketplace"
  inst "superpowers@superpowers-marketplace"
  inst "playwright@claude-plugins-official"
  if [ "$FULL" = 1 ]; then
    add_market "mukul975/Anthropic-Cybersecurity-Skills"
    add_market "openai/codex-plugin-cc"
    inst "figma@claude-plugins-official"
    inst "cybersecurity-skills@anthropic-cybersecurity-skills"
    inst "codex@openai-codex"
  fi
else warn "Claude Code недоступен — плагины поставятся сами при первом запуске из настроек"
fi

say "Шаг 9/9. GitHub и репозитории"
if [ "$DO_CLONE" = 0 ]; then ok "пропущено по флагу"
elif ! have gh; then warn "нет gh — репозитории не скачаны"
else
  if ! gh auth status >/dev/null 2>&1; then
    echo "  Сейчас откроется браузер для входа в GitHub. Выбирай: GitHub.com → HTTPS → Login with a web browser."
    gh auth login --hostname github.com --git-protocol https --web || warn "вход в GitHub не завершён"
  fi
  if gh auth status >/dev/null 2>&1; then
    ok "вошёл как $(gh api user --jq .login 2>/dev/null)"
    gh auth setup-git >/dev/null 2>&1 || true
    mkdir -p "$WORKDIR"
    for r in "${REPOS[@]}"; do
      if [ -d "$WORKDIR/$r/.git" ]; then ok "$r уже скачан"
      elif gh repo clone "$OWNER/$r" "$WORKDIR/$r" -- --quiet >/dev/null 2>&1; then ok "$r скачан в $WORKDIR/$r"
      else warn "$r не скачался — скорее всего тебя ещё не добавили в проект. Напиши Дмитрию свой ник GitHub и запусти скрипт ещё раз."
      fi
    done
    [ -f "$HOME/.gitconfig" ] || : 
    git config --global --get user.name  >/dev/null || warn "не задано имя в git — Claude Code спросит при первом коммите"
  fi
fi

printf "\n\033[1m═══════════════════════════════════════\033[0m\n"
if [ ${#PROBLEMS[@]} -eq 0 ]; then
  printf "\033[1;32mВсё готово.\033[0m\n"
else
  printf "\033[1;33mГотово, но с замечаниями:\033[0m\n"
  for p in "${PROBLEMS[@]}"; do echo "  - $p"; done
  echo "  Скопируй этот список в чат с Claude Code — он починит."
fi
cat <<'FIN'

Что дальше:
  1. Открой Cursor → File → Open Folder → ~/hackathon/MosForum-DayTrack
  2. Открой в Cursor терминал и набери:  claude
  3. Claude покажет ссылку для входа — СКОПИРУЙ её и пришли Дмитрию в чат.
     Сам по ссылке не переходи. Он активирует со своей подписки.
  4. Когда Дмитрий напишет «активировал» — вставь в Claude Code промпт
     из файла PROMPT.md (он рядом с этим скриптом).
FIN
