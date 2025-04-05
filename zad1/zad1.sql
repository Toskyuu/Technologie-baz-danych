-- Jakub Stępnicki
-- Robert Łaski 259337

-- 3.1
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
    opis TEXT,
    gatunek_id INTEGER
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

-- Tabela dodana, żeby można było utworzyć jakiś trigger after insert
CREATE TABLE log_bilet (
    id SERIAL PRIMARY KEY,
    bilet_id INTEGER NOT NULL,
    seans_id INTEGER NOT NULL,
    klient_id INTEGER NOT NULL,
    typ VARCHAR(10) NOT NULL,
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
    ADD CONSTRAINT fk_film_gatunek
    FOREIGN KEY (gatunek_id) REFERENCES gatunek(id) ON DELETE CASCADE;


-- Przykładowe inserty
INSERT INTO sala (numer, ilosc_miejsc) VALUES (100, 100);

INSERT INTO gatunek (nazwa) VALUES ('Komedia');

INSERT INTO film (tytul, rezyser, data_wydania, czas_trwania, opis, gatunek_id) 
VALUES ('Incepcja', 'Christopher Nolan', '2010-07-16', 148, 'Film science-fiction o podróżach w głąb snów.', 1);

INSERT INTO seans (sala_id, film_id, godzina_rozpoczecia, godzina_zakonczenia) 
VALUES (1, 1, '2024-04-02 18:00:00', '2024-04-02 20:30:00');

INSERT INTO klient (imie, nazwisko, email) 
VALUES ('Jan', 'Kowalski', 'jan.kowalski@example.com');

INSERT INTO bilet (seans_id, klient_id, typ, cena) 
VALUES (10, 3, 'normalny', 25.00);


-- 3.2
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

CALL add_film('Matrix', 'Lana Wachowski, Lilly Wachowski', '1999-03-31', 136, 'Film science-fiction o wirtualnej rzeczywistości', 1);


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

CALL add_seans(1, 1, '2024-04-05 18:00:00', '2024-04-05 20:30:00');

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

SELECT * FROM get_film_by_id(1);

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

CALL update_klient(1, 'Adam', 'Nowak', 'adam.nowak@example.com');

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
        RETURN 0.00;  
    END IF;
END;
$$;

SELECT calculate_bilet_price('normalny');

CREATE OR REPLACE PROCEDURE reserve_bilet(
    p_seans_id INTEGER,
    p_klient_id INTEGER,
    p_typ VARCHAR(10)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ilosc_sprzedanych INTEGER;
    v_ilosc_miejsc INTEGER;
    v_cena DECIMAL(6,2);
BEGIN
    SELECT COUNT(*) INTO v_ilosc_sprzedanych FROM bilet WHERE seans_id = p_seans_id;
    
    SELECT s.ilosc_miejsc INTO v_ilosc_miejsc
    FROM seans se
    JOIN sala s ON se.sala_id = s.id
    WHERE se.id = p_seans_id;

    IF v_ilosc_sprzedanych >= v_ilosc_miejsc THEN
        RAISE EXCEPTION 'Brak wolnych miejsc na seans';
    END IF;

    v_cena := calculate_bilet_price(p_typ);

    INSERT INTO bilet (seans_id, klient_id, typ, cena)
    VALUES (p_seans_id, p_klient_id, p_typ, v_cena);
    
END;
$$;

CALL reserve_bilet(1, 1, 'ulgowy');


-- 4.2
CREATE OR REPLACE PROCEDURE add_klient(
    p_imie VARCHAR,
    p_nazwisko VARCHAR,
    p_email VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM klient WHERE email = p_email) THEN
        RAISE EXCEPTION 'Użytkownik z e-mailem % już istnieje', p_email;
    END IF;

    INSERT INTO klient (imie, nazwisko, email)
    VALUES (p_imie, p_nazwisko, p_email);

END;
$$;

CALL add_klient('Ewa', 'Kowalska', 'ewa.kowalska@example.com');

CREATE OR REPLACE FUNCTION count_bilety_by_klient(p_klient_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER := 0;
    rec RECORD;
BEGIN
    FOR rec IN (SELECT id FROM bilet WHERE klient_id = p_klient_id) LOOP
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

SELECT count_bilety_by_klient(1);

CREATE OR REPLACE PROCEDURE remove_old_seanse()
LANGUAGE plpgsql
AS $$
DECLARE
    cur CURSOR FOR 
        SELECT id FROM seans WHERE godzina_rozpoczecia < NOW() - INTERVAL '1 month';
    v_seans_id INTEGER;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO v_seans_id;
        EXIT WHEN NOT FOUND;

        DELETE FROM seans WHERE id = v_seans_id;
    END LOOP;
    CLOSE cur;
END;
$$;

CALL remove_old_seanse();

CREATE OR REPLACE PROCEDURE add_seans_na_calydzien(
    p_sala_id INTEGER,
    p_film_id INTEGER,
    p_godzina_rozpoczecia TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_czas_trwania INTEGER;  
    v_godzina_zakonczenia TIMESTAMP;
BEGIN
    SELECT czas_trwania INTO v_czas_trwania
    FROM film
    WHERE id = p_film_id;

    WHILE EXTRACT(HOUR FROM p_godzina_rozpoczecia) < 21 LOOP
        v_godzina_zakonczenia := p_godzina_rozpoczecia + INTERVAL '1 minute' * v_czas_trwania;

        CALL add_seans(p_sala_id, p_film_id, p_godzina_rozpoczecia, v_godzina_zakonczenia);

        p_godzina_rozpoczecia := v_godzina_zakonczenia + INTERVAL '15 minute';
    END LOOP;
END;
$$;

CALL add_seans_na_calydzien(1, 1, '2024-04-05 10:00:00');


-- 4.3
CREATE OR REPLACE FUNCTION sprawdz_konflikty_seansow() 
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM seans
        WHERE sala_id = NEW.sala_id
        AND (
            (NEW.godzina_rozpoczecia BETWEEN godzina_rozpoczecia AND godzina_zakonczenia) OR
            (NEW.godzina_zakonczenia BETWEEN godzina_rozpoczecia AND godzina_zakonczenia)
        )
    ) THEN
        RAISE EXCEPTION 'Konflikt godzinowy w sali %', NEW.sala_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER przed_wstawieniem_seansu_trigger
BEFORE INSERT ON seans
FOR EACH ROW
EXECUTE FUNCTION sprawdz_konflikty_seansow();

INSERT INTO seans (id, sala_id, godzina_rozpoczecia, godzina_zakonczenia) 
VALUES (1, 101, '2025-04-02 18:00:00', '2025-04-02 20:00:00');


CREATE OR REPLACE FUNCTION przed_wstawieniem_klienta() 
RETURNS TRIGGER AS $$
BEGIN
    NEW.email := LOWER(NEW.email);  
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER przed_wstawieniem_klienta_trigger
BEFORE INSERT ON klient
FOR EACH ROW
EXECUTE FUNCTION przed_wstawieniem_klienta();

INSERT INTO klient (id, imie, nazwisko, email) 
VALUES (1, 'Jan', 'Kowalski', 'TestowyEmail@Domena.PL');


CREATE OR REPLACE FUNCTION check_bilet_delete()
RETURNS trigger AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM seans
        WHERE id = OLD.seans_id
        AND godzina_rozpoczecia < CURRENT_TIMESTAMP
    ) THEN
        RAISE EXCEPTION 'Nie można usunąć biletu, ponieważ seans już się rozpoczął';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_bilet_delete_trigger
BEFORE DELETE ON bilet
FOR EACH ROW
EXECUTE FUNCTION check_bilet_delete();

DELETE FROM bilet WHERE id = 1;

CREATE OR REPLACE FUNCTION after_insert_bilet_log()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO log_bilet (bilet_id, seans_id, klient_id, typ, cena, data_zakupu)
    VALUES (NEW.id, NEW.seans_id, NEW.klient_id, NEW.typ, NEW.cena, NEW.data_zakupu);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER after_insert_bilet_log_trigger
AFTER INSERT ON bilet
FOR EACH ROW
EXECUTE FUNCTION after_insert_bilet_log();

INSERT INTO bilet (id, seans_id, klient_id, typ, cena, data_zakupu) 
VALUES (2, 1, 1, 'ulgowy', 25.00, NOW());


-- Instalacja rozszerzenia pg_cron
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
    'delete_old_seances',
    '0 0 * * *',
    'CALL remove_old_seanse();'
);

SELECT cron.schedule(
    'minute_task',
    '* * * * *',
    'CALL update_klient(1, ''NoweImie'', ''NoweNazwisko'', ''nowy.email@example.com'');'
);



-- Wyświetlenie zaplanowanych zadań
SELECT * FROM cron.job;
