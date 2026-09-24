#!/usr/bin/env python
"""CityJSON binalarindan basit bir PostGIS demo veri seti uretir.

Her binanin GERCEK dis hatti (footprint) yerine, CityJSON'daki
geographicalExtent'ten (bbox) turetilen dikdortgen bir poligon kullaniyoruz -
binanin duvarlarindan gercek footprint cikarmak (WallSurface'lerin taban
kenarlarini birlestirmek) daha karmasik bir geometri isi, ve bu script'in
amaci PostGIS/mekansal sorgu yetkinligini gostermek, piksel-hassas bina
dis hatlari degil.

Cikti: data/postgis/buildings.sql - PostGIS eklentisini acan, tabloyu
kuran ve 10 binayi INSERT eden, kendi kendine yeten bir SQL dosyasi.
"""
import json
import glob
import os
from pyproj import Transformer

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CITYJSON_DIR = os.path.join(REPO_ROOT, "data", "cityjson")
OUT_DIR = os.path.join(REPO_ROOT, "data", "postgis")
OUT_PATH = os.path.join(OUT_DIR, "buildings.sql")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    to_wgs84 = Transformer.from_crs("EPSG:5258", "EPSG:4326", always_xy=True)

    rows = []
    for path in sorted(glob.glob(os.path.join(CITYJSON_DIR, "*.json"))):
        d = json.load(open(path, encoding="utf-8"))
        bid = os.path.basename(path).replace(".json", "")
        minx, miny, minz, maxx, maxy, maxz = d["metadata"]["geographicalExtent"]

        # bbox'in 4 kosesini WGS84'e cevir (dikdortgen footprint)
        corners_src = [(minx, miny), (maxx, miny), (maxx, maxy), (minx, maxy), (minx, miny)]
        corners_wgs84 = [to_wgs84.transform(x, y) for x, y in corners_src]
        ring = ", ".join(f"{lon:.7f} {lat:.7f}" for lon, lat in corners_wgs84)

        height = maxz - minz
        footprint_area_m2 = (maxx - minx) * (maxy - miny)

        rows.append(
            {
                "id": bid,
                "polygon_wkt": f"POLYGON(({ring}))",
                "height_m": round(height, 2),
                "base_elevation_m": round(minz, 2),
                "footprint_area_m2": round(footprint_area_m2, 1),
            }
        )

    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write("-- TUCBS binalari icin PostGIS demo veri seti.\n")
        f.write("-- scripts/generate_postgis_data.py ile uretildi, elle duzenlemeyin.\n\n")
        f.write("CREATE EXTENSION IF NOT EXISTS postgis;\n\n")
        f.write("DROP TABLE IF EXISTS buildings;\n")
        f.write(
            "CREATE TABLE buildings (\n"
            "    id TEXT PRIMARY KEY,\n"
            "    height_m REAL,\n"
            "    base_elevation_m REAL,\n"
            "    footprint_area_m2 REAL,\n"
            "    footprint GEOMETRY(Polygon, 4326)\n"
            ");\n\n"
        )
        for r in rows:
            f.write(
                "INSERT INTO buildings (id, height_m, base_elevation_m, footprint_area_m2, footprint) "
                f"VALUES ('{r['id']}', {r['height_m']}, {r['base_elevation_m']}, {r['footprint_area_m2']}, "
                f"ST_GeomFromText('{r['polygon_wkt']}', 4326));\n"
            )
        f.write("\n-- Mekansal sorgular icin index (gercek/buyuk veri setlerinde performans farki yaratir)\n")
        f.write("CREATE INDEX buildings_footprint_idx ON buildings USING GIST (footprint);\n")

    print(f"Yazildi: {OUT_PATH} ({len(rows)} bina)")


if __name__ == "__main__":
    main()
