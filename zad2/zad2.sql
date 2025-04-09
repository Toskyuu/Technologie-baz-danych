-- Jakub Stępnicki 259315
-- Robert Łaski 259337

-- SQL TWORZĄCY
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE police_stations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    location GEOMETRY(Point, 4326) NOT NULL
);

CREATE TABLE patrol_routes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    route GEOMETRY(LineString, 4326) NOT NULL
);

CREATE TABLE districts (
    id SERIAL PRIMARY KEY,
    station_id INT REFERENCES police_stations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    area GEOMETRY(Polygon, 4326) NOT NULL
);

CREATE TABLE officers (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    rank VARCHAR(50) NOT NULL,
    station_id INT REFERENCES police_stations(id) ON DELETE CASCADE
);

-- WYPEŁNIENIE DANYMI
INSERT INTO police_stations (name, address, location)
VALUES
    ('Komisariat I', 'ul. Sienkiewicza 28/30, 90-114 Łódź', ST_SetSRID(ST_MakePoint(19.457216, 51.770054), 4326)),
    ('Komisariat II', 'ul. Ciesielska 27, 94-208 Łódź', ST_SetSRID(ST_MakePoint(19.398733, 51.759247), 4326)),
    ('Komisariat III', 'ul. Armii Krajowej 33, 94-046 Łódź', ST_SetSRID(ST_MakePoint(19.391293, 51.770892), 4326));

INSERT INTO patrol_routes (name, route)
VALUES
    ('Patrol I', ST_SetSRID(ST_MakeLine(ARRAY[
        ST_MakePoint(19.456, 51.755),
        ST_MakePoint(19.457, 51.756),
        ST_MakePoint(19.458, 51.757)
    ]), 4326)),
    ('Patrol II', ST_SetSRID(ST_MakeLine(ARRAY[
        ST_MakePoint(19.398, 51.759),
        ST_MakePoint(19.399, 51.760),
        ST_MakePoint(19.400, 51.761)
    ]), 4326)),
    ('Patrol III', ST_SetSRID(ST_MakeLine(ARRAY[
        ST_MakePoint(19.391, 51.771),
        ST_MakePoint(19.392, 51.772),
        ST_MakePoint(19.393, 51.773)
    ]), 4326));

INSERT INTO districts (station_id, name, area)
VALUES
    (1, 'Rejon I', ST_SetSRID(ST_GeomFromText('POLYGON((19.455 51.754, 19.457 51.755, 19.459 51.756, 19.455 51.754))'), 4326)),
    (2, 'Rejon II', ST_SetSRID(ST_GeomFromText('POLYGON((19.397 51.758, 19.399 51.759, 19.401 51.760, 19.397 51.758))'), 4326)),
    (3, 'Rejon III', ST_SetSRID(ST_GeomFromText('POLYGON((19.390 51.770, 19.392 51.771, 19.394 51.772, 19.390 51.770))'), 4326));


INSERT INTO officers (first_name, last_name, rank, station_id)
VALUES
    ('Jan', 'Kowalski', 'Sierżant', 1),
    ('Anna', 'Nowak', 'Aspirant', 2),
    ('Marek', 'Wiśniewski', 'Komisarz', 3);


-- INDEKSY PRZESTRZENNE
CREATE INDEX idx_police_stations_geom ON police_stations USING GIST(location);
CREATE INDEX idx_patrol_routes_geom ON patrol_routes USING GIST(route);
CREATE INDEX idx_districts_geom ON districts USING GIST(area);

