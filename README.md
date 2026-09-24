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

**Resolved issue (2026-09-23/24):** several buildings initially failed to render (or
loaded but stayed invisible) in the CesiumJS viewer. Root cause: real-world terrain
elevation at each building's location didn't match the buildings' own absolute height
values (EPSG:5258 source data) closely enough (off by ~20-33m, varying per building)
— several buildings ended up sunk below the terrain surface and were fully occluded
from above. Fixed in `scripts/generate_3dtiles_textured.mjs`: each building's glTF
node `translation` (an ECEF-derived offset baked in by `buildGeometry()`) is corrected
by sampling the real Cesium World Terrain height at that location and shifting the
node's height component by the difference — a pure vertical translation.

Two things made this trickier than it sounds, both discovered by testing rather than
assuming:
- Sampling terrain only at each building's *center* point still left several buildings
  visibly floating — terrain can vary by 10+ meters across a single building's own
  footprint on sloped ground (7968: 13.5m between its own corners). Fixed by sampling
  all 4 corners (see `scripts/sample_terrain_heights.mjs`) and using the *minimum*, so
  no corner ends up below ground (a sloped building may sit slightly into the uphill
  side, which reads far better visually than floating).
- `buildGeometry()`'s node `translation` is **not** plain ECEF (x, y, z) — it stores
  `[x, z, -y]` (a leftover of an internal Y-up conversion). Treating it as literal ECEF
  when computing the correction gave a result that was directionally wrong but,
  because WGS84 is nearly spherical, only *slightly* wrong for most buildings and
  clearly wrong for others (10158) — a partial "fix" that was easy to mistake for
  "good enough." The real fix converts to true ECEF (`x, -z, y`) before doing any
  cartographic math, then converts back with the same permutation.

`viewer/app.js` uses `Cesium.Terrain.fromWorldTerrain()` again; all 10 buildings now
sit correctly on the real terrain surface with real textures.

An earlier hand-rolled pipeline (cjio export OBJ -> obj2gltf -> 3d-tiles-tools glbToB3dm
+ a custom ENU->ECEF transform matrix) was replaced after an unresolved axis/orientation
bug kept placing buildings sideways or flattened. A second attempt using the library's
own high-level API also got replaced (see above). See project memory / commit history
for that investigation if useful context.

## Running with Docker

The whole conversion pipeline (CityGML -> CityJSON -> 3D Tiles: Java, Python and
Node.js together) is also packaged as a single Docker image, so it can be run without
installing anything locally except Docker itself:

    docker build -t tucbs-building .
    docker run --rm \
      -v "$(pwd)/data/cityjson:/app/data/cityjson" \
      -v "$(pwd)/data/3dtiles:/app/data/3dtiles" \
      tucbs-building

The `-v` (volume) flags mount the container's output directories to the real
`data/cityjson` and `data/3dtiles` folders on the host, so the generated files land
in the repo as usual and survive after the container exits. This is the same pipeline
described below (`scripts/convert_to_cityjson.sh` + `scripts/generate_3dtiles_textured.mjs`)
running inside the container's own Java 17 + Python 3 + Node 22 environment.

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

## PostGIS demo

The 10 buildings' footprints and attributes (height, base elevation, footprint area)
can be loaded into a local PostGIS database to demonstrate spatial querying. Since
CityJSON only stores each building's bounding-box extent (not its true wall-derived
footprint), `scripts/generate_postgis_data.py` derives a rectangular footprint from
that bbox rather than a pixel-accurate outline — enough to demonstrate spatial
indexing, joins, distance and area queries.

Start a local PostGIS container:

    docker run --name tucbs-postgis -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgis/postgis

Generate the data and load it:

    python scripts/generate_postgis_data.py          # data/cityjson/ -> data/postgis/buildings.sql
    docker exec -i tucbs-postgis psql -U postgres < data/postgis/buildings.sql

Run the example spatial queries (nearest buildings, total footprint area, average
height, centroids, PostGIS-computed vs. precomputed area):

    docker exec -i tucbs-postgis psql -U postgres < scripts/postgis_example_queries.sql

## Requirements

- Java 17+ (for citygml-tools)
- Conda
- Git Bash (Windows) or any POSIX shell
- Docker (for the containerized pipeline and/or the PostGIS demo)

## License

MIT
