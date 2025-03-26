CREATE TABLE sala (
    id SERIAL PRIMARY KEY,
    numer INTEGER UNIQUE NOT NULL,
    ilosc_miejsc INTEGER NOT NULL CHECK (ilosc_miejsc > 0)
);

CREATE TABLE gatunek (
    id SERIAL PRIMARY KEY,
    nazwa VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE film (
    id SERIAL PRIMARY KEY,
    tytul VARCHAR(100) NOT NULL,
    rezyser VARCHAR(100) NOT NULL,
    data_wydania DATE NOT NULL,
    czas_trwania INTEGER NOT NULL CHECK (czas_trwania > 0),
    opis TEXT
);

CREATE TABLE seans (
    id SERIAL PRIMARY KEY,
    sala_id INTEGER NOT NULL,
    film_id INTEGER NOT NULL,
    godzina_rozpoczecia TIMESTAMP NOT NULL,
    godzina_zakonczenia TIMESTAMP NOT NULL,
    CHECK (godzina_zakonczenia > godzina_rozpoczecia)
);

CREATE TABLE klient (
    id SERIAL PRIMARY KEY,
    imie VARCHAR(50) NOT NULL,
    nazwisko VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE bilet (
    id SERIAL PRIMARY KEY,
    seans_id INTEGER NOT NULL,
    klient_id INTEGER NOT NULL,
    typ VARCHAR(10) NOT NULL CHECK (typ IN ('ulgowy', 'normalny')),
    cena DECIMAL(6,2) NOT NULL,
    data_zakupu TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE seans
    ADD CONSTRAINT fk_seans_sala
    FOREIGN KEY (sala_id) REFERENCES sala(id) ON DELETE CASCADE;

ALTER TABLE seans
    ADD CONSTRAINT fk_seans_film
    FOREIGN KEY (film_id) REFERENCES film(id) ON DELETE CASCADE;

ALTER TABLE bilet
    ADD CONSTRAINT fk_bilet_seans
    FOREIGN KEY (seans_id) REFERENCES seans(id) ON DELETE CASCADE;

ALTER TABLE bilet
    ADD CONSTRAINT fk_bilet_klient
    FOREIGN KEY (klient_id) REFERENCES klient(id) ON DELETE CASCADE;

ALTER TABLE film
    ADD COLUMN gatunek_id INTEGER NOT NULL;

ALTER TABLE film
    ADD CONSTRAINT fk_film_gatunek
    FOREIGN KEY (gatunek_id) REFERENCES gatunek(id) ON DELETE CASCADE;


CREATE OR REPLACE PROCEDURE add_film(
    p_tytul VARCHAR,
    p_rezyser VARCHAR,
    p_data_wydania DATE,
    p_czas_trwania INTEGER,
    p_opis TEXT,
    p_gatunek_id INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO film (tytul, rezyser, data_wydania, czas_trwania, opis, gatunek_id)
    VALUES (p_tytul, p_rezyser, p_data_wydania, p_czas_trwania, p_opis, p_gatunek_id);
END;
$$;


CREATE OR REPLACE PROCEDURE add_seans(
    p_sala_id INTEGER,
    p_film_id INTEGER,
    p_godzina_rozpoczecia TIMESTAMP,
    p_godzina_zakonczenia TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO seans (sala_id, film_id, godzina_rozpoczecia, godzina_zakonczenia)
    VALUES (p_sala_id, p_film_id, p_godzina_rozpoczecia, p_godzina_zakonczenia);
END;
$$;


CREATE OR REPLACE FUNCTION get_film_by_id(film_id INTEGER)
RETURNS TABLE (id INTEGER, tytul VARCHAR, rezyser VARCHAR, data_wydania DATE, czas_trwania INTEGER, opis TEXT, gatunek_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT film.id, film.tytul, film.rezyser, film.data_wydania, film.czas_trwania, film.opis, film.gatunek_id
    FROM film
    WHERE film.id = film_id;
END;
$$;



CREATE OR REPLACE PROCEDURE update_klient(
    p_id INTEGER,
    p_imie VARCHAR,
    p_nazwisko VARCHAR,
    p_email VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE klient
    SET imie = p_imie, nazwisko = p_nazwisko, email = p_email
    WHERE id = p_id;
END;
$$;


CREATE OR REPLACE FUNCTION calculate_bilet_price(bilet_typ VARCHAR)
RETURNS DECIMAL(6,2)
LANGUAGE plpgsql
AS $$
BEGIN
    IF bilet_typ = 'ulgowy' THEN
        RETURN 15.00;
    ELSIF bilet_typ = 'normalny' THEN
        RETURN 25.00;
    ELSE
        RETURN 0.00;  -- Jeśli typ nie jest poprawny
    END IF;
END;
$$;