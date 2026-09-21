#!/usr/bin/env bash
# citygml-tools'u (CityGML -> CityJSON dönüştürücü, Java tabanlı, citygml4j projesi)
# indirir ve tools/citygml-tools altına açar. npm/conda'da paket olarak bulunmadığı
# için bu ayrı script gerekiyor. Java 17+ sistemde kurulu olmalı (java -version ile kontrol et).
set -euo pipefail

VERSION="2.5.0"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools"
TARGET_DIR="$TOOLS_DIR/citygml-tools"
ZIP_URL="https://github.com/citygml4j/citygml-tools/releases/download/v${VERSION}/citygml-tools-${VERSION}.zip"
ZIP_PATH="$TOOLS_DIR/citygml-tools-${VERSION}.zip"

if [[ -d "$TARGET_DIR" ]]; then
  echo "citygml-tools zaten kurulu: $TARGET_DIR"
  exit 0
fi

mkdir -p "$TOOLS_DIR"
echo "citygml-tools v$VERSION indiriliyor..."
curl -sL -o "$ZIP_PATH" "$ZIP_URL"

echo "Açılıyor..."
unzip -q "$ZIP_PATH" -d "$TOOLS_DIR"
mv "$TOOLS_DIR/citygml-tools-${VERSION}" "$TARGET_DIR"
rm "$ZIP_PATH"

echo "Kuruldu: $TARGET_DIR/citygml-tools.bat"
