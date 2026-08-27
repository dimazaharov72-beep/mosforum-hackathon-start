# =============================================================================
# Хакатон МосФорум — настройка рабочего места (Windows 10/11)
# Запуск: правой кнопкой по PowerShell → «Запуск от имени администратора», затем:
#   cd путь\к\hackathon-start
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
# Флаги: -Full  -NoDocker  -NoCursor  -NoClone
# Скрипт можно запускать повторно.
# =============================================================================
param([switch]$Full, [switch]$NoDocker, [switch]$NoCursor, [switch]$NoClone)
$ErrorActionPreference = 'Continue'

$Here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$Owner   = 'dimazaharov72-beep'
$Repos   = @('MosForum-DayTrack','MosForum-ERP','MosForum-Tasker')
$WorkDir = Join-Path $HOME 'hackathon'
$Problems = New-Object System.Collections.ArrayList

function Say  ($m) { Write-Host "`n> $m" -ForegroundColor Cyan }
function Ok   ($m) { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn ($m) { Write-Host "  [!] $m" -ForegroundColor Yellow; [void]$Problems.Add($m) }
function Have ($c) { [bool](Get-Command $c -ErrorAction SilentlyContinue) }
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
              [Environment]::GetEnvironmentVariable('Path','User')
}

Say 'Шаг 1/8. Проверка winget (установщик программ Windows)'
if (Have 'winget') { Ok 'winget на месте' }
else { Warn 'Нет winget. Открой Microsoft Store, найди "App Installer", установи и запусти скрипт заново.'; }

function Install-App ($id, $name) {
  if (-not (Have 'winget')) { Warn "$name не поставлен (нет winget)"; return }
  winget install --id $id --accept-source-agreements --accept-package-agreements --silent -e 2>&1 | Out-Null
  Refresh-Path
  Ok "$name"
}

Say 'Шаг 2/8. git, GitHub CLI, Node.js 22'
if (Have 'git') { Ok "git уже стоит" } else { Install-App 'Git.Git' 'git' }
if (Have 'gh')  { Ok "gh уже стоит" }  else { Install-App 'GitHub.cli' 'GitHub CLI' }
if (Have 'node') { Ok "node уже стоит ($(node -v))" } else { Install-App 'OpenJS.NodeJS.LTS' 'Node.js LTS' }
Refresh-Path
if (Have 'node') { if ((node -v) -notlike 'v22.*') { Warn "нужна Node.js 22, а стоит $(node -v) - скажи об этом Claude Code" } }

Say 'Шаг 3/8. Редактор Cursor'
if ($NoCursor) { Ok 'пропущено по флагу' }
elseif (Test-Path "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe") { Ok 'уже стоит' }
else { Install-App 'Anysphere.Cursor' 'Cursor' }

Say 'Шаг 4/8. Docker Desktop (нужен для базы данных DayTrack)'
if ($NoDocker) { Ok 'пропущено по флагу' }
elseif (Have 'docker') { Ok 'уже стоит' }
else { Write-Host '  Это большая загрузка (~2 ГБ), может занять 10-20 минут.'; Install-App 'Docker.DockerDesktop' 'Docker Desktop' }

