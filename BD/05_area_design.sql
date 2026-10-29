-- 05 — Área DESIGN (incluye MOT, que es diseño)
-- Cada tabla declara qué Type of Project admite: valor fijo + FK compuesta.

BEGIN;

-- Fila KMV-P (o Miscellaneous). Survey Completed, Design Completed y
-- PM Approval Date se repiten en todas las filas del tracking: se toman de KMV-P.
CREATE TABLE design (
    project_task_id                  bigint PRIMARY KEY,
    type_of_project_code             text NOT NULL DEFAULT 'P'
                                     CHECK (type_of_project_code IN ('P', 'MISC')),
    survey_completed_date            date,
    survey_check                     boolean NOT NULL DEFAULT false,
    design_completed_date            date,
    pm_approval_date                 date,
    stamp_seal                       boolean NOT NULL DEFAULT false,     -- "Stamp & Seal"
    stamp_and_signatures             smallint CHECK (stamp_and_signatures >= 0),  -- "Stamp And Signatures #"
    prepare_packages                 boolean NOT NULL DEFAULT false,
    prepare_packages_request_date    date,
    prepare_packages_qc_date         date,
    prepare_packages_completed_date  date,
    CONSTRAINT design_project_task_fk FOREIGN KEY (project_task_id, type_of_project_code)
        REFERENCES project_task (project_task_id, type_of_project_code) ON DELETE CASCADE,
    CONSTRAINT design_packages_dates_ck CHECK
        (prepare_packages_completed_date IS NULL OR prepare_packages_request_date IS NULL
         OR prepare_packages_completed_date >= prepare_packages_request_date)
);

-- Fila KMV-MOT: Design MOT
CREATE TABLE design_mot (
    project_task_id            bigint PRIMARY KEY,
    type_of_project_code       text NOT NULL DEFAULT 'MOT' CHECK (type_of_project_code = 'MOT'),
    custom_mot                 boolean NOT NULL DEFAULT false,   -- Custom MOT vs TYPICAL MOT
    design_mot_request_date    date,
    design_mot_qc_date         date,
    design_mot_completed_date  date,
    CONSTRAINT design_mot_project_task_fk FOREIGN KEY (project_task_id, type_of_project_code)
        REFERENCES project_task (project_task_id, type_of_project_code) ON DELETE CASCADE,
    CONSTRAINT design_mot_dates_ck CHECK
        (design_mot_completed_date IS NULL OR design_mot_request_date IS NULL
         OR design_mot_completed_date >= design_mot_request_date)
);

-- As-Built e inspección (fila KMV-P)
CREATE TABLE as_built (
    project_task_id                bigint PRIMARY KEY,
    type_of_project_code           text NOT NULL DEFAULT 'P'
                                   CHECK (type_of_project_code IN ('P', 'MISC')),
    asbuilt_received_bore_log_date date,     -- "Asbuilt received - Bore Log"
    as_built_complete_date         date,
    inspection_date                date,
    inspection_pass_date           date,     -- "Inspection Pass" es una fecha
    CONSTRAINT as_built_project_task_fk FOREIGN KEY (project_task_id, type_of_project_code)
        REFERENCES project_task (project_task_id, type_of_project_code) ON DELETE CASCADE,
    CONSTRAINT as_built_dates_ck CHECK
        (as_built_complete_date IS NULL OR asbuilt_received_bore_log_date IS NULL
         OR as_built_complete_date >= asbuilt_received_bore_log_date)
);

COMMIT;
