DROP TABLE IF EXISTS exhibit CASCADE;
DROP TABLE IF EXISTS category CASCADE;
DROP TABLE IF EXISTS exhibit_category CASCADE;
DROP TABLE IF EXISTS institution CASCADE;
DROP TABLE IF EXISTS event CASCADE;
DROP TABLE IF EXISTS zone CASCADE;
DROP TABLE IF EXISTS location CASCADE;
DROP TABLE IF EXISTS history CASCADE;

CREATE TABLE exhibit (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,     /* name of the exhibit must be unique and not null */
    owner INTEGER NOT NULL,                /* id of the institution owner of the exhibit, not null */
    description TEXT,
    status VARCHAR(128) NOT NULL,          /* status of the exhibit (na ceste, vystaveny, ...) */
    control_start TIMESTAMP DEFAULT NULL,  /* start date of the control */
    control_end TIMESTAMP DEFAULT NULL,    /* end date of the control */
    CHECK (control_start >= now()),        /* start of the control must be later than current day */
    CHECK (control_start < control_end)    /* end of the control must be later than the start */
);

CREATE TABLE category (
    id SERIAL PRIMARY KEY,
    name VARCHAR(128) UNIQUE NOT NULL  /* category names must be unique and not null */
);

CREATE TABLE exhibit_category (
    exhibit_id INTEGER REFERENCES exhibit(id),
    category_id INTEGER REFERENCES category(id)
);

CREATE TABLE institution (
    id SERIAL PRIMARY KEY,
    name VARCHAR(128) UNIQUE NOT NULL,           /* name of the institution */
    type VARCHAR(128) NOT NULL DEFAULT 'Museum'  /* default type is museum, not null */
);

CREATE TABLE event (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,  /* name of the event */
    status VARCHAR(128),                /* status of the event (planned, ongoing, ...) */
    start_date TIMESTAMP,               /* start date of the event */
    end_date TIMESTAMP,                 /* end date of the event */
    CHECK (start_date >= now()),        /* check for the start date must be later than current date */
    CHECK (start_date < end_date)       /* check for the end date must be later than the start */
);

CREATE TABLE zone (
    id SERIAL PRIMARY KEY,
    name VARCHAR(128) UNIQUE NOT NULL  /* name zone, must be unique for the institution, not null */
);

CREATE TABLE location (
    id SERIAL PRIMARY KEY,
    exhibit_id INTEGER REFERENCES exhibit(id) NOT NULL,
    event_id INTEGER REFERENCES event(id),
    zone_id INTEGER REFERENCES zone(id),
    start_date TIMESTAMP NOT NULL,                       /* start date, not null */
    end_date TIMESTAMP,                                  /* end date, may be null */
    loaned BOOLEAN NOT NULL,                             /* loaned info, not null */
    loaned_from INTEGER,
    loaned_to INTEGER,
    CHECK (start_date < end_date)                        /* start date is less than end */
);

CREATE TABLE history (
    id SERIAL PRIMARY KEY,
    location_id INTEGER REFERENCES location(id),
    event_id INTEGER,
    exhibit_id INTEGER NOT NULL,
    zone_id INTEGER,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP,
    loaned BOOLEAN NOT NULL,
    loaned_from INTEGER,
    loaned_to INTEGER
);

CREATE OR REPLACE FUNCTION prevent_overlap()
RETURNS TRIGGER AS
$$
BEGIN
    IF exists(
        SELECT 1 FROM event
        /* check if the new event overlaps the existing event */
        WHERE id != new.id AND
              (new.start_date BETWEEN start_date AND end_date OR
               new.end_date BETWEEN start_date AND end_date OR
               start_date BETWEEN new.start_date AND new.end_date OR
               end_date BETWEEN new.start_date AND new.end_date)
        ) THEN
        RAISE EXCEPTION 'Cannot plan an event for the same date as another';
    END IF;
    RETURN new;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_overlap_trigger
BEFORE INSERT OR UPDATE ON event
FOR EACH ROW
EXECUTE FUNCTION prevent_overlap();

