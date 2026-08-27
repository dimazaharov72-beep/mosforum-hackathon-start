#!/usr/bin/env bash
# Первая команда на чистом Mac. Качает пакет без git и запускает установку.
#   curl -fsSL <адрес>/bootstrap.sh | bash
set -euo pipefail
REPO="dimazaharov72-beep/mosforum-hackathon-start"
DEST="$HOME/hackathon-start"
echo "▶ Скачиваю пакет настройки..."
TMP="$(mktemp -d)"
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" -o "$TMP/pkg.tgz"
rm -rf "$DEST"; mkdir -p "$DEST"
tar -xzf "$TMP/pkg.tgz" -C "$DEST" --strip-components=1
rm -rf "$TMP"
echo "▶ Пакет в $DEST. Запускаю установку..."
exec bash "$DEST/setup.sh" "$@"
