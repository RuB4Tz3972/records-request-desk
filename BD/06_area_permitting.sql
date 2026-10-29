-- 06 — Área PERMITTING: Design Ticket, Mile Post, Records (incluye Future
-- Project), Permit y revisiones.

BEGIN;

-- "Mile Post #" (hojas 2025 y anteriores): un dato de permisos por proyecto
CREATE TABLE project_permitting (
    project_id  bigint PRIMARY KEY REFERENCES project (project_id) ON DELETE CASCADE,
    mile_post   text,
    obs         text
);

-- "Design Ticket": un proyecto puede tener varios ("022602573 - New Ticket")
CREATE TABLE design_ticket (
    design_ticket_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id        bigint NOT NULL REFERENCES project (project_id) ON DELETE CASCADE,
    design_ticket     text NOT NULL,          -- 006605268
    is_current        boolean NOT NULL DEFAULT true,
    request_date      date,
    obs               text,
    CONSTRAINT design_ticket_uq UNIQUE (project_id, design_ticket)
);
CREATE UNIQUE INDEX design_ticket_current_uq ON design_ticket (project_id) WHERE is_current;

-- Permit de una agencia (filas KMV-Line, KMV-Permit y KMV-MOT).
-- El estado del trámite es el Project Status de la fila; no se duplica aquí.
CREATE TABLE permit (
    permit_id                          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_task_id                    bigint NOT NULL UNIQUE,
    type_of_project_code               text NOT NULL CHECK (type_of_project_code IN ('LINE', 'PERMIT', 'MOT')),
    permit_number                      text,             -- "Permit #"
    permit_fee                         numeric(14,2) CHECK (permit_fee >= 0),
    bond                               text,             -- "Bond?"
    bond_fee_application               numeric(14,2) CHECK (bond_fee_application >= 0),
    permit_coordinator_approved_date   date,             -- "Permit Coordinator Approved Date (QC)"
    app_sent_to_contractor_date        date,
    app_returned_from_contractor_date  date,
    runner_submitting_date             date,
    runner_pick_up_date                date,
    permit_approved_date               date,
    permit_expires_date                date,
    CONSTRAINT permit_project_task_fk FOREIGN KEY (project_task_id, type_of_project_code)
        REFERENCES project_task (project_task_id, type_of_project_code) ON DELETE CASCADE,
    CONSTRAINT permit_contractor_dates_ck CHECK
        (app_returned_from_contractor_date IS NULL OR app_sent_to_contractor_date IS NULL
         OR app_returned_from_contractor_date >= app_sent_to_contractor_date),
    CONSTRAINT permit_expires_ck CHECK
        (permit_expires_date IS NULL OR permit_approved_date IS NULL
         OR permit_expires_date >= permit_approved_date)
);

-- "1st Revision Req / Completed / Permit 1st Resubmitted", 2nd… sin límite
CREATE TABLE permit_revision (
    permit_revision_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    permit_id                bigint NOT NULL REFERENCES permit (permit_id) ON DELETE CASCADE,
    revision_number          smallint NOT NULL CHECK (revision_number > 0),
    revision_req_date        date,
    revision_completed_date  date,
    permit_resubmitted_date  date,
    obs                      text,
    CONSTRAINT permit_revision_number_uq UNIQUE (permit_id, revision_number),
    CONSTRAINT permit_revision_dates_ck CHECK
        (revision_completed_date IS NULL OR revision_req_date IS NULL
         OR revision_completed_date >= revision_req_date)
);

-- Records de la agencia (filas KMV-Line y KMV-Permit)
CREATE TABLE records (
    project_task_id             bigint PRIMARY KEY,
    type_of_project_code        text NOT NULL DEFAULT 'LINE'
                                CHECK (type_of_project_code IN ('LINE', 'PERMIT')),
    records_status_code         text REFERENCES records_status (code),
    record_request_date         date,
    record_received_date        date,
    record_box                  boolean NOT NULL DEFAULT false,
    last_touched_records_date   date,          -- "LT Records"
    record_id_text              text,          -- "Record ID" tal cual, para auditar el desglose
    CONSTRAINT records_project_task_fk FOREIGN KEY (project_task_id, type_of_project_code)
        REFERENCES project_task (project_task_id, type_of_project_code) ON DELETE CASCADE,
    CONSTRAINT records_dates_ck CHECK
        (record_received_date IS NULL OR record_request_date IS NULL
         OR record_received_date >= record_request_date)
);

-- Cada solicitud que hoy va mezclada en "Record ID":
-- "PRR-2026-6020 / 8D67E4BD - FDOT Records - Received
--  PRR-2026-6232 / CBB4E0B0 - Future Project"  → 2 filas
CREATE TABLE record_request (
    record_request_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_task_id           bigint NOT NULL REFERENCES records (project_task_id) ON DELETE CASCADE,
    record_request_type_code  text NOT NULL REFERENCES record_request_type (code),
    prr_number                text,          -- PRR-2026-3407
    security_key              text,          -- 51A838C3
    future_project_number     text,          -- 438379-5 (solo Future Project)
    records_status_code       text REFERENCES records_status (code),
    received_date             date,
    obs                       text,
    CONSTRAINT record_request_future_project_ck CHECK
        (future_project_number IS NULL OR record_request_type_code = 'FUTURE_PROJECT')
);

COMMIT;
