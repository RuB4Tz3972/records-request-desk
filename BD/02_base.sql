-- 02 — Base: áreas, clientes, contratistas, personas, equipos, ciudades, condados, agencias
-- Nombres de tablas y campos = columnas de Smartsheet en snake_case.
-- Ver "Glosario" en MAPEO_SMARTSHEET.md.

BEGIN;

-- Normaliza texto para comparar alias: minúsculas y sin espacios repetidos.
-- "6. Permit - MOT  By others" y "6. permit - mot by others" quedan iguales.
CREATE FUNCTION normalize_text(value text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$ SELECT lower(regexp_replace(btrim(value), '\s+', ' ', 'g')) $$;

-- ─── Áreas de trabajo ──────────────────────────────────────────────
CREATE TABLE area (
    code         text PRIMARY KEY,
    name         text NOT NULL UNIQUE,
    parent_code  text REFERENCES area (code),
    CONSTRAINT area_parent_ck CHECK (parent_code IS DISTINCT FROM code)
);

INSERT INTO area (code, name, parent_code) VALUES
    ('DESIGN',     'Design',     NULL),
    ('MOT',        'MOT',        'DESIGN'),    -- MOT es parte de diseño
    ('PERMITTING', 'Permitting', NULL),
    ('INVOICING',  'Invoicing',  NULL);

-- ─── Customer (picklist "Customer": "CC-Crown Castle") ─────────────
CREATE TABLE customer (
    customer_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code             text NOT NULL UNIQUE,          -- CC
    name             text NOT NULL,                 -- Crown Castle
    tracking_prefix  text UNIQUE,                   -- KMV-CC- (Hotwire: código HC, tracking KMV-HW-)
    active           boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX customer_name_uq ON customer (normalize_text(name));

INSERT INTO customer (code, name, tracking_prefix) VALUES
    ('BZ',  'Breezeline',             'KMV-BZ-'),
    ('BS',  'Blue Stream',            'KMV-BS-'),
    ('CC',  'Crown Castle',           'KMV-CC-'),
    ('HC',  'Hotwire Communications', 'KMV-HW-'),
    ('IBT', 'IBT Group USA',          NULL),
    ('LP',  'Lightpath',              'KMV-LP-'),
    ('ME',  'Mesa Electric',          'KMV-ME-'),
    ('OT',  'Others',                 'KMV-OT-'),
    ('VI',  'Valhalla Industries',    NULL),
    ('TF',  'Tillma Fiber',           NULL),
    ('ZY',  'Zayo Group',             NULL),
    -- Solo en hojas 2025 y anteriores
    ('AB',  'Atlantic Broadband',     'KMV-AAB-'),
    ('AT',  'AT&T',                   NULL),
    ('CM',  'Comcast',                NULL),
    ('CW',  'CWSI',                   NULL),
    ('FL',  'Fiberlight',             NULL),
    ('FN',  'FPL FiberNet',           NULL),
    ('L3',  'Level 3',                NULL),
    ('MT',  'Mastec',                 NULL),
    ('VZ',  'Verizon',                NULL),
    ('XO',  'XO Communications',      NULL);

-- Textos del picklist "Customer" en todas las hojas
CREATE TABLE customer_alias (
    alias        text PRIMARY KEY,
    customer_id  bigint NOT NULL REFERENCES customer (customer_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX customer_alias_normalized_uq ON customer_alias (normalize_text(alias));

INSERT INTO customer_alias (alias, customer_id)
SELECT v.alias, c.customer_id
FROM (VALUES
    ('BZ-Breezeline', 'BZ'), ('Breezeline', 'BZ'), ('BS-Blue Stream', 'BS'),
    ('CC-Crown Castle', 'CC'), ('HC-Hotwire Communications', 'HC'),
    ('IBT-IBT Group USA', 'IBT'), ('LP-Lightpath', 'LP'), ('ME-Mesa Electric', 'ME'),
    ('OT-Others', 'OT'), ('VI-Valhalla Industries', 'VI'), ('TF-Tillma Fiber', 'TF'),
    ('ZY-Zayo Group', 'ZY'), ('AB-Atlantic Broadband', 'AB'), ('AT-AT&T', 'AT'),
    ('CW-CWSI', 'CW'), ('FL-Fiberlight', 'FL'), ('FN-FPL FiberNet', 'FN'),
    ('L3-Level 3', 'L3'), ('Mastec', 'MT'), ('Verizon', 'VZ'),
    ('XO-XO Communications', 'XO')
    -- "CC-Comcast" (picklist de la hoja Crown Castle 2025) se revisa a mano:
    -- el código CC es de Crown Castle.
) AS v (alias, code)
JOIN customer c ON c.code = v.code;

-- ─── Contractor (picklist "Contractor") ────────────────────────────
CREATE TABLE contractor (
    contractor_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name           text NOT NULL,
    active         boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX contractor_name_uq ON contractor (normalize_text(name));

INSERT INTO contractor (name)
SELECT unnest(ARRAY[
    'Bore-Tech', 'BTR', 'Buckley Cable Construction', 'CWSI', 'C-&-E',
    'Cypress Communications', 'DBE Utility Services Inc', 'Down South', 'Draft-Pro',
    'Electricom LLC', 'Expert Drill', 'Florida Sol Inc', 'Full Circle Fiber Partners',
    'Hypower', 'MasTec', 'MTX Group One', 'M Broadband Services INC', 'Neuwire Inc',
    'PI Communications', 'Power Core', 'Quanta', 'R.M. Cable Group', 'Reel Broadband LLC',
    'UFO', 'UNITEC', 'Southwest Communications Solutions, Inc.', 'Skynet',
    'Southeast Utilities', 'Vasi and Associates', 'Valhalla Industries Inc.', 'YCom',
    'One Installation INC', 'Kilowatt Electric Company', 'KC Fiber Optics',
    'Creative Lighthing & Power, LLC', '3COM',
    'Lightspeed Construction Group LLC (Full Circle)', 'PWR LLC', 'Mesa Electric',
    'SPF Underground',
    -- Solo en hojas 2025 y anteriores
    'Alpine', 'FiberLink, LLC', 'GenXC Construction', 'ITG Communications LLC',
    'Lynks, LLC', 'Mainline Fiber', 'RLM Underground, LLC', 'Reel Telecomunications']);

-- Variantes del picklist "Contractor" entre hojas
CREATE TABLE contractor_alias (
    alias          text PRIMARY KEY,
    contractor_id  bigint NOT NULL REFERENCES contractor (contractor_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX contractor_alias_normalized_uq ON contractor_alias (normalize_text(alias));

INSERT INTO contractor_alias (alias, contractor_id)
SELECT v.alias, c.contractor_id
FROM (VALUES
    ('Mesa Electric Systems Corp', 'Mesa Electric'),
    ('3COM COMMUNICATIONS LLC',    '3COM')
) AS v (alias, name)
JOIN contractor c ON c.name = v.name;

-- ─── Personas (equivale a la hoja "Directorio") ────────────────────
-- Designers, Permitting Team, Engineer, Surveyor y Construction Manager.
CREATE TABLE person (
    person_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name   text NOT NULL,
    email       text,
    phone       text,
    company     text,                 -- KMV, GALP, Crown Castle, Fibernet Direct…
    active      boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX person_email_uq ON person (normalize_text(email)) WHERE email IS NOT NULL;

-- Variantes de nombre ("Carlos Lopez" / "Carlos López")
CREATE TABLE person_alias (
    alias      text PRIMARY KEY,
    person_id  bigint NOT NULL REFERENCES person (person_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX person_alias_normalized_uq ON person_alias (normalize_text(alias));

-- Rol = columna de Smartsheet donde aparece la persona
CREATE TABLE role (
    code              text PRIMARY KEY,
    name              text NOT NULL UNIQUE,
    smartsheet_column text
);

INSERT INTO role (code, name, smartsheet_column) VALUES
    ('DESIGNER1',       'Designer 1',        'Designer1'),
    ('DESIGNER2',       'Designer 2',        'Designer2'),
    ('PERMITTING_TEAM', 'Permitting Team',   'Permitting Team'),
    ('ENGINEER',        'Engineer',          'Engineer'),
    ('SURVEYOR',        'Surveyor',          'Surveyor'),
    ('QC',              'QC',                NULL),
    ('RUNNER',          'Runner',            NULL),
    ('TEAM_LEAD',       'Team Lead',         NULL),
    ('DIRECTOR',        'Director',          NULL),
    ('INVOICING',       'Invoicing',         NULL);

CREATE TABLE team (
    team_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_team_id  bigint REFERENCES team (team_id),
    area_code       text REFERENCES area (code),
    name            text NOT NULL,
    active          boolean NOT NULL DEFAULT true,
    CONSTRAINT team_parent_ck CHECK (parent_team_id IS DISTINCT FROM team_id)
);

CREATE TABLE team_member (
    team_member_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    team_id         bigint NOT NULL REFERENCES team (team_id),
    person_id       bigint NOT NULL REFERENCES person (person_id),
    role_code       text REFERENCES role (code),
    is_team_lead    boolean NOT NULL DEFAULT false,
    start_date      date NOT NULL DEFAULT current_date,
    end_date        date,
    CONSTRAINT team_member_dates_ck CHECK (end_date IS NULL OR end_date >= start_date)
);
CREATE UNIQUE INDEX team_member_active_uq
    ON team_member (team_id, person_id) WHERE end_date IS NULL;
CREATE UNIQUE INDEX team_lead_active_uq
    ON team_member (team_id) WHERE is_team_lead AND end_date IS NULL;

-- ─── County / City ─────────────────────────────────────────────────
CREATE TABLE county (
    county_id  smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       text NOT NULL,
    us_state   text NOT NULL DEFAULT 'FL',
    CONSTRAINT county_uq UNIQUE (name, us_state)
);

CREATE TABLE city (
    city_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       text NOT NULL,
    county_id  smallint REFERENCES county (county_id),
    us_state   text NOT NULL DEFAULT 'FL',
    CONSTRAINT city_uq UNIQUE (name, us_state)
);

-- ─── Agency ────────────────────────────────────────────────────────
-- category = separadores del picklist "Agency" (State/Federal, County, City…)
-- parent_agency_id agrupa variantes: "Fort Lauderdale MOT" → "Fort Lauderdale"
CREATE TABLE agency (
    agency_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_agency_id  bigint REFERENCES agency (agency_id),
    name              text NOT NULL,
    category          text NOT NULL CHECK (category IN
                        ('STATE_FEDERAL', 'COUNTY', 'CITY', 'WATER_DISTRICT',
                         'TRAIN_RAIL', 'ELECTRIC', 'AIRPORT', 'OTHERS')),
    county_id         smallint REFERENCES county (county_id),
    city_id           integer REFERENCES city (city_id),
    portal_url        text,
    phone             text,
    email             text,
    active            boolean NOT NULL DEFAULT true,
    CONSTRAINT agency_parent_ck CHECK (parent_agency_id IS DISTINCT FROM agency_id)
);
CREATE UNIQUE INDEX agency_name_uq ON agency (normalize_text(name));

-- Duplicados del picklist ("St Lucie County" = "Saint Lucie County")
CREATE TABLE agency_alias (
    alias      text PRIMARY KEY,
    agency_id  bigint NOT NULL REFERENCES agency (agency_id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX agency_alias_normalized_uq ON agency_alias (normalize_text(alias));

-- ─── Hojas de Smartsheet de origen ─────────────────────────────────
CREATE TABLE smartsheet_sheet (
    sheet_id     bigint PRIMARY KEY,
    sheet_name   text NOT NULL,
    customer_id  bigint REFERENCES customer (customer_id),
    year         smallint,
    is_test_copy boolean NOT NULL DEFAULT false
);

INSERT INTO smartsheet_sheet (sheet_id, sheet_name, customer_id, year, is_test_copy)
SELECT 4393235477909380, 'Copy of 8. Crown Castle Fiber - Engineering Plan', customer_id, 2026, true
FROM customer WHERE code = 'CC';

COMMIT;