CREATE OR REPLACE FUNCTION plan_event(
    _name VARCHAR(255),         /* name of the event */
    _status VARCHAR(128),       /* status of the event */
    _start_date TIMESTAMP,      /* start date of the event */
    _end_date TIMESTAMP,        /* end date of the event */
    _zone_names VARCHAR(128)[]  /* array of zones for the event */
)
RETURNS VOID AS
$$
DECLARE
    _zone_id INTEGER;
    _zone_name VARCHAR(128);
BEGIN
    INSERT INTO event(name, status, start_date, end_date)
    VALUES (_name, _status, _start_date, _end_date);

    /* for each zone in zones array */
    FOREACH _zone_name IN ARRAY _zone_names LOOP
        /* select zone id from zone table where name = zone_name */
        SELECT id INTO _zone_id FROM zone WHERE name = _zone_name;

        /* if zone does not exist, then insert it to the zone table */
        IF _zone_id IS NULL THEN
            INSERT INTO zone(name) VALUES(_zone_name);
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION move_exhibit(
    _exhibit_name VARCHAR(255),       /* exhibit name */
    _event_name VARCHAR(255),         /* event name */
    _current_zone_name VARCHAR(128),  /* current zone name */
    _new_zone_name VARCHAR(128)       /* new zone name */
)
RETURNS VOID AS
$$
DECLARE
    _exhibit_id INTEGER;
    _event_id INTEGER;
    _current_zone_id INTEGER;
    _new_zone_id INTEGER;
BEGIN
    /* Select ids from exhibit, event and zone tables */
    SELECT id INTO _exhibit_id FROM exhibit WHERE name = _exhibit_name;
    SELECT id INTO _event_id FROM event WHERE name = _event_name;
    SELECT id INTO _current_zone_id FROM zone WHERE name = _current_zone_name;

    /* Check if the exhibit don't have zone or event */
    IF NOT exists(
        SELECT 1 FROM location
        WHERE exhibit_id = _exhibit_id AND
              event_id = _event_id AND
              zone_id = _current_zone_id
    ) THEN
        IF NOT exists(
        SELECT 1 FROM history
        WHERE exhibit_id = _exhibit_id AND
              event_id = _event_id AND
              zone_id = _current_zone_id
        ) THEN RAISE EXCEPTION 'Exhibit % is not currently in the specified zone or event', _exhibit_name;
        END IF;
    END IF;

    /* Select id of the new zone */
    SELECT id INTO _new_zone_id FROM zone WHERE name = _new_zone_name;

    /* Check if the exhibit is in the same zone */
    IF exists(
        SELECT 1 FROM location
        WHERE exhibit_id = _exhibit_id AND
              zone_id = _new_zone_id AND
              event_id = _event_id
    ) THEN RAISE EXCEPTION 'Exhibit % is already in the new zone', _exhibit_name;
    ELSIF exists(
        SELECT 1 FROM history
        WHERE exhibit_id = _exhibit_id AND
              zone_id = _new_zone_id AND
              event_id = _event_id
    ) THEN RAISE EXCEPTION 'Exhibit % is already in the new zone', _exhibit_name;
    END IF;

    /* Update location table */
    UPDATE location
    SET zone_id = _new_zone_id
    WHERE exhibit_id = _exhibit_id AND
          event_id = _event_id AND
          zone_id = _current_zone_id;

    UPDATE history
    SET zone_id = _new_zone_id
    WHERE exhibit_id = _exhibit_id AND
          event_id = _event_id AND
          zone_id = _current_zone_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION loan_exhibit(
    _exhibit_name VARCHAR(255),    /* exhibit name */
    _owner_name VARCHAR(255),      /* museum that give the exhibit */
    _loaned_to_name VARCHAR(255),  /* museum that takes the exhibit */
    _start_date TIMESTAMP,         /* start of the loan */
    _end_date TIMESTAMP            /* end of the loan */
)
RETURNS VOID AS
$$
DECLARE
    _exhibit_id INTEGER;
    _owner_id INTEGER;
    _loaned_to INTEGER;
