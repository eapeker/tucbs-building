-- TUCBS binalari - PostGIS mekansal sorgu ornekleri.
-- Once buildings.sql yuklenmis olmali (bkz. README.md "PostGIS demo" bolumu).

-- 1. Tum binalar, yukseklik ve taban alani ile (basit SELECT + PostGIS sutunu)
SELECT id, height_m, footprint_area_m2
FROM buildings
ORDER BY height_m DESC;

-- 2. Her binanin taban alaninin GERCEKTEN PostGIS ile hesaplanmis hali
--    (footprint_area_m2 sutunu bizim onceden hesapladigimizdi - bu sorgu
--    PostGIS'in kendi ST_Area fonksiyonuyla dogrulama yapiyor). Geometri
--    WGS84 (SRID 4326, derece cinsinden) oldugu icin metre kareye cevirmek
--    icin geography tipine donusturuyoruz.
SELECT id,
       footprint_area_m2 AS onceden_hesaplanan,
       ROUND(ST_Area(footprint::geography)::numeric, 1) AS postgis_hesapladi
FROM buildings;

-- 3. Belirli bir noktaya (ornegin 7968'in civarindaki bir koordinat)
--    250 metre icindeki binalar - ST_DWithin, mekansal index kullanan
--    klasik bir "yakinlik sorgusu" (spatial join'lerin temeli).
SELECT id, height_m,
       ROUND(ST_Distance(
           ST_Centroid(footprint)::geography,
           ST_SetSRID(ST_MakePoint(41.4269, 41.4005), 4326)::geography
       )::numeric, 1) AS mesafe_metre
FROM buildings
WHERE ST_DWithin(
    footprint::geography,
    ST_SetSRID(ST_MakePoint(41.4269, 41.4005), 4326)::geography,
    250
)
ORDER BY mesafe_metre;

-- 4. En yuksek 3 bina
SELECT id, height_m FROM buildings ORDER BY height_m DESC LIMIT 3;

-- 5. Tum binalarin toplam taban alani ve ortalama yuksekligi (agregasyon)
SELECT
    COUNT(*) AS bina_sayisi,
    ROUND(SUM(footprint_area_m2)::numeric, 1) AS toplam_taban_alani_m2,
    ROUND(AVG(height_m)::numeric, 1) AS ortalama_yukseklik_m
FROM buildings;

-- 6. Her binanin merkez noktasi (centroid) - ornegin bir haritada
--    etiket/marker koymak icin kullanislidir.
SELECT id, ST_AsText(ST_Centroid(footprint)) AS merkez_nokta
FROM buildings;
