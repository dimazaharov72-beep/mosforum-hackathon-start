# Первая команда на чистом Windows. Качает пакет без git и запускает установку.
#   irm <адрес>/bootstrap.ps1 | iex
$ErrorActionPreference = 'Stop'
$Repo = 'dimazaharov72-beep/mosforum-hackathon-start'
$Dest = Join-Path $HOME 'hackathon-start'
Write-Host '> Скачиваю пакет настройки...' -ForegroundColor Cyan
$Tmp = Join-Path $env:TEMP ("hk-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
$Zip = Join-Path $Tmp 'pkg.zip'
Invoke-WebRequest -Uri "https://codeload.github.com/$Repo/zip/refs/heads/main" -OutFile $Zip
Expand-Archive -Path $Zip -DestinationPath $Tmp -Force
$Src = Get-ChildItem $Tmp -Directory | Select-Object -First 1
if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
Move-Item $Src.FullName $Dest
Remove-Item $Tmp -Recurse -Force
Write-Host "> Пакет в $Dest. Запускаю установку..." -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File (Join-Path $Dest 'setup.ps1')