BEGIN
    /* Select required ids */
    SELECT id INTO _exhibit_id FROM exhibit WHERE name = _exhibit_name;
    SELECT id INTO _owner_id FROM institution WHERE name = _owner_name;
    SELECT id INTO _loaned_to FROM institution WHERE name = _loaned_to_name;
    IF _loaned_to IS NULL THEN INSERT INTO institution(name) VALUES (_loaned_to_name) RETURNING id INTO _loaned_to; END IF;

    RAISE NOTICE 'Check: %', _exhibit_id;

    IF exists(SELECT 1
        FROM location
        WHERE exhibit_id = _exhibit_id AND
              loaned = TRUE AND
              (_start_date BETWEEN start_date AND end_date OR
               _end_date BETWEEN start_date AND end_date OR
               start_date BETWEEN _start_date AND _end_date)
        ) THEN RAISE EXCEPTION 'The exhibit is already rented during the specified rental period';
    END IF;

    IF exists(SELECT 1
        FROM history
        WHERE exhibit_id = _exhibit_id AND
              loaned = TRUE AND
              (_start_date BETWEEN start_date AND end_date OR
               _end_date BETWEEN start_date AND end_date OR
               start_date BETWEEN _start_date AND _end_date)
        ) THEN RAISE EXCEPTION 'The exhibit is already rented during the specified rental period';
    END IF;

    UPDATE location
    SET start_date = _start_date, end_date = _end_date,
        event_id = NULL, zone_id = NULL, loaned = TRUE,
        loaned_from = _owner_id, loaned_to = _loaned_to
    WHERE exhibit_id = _exhibit_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION give_exhibit(
    _exhibit_name VARCHAR(255),
    _renter_name VARCHAR(255),
    _start_date TIMESTAMP,
    _end_date TIMESTAMP
)
RETURNS VOID AS
$$
DECLARE
    _exhibit_id INTEGER;
    _owner_id INTEGER;
    _renter_id INTEGER;
BEGIN
    /* Select ids */
    SELECT id, owner INTO _exhibit_id, _owner_id FROM exhibit WHERE name = _exhibit_name;
    SELECT id INTO _renter_id FROM institution WHERE name = _renter_name;
    IF _renter_id IS NULL THEN
        INSERT INTO institution(name) VALUES(_renter_name) RETURNING id INTO _renter_id;
    END IF;

    /* Check if the renter has already have the exhibit */
    IF exists(
        SELECT 1 FROM location WHERE exhibit_id = _exhibit_id AND loaned_to = _renter_id) THEN
        RAISE EXCEPTION 'The exhibit is already rented by the renter';
    END IF;

    /* Check the rental period not overlap */
    IF exists(SELECT 1
        FROM location
        WHERE exhibit_id = _exhibit_id AND
              (_start_date BETWEEN start_date AND end_date OR
               _end_date BETWEEN start_date AND end_date OR
               start_date BETWEEN _start_date AND _end_date OR
               end_date BETWEEN _start_date AND _end_date)
        ) THEN RAISE EXCEPTION 'The exhibit is already rented during the specified rental period';
    END IF;

    IF exists(SELECT 1
        FROM history
        WHERE exhibit_id = _exhibit_id AND
              (_start_date BETWEEN start_date AND end_date OR
               _end_date BETWEEN start_date AND end_date OR
               start_date BETWEEN _start_date AND _end_date OR
               end_date BETWEEN _start_date AND _end_date)
        ) THEN RAISE EXCEPTION 'The exhibit is already rented during the specified rental period';
    END IF;

    UPDATE location
    SET start_date = _start_date, end_date = _end_date,
        event_id = NULL, zone_id = NULL, loaned = TRUE,
        loaned_from = _owner_id, loaned_to = _renter_id
    WHERE exhibit_id = _exhibit_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_exhibit_to_event(
    _event_name VARCHAR(255),       /* name of the event */
    _exhibit_names VARCHAR(255)[],  /* array of exhibits names */
    _zone_name VARCHAR(128)         /* zone to add exhibits */
)
RETURNS VOID AS
$$
DECLARE
    _exhibit_id INTEGER;
    _event_id INTEGER;
    _zone_id INTEGER;
    _exhibit_name VARCHAR(255);
    _start_date TIMESTAMP;
    _end_date TIMESTAMP;
