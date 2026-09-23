// TUCBS 10 binasının 3D Tiles çıktısını CesiumJS'te gösterir.
// Token config.js'den geliyor (bkz. config.example.js) — config.js .gitignore'da,
// hiç commit'lenmiyor.
//
// Tek bir birleşik tileset.json kullanıyoruz (data/3dtiles/tileset.json,
// scripts/generate_3dtiles_textured.mjs tarafından üretiliyor) — her bina
// kendi region boundingVolume'una sahip ayrı bir child tile + kendi
// data/3dtiles/<id>/<id>.glb dosyası (gerçek dokularla). "Şu binaya uç"
// listesi ayrı tileset objelerine değil, her binanın kendi region'undan
// hesaplanmış merkez lon/lat/yükseklik koordinatına flyTo yapıyor.

Cesium.Ion.defaultAccessToken = window.CESIUM_ION_TOKEN;

// Terrain'i tekrar açtık (2026-09-24) - scripts/generate_3dtiles_textured.mjs
// artık her binanın yüksekliğini gerçek Cesium World Terrain rakımına göre
// düzeltiyor (node.translation'ı kaydırarak), o yüzden terrain'in altında
// kalma/havada asılı kalma sorunu artık yok.
const viewer = new Cesium.Viewer("cesiumContainer", {
  terrain: Cesium.Terrain.fromWorldTerrain(),
});

// Cesium varsayılan olarak gerçekçi güneş ışıklandırmasını kapalı tutuyor —
// bu, düz renkli (dokusuz) yüzeylerin çatı/duvar farkı olmadan tamamen aynı
// tonda, yani "2D gibi" görünmesine sebep oluyor. Işıklandırmayı açınca
// farklı yönlere bakan yüzeyler farklı parlaklıkta görünür, 3D şekil belirginleşir.
viewer.scene.globe.enableLighting = true;
viewer.shadows = true;

// Debug/test amaçlı: konsoldan ve headless test scriptlerinden erişilebilsin.
window.viewer = viewer;

// data/3dtiles/tileset.json'daki her binanın KENDİ (artık paylaşılmayan,
// izole) region boundingVolume'undan hesaplandı - scripts/generate_3dtiles_textured.mjs
// her binayı ayrı ayrı işlediği için artık komşu bina paylaşımı da yok.
const BUILDINGS = [
  { id: "10158", lon: 41.425911, lat: 41.395129, height: 76.7, radius: 61 },
  { id: "10393", lon: 41.432252, lat: 41.408657, height: 15.4, radius: 60 },
  { id: "7968", lon: 41.426892, lat: 41.400514, height: 14.1, radius: 108 },
  { id: "8257", lon: 41.423159, lat: 41.388931, height: 17.8, radius: 56 },
  { id: "8306", lon: 41.433935, lat: 41.410940, height: 15.8, radius: 59 },
  { id: "8351", lon: 41.450553, lat: 41.386927, height: 43.4, radius: 104 },
  { id: "9005", lon: 41.424884, lat: 41.398967, height: 33.6, radius: 70 },
  { id: "9215", lon: 41.428080, lat: 41.403086, height: 20.2, radius: 90 },
  { id: "9711", lon: 41.432621, lat: 41.408527, height: 16.4, radius: 60 },
  { id: "9997", lon: 41.432976, lat: 41.408423, height: 17.3, radius: 58 },
];

async function loadBuildings() {
  // Cache-bust: tarayıcının eski tileset.json/glb dosyalarını önbellekten
  // göstermesini önlemek için her yüklemede benzersiz bir sorgu parametresi.
  const tileset = await Cesium.Cesium3DTileset.fromUrl(
    `../data/3dtiles/tileset.json?v=${Date.now()}`
  );
  viewer.scene.primitives.add(tileset);
  await viewer.zoomTo(tileset);

  buildBuildingList();
}

function flyToBuilding(b) {
  const target = Cesium.Cartesian3.fromDegrees(b.lon, b.lat, b.height);
  viewer.camera.flyToBoundingSphere(new Cesium.BoundingSphere(target, b.radius), {
    offset: new Cesium.HeadingPitchRange(
      Cesium.Math.toRadians(45),
      Cesium.Math.toRadians(-30)
      // range verilmiyor - Cesium sphere'in radius'una göre kendi hesaplıyor.
    ),
    duration: 1.5,
  });
}

function buildBuildingList() {
  const panel = document.createElement("div");
  panel.id = "buildingListPanel";
  panel.style.position = "absolute";
  panel.style.top = "10px";
  panel.style.left = "10px";
  panel.style.background = "rgba(30,30,30,0.75)";
  panel.style.color = "white";
  panel.style.padding = "8px 12px";
  panel.style.borderRadius = "6px";
  panel.style.fontFamily = "sans-serif";
  panel.style.fontSize = "13px";
  panel.style.maxHeight = "80vh";
  panel.style.overflowY = "auto";

  const title = document.createElement("div");
  title.textContent = "TUCBS Binaları";
  title.style.fontWeight = "bold";
  title.style.marginBottom = "6px";
  panel.appendChild(title);

  for (const b of BUILDINGS) {
    const btn = document.createElement("button");
    btn.textContent = b.id;
    btn.style.display = "block";
    btn.style.width = "100%";
    btn.style.margin = "2px 0";
    btn.style.cursor = "pointer";
    btn.onclick = () => flyToBuilding(b);
    panel.appendChild(btn);
  }

  document.body.appendChild(panel);
}

loadBuildings().catch((err) => {
  console.error("Bina yükleme hatası:", err);
});