-- PROCEDURY
-- WYŚWIETLANIE DANYCH
CREATE OR REPLACE PROCEDURE display_police_station_by_id(
    p_station_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    station_name TEXT;
	station_address TEXT;
    station_location GEOMETRY;
BEGIN
    SELECT name, address, location INTO station_name, station_address, station_location
    FROM police_stations
    WHERE id = p_station_id;

    IF station_name IS NULL THEN
        RAISE EXCEPTION 'Komisariat o ID % nie istnieje', p_station_id;
    END IF;

    RAISE NOTICE E'\nKomisariat: %\nAdres: %\nLokalizacja:\n\tSzerokość geograficzna: %\n\tDługość geograficzna: %',
        station_name, station_address, ST_Y(station_location), ST_X(station_location);
END;
$$;

call display_police_station_by_id(6)

CREATE OR REPLACE PROCEDURE display_patrol_route(
    p_route_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    route_name TEXT;
    route_geom GEOMETRY;
BEGIN
    SELECT name, route INTO route_name, route_geom
    FROM patrol_routes
    WHERE id = p_route_id;

    IF route_name IS NULL THEN
        RAISE EXCEPTION 'Trasa o ID % nie istnieje', p_route_id;
    END IF;


    RAISE NOTICE E'\nTrasa: %\nWspółrzędne: %', route_name, ST_AsText(route_geom);
END;
$$;

call display_patrol_route(1)

CREATE OR REPLACE PROCEDURE display_district(
    p_district_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    district_name TEXT;
	police_station_id NUMERIC;
    district_area GEOMETRY;
BEGIN
    SELECT name, station_id, area INTO district_name, police_station_id, district_area
    FROM districts
    WHERE id = p_district_id;

    IF district_name IS NULL THEN
        RAISE EXCEPTION 'Rejon o ID % nie istnieje', p_district_id;
    END IF;

    RAISE NOTICE E'\nRejon: %\nID podlegającego komisariatu: %\nWspółrzędne obszaru: %', district_name, police_station_id, ST_AsText(district_area);
END;
$$;

call display_district(1)

-- ŁADOWANIE DANYCH
CREATE OR REPLACE PROCEDURE load_police_station_data(
    p_station_id INT,
    p_latitudes NUMERIC,
    p_longitudes NUMERIC,
    p_name VARCHAR,
    p_address VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO police_stations (id, name, location, address)
    VALUES (p_station_id, p_name,
            ST_SetSRID(ST_MakePoint(p_longitudes, p_latitudes), 4326),
            p_address);
END;
$$;

CALL load_police_station_data(6, 51.754, 19.455, 'Komisariat I', 'ul. Przykładowa 1');


CREATE OR REPLACE PROCEDURE load_patrol_route_data(
    p_route_id INT,
    p_name VARCHAR,
    p_latitudes NUMERIC[],
    p_longitudes NUMERIC[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    route_line geometry;
BEGIN
    route_line := ST_MakeLine(ARRAY(
        SELECT ST_MakePoint(p_longitudes[i], p_latitudes[i])
        FROM generate_series(1, array_length(p_latitudes, 1)) AS i
    ));

    INSERT INTO patrol_routes (id, name, route)
    VALUES (p_route_id, p_name, ST_SetSRID(route_line, 4326));
END;
$$;
CALL load_patrol_route_data(4, 'Trasa A', ARRAY[51.754, 51.755, 51.756], ARRAY[19.455, 19.456, 19.457]);


CREATE OR REPLACE PROCEDURE load_district_data(
    p_district_id INT,
	p_police_station_id INT,
    p_name VARCHAR,
    p_latitudes NUMERIC[],
    p_longitudes NUMERIC[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    polygon geometry;
BEGIN
    polygon := ST_GeomFromText('POLYGON((' ||
        array_to_string(
            ARRAY(
                SELECT p_longitudes[i] || ' ' || p_latitudes[i]
                FROM generate_series(1, array_length(p_latitudes, 1)) AS i
            ), ', '
        ) || '))');

    INSERT INTO districts (id, station_id, name, area)
    VALUES (p_district_id, p_police_station_id, p_name, ST_SetSRID(polygon, 4326));
END;
$$;

CALL load_district_data(5, 1, 'Rejon V', ARRAY[51.754, 51.755, 51.756, 51.754], ARRAY[19.455, 19.457, 19.459, 19.455]);

CREATE OR REPLACE PROCEDURE set_route_srid(srid INTEGER)
AS $$
BEGIN
    UPDATE patrol_routes
    SET route = ST_Transform(route, srid)
    WHERE ST_SRID(route) = 0;
END;
$$ LANGUAGE plpgsql;

CALL set_route_srid(3857);

CREATE OR REPLACE FUNCTION  build_all_districts_area()
RETURNS GEOMETRY AS $$
BEGIN
    RETURN (
        SELECT ST_Union(area)
        FROM  districts
    );
END;
$$ LANGUAGE plpgsql;

select * from build_all_districts_area();

CREATE OR REPLACE FUNCTION get_district_area(p_district_id INT)
RETURNS NUMERIC AS $$
DECLARE
    district_geom GEOMETRY;
    area_value NUMERIC;
BEGIN
    SELECT area INTO district_geom
    FROM districts
    WHERE id = p_district_id;

    IF district_geom IS NULL THEN
        RAISE EXCEPTION 'Rejon o ID % nie istnieje', p_district_id;
    END IF;

    area_value := ST_Area(district_geom);
    RETURN area_value;
END;
$$ LANGUAGE plpgsql;

-- Przykład użycia:
-- SELECT get_district_area(1);

-- Obliczanie odległości między dwoma punktami (np. komisariatami)
CREATE OR REPLACE FUNCTION get_distance_between_stations(p_station_id1 INT, p_station_id2 INT)
RETURNS NUMERIC AS $$
DECLARE
    point1 GEOMETRY;
    point2 GEOMETRY;
    distance_value NUMERIC;
BEGIN
    SELECT location INTO point1
    FROM police_stations
    WHERE id = p_station_id1;

    SELECT location INTO point2
    FROM police_stations
    WHERE id = p_station_id2;

    IF point1 IS NULL OR point2 IS NULL THEN
        RAISE EXCEPTION 'Jeden lub oba komisariaty o podanych ID nie istnieją';
    END IF;

    distance_value := ST_Distance(point1, point2);
    RETURN distance_value;
END;
$$ LANGUAGE plpgsql;

-- Przykład użycia:
-- SELECT get_distance_between_stations(1, 2);

-- Wyznaczanie komisariatu znajdującego się w danym zakresie (prostokątnym oknem)
CREATE OR REPLACE FUNCTION find_stations_in_bbox(
    p_min_lon NUMERIC,
    p_min_lat NUMERIC,
    p_max_lon NUMERIC,
    p_max_lat NUMERIC
)
RETURNS TABLE (id INT, name VARCHAR, address TEXT, location GEOMETRY) AS $$
BEGIN
    RETURN QUERY
    SELECT ps.id, ps.name, ps.address, ps.location
    FROM police_stations ps
    WHERE ps.location && ST_MakeBox2D(ST_MakePoint(p_min_lon, p_min_lat), ST_MakePoint(p_max_lon, p_max_lat));
END;
$$ LANGUAGE plpgsql;

-- Przykład użycia:
-- SELECT * FROM find_stations_in_bbox(19.45, 51.76, 19.46, 51.77);

-- Wyznaczanie rejonów zawierających dany punkt (np. zgłoszenie)
CREATE OR REPLACE FUNCTION find_district_containing_point(p_longitude NUMERIC, p_latitude NUMERIC)
RETURNS TABLE (id INT, station_id INT, name VARCHAR, area GEOMETRY) AS $$
DECLARE
    point_geom GEOMETRY;
BEGIN
    point_geom := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
    RETURN QUERY
    SELECT d.id, d.station_id, d.name, d.area
    FROM districts d
    WHERE ST_Contains(d.area, point_geom);
END;
$$ LANGUAGE plpgsql;

-- Przykład użycia:
-- SELECT * FROM find_district_containing_point(19.456, 51.755);

-- PROCEDURY DO WALIDACJI GEOMETRII

-- Walidacja poprawności geometrii rejonu
CREATE OR REPLACE FUNCTION validate_district_geometry(p_district_id INT)
RETURNS TEXT AS $$
DECLARE
    district_geom GEOMETRY;
    validation_result TEXT;
BEGIN
    SELECT area INTO district_geom
    FROM districts
    WHERE id = p_district_id;

    IF district_geom IS NULL THEN
        RETURN 'Rejon o ID ' || p_district_id || ' nie istnieje';
    END IF;

    IF ST_IsValid(district_geom) THEN
        validation_result := 'Geometria rejonu o ID ' || p_district_id || ' jest poprawna';
    ELSE
        validation_result := 'Geometria rejonu o ID ' || p_district_id || ' jest niepoprawna. Powód: ' || ST_IsValidReason(district_geom);
    END IF;

    RETURN validation_result;
END;
$$ LANGUAGE plpgsql;

-- Przykład użycia:
-- SELECT validate_district_geometry(1);

-- Walidacja poprawności geometrii trasy patrolu
CREATE OR REPLACE FUNCTION validate_patrol_route_geometry(p_route_id INT)
RETURNS TEXT AS $$
DECLARE
    route_geom GEOMETRY;
    validation_result TEXT;
BEGIN
    SELECT route INTO route_geom
    FROM patrol_routes
    WHERE id = p_route_id;

    IF route_geom IS NULL THEN
        RETURN 'Trasa patrolu o ID ' || p_route_id || ' nie istnieje';
    END IF;

    IF ST_IsValid(route_geom) THEN
        validation_result := 'Geometria trasy patrolu o ID ' || p_route_id || ' jest poprawna';
    ELSE
        validation_result := 'Geometria trasy patrolu o ID ' || p_route_id || ' jest niepoprawna. Powód: ' || ST_IsValidReason(route_geom);
    END IF;

    RETURN validation_result;
END;
$$ LANGUAGE plpgsql;

-- Przykład użycia:
-- SELECT validate_patrol_route_geometry(1);