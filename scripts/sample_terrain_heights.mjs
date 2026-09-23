#!/usr/bin/env node
// Her binanin merkez lon/lat'inda gercek Cesium World Terrain yuksekligini
// ornekler ve scripts/generate_3dtiles_textured.mjs'deki TERRAIN_HEIGHT
// tablosuna kopyalanabilecek bir JS objesi yazdirir. Yeni bina eklenirse
// ya da terrain verisi guncellenirse tekrar calistirilabilir.
//
// Terrain sadece bir tarayici/WebGL context'inde ornek­lenebiliyor (Node'da
// dogrudan degil), bu yuzden bu script gecici bir HTML sayfasi olusturup
// puppeteer ile aciyor. Onceden calistir: cd tools && npm install puppeteer --no-save
// Ve repo kokunu bir HTTP sunucusuyla servis et: python -m http.server 8000
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import proj4pkg from "../tools/node_modules/proj4/dist/proj4.js";
import puppeteer from "../tools/node_modules/puppeteer/lib/esm/puppeteer/puppeteer.js";
import { convertEPSGFromCityJSONToProj4 } from "../tools/node_modules/@csi-foxbyte/cityjson-to-3d-tiles/dist/index.js";

const proj4 = proj4pkg;
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const cityjsonDir = path.join(repoRoot, "data", "cityjson");
const toolsDir = path.join(repoRoot, "tools");

// Elle proj4 tanimi yazmiyoruz - kutuphanenin kendi CityJSON->proj4
// donusturucusunu kullaniyoruz (elle yazilan bir tanim yanlis merkez
// meridyen kullanip 9 derece yanlis lon verdi, 2026-09-24'te fark edildi).
// Merkez yerine binanin 4 kosesinden orneklenen EN DUSUK terrain yuksekligini
// kullaniyoruz - terrain bir binanin footprint'i icinde bile onemli olcude
// egimli olabiliyor (2026-09-24'te 7968'de 13.5m fark bulundu), sadece
// merkezden orneklemek bazi binalarin hala hafif havada kalmasina sebep
// oluyordu.
const buildings = fs
  .readdirSync(cityjsonDir)
  .filter((f) => f.endsWith(".json"))
  .map((f) => {
    const d = JSON.parse(fs.readFileSync(path.join(cityjsonDir, f), "utf-8"));
    const ext = d.metadata.geographicalExtent;
    const [minx, miny, , maxx, maxy] = ext;
    const srcProj4 = convertEPSGFromCityJSONToProj4(d.metadata.referenceSystem);
    const corners = [
      [minx, miny], [minx, maxy], [maxx, miny], [maxx, maxy],
    ].map(([cx, cy]) => proj4(srcProj4, "EPSG:4326", [cx, cy]));
    return { id: f.replace(".json", ""), corners };
  });

const htmlPath = path.join(toolsDir, "_sample_terrain_tmp.html");
fs.writeFileSync(
  htmlPath,
  `<!DOCTYPE html><html><head>
<script src="https://cesium.com/downloads/cesiumjs/releases/1.121/Build/Cesium/Cesium.js"></script>
</head><body><div id="c" style="width:10px;height:10px;"></div>
<script src="../viewer/config.js"></script>
<script>
Cesium.Ion.defaultAccessToken = window.CESIUM_ION_TOKEN;
window.done = false;
(async () => {
  const terrainProvider = await Cesium.CesiumTerrainProvider.fromIonAssetId(1);
  const buildings = ${JSON.stringify(buildings)};
  const allPositions = [];
  const counts = [];
  for (const b of buildings) {
    counts.push(b.corners.length);
    for (const [lon, lat] of b.corners) allPositions.push(Cesium.Cartographic.fromDegrees(lon, lat));
  }
  const sampled = await Cesium.sampleTerrainMostDetailed(terrainProvider, allPositions);
  let idx = 0;
  window.result = buildings.map((b, i) => {
    const heights = [];
    for (let k = 0; k < counts[i]; k++) { heights.push(sampled[idx].height); idx++; }
    return { id: b.id, terrainHeight: Math.min(...heights) };
  });
  window.done = true;
})();
</script></body></html>`
);

const browser = await puppeteer.launch({
  headless: true,
  args: [
    "--use-gl=angle", "--use-angle=swiftshader", "--enable-webgl",
    "--ignore-gpu-blocklist", "--enable-unsafe-swiftshader", "--disable-gpu-sandbox",
  ],
});
const page = await browser.newPage();
await page.goto(`http://localhost:8000/tools/_sample_terrain_tmp.html?t=${Date.now()}`, { waitUntil: "networkidle2" });
await page.waitForFunction("window.done === true", { timeout: 30000 });
const result = await page.evaluate(() => window.result);
await browser.close();
fs.unlinkSync(htmlPath);

console.log("const TERRAIN_HEIGHT = {");
for (const r of result) {
  console.log(`  "${r.id}": ${r.terrainHeight},`);
}
console.log("};");