Say 'Шаг 5/8. Claude Code'
if (Have 'claude') { Ok 'уже стоит' }
else {
  try { irm https://claude.ai/install.ps1 | iex; Refresh-Path; Ok 'поставлен' }
  catch { Warn 'Claude Code не поставился - поставь вручную по инструкции docs.claude.com' }
}
$env:Path = "$HOME\.local\bin;$env:Path"

Say 'Шаг 6/8. Общий профиль: правила, скиллы, настройки'
$Cl = Join-Path $HOME '.claude'
New-Item -ItemType Directory -Force -Path (Join-Path $Cl 'skills') | Out-Null
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($f in @('CLAUDE.md','settings.json')) {
  $p = Join-Path $Cl $f
  if (Test-Path $p) { Copy-Item $p "$p.бэкап-$Stamp"; Ok "старый $f сохранён рядом" }
}
Copy-Item (Join-Path $Here 'profile\CLAUDE.md')         (Join-Path $Cl 'CLAUDE.md') -Force
Copy-Item (Join-Path $Here 'profile\settings.win.json') (Join-Path $Cl 'settings.json') -Force
Copy-Item (Join-Path $Here 'profile\skills\*') (Join-Path $Cl 'skills') -Recurse -Force
Ok 'правила установлены'
Ok ("скиллов установлено: " + (Get-ChildItem (Join-Path $Cl 'skills') -Directory).Count)

Say 'Шаг 7/8. Плагины Claude Code'
if (Have 'claude') {
  claude plugin marketplace add obra/superpowers-marketplace 2>&1 | Out-Null
  foreach ($p in @('superpowers@superpowers-marketplace','playwright@claude-plugins-official')) {
    claude plugin install $p -y --scope user 2>&1 | Out-Null; Ok "плагин $p"
  }
  if ($Full) {
    claude plugin marketplace add mukul975/Anthropic-Cybersecurity-Skills 2>&1 | Out-Null
    claude plugin marketplace add openai/codex-plugin-cc 2>&1 | Out-Null
    foreach ($p in @('figma@claude-plugins-official','cybersecurity-skills@anthropic-cybersecurity-skills','codex@openai-codex')) {
      claude plugin install $p -y --scope user 2>&1 | Out-Null; Ok "плагин $p"
    }
  }
} else { Warn 'Claude Code недоступен - плагины подтянутся при первом запуске из настроек' }

Say 'Шаг 8/8. GitHub и репозитории'
if ($NoClone) { Ok 'пропущено по флагу' }
elseif (-not (Have 'gh')) { Warn 'нет gh - репозитории не скачаны' }
else {
  gh auth status 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host '  Сейчас откроется браузер для входа в GitHub. Выбирай: GitHub.com -> HTTPS -> Login with a web browser.'
    gh auth login --hostname github.com --git-protocol https --web
  }
  gh auth status 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Ok ("вошёл как " + (gh api user --jq .login))
    gh auth setup-git 2>&1 | Out-Null
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    foreach ($r in $Repos) {
      $dst = Join-Path $WorkDir $r
      if (Test-Path (Join-Path $dst '.git')) { Ok "$r уже скачан" }
      else {
        gh repo clone "$Owner/$r" $dst 2>&1 | Out-Null
        if (Test-Path (Join-Path $dst '.git')) { Ok "$r скачан в $dst" }
        else { Warn "$r не скачался - скорее всего тебя ещё не добавили в проект. Пришли Дмитрию свой ник GitHub и запусти скрипт ещё раз." }
      }
    }
  } else { Warn 'вход в GitHub не завершён' }
}

Write-Host "`n═══════════════════════════════════════"
if ($Problems.Count -eq 0) { Write-Host 'Всё готово.' -ForegroundColor Green }
else {
  Write-Host 'Готово, но с замечаниями:' -ForegroundColor Yellow
  $Problems | ForEach-Object { Write-Host "  - $_" }
  Write-Host '  Скопируй этот список в чат с Claude Code - он починит.'
}
@'

Что дальше:
  1. Открой Cursor -> File -> Open Folder -> C:\Users\<ты>\hackathon\MosForum-DayTrack
  2. Открой в Cursor терминал и набери:  claude
  3. Claude покажет ссылку для входа - СКОПИРУЙ её и пришли Дмитрию в чат.
     Сам по ссылке не переходи. Он активирует со своей подписки.
  4. Когда Дмитрий напишет «активировал» - вставь в Claude Code промпт
     из файла PROMPT.md (он рядом с этим скриптом).

Примечание: на Windows не ставятся звуковые уведомления и статус-строка -
они сделаны под macOS. На работу это не влияет.
'@ | Write-Host
