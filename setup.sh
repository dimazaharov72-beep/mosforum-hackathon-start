#!/usr/bin/env bash
# =============================================================================
# Хакатон МосФорум — настройка рабочего места (macOS)
# Запуск:  bash setup.sh
# Флаги:   --office      офисный режим: Excel, Word, PDF без среды разработки
#                        (без Docker, Codex, GitHub и кода проектов)
#          --full        поставить и дополнительные плагины (figma, кибербез)
#          --no-docker   не ставить Docker Desktop (это ~2 ГБ и долго)
#          --no-cursor   не ставить редактор Cursor
#          --no-clone    не скачивать репозитории
# Скрипт можно запускать повторно — он ничего не ломает и доделывает пропущенное.
# =============================================================================
set -uo pipefail

FULL=0; OFFICE=0; DO_DOCKER=1; DO_CURSOR=1; DO_CLONE=1
for a in "$@"; do case "$a" in
  --office) OFFICE=1; DO_DOCKER=0; DO_CLONE=0;;
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

# Пароль от Mac спрашиваем системным окном, а не в терминале: так установку
# может вести и человек, и Claude Code (у него нет терминала для ввода пароля).
# Homebrew и sudo -A сами зовут этот помощник.
export SUDO_ASKPASS="$HERE/askpass.sh"
chmod +x "$SUDO_ASKPASS" 2>/dev/null || true

# Инструменты считаем поставленными, только если git из них реально есть:
# «xcode-select -p» бывает доволен и сломанной установкой.
clt_ready() { [ -x /Library/Developer/CommandLineTools/usr/bin/git ] || [ -x "$(xcode-select -p 2>/dev/null)/usr/bin/git" ]; }

say "Шаг 1/9. Инструменты командной строки Apple"
if clt_ready; then ok "уже стоят"
else
  # Путь 1 - тихо, через «Обновление ПО», как это делает сам Homebrew.
  # Метка-файл заставляет softwareupdate показать инструменты в списке.
  echo "  Ищу инструменты на серверах Apple (1-2 минуты). Может спросить пароль от Mac."
  CLT_FLAG="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo -A touch "$CLT_FLAG" 2>/dev/null
  CLT_LABEL="$(softwareupdate -l 2>/dev/null | grep -B 1 -E 'Command Line Tools' \
    | awk -F'*' '/^ *\*/ {print $2}' | sed -e 's/^ *Label: //' -e 's/^ *//' | sort -V | tail -n1)"
  if [ -n "$CLT_LABEL" ]; then
    echo "  Ставлю «$CLT_LABEL» - это 5-15 минут, окон нажимать не нужно."
    sudo -A softwareupdate -i "$CLT_LABEL" >/dev/null 2>&1
    sudo -A xcode-select --switch /Library/Developer/CommandLineTools 2>/dev/null
  fi
  sudo -A rm -f "$CLT_FLAG" 2>/dev/null
  # Путь 2 - окно Apple. Ждём не вечно: если Apple ответит «недоступно»,
  # скрипт не должен висеть.
  if ! clt_ready; then
    echo "  Тихо не вышло. Сейчас откроется окно Apple - нажми «Установить» и дождись конца."
    xcode-select --install >/dev/null 2>&1 || true
    for _ in $(seq 1 180); do clt_ready && break; sleep 10; done
  fi
  if clt_ready; then ok "поставлены"
  else
    printf "\n  \033[1;31m✗ Инструменты Apple не поставились, без них дальше нельзя.\033[0m\n"
    echo "  Последний путь - скачать вручную (нужен Apple ID, подойдёт личный):"
    echo "    1. Открой https://developer.apple.com/download/all/?q=Command%20Line%20Tools"
    echo "    2. Войди и скачай верхний «Command Line Tools for Xcode» (файл .dmg)."
    echo "    3. Открой его, запусти установщик внутри, дождись конца."
    echo "    4. Запусти эту же команду установки ещё раз - она продолжит с этого места."
    exit 1
  fi
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
if [ "$OFFICE" = 1 ]; then BREW_PKGS=(git jq node@22); else BREW_PKGS=(git gh jq node@22); fi
have brew && brew install --quiet "${BREW_PKGS[@]}" >/dev/null 2>&1
if have brew; then brew link --overwrite --force node@22 >/dev/null 2>&1 || true; fi
export PATH="$(brew --prefix 2>/dev/null)/opt/node@22/bin:$PATH"
if ! grep -q 'opt/node@22/bin' "$HOME/.zprofile" 2>/dev/null && have brew; then
  echo "export PATH=\"$(brew --prefix)/opt/node@22/bin:\$PATH\"" >> "$HOME/.zprofile"
