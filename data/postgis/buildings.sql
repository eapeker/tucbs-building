-- TUCBS binalari icin PostGIS demo veri seti.
-- scripts/generate_postgis_data.py ile uretildi, elle duzenlemeyin.

CREATE EXTENSION IF NOT EXISTS postgis;

DROP TABLE IF EXISTS buildings;
CREATE TABLE buildings (
    id TEXT PRIMARY KEY,
    height_m REAL,
    base_elevation_m REAL,
    footprint_area_m2 REAL,
    footprint GEOMETRY(Polygon, 4326)
);

INSERT INTO buildings (id, height_m, base_elevation_m, footprint_area_m2, footprint) VALUES ('10158', 27.99, 62.66, 1121.8, ST_GeomFromText('POLYGON((41.4257043 41.3949829, 41.4261209 41.3949850, 41.4261183 41.3952749, 41.4257017 41.3952728, 41.4257043 41.3949829))', 4326));
INSERT INTO buildings (id, height_m, base_elevation_m, footprint_area_m2, footprint) VALUES ('10393', 20.24, 5.32, 1276.8, ST_GeomFromText('POLYGON((41.4320318 41.4085003, 41.4324744 41.4085025, 41.4324717 41.4088131, 41.4320291 41.4088109, 41.4320318 41.4085003))', 4326));
INSERT INTO buildings (id, height_m, base_elevation_m, footprint_area_m2, footprint) VALUES ('7968', 14.4, 6.95, 4591.6, ST_GeomFromText('POLYGON((41.4265404 41.4001641, 41.4272506 41.4001677, 41.4272445 41.4008637, 41.4265342 41.4008601, 41.4265404 41.4001641))', 4326));
INSERT INTO buildings (id, height_m, base_elevation_m, footprint_area_m2, footprint) VALUES ('8257', 22.55, 6.54, 1032.0, ST_GeomFromText('POLYGON((41.4229650 41.3887880, 41.4233557 41.3887899, 41.4233532 41.3890742, 41.4229625 41.3890723, 41.4229650 41.3887880))', 4326));
INSERT INTO buildings (id, height_m, base_elevation_m, footprint_area_m2, footprint) VALUES ('8306', 22.15, 4.7, 1167.1, ST_GeomFromText('POLYGON((41.4337097 41.4108003, 41.4341620 41.4108025, 41.4341596 41.4110803, 41.4337073 41.4110781, 41.4337097 41.4108003))', 4326));
INSERT INTO buildings (id, height_m, base_elevation_m, footprint_area_m2, footprint) VALUES ('8351', 16.09, 35.31, 3470.7, ST_GeomFromText('POLYGON((41.4500581 41.3867363, 41.4510512 41.3867410, 41.4510480 41.3871172, 41.4500549 41.3871124, 41.4500581 41.3867363))', 4326));
INSERT INTO buildings (id, height_m, base_elevation_m, footprint_area_m2, footprint) VALUES ('9005', 53.77, 6.76, 586.5, ST_GeomFromText('POLYGON((41.4247343 41.3988623, 41.4250365 41.3988638, 41.4250346 41.3990727, 41.4247325 41.3990712, 41.4247343 41.3988623))', 4326));
INSERT INTO buildings (id, height_m, base_elevation_m, footprint_area_m2, footprint) VALUES ('9215', 28.53, 5.96, 2948.3, ST_GeomFromText('POLYGON((41.4277362 41.4028543, 41.4284275 41.4028577, 41.4284235 41.4033169, 41.4277322 41.4033134, 41.4277362 41.4028543))', 4326));
INSERT INTO buildings (id, height_m, base_elevation_m, footprint_area_m2, footprint) VALUES ('9711', 20.44, 6.22, 1280.3, ST_GeomFromText('POLYGON((41.4324025 41.4083689, 41.4328425 41.4083711, 41.4328397 41.4086844, 41.4323998 41.4086822, 41.4324025 41.4083689))', 4326));
INSERT INTO buildings (id, height_m, base_elevation_m, footprint_area_m2, footprint) VALUES ('9997', 20.05, 7.23, 1207.5, ST_GeomFromText('POLYGON((41.4327706 41.4082645, 41.4331833 41.4082666, 41.4331805 41.4085816, 41.4327678 41.4085796, 41.4327706 41.4082645))', 4326));

-- Mekansal sorgular icin index (gercek/buyuk veri setlerinde performans farki yaratir)
CREATE INDEX buildings_footprint_idx ON buildings USING GIST (footprint);
