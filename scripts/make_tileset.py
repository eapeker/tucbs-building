#!/usr/bin/env python
"""tileset.json üretir: EPSG'li bir orijin noktasını ECEF'e çevirip
East-North-Up -> ECEF dönüşüm matrisini (Cesium'un eastNorthUpToFixedFrame'i
ile aynı yöntem) hesaplar. Bina modelinin yerel (crs_translate sonrası orijine
göre) koordinatlarını doğru coğrafi konuma yerleştirmek için kullanılır.

Kullanım:
    python make_tileset.py <epsg> <minx> <miny> <minz> <maxx> <maxy> <maxz> <content_uri> <out_path>
"""
import json
import math
import sys
from pyproj import Transformer


def enu_to_ecef_transform(lon_deg, lat_deg, ecef_x, ecef_y, ecef_z):
    lon = math.radians(lon_deg)
    lat = math.radians(lat_deg)
    east = (-math.sin(lon), math.cos(lon), 0.0)
    north = (-math.sin(lat) * math.cos(lon), -math.sin(lat) * math.sin(lon), math.cos(lat))
    up = (math.cos(lat) * math.cos(lon), math.cos(lat) * math.sin(lon), math.sin(lat))
    # column-major 4x4: [east | north | up | translation]
    return [
        east[0], east[1], east[2], 0.0,
        north[0], north[1], north[2], 0.0,
        up[0], up[1], up[2], 0.0,
        ecef_x, ecef_y, ecef_z, 1.0,
    ]


def main():
    epsg = int(sys.argv[1])
    minx, miny, minz, maxx, maxy, maxz = map(float, sys.argv[2:8])
    content_uri = sys.argv[8]
    out_path = sys.argv[9]

    to_geodetic = Transformer.from_crs(f"EPSG:{epsg}", "EPSG:4979", always_xy=True)
    lon, lat, height = to_geodetic.transform(minx, miny, minz)

    to_ecef = Transformer.from_crs("EPSG:4979", "EPSG:4978", always_xy=True)
    ecef_x, ecef_y, ecef_z = to_ecef.transform(lon, lat, height)

    transform = enu_to_ecef_transform(lon, lat, ecef_x, ecef_y, ecef_z)

    dx, dy, dz = maxx - minx, maxy - miny, maxz - minz
    box = [
        dx / 2, dy / 2, dz / 2,
        dx / 2, 0, 0,
        0, dy / 2, 0,
        0, 0, dz / 2,
    ]

    tileset = {
        "asset": {"version": "1.0"},
        "geometricError": max(dx, dy, dz),
        "root": {
            "transform": transform,
            "boundingVolume": {"box": box},
            "geometricError": 0,
            "refine": "ADD",
            "content": {"uri": content_uri},
        },
    }

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(tileset, f, indent=2)

    print(f"lon={lon:.6f} lat={lat:.6f} height={height:.2f}")


if __name__ == "__main__":
    main()
