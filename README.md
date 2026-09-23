# tucbs-building

Converting Turkey's national TUCBS 3D Building Model Sample Dataset (CityGML, LoD3)
to CityJSON and 3D Tiles.

Source data: TUCBS 3B Bina Modeli Ornek Veri Kumesi (cbs.csb.gov.tr, CBS Genel
Mudurlugu, public sample dataset), 10 buildings, EPSG:5258 (TUREF / TM, Turkey).

## Pipeline

data/raw/<id>/<id>.gml   (CityGML LoD3)
    -> scripts/convert_to_cityjson.sh       (citygml-tools)
data/cityjson/<id>.json  (CityJSON 2.0, textured)
    -> scripts/generate_3dtiles_textured.mjs
data/3dtiles/<id>/<id>.glb (per building, real textures) + data/3dtiles/tileset.json
    (one combined tileset, each building as a child tile with its own region)

CRS (EPSG:5258) is read automatically from each CityJSON's metadata.referenceSystem.
The tileset uses plain geographic "region" bounding volumes (radians), computed
directly by the underlying library from each building's own geometry — no manual
ECEF/rotation transform matrix is needed.

`scripts/generate_3dtiles_textured.mjs` calls `@csi-foxbyte/cityjson-to-3d-tiles`'s
low-level `buildGeometry()` function directly, one building at a time, rather than
its documented high-level API (`generateTileDatabaseFromCityJSON` +
`generate3DTilesFromTileDatabase`). The high-level API silently produces zero
geometry when given the real texture theme name ("unnamed", citygml-tools' default
fallback theme) — no exception, just an empty tileset — somewhere in its worker-thread
orchestration; `buildGeometry()` itself works correctly with real textures when
called directly. The script attaches each building's real PNG texture (via
gltf-transform) and sets `metallicFactor: 0` on every material, since the library's
default (fully metallic, no environment map) renders flat/shadeless in CesiumJS.

**Resolved issue (2026-09-23):** several buildings initially failed to render (or
loaded but stayed invisible) in the CesiumJS viewer. Root cause: `viewer/app.js` was
using `Cesium.Terrain.fromWorldTerrain()`, and the real-world terrain elevation at
each building's location didn't match the buildings' own absolute height values
(from EPSG:5258 source data) closely enough — several buildings ended up sunk below
the terrain surface and were fully occluded from above. Confirmed by re-rendering
with terrain disabled: all 10 buildings appeared correctly. `viewer/app.js` no longer
requests world terrain (flat ellipsoid + satellite imagery instead); all 10 buildings
now render correctly with real textures.

An earlier hand-rolled pipeline (cjio export OBJ -> obj2gltf -> 3d-tiles-tools glbToB3dm
+ a custom ENU->ECEF transform matrix) was replaced after an unresolved axis/orientation
bug kept placing buildings sideways or flattened. A second attempt using the library's
own high-level API also got replaced (see above). See project memory / commit history
for that investigation if useful context.

## Setup

Python side (cjio, pyproj, triangle):

    conda env create -f environment.yml
    conda activate tucbs-building

Node side (portable install, no system Node.js needed):

    bash scripts/setup_node.sh
    cd tools && npm install && cd ..

CityGML to CityJSON converter (Java, citygml4j):

    bash scripts/setup_citygml_tools.sh

## Running the conversion

    bash scripts/convert_to_cityjson.sh                          # data/raw/ -> data/cityjson/
    node scripts/generate_3dtiles_textured.mjs                   # data/cityjson/ -> data/3dtiles/
    (run the second one from inside tools/, or with tools/node on PATH)

## Viewing in CesiumJS

    cp viewer/config.example.js viewer/config.js   # paste your own Cesium ion access token
    python -m http.server 8000                     # serve the repo root
    open http://localhost:8000/viewer/index.html

## Requirements

- Java 17+ (for citygml-tools)
- Conda
- Git Bash (Windows) or any POSIX shell

## License

MIT
