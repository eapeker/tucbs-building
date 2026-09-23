#!/usr/bin/env bash
# CityGML (LoD3) -> CityJSON dönüşümü, TUCBS örnek veri kümesindeki tüm binalar için.
# citygml-tools 2.5.0'ın --epsg bayrağı metadata'ya CRS eklemiyor (bilinen kısıtlama),
# bu yüzden referenceSystem alanını dönüşümden sonra Python ile elle ekliyoruz.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CITYGML_TOOLS="$REPO_ROOT/tools/citygml-tools/citygml-tools.bat"
PYTHON="/c/ProgramData/anaconda3/envs/tucbs-building/python.exe"
RAW_DIR="$REPO_ROOT/data/raw"
OUT_DIR="$REPO_ROOT/data/cityjson"
EPSG=5258

mkdir -p "$OUT_DIR"

for building_dir in "$RAW_DIR"/*/; do
  id=$(basename "$building_dir")
  gml_file="$building_dir/$id.gml"

  if [[ ! -f "$gml_file" ]]; then
    echo "UYARI: $gml_file bulunamadı, atlanıyor." >&2
    continue
  fi

  echo "=== $id: CityJSON'a çevriliyor ==="
  "$CITYGML_TOOLS" to-cityjson "$gml_file" -o "$OUT_DIR" -c --pretty-print

  json_file="$OUT_DIR/$id.json"
  win_json_file="$(/usr/bin/cygpath -w "$json_file")"
  "$PYTHON" -c "
import json
path = r'$win_json_file'
d = json.load(open(path, encoding='utf-8'))
d.setdefault('metadata', {})['referenceSystem'] = 'https://www.opengis.net/def/crs/EPSG/0/$EPSG'
with open(path, 'w', encoding='utf-8') as f:
    json.dump(d, f, indent=2)
"
  echo "=== $id: tamamlandı -> $json_file ==="
done

echo "Tüm dönüşümler bitti."
