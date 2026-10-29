-- 04 — Núcleo: project (Tracking Project) y project_task (cada fila de la hoja)
-- Lo que en la hoja se repite en todas las filas del tracking (Customer, PO,
-- dirección, Contractor, Survey, PM Approval, Invoice) se guarda una sola vez.

BEGIN;

CREATE TABLE project (
    project_id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tracking_project         text NOT NULL UNIQUE,      -- KMV-CC-26-001
    linked_tracking          text,                      -- "Linked Tracking" (puede ser un código viejo: KMV-CCF-25-680)
    linked_project_id        bigint REFERENCES project (project_id),
    customer_id              bigint NOT NULL REFERENCES customer (customer_id),
    kmv_galp                 text NOT NULL DEFAULT 'KMV' CHECK (kmv_galp IN ('KMV', 'GALP')),
    contractor_id            bigint REFERENCES contractor (contractor_id),
    construction_manager_id  bigint REFERENCES person (person_id),
    task_code                text REFERENCES task (code),   -- "Task" de la fila KMV-P (Jumper, Enterprise…)
    cc_system                text,                      -- "CC System": JDE / Oracle (solo Crown Castle)
    purchase_order           text,                      -- "Purchase Orden"
    project_name             text NOT NULL,
    project_address          text,
    city_id                  integer REFERENCES city (city_id),
    county_id                smallint REFERENCES county (county_id),
    us_state                 text,                      -- FL, GA… (Blue Stream lo escribe en "CC System")
    date_received            date,
    drawing_due_date         date,
    obs                      text,
    created_at               timestamptz NOT NULL DEFAULT now(),
    modified_at              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT project_linked_ck CHECK (linked_project_id IS DISTINCT FROM project_id),
    CONSTRAINT project_dates_ck CHECK
        (drawing_due_date IS NULL OR date_received IS NULL OR drawing_due_date >= date_received)
);

-- Códigos del cliente que hoy van dentro de "Project Name":
-- "PD599393 / S473071 - 477 S ROSEMARY AVE" → PD = PD599393, S = S473071
CREATE TABLE project_reference (
    project_id      bigint NOT NULL REFERENCES project (project_id) ON DELETE CASCADE,
    reference_type  text NOT NULL CHECK (reference_type IN ('PD', 'S', 'WO', 'FPID', 'OTHER')),
    value           text NOT NULL,
    PRIMARY KEY (project_id, reference_type, value)
);

-- Una fila de Smartsheet = un project_task
CREATE TABLE project_task (
    project_task_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id            bigint NOT NULL REFERENCES project (project_id),
    type_of_project_code  text NOT NULL REFERENCES type_of_project (code),   -- KMV-P, KMV-Line…
    task_code             text REFERENCES task (code),                        -- PM LINE, Jumper…
    agency_id             bigint REFERENCES agency (agency_id),
    project_status_code   text,
    priority              text CHECK (priority IN ('RED', 'YELLOW', 'GREEN')),
    obs                   text,
    last_touched_date     date,                 -- "LT"
    submitted_date        date,                 -- "Submitted Date"
    due_date              date,                 -- "Due Date" (hojas 2025)
    smartsheet_sheet_id   bigint REFERENCES smartsheet_sheet (sheet_id),
    smartsheet_row_id     bigint UNIQUE,
    created_at            timestamptz NOT NULL DEFAULT now(),
    modified_at           timestamptz NOT NULL DEFAULT now(),
    -- Destino de las FKs de las tablas de cada área (validan el Type of Project)
    CONSTRAINT project_task_id_type_uq UNIQUE (project_task_id, type_of_project_code),
    -- El Project Status debe estar permitido para el Type of Project
    CONSTRAINT project_task_status_fk FOREIGN KEY (type_of_project_code, project_status_code)
        REFERENCES type_of_project_status (type_of_project_code, project_status_code)
);

-- Designer1, Designer2, Permitting Team, Engineer, Surveyor… por fila
CREATE TABLE project_task_assignment (
    project_task_assignment_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_task_id             bigint NOT NULL REFERENCES project_task (project_task_id) ON DELETE CASCADE,
    person_id                   bigint NOT NULL REFERENCES person (person_id),
    role_code                   text NOT NULL REFERENCES role (code),
    assigned_at                 timestamptz NOT NULL DEFAULT now(),
    ended_at                    timestamptz,
    CONSTRAINT project_task_assignment_dates_ck CHECK (ended_at IS NULL OR ended_at >= assigned_at)
);
CREATE UNIQUE INDEX project_task_assignment_active_uq
    ON project_task_assignment (project_task_id, person_id, role_code) WHERE ended_at IS NULL;

-- Total Footage, UG, ISP, Aerial…: una fila por concepto con valor
CREATE TABLE project_task_quantity (
    project_task_id     bigint NOT NULL REFERENCES project_task (project_task_id) ON DELETE CASCADE,
    quantity_item_code  text NOT NULL REFERENCES quantity_item (code),
    quantity            numeric(12,2) NOT NULL CHECK (quantity >= 0),
    PRIMARY KEY (project_task_id, quantity_item_code)
);

-- QC IN / QC OUT (filas KMV-P y KMV-Line). Una fila por ronda de QC.
CREATE TABLE qc (
    qc_id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_task_id  bigint NOT NULL REFERENCES project_task (project_task_id) ON DELETE CASCADE,
    round_number     smallint NOT NULL DEFAULT 1 CHECK (round_number > 0),
    qc_person_id     bigint REFERENCES person (person_id),
    qc_in_date       date,
    qc_out_date      date,
    CONSTRAINT qc_round_uq UNIQUE (project_task_id, round_number),
    CONSTRAINT qc_dates_ck CHECK (qc_out_date IS NULL OR qc_in_date IS NULL OR qc_out_date >= qc_in_date)
);

-- Sonde Request / Sonde Received (filas KMV-Line, Miscellaneous y KMV-P)
CREATE TABLE sonde (
    project_task_id      bigint PRIMARY KEY REFERENCES project_task (project_task_id) ON DELETE CASCADE,
    sonde_request_date   date,
    sonde_received_date  date,
    CONSTRAINT sonde_dates_ck CHECK
        (sonde_received_date IS NULL OR sonde_request_date IS NULL
         OR sonde_received_date >= sonde_request_date)
);

COMMIT;