BEGIN
    /* Select id, start_date and end_date from event table */
    SELECT id, start_date, end_date INTO _event_id, _start_date, _end_date
    FROM event WHERE name = _event_name;

    /* Select zone id from zone table */
    SELECT id INTO _zone_id FROM zone WHERE name = _zone_name;

    /* For each exhibit in exhibit array */
    FOREACH _exhibit_name IN ARRAY _exhibit_names LOOP
        SELECT id INTO _exhibit_id FROM exhibit WHERE name = _exhibit_name;

        /* Check location table, if the exhibit in the location table already has event and zone id
           at given time then raise an exception. */
        IF exists(
            SELECT 1 FROM location
            WHERE exhibit_id = _exhibit_id AND
                  event_id = _event_id AND
                  zone_id = _zone_id AND
                  (_start_date BETWEEN start_date AND end_date OR
                   _end_date BETWEEN start_date AND end_date OR
                   start_date BETWEEN _start_date AND _end_date OR
                   end_date BETWEEN _start_date AND _end_date))
            THEN RAISE EXCEPTION 'Exhibit % is already associated with a different event or zone', _exhibit_name;
        END IF;

        /* Check history table, for planned events */
        IF exists(
            SELECT 1 FROM history
            WHERE exhibit_id = _exhibit_id AND
                  event_id = _event_id AND
                  zone_id = _zone_id AND
                  (_start_date BETWEEN start_date AND end_date OR
                   _end_date BETWEEN start_date AND end_date OR
                   start_date BETWEEN _start_date AND _end_date OR
                   end_date BETWEEN _start_date AND _end_date))
            THEN RAISE EXCEPTION 'Exhibit % is already associated with a different event or zone', _exhibit_name;
        END IF;

        /* Update the location table, write to the exhibit event and zone */
        UPDATE location
        SET event_id = _event_id,
            zone_id = _zone_id,
            start_date = _start_date,
            end_date = _end_date
        WHERE exhibit_id = _exhibit_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_exhibit(
    _name VARCHAR(255),
    _description TEXT,
    _status VARCHAR(128),                         /* current status */
    _categories VARCHAR(128)[],                   /* array of categories */
    _owner VARCHAR(128),
    _loaned BOOLEAN,                              /* was the exhibit loaned? */
    _start_date TIMESTAMP,
    _end_date TIMESTAMP DEFAULT NULL,
    _control_start TIMESTAMP DEFAULT NULL,        /* control start */
    _control_end TIMESTAMP DEFAULT NULL,          /* control end */
    _loaned_from_name VARCHAR(128) DEFAULT NULL,  /* name of the institution */
    _loaned_to_name VARCHAR(128) DEFAULT NULL     /* name of the institution */
)
RETURNS VOID AS
$$
DECLARE
    _exhibit_id INTEGER;
    _category_id INTEGER;
    _category_name VARCHAR(128);
    _loaned_from_id INTEGER;
    _loaned_to_id INTEGER;
    _owner_id INTEGER;
