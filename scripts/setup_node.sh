#!/usr/bin/env bash
# Portable Node.js kurulumu (tools/node altına). conda-forge üzerinden kurmak
# bu ortamda SSL sertifika hatası verdiği için nodejs.org'dan doğrudan indiriyoruz.
# Node 22 LTS kullanıyoruz (Node 24 için 3d-tiles-tools'un native bağımlılığı
# better-sqlite3'ün henüz derlenmiş (prebuilt) ikili sürümü yok, bu da derleme
# araçları -Python/MSVC- gerektiriyor; Node 22'de hazır ikili mevcut).
set -euo pipefail

VERSION="22.23.2"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools"
TARGET_DIR="$TOOLS_DIR/node"
ZIP_URL="https://nodejs.org/dist/v${VERSION}/node-v${VERSION}-win-x64.zip"
ZIP_PATH="$TOOLS_DIR/node-v${VERSION}-win-x64.zip"

if [[ -d "$TARGET_DIR" ]]; then
  echo "Node.js zaten kurulu: $TARGET_DIR"
  exit 0
fi

mkdir -p "$TOOLS_DIR"
echo "Node.js v$VERSION indiriliyor..."
curl -sL -o "$ZIP_PATH" "$ZIP_URL"

echo "Açılıyor..."
unzip -q "$ZIP_PATH" -d "$TOOLS_DIR"
mv "$TOOLS_DIR/node-v${VERSION}-win-x64" "$TARGET_DIR"
rm "$ZIP_PATH"

echo "Kuruldu: $TARGET_DIR/node.exe"
