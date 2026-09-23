#!/usr/bin/env node
// CityJSON -> 3D Tiles, GERÇEK DOKULARLA.
//
// @csi-foxbyte/cityjson-to-3d-tiles kütüphanesinin üst-seviye API'si
// (generateTileDatabaseFromCityJSON + generate3DTilesFromTileDatabase)
// "unnamed" tema adıyla (bizim CityJSON'ların gerçek doku teması) hiç
// geometri üretmiyor - worker thread orkestrasyon katmanında bir yerde
// sessizce başarısız oluyor, hata bile fırlatmıyor (2026-09-23'te uzun bir
// hata ayıklama sürecinde bulundu). AMA kütüphanenin alt-seviye
// buildGeometry() fonksiyonu doğrudan çağrılınca "unnamed" temayla,
// dokularla birlikte MÜKEMMEL çalışıyor. Bu script o alt-seviye fonksiyonu
// doğrudan kullanıp, dokuyu (PNG) kendimiz gltf-transform ile ekliyor,
// ve tileset.json'ı da kütüphanenin verdiği cartographicBox (radyan
// lon/lat/height) değerlerinden region olarak kuruyoruz - bu sayede eski
// pipeline'daki ECEF/eksen matrisi belasına hiç gerek kalmıyor.
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { buildGeometry } from "../tools/node_modules/@csi-foxbyte/cityjson-to-3d-tiles/dist/cityjson/buildGeometry.js";
import { createDatabase } from "../tools/node_modules/@csi-foxbyte/cityjson-to-3d-tiles/dist/database/index.js";
import { convertEPSGFromCityJSONToProj4 } from "../tools/node_modules/@csi-foxbyte/cityjson-to-3d-tiles/dist/index.js";
import { NodeIO } from "../tools/node_modules/@gltf-transform/core/dist/index.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const cityjsonDir = path.join(repoRoot, "data", "cityjson");
const outDir = path.join(repoRoot, "data", "3dtiles");
const tmpDbPath = path.join(repoRoot, "tools", "_tmp_build.db");

const io = new NodeIO();

async function processBuilding(id) {
  const cityJsonPath = path.join(cityjsonDir, `${id}.json`);
  const cityJson = JSON.parse(fs.readFileSync(cityJsonPath, "utf-8"));
  const objectId = Object.keys(cityJson.CityObjects)[0];

  if (fs.existsSync(tmpDbPath)) fs.unlinkSync(tmpDbPath);
  const dbInstance = await createDatabase(tmpDbPath, true);

  const [geom] = await buildGeometry({
    geometry: cityJson.CityObjects[objectId].geometry,
    vertices: cityJson.vertices,
    id: objectId,
    cityJson,
    src: convertEPSGFromCityJSONToProj4(cityJson.metadata.referenceSystem),
    dest: "+proj=geocent +datum=WGS84 +units=m +no_defs +type=crs",
    folderPath: cityjsonDir,
    appearance: "unnamed",
    semanticSurfaceColors: {},
    noTransform: false,
    dbInstance,
  });
  await dbInstance.close();

  const glbBytes = Uint8Array.from(Object.values(geom.serializedDoc));
  const tmpGlbPath = path.join(outDir, `${id}.tmp.glb`);
  fs.writeFileSync(tmpGlbPath, glbBytes);

  const doc = await io.read(tmpGlbPath);
  for (const mat of doc.getRoot().listMaterials()) {
    const name = mat.getName();
    mat.setMetallicFactor(0);
    mat.setRoughnessFactor(1);
    // CityGML/gercek dunya verisinden gelen yuzeylerde tutarsiz polygon
    // cevirme sirasi (winding order) yaygin - gercek GPU'larda backface
    // culling bu yuzeyleri gizleyebilir (yazilim render'da fark edilmiyor
    // olabilir). Cift-tarafli yaparak bu riski tamamen ortadan kaldiriyoruz.
    mat.setDoubleSided(true);
    if (name === "UNTEXTURED" || !name) continue;
    const imgPath = path.join(cityjsonDir, name);
    if (!fs.existsSync(imgPath)) {
      console.log(`  UYARI: doku dosyasi bulunamadi: ${imgPath}`);
      continue;
    }
    const imgBytes = fs.readFileSync(imgPath);
    const tex = doc.createTexture().setImage(imgBytes).setMimeType("image/png");
    mat.setBaseColorTexture(tex);
  }
  fs.unlinkSync(tmpGlbPath);

  const finalGlbPath = path.join(outDir, id, `${id}.glb`);
  fs.mkdirSync(path.dirname(finalGlbPath), { recursive: true });
  await io.write(finalGlbPath, doc);

  return {
    id,
    region: [
      geom.cartographicBoxMinX,
      geom.cartographicBoxMinY,
      geom.cartographicBoxMaxX,
      geom.cartographicBoxMaxY,
      geom.cartographicBoxMinZ,
      geom.cartographicBoxMaxZ,
    ],
  };
}

(async () => {
  const ids = fs
    .readdirSync(cityjsonDir)
    .filter((f) => f.endsWith(".json"))
    .map((f) => f.replace(".json", ""));

  const buildings = [];
  for (const id of ids) {
    console.log(`=== ${id}: isleniyor ===`);
    const info = await processBuilding(id);
    buildings.push(info);
    console.log(`=== ${id}: tamamlandi -> data/3dtiles/${id}/${id}.glb ===`);
  }

  fs.rmSync(tmpDbPath, { force: true });

  // Tek birlestirilmis tileset.json - her bina ayri bir child tile,
  // kendi region bounding volume'u ile (transform matrisi gerekmiyor).
  const geometricError = 200;
  const tileset = {
    asset: { version: "1.1" },
    geometricError,
    root: {
      refine: "ADD",
      geometricError,
      boundingVolume: {
        region: [
          Math.min(...buildings.map((b) => b.region[0])),
          Math.min(...buildings.map((b) => b.region[1])),
          Math.max(...buildings.map((b) => b.region[2])),
          Math.max(...buildings.map((b) => b.region[3])),
          Math.min(...buildings.map((b) => b.region[4])),
          Math.max(...buildings.map((b) => b.region[5])),
        ],
      },
      children: buildings.map((b) => ({
        geometricError: 0,
        refine: "ADD",
        boundingVolume: { region: b.region },
        content: { uri: `${b.id}/${b.id}.glb` },
      })),
    },
  };

  fs.writeFileSync(path.join(outDir, "tileset.json"), JSON.stringify(tileset, null, 2));
  console.log("Tamamlandi ->", path.join(outDir, "tileset.json"));
})().catch((err) => {
  console.error("HATA:", err);
  process.exit(1);
});