BEGIN
    /* Check if owner is present in institution table */
    SELECT id INTO _owner_id FROM institution WHERE name = _owner;
    IF _owner_id IS NULL THEN
        INSERT INTO institution(name) VALUES (_owner) RETURNING id INTO _owner_id;
    END IF;

    RAISE NOTICE 'Check %', _owner_id;
    RAISE NOTICE 'Check: %', (SELECT name FROM institution WHERE id = _owner_id);

    IF _loaned THEN
        /* If the exhibit is loaned and no arguments for the institution was not provided, then raise exception */
        IF _loaned_from_name IS NULL AND _loaned_to_name IS NULL THEN
            RAISE EXCEPTION 'If an exhibit is loaned, loaned_from or loaned_to must be provided';
        END IF;

        /* If loaned from is provided, but no such institution in the table institution, then
           add this institution to the table. */
        IF _loaned_from_name IS NOT NULL THEN
            SELECT id INTO _loaned_from_id FROM institution WHERE name = _loaned_from_name;
            IF _loaned_from_id IS NULL THEN
                INSERT INTO institution(name) VALUES (_loaned_from_name) RETURNING id INTO _loaned_from_id;
            END IF;
        END IF;

        /* The same process for loaned to */
        IF _loaned_to_name IS NOT NULL THEN
            SELECT id INTO _loaned_to_id FROM institution WHERE name = _loaned_to_name;
            IF _loaned_to_id IS NULL THEN
                INSERT INTO institution(name) VALUES (_loaned_to_name) RETURNING id INTO _loaned_to_id;
            END IF;
        END IF;
    END IF;

    /* Insert row in the exhibit table */
    INSERT INTO exhibit(name, owner, description, status, control_start, control_end)
    VALUES (_name, _owner_id, _description, _status, _control_start, _control_end)
    RETURNING id INTO _exhibit_id;

    /* For each category in the category array */
    FOREACH _category_name IN ARRAY _categories LOOP
        SELECT id INTO _category_id FROM category WHERE name = _category_name;

        /* Insert category to the category table if it does not exist */
        IF _category_id IS NULL THEN
            INSERT INTO category(name) VALUES (_category_name) RETURNING id INTO _category_id;
        end if;

        INSERT INTO exhibit_category(exhibit_id, category_id)
        VALUES (_exhibit_id, _category_id);
    END LOOP;

    /* Insert the current location of the exhibit (event and zone is null by default) */
    INSERT INTO location(exhibit_id, event_id, zone_id, start_date, end_date, loaned, loaned_from, loaned_to)
    VALUES (_exhibit_id, NULL, NULL, _start_date, _end_date, _loaned, _loaned_from_id, _loaned_to_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_location_history()
RETURNS TRIGGER AS
$$
BEGIN
    INSERT INTO history(location_id, event_id, exhibit_id, zone_id, start_date, end_date, loaned, loaned_from, loaned_to)
    VALUES (old.id, old.event_id, old.exhibit_id, old.zone_id, old.start_date, old.end_date, old.loaned, old.loaned_from, old.loaned_to);

    RETURN new;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_location_history_trigger
AFTER UPDATE ON location
FOR EACH ROW
EXECUTE FUNCTION update_location_history();

SELECT add_exhibit('Exhibit 1', 'Description', 'At warehouse', ARRAY['Cat1', 'Cat2'], 'Museum 1', FALSE, '2024-06-01');
SELECT add_exhibit('Exhibit 2', 'Description', 'At warehouse', ARRAY['Cat2', 'Cat3'], 'Museum 1', FALSE, '2024-05-01');
SELECT add_exhibit('Exhibit 3', 'Description', 'At warehouse', ARRAY['Cat4', 'Cat5'], 'Museum 2', FALSE, '2024-05-01');

SELECT plan_event('Event 1', 'Planned', '2024-06-15', '2024-06-30', ARRAY['Zone 1', 'Zone 2']);
SELECT plan_event('Event 2', 'Planned', '2024-07-01', '2024-07-15', ARRAY['Zone 1']);
/* SELECT plan_event('Event 2', 'Planned', '2024-06-15', '2024-06-20', ARRAY['Zone 1']); */

SELECT add_exhibit_to_event('Event 1', ARRAY['Exhibit 1'], 'Zone 1');
SELECT add_exhibit_to_event('Event 1', ARRAY['Exhibit 2'], 'Zone 2');

SELECT add_exhibit_to_event('Event 2', ARRAY['Exhibit 1'], 'Zone 1');

/* SELECT give_exhibit('Exhibit 2', 'Museum 2', '2024-06-01', '2024-12-31'); */

SELECT give_exhibit('Exhibit 2', 'Museum 2', '2024-07-01', '2024-07-15');
SELECT loan_exhibit('Exhibit 3', 'Museum 2', 'Museum 1', '2024-08-01', '2024-08-31');

SELECT plan_event('Event 3', 'Planned', '2024-08-01', '2024-08-15', ARRAY['Zone 1', 'Zone 2']);
SELECT add_exhibit_to_event('Event 3', ARRAY['Exhibit 1', 'Exhibit 2'], 'Zone 1');
SELECT add_exhibit_to_event('Event 3', ARRAY['Exhibit 3'], 'Zone 2');

SELECT move_exhibit('Exhibit 1', 'Event 1', 'Zone 1', 'Zone 2');