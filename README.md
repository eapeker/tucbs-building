# tucbs-building

Converting Turkey's national TUCBS 3D Building Model Sample Dataset (CityGML, LoD3)
to CityJSON and 3D Tiles.

Source data: TUCBS 3B Bina Modeli Ornek Veri Kumesi (cbs.csb.gov.tr, CBS Genel
Mudurlugu, public sample dataset), 10 buildings, EPSG:5258 (TUREF / TM, Turkey).

## Pipeline

data/raw/<id>/<id>.gml   (CityGML LoD3)
    -> scripts/convert_to_cityjson.sh   (citygml-tools)
data/cityjson/<id>.json  (CityJSON 2.0, textured)
    -> scripts/convert_to_3dtiles.sh    (cjio, obj2gltf, 3d-tiles-tools)
data/3dtiles/<id>/tileset.json + <id>.b3dm

Each building is re-centered on its own local origin, converted to a textured glTF, and
wrapped in a b3dm tile. scripts/make_tileset.py computes an East-North-Up -> ECEF
transform matrix (via pyproj) so every building is placed at its true geographic
location and orientation when loaded in a 3D Tiles viewer (e.g. CesiumJS).

## Setup

Python side (cjio, pyproj, triangle):

    conda env create -f environment.yml
    conda activate tucbs-building

Node side (obj2gltf, 3d-tiles-tools), portable install, no system Node.js needed:

    bash scripts/setup_node.sh
    cd tools && npm install && cd ..

CityGML to CityJSON converter (Java, citygml4j):

    bash scripts/setup_citygml_tools.sh

## Running the conversion

    bash scripts/convert_to_cityjson.sh   # data/raw/  -> data/cityjson/
    bash scripts/convert_to_3dtiles.sh    # data/cityjson/ -> data/3dtiles/

## Requirements

- Java 17+ (for citygml-tools)
- Conda
- Git Bash (Windows) or any POSIX shell

## License

MIT