fi
have git  && ok "git $(git --version | awk '{print $3}')"       || warn "git не установился"
if [ "$OFFICE" = 0 ]; then
  have gh && ok "gh $(gh --version | head -1 | awk '{print $3}')" || warn "gh не установился"
fi
have node && ok "node $(node -v)"                                 || warn "Node.js не установился"
if [ "$OFFICE" = 1 ]; then :
elif have codex; then ok "codex $(codex --version 2>/dev/null | awk '{print $2}')"
elif have npm; then npm install -g @openai/codex >/dev/null 2>&1 && ok "codex установлен" || warn "codex не установился (доставим командой /codex:setup)"
fi
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
cp "$HERE/profile/statusline.sh" "$HERE/profile/statusline.py" "$HOME/.claude/"
chmod +x "$HOME/.claude/statusline.sh"
if [ "$OFFICE" = 1 ]; then
  cp "$HERE/profile/CLAUDE.office.md"     "$HOME/.claude/CLAUDE.md"
  cp "$HERE/profile/settings.office.json" "$HOME/.claude/settings.json"
  # Только скиллы для документов - остальные про разработку и дизайн сайтов
  for s in xlsx docx pdf pptx doc-coauthoring internal-comms; do
    cp -R "$HERE/profile/skills/$s" "$HOME/.claude/skills/"
  done
else
  cp "$HERE/profile/CLAUDE.md"        "$HOME/.claude/CLAUDE.md"
  cp "$HERE/profile/settings.mac.json" "$HOME/.claude/settings.json"
  cp -R "$HERE/profile/skills/." "$HOME/.claude/skills/"
fi
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
  if [ "$OFFICE" = 0 ]; then
    add_market "openai/codex-plugin-cc"
    inst "playwright@claude-plugins-official"
    inst "codex@openai-codex"
  fi
  if [ "$FULL" = 1 ] && [ "$OFFICE" = 0 ]; then
    add_market "mukul975/Anthropic-Cybersecurity-Skills"
    inst "figma@claude-plugins-official"
    inst "cybersecurity-skills@anthropic-cybersecurity-skills"
  fi
else warn "Claude Code недоступен — плагины поставятся сами при первом запуске из настроек"
fi

if [ "$OFFICE" = 1 ]; then
  say "Шаг 9/9. Офисные инструменты: LibreOffice, pandoc, PDF, распознавание"
  bash "$HERE/office-tools.sh" || warn "офисные инструменты встали не все (подробности выше)"
  mkdir -p "$HOME/Documents/Отчёты"
  ok "рабочая папка: ~/Documents/Отчёты"
else
say "Шаг 9/9. GitHub и репозитории"
fi
if [ "$OFFICE" = 1 ]; then :
elif [ "$DO_CLONE" = 0 ]; then ok "пропущено по флагу"
elif ! have gh; then warn "нет gh — репозитории не скачаны"
else
  if ! gh auth status >/dev/null 2>&1; then
    echo "  Вход в GitHub: ниже появится код из 8 знаков. Открой github.com/login/device, введи код, нажми Authorize."
    [ -t 0 ] || open "https://github.com/login/device" 2>/dev/null
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
if [ "$OFFICE" = 1 ]; then cat <<'FIN'

Что дальше:
  1. Полностью закрой Cursor (Cmd+Q) и открой заново - чтобы он увидел новые программы.
  2. File → Open Folder → Документы → Отчёты.
  3. Открой терминал (Ctrl+`) и набери:  claude
  4. Напиши Claude по-русски, что нужно сделать с документом.
FIN
exit 0
fi
cat <<'FIN'

Если установку вёл Claude - он продолжит сам по START.md. Иначе:
  1. Открой Cursor → File → Open Folder → ~/hackathon/MosForum-DayTrack
  2. Открой в Cursor терминал и набери:  claude
  3. Claude покажет ссылку для входа — СКОПИРУЙ её и пришли Дмитрию в чат.
     Сам по ссылке не переходи. Он активирует со своей подписки.
  4. Там же набери:  codex login --device-auth
     Он покажет ссылку и короткий код — пришли код Дмитрию тем же способом.
  5. Когда Дмитрий подтвердит оба входа — вставь в Claude Code промпт
     из файла PROMPT.md (он рядом с этим скриптом).
FIN
