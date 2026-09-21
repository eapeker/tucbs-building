#!/usr/bin/env bash
# CityJSON -> 3D Tiles (b3dm + tileset.json), TUCBS örnek veri kümesindeki tüm binalar için.
#
# Adımlar (her bina için):
#   1. cjio ile bina modelini kendi bbox min köşesine göre yerel orijine kaydır
#      (crs_translate), sonra dokularıyla birlikte OBJ olarak dışa aktar.
#   2. obj2gltf ile OBJ -> binary glTF (glb). Kaynak veri Z-up (CityGML/GIS
#      konvansiyonu) olduğu için --inputUpAxis Z veriyoruz; obj2gltf bunu
#      standart glTF Y-up'a çeviriyor. b3dm'e sarılınca Cesium bunu otomatik
#      olarak Z-up'a geri çevirir (3D Tiles spesifikasyonunun beklediği gibi).
#   3. 3d-tiles-tools glbToB3dm ile glb -> b3dm.
#   4. make_tileset.py ile EPSG:5258 orijin noktasını ECEF'e çevirip
#      tileset.json'ı (doğru coğrafi konum + bounding box) üret.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CITYJSON_DIR="$REPO_ROOT/data/cityjson"
OUT_DIR="$REPO_ROOT/data/3dtiles"
PYTHON="/c/ProgramData/anaconda3/envs/tucbs-building/python.exe"
NODE_BIN="$REPO_ROOT/tools/node"
NPX="$NODE_BIN/npx.cmd"
EPSG=5258

mkdir -p "$OUT_DIR"

for cityjson_file in "$CITYJSON_DIR"/*.json; do
  id=$(basename "$cityjson_file" .json)
  texture_file="$CITYJSON_DIR/$id.png"
  build_dir="$OUT_DIR/$id"

  echo "=== $id: 3D Tiles'a çevriliyor ==="
  mkdir -p "$build_dir"

  # bbox'u metadata'dan oku
  read -r minx miny minz maxx maxy maxz <<< "$("$PYTHON" -c "
import json
d = json.load(open(r'$(cygpath -w "$cityjson_file")', encoding='utf-8'))
e = d['metadata']['geographicalExtent']
print(*e)
")"

  neg_minx=$(awk "BEGIN{print -1*$minx}")
  neg_miny=$(awk "BEGIN{print -1*$miny}")
  neg_minz=$(awk "BEGIN{print -1*$minz}")

  # 1. yerel orijine kaydır + OBJ export (doku dahil)
  export PATH="/c/ProgramData/anaconda3/envs/tucbs-building:/c/ProgramData/anaconda3/envs/tucbs-building/Scripts:$PATH"
  cjio "$cityjson_file" crs_translate --minxyz "$neg_minx" "$neg_miny" "$neg_minz" export obj "$build_dir/$id.obj"
  cp "$texture_file" "$build_dir/$id.png"

  # 2. OBJ -> GLB
  export PATH="$NODE_BIN:$PATH"
  "$NPX" obj2gltf -i "$build_dir/$id.obj" -o "$build_dir/$id.glb" -b --inputUpAxis Z --outputUpAxis Y

  # 3. GLB -> B3DM
  "$NPX" 3d-tiles-tools glbToB3dm -i "$build_dir/$id.glb" -o "$build_dir/$id.b3dm"

  # 4. tileset.json (ECEF transform)
  "$PYTHON" "$REPO_ROOT/scripts/make_tileset.py" "$EPSG" "$minx" "$miny" "$minz" "$maxx" "$maxy" "$maxz" "$id.b3dm" "$build_dir/tileset.json"

  # ara dosyaları temizle (obj/mtl/png/glb), sadece b3dm + tileset.json kalsın
  rm -f "$build_dir/$id.obj" "$build_dir/$id.mtl" "$build_dir/$id.png" "$build_dir/$id.glb"

  echo "=== $id: tamamlandı -> $build_dir/tileset.json ==="
done

echo "Tüm 3D Tiles dönüşümleri bitti."
