-- 03 — Catálogos: Type of Project, Project Status, Task, cantidades, Records Status
-- Cada catálogo tiene un code estable y un name igual al texto de Smartsheet.
-- Las variantes de texto entre hojas y años van en las tablas *_alias.

BEGIN;

-- ─── Type of Project (KMV-P, KMV-Line, KMV-Permit, KMV-MOT, KMV-Miscellaneous) ─
CREATE TABLE type_of_project (
    code         text PRIMARY KEY,
    name         text NOT NULL UNIQUE,          -- valor en Smartsheet
    area_code    text NOT NULL REFERENCES area (code),
    description  text,
    sort_order   smallint NOT NULL
);

INSERT INTO type_of_project (code, name, area_code, description, sort_order) VALUES
    ('P',      'KMV-P',             'DESIGN',
     'Fila principal del proyecto: survey, diseño, QC, packages, as-built', 1),
    ('MISC',   'KMV-Miscellaneous', 'DESIGN',
     'UWS, GPR, S&S, OMNI y otros trabajos sin flujo completo', 2),
    ('MOT',    'KMV-MOT',           'MOT',
     'Design MOT por agencia y seguimiento de su permiso', 3),
    ('LINE',   'KMV-Line',          'PERMITTING',
     'Una por agencia: records; el permiso lo tramita el cliente u otros', 4),
    ('PERMIT', 'KMV-Permit',        'PERMITTING',
     'Permiso (o permiso de MOT) tramitado por KMV', 5);

CREATE TABLE type_of_project_alias (
    alias                 text PRIMARY KEY,
    type_of_project_code  text NOT NULL REFERENCES type_of_project (code)
);
CREATE UNIQUE INDEX type_of_project_alias_normalized_uq
    ON type_of_project_alias (normalize_text(alias));

INSERT INTO type_of_project_alias (alias, type_of_project_code) VALUES
    ('KMV-P', 'P'), ('GALP-P', 'P'), ('Omni 194-P', 'P'),
    ('KMV-Miscellaneous', 'MISC'),
    ('KMV-MOT', 'MOT'), ('KMV - MOT', 'MOT'), ('GALP- MOT', 'MOT'), ('Omni 194 - MOT', 'MOT'),
    ('KMV-Line', 'LINE'),
    ('KMV-Permit', 'PERMIT'), ('GALP-Permit', 'PERMIT'), ('Omni 194-Permit', 'PERMIT'),
    ('KMV - Permitting Process', 'PERMIT'), ('KMV - MOT Process', 'PERMIT'),
    -- Hojas 2025: filas principales de un tipo concreto (confirmar)
    ('KMV-AB', 'P'), ('KMV - RGB', 'P'), ('KMV - UWS', 'P'), ('KMV - RELOCATION', 'P');

-- ─── Project Status ────────────────────────────────────────────────
-- Grupos = bloques del picklist (1. Survey, 2. Design, 3. Packages/APP…).
-- Se agrupa por significado, no por número: en 2025 "3." era permisos y
-- "7." Design MOT; en 2026 "3." es packages y "5." Design MOT.
CREATE TABLE project_status_group (
    code        text PRIMARY KEY,
    name        text NOT NULL UNIQUE,
    area_code   text REFERENCES area (code),     -- NULL = estados antiguos generales
    sort_order  smallint NOT NULL
);

INSERT INTO project_status_group (code, name, area_code, sort_order) VALUES
    ('SURVEY',     'Survey',            'DESIGN',     1),
    ('DESIGN',     'Design',            'DESIGN',     2),
    ('PACKAGES',   'Packages',          'DESIGN',     3),
    ('APP',        'APP',               'PERMITTING', 4),
    ('PERMIT',     'Permit',            'PERMITTING', 5),
    ('DESIGN_MOT', 'Design MOT',        'MOT',        6),
    ('PERMIT_MOT', 'Permit - MOT',      'PERMITTING', 7),
    ('AS_BUILT',   'As-Built',          'DESIGN',     8),
    ('CLOSE',      'Close',             'PERMITTING', 9),
    ('EXTENSION',  'Permit Extension',  'PERMITTING', 10),
    ('TICKET',     'Ticket',            'PERMITTING', 11),
    ('LEGACY',     'Legacy',            NULL,         12);

-- "By others" y "On Hold" se conservan como estados (el equipo trabaja igual)
-- y se marcan con is_by_others / is_on_hold para filtrarlos y medirlos.
CREATE TABLE project_status (
    code          text PRIMARY KEY,
    name          text NOT NULL UNIQUE,      -- texto de Smartsheet sin el número
    group_code    text NOT NULL REFERENCES project_status_group (code),
    is_final      boolean NOT NULL DEFAULT false,
    is_on_hold    boolean NOT NULL DEFAULT false,
    is_by_others  boolean NOT NULL DEFAULT false,
    is_legacy     boolean NOT NULL DEFAULT false,   -- no usar en registros nuevos
    sort_order    smallint NOT NULL
);

INSERT INTO project_status (code, name, group_code, is_final, is_on_hold, is_by_others, is_legacy, sort_order) VALUES
    ('SURVEY_PROGRESS',                  'Survey Progress',                  'SURVEY',     false, false, false, false, 101),
    ('SURVEY_COMPLETED',                 'Survey Completed',                 'SURVEY',     false, false, false, false, 102),
    ('SURVEY_ON_HOLD',                   'Survey on Hold',                   'SURVEY',     false, true,  false, false, 103),
    ('DESIGN_PROCESS',                   'Design Process',                   'DESIGN',     false, false, false, false, 201),
    ('DESIGN_NEEDS_QC',                  'Design Needs QC',                  'DESIGN',     false, false, false, false, 202),
    ('DESIGN_PENDING_APPROVAL',          'Design Pending Approval',          'DESIGN',     false, false, false, false, 203),
    ('DESIGN_NEEDS_REVISION',            'Design Needs Revision',            'DESIGN',     false, false, false, false, 204),
    ('DESIGN_REVISION_COMPLETED',        'Design Revision Completed',        'DESIGN',     false, false, false, false, 205),
    ('DESIGN_GPR_OR_SOFT_DIG',           'Design GPR or Soft Dig',           'DESIGN',     false, false, false, false, 206),
    ('DESIGN_ON_HOLD',                   'Design on Hold',                   'DESIGN',     false, true,  false, false, 207),
    ('DESIGN_COMPLETED',                 'Design Completed',                 'DESIGN',     false, false, false, false, 208),
    ('PREPARE_PACKAGES',                 'Prepare Packages',                 'PACKAGES',   false, false, false, false, 301),
    ('PACKAGES_COMPLETED',               'Packages Completed',               'PACKAGES',   false, false, false, false, 302),
    ('PREPARE_APP_ONLY',                 'Prepare APP Only',                 'APP',        false, false, false, false, 401),
    ('PREPARE_MOT_APP',                  'Prepare MOT APP',                  'APP',        false, false, false, false, 402),
    ('APP_NEEDS_QC',                     'APP Needs QC',                     'APP',        false, false, false, false, 403),
    ('APP_NEEDS_SIGNATURE',              'APP Needs Signature',              'APP',        false, false, false, false, 404),
    ('PENDING_COI',                      'Pending COI',                      'APP',        false, true,  false, false, 405),
    ('PENDING_REGISTRATION',             'Pending Registration',             'APP',        false, true,  false, false, 406),
    ('PERMIT_IS_REQUIRED',               'Permit is Required',               'PERMIT',     false, false, false, false, 501),
    ('PERMIT_ON_HOLD',                   'Permit on Hold',                   'PERMIT',     false, true,  false, false, 502),
    ('PERMIT_PROCESS',                   'Permit Process',                   'PERMIT',     false, false, false, false, 503),
    ('PERMIT_NEEDS_QC',                  'Permit Needs QC',                  'PERMIT',     false, false, false, false, 504),
    ('PERMIT_NEEDS_REVISION',            'Permit Needs Revision',            'PERMIT',     false, false, false, false, 505),
    ('PERMIT_REVISION_COMPLETED',        'Permit Revision Completed',        'PERMIT',     false, false, false, false, 506),
    ('PERMIT_AWAITING_CHECKS',           'Permit-Awaiting Checks',           'PERMIT',     false, true,  false, false, 507),
    ('PERMIT_AWAITING_NUMBER',           'Permit-Awaiting number',           'PERMIT',     false, true,  false, false, 508),
    ('PERMIT_GPR_OR_SOFT_DIG',           'Permit GPR or Soft Dig',           'PERMIT',     false, false, false, false, 509),
    ('PERMIT_PENDING_BOND',              'Permit-Pending Bond',              'PERMIT',     false, true,  false, false, 510),
    ('RUNNER_SUBMIT_PERMIT',             'Runner: Submit Permit',            'PERMIT',     false, false, false, false, 511),
    ('RUNNER_PRECON_PICK_UP',            'Runner: Pre-con/Pick up',          'PERMIT',     false, false, false, false, 512),
    ('PERMIT_PENDING_APPROVAL',          'Permit Pending Approval',          'PERMIT',     false, false, false, false, 513),
    ('PERMIT_APPROVED_PENDING_ISSUANCE', 'Permit Approved - Pending issuance','PERMIT',    false, false, false, false, 514),
    ('PERMIT_APPROVED',                  'Permit Approved',                  'PERMIT',     false, false, false, false, 515),
    ('PERMIT_EXPIRED',                   'Permit Expired',                   'PERMIT',     false, false, false, false, 516),
    ('PERMIT_PROCESS_BY_OTHERS',         'Permit Process by others',         'PERMIT',     false, false, true,  false, 517),
    ('PERMIT_CANCELLED',                 'Permit Cancelled',                 'PERMIT',     true,  false, false, false, 518),
    ('PERMIT_CLOSED',                    'Permit Closed',                    'PERMIT',     true,  false, false, false, 519),
    ('NO_PERMIT_REQUIRED',               'No Permit Required',               'PERMIT',     true,  false, false, false, 520),
    ('DESIGN_MOT_REQUIRED',              'Design MOT Required',              'DESIGN_MOT', false, false, false, false, 601),
    ('DESIGN_MOT_PROCESS',               'Design MOT Process',               'DESIGN_MOT', false, false, false, false, 602),
    ('DESIGN_MOT_NEEDS_QC',              'Design MOT Needs QC',              'DESIGN_MOT', false, false, false, false, 603),
    ('DESIGN_MOT_REVISION',              'Design MOT Revision',              'DESIGN_MOT', false, false, false, false, 604),
    ('DESIGN_MOT_ON_HOLD',               'Design MOT on Hold',               'DESIGN_MOT', false, true,  false, false, 605),
    ('DESIGN_MOT_COMPLETED',             'Design MOT Completed',             'DESIGN_MOT', false, false, false, false, 606),
    ('PERMIT_MOT_PROCESS',               'Permit - MOT Process',             'PERMIT_MOT', false, false, false, false, 701),
    ('PERMIT_MOT_REVISION',              'Permit - MOT Revision',            'PERMIT_MOT', false, false, false, false, 702),
    ('PERMIT_MOT_PENDING_APPROVAL',      'Permit - MOT Pending Approval',    'PERMIT_MOT', false, false, false, false, 703),
    ('PERMIT_MOT_APPROVED',              'Permit - MOT Approved',            'PERMIT_MOT', false, false, false, false, 704),
    ('PERMIT_MOT_BY_OTHERS',             'Permit - MOT By others',           'PERMIT_MOT', false, false, true,  false, 705),
    ('AS_BUILT_REQUIRED',                'As-Built Required',                'AS_BUILT',   false, false, false, false, 801),
    ('AS_BUILT_ON_HOLD',                 'As-Built on Hold',                 'AS_BUILT',   false, true,  false, false, 802),
    ('AS_BUILT_QC',                      'As-Built QC',                      'AS_BUILT',   false, false, false, false, 803),
    ('AS_BUILT_REVISION',                'As-Built Revision',                'AS_BUILT',   false, false, false, false, 804),
    ('AS_BUILT_S_S',                     'As-Built (S&S)',                   'AS_BUILT',   false, false, false, false, 805),
    ('AS_BUILT_COMPLETED',               'As-Built Completed',               'AS_BUILT',   true,  false, false, false, 806),
    ('CLOSE_PERMIT_PROCESS',             'Close - Permit Process',           'CLOSE',      false, false, false, false, 901),
    ('CLOSE_PENDING_APPROVAL',           'Close - Pending Approval',         'CLOSE',      false, false, false, false, 902),
    ('CLOSE_PERMIT_CLOSED',              'Close - Permit Closed',            'CLOSE',      true,  false, false, false, 903),
    ('PROCESS_COMPLETED',                'Process completed',                'CLOSE',      true,  false, false, false, 904),
    ('PERMIT_EXTENSION_PROCESS',         'Permit Extension - Process',       'EXTENSION',  false, false, false, false, 1001),
    ('PERMIT_EXTENSION_COMPLETED',       'Permit Extension - Completed',     'EXTENSION',  true,  false, false, false, 1002),
    ('PERMIT_REAPPLICATION',             'Permit Reapplication',             'EXTENSION',  false, false, false, false, 1003),
    ('PERMIT_REOPENING',                 'Permit Reopening',                 'EXTENSION',  false, false, false, false, 1004),
    ('TICKET_PROCESS',                   'Ticket - Process',                 'TICKET',     false, false, false, false, 1101),
    ('TICKET_COMPLETED',                 'Ticket - Completed',               'TICKET',     true,  false, false, false, 1102),
    ('COMPLETE',                         'COMPLETE',                         'LEGACY',     true,  false, false, true,  1201),
    ('CANCELLED',                        'CANCELLED',                        'LEGACY',     true,  false, false, true,  1202),
    ('IN_PROGRESS',                      'IN PROGRESS',                      'LEGACY',     false, false, false, true,  1203),
    ('IN_PERMITTING',                    'IN PERMITTING',                    'LEGACY',     false, false, false, true,  1204),
    ('NO_PERMIT_REQUIRED_LEGACY',        'NO PERMIT REQUIRED',               'LEGACY',     true,  false, false, true,  1205);

-- Todos los textos de "Project Status" vistos en las hojas 2025–2026
CREATE TABLE project_status_alias (
    alias                text PRIMARY KEY,
    project_status_code  text NOT NULL REFERENCES project_status (code)
);
CREATE UNIQUE INDEX project_status_alias_normalized_uq
    ON project_status_alias (normalize_text(alias));

INSERT INTO project_status_alias (alias, project_status_code) VALUES
    ('1. Survey Progress', 'SURVEY_PROGRESS'),
    ('1. Survey Completed', 'SURVEY_COMPLETED'),
    ('1. Survey on Hold', 'SURVEY_ON_HOLD'),
    ('2. Design Process', 'DESIGN_PROCESS'),
    ('2. Design Needs QC', 'DESIGN_NEEDS_QC'),
    ('2. Design Need QC', 'DESIGN_NEEDS_QC'),
    ('2. Design Pending Approval', 'DESIGN_PENDING_APPROVAL'),
    ('2. Design Needs Revision', 'DESIGN_NEEDS_REVISION'),
    ('2. Design Need Revision', 'DESIGN_NEEDS_REVISION'),
    ('2. Design Revision Completed', 'DESIGN_REVISION_COMPLETED'),
    ('2. Design GPR or Soft Dig', 'DESIGN_GPR_OR_SOFT_DIG'),
    ('2. GPR or Soft Dig', 'DESIGN_GPR_OR_SOFT_DIG'),
    ('2. Design on Hold', 'DESIGN_ON_HOLD'),
    ('2. Design Completed', 'DESIGN_COMPLETED'),
    ('2. Completed', 'DESIGN_COMPLETED'),
    ('3. Prepare Packages', 'PREPARE_PACKAGES'),
    ('8. Prepare Packages', 'PREPARE_PACKAGES'),
    ('3. Packages Completed', 'PACKAGES_COMPLETED'),
    ('8. Packages Completed', 'PACKAGES_COMPLETED'),
    ('3. Prepare APP Only', 'PREPARE_APP_ONLY'),
    ('3. Prepare MOT APP', 'PREPARE_MOT_APP'),
    ('3. APP Needs QC', 'APP_NEEDS_QC'),
    ('3. APP Needs Signature', 'APP_NEEDS_SIGNATURE'),
    ('3. Pending COI', 'PENDING_COI'),
    ('6. Pending COI', 'PENDING_COI'),
    ('3. Pending Registration', 'PENDING_REGISTRATION'),
    ('5. Pending Registration', 'PENDING_REGISTRATION'),
    ('4. Permit is Required', 'PERMIT_IS_REQUIRED'),
    ('3. Permit is Required', 'PERMIT_IS_REQUIRED'),
    ('4. Permit on Hold', 'PERMIT_ON_HOLD'),
    ('3. Permit on hold', 'PERMIT_ON_HOLD'),
    ('4. Permit Process', 'PERMIT_PROCESS'),
    ('3. Permitting Process', 'PERMIT_PROCESS'),
    ('4. Permit Needs QC', 'PERMIT_NEEDS_QC'),
    ('3. Permit Needs QC', 'PERMIT_NEEDS_QC'),
    ('4. Permit Needs Revision', 'PERMIT_NEEDS_REVISION'),
    ('3. Permit Needs Revision', 'PERMIT_NEEDS_REVISION'),
    ('4. Permit Revision Completed', 'PERMIT_REVISION_COMPLETED'),
    ('3. Permit Revision Completed', 'PERMIT_REVISION_COMPLETED'),
    ('4. Permit-Awaiting Checks', 'PERMIT_AWAITING_CHECKS'),
    ('3. Permitting Awaiting Checks', 'PERMIT_AWAITING_CHECKS'),
    ('4. Permit-Awaiting number', 'PERMIT_AWAITING_NUMBER'),
    ('3. Permitting Awaiting number', 'PERMIT_AWAITING_NUMBER'),
    ('4. Permit GPR or Soft Dig', 'PERMIT_GPR_OR_SOFT_DIG'),
    ('3. Permitting - GPR or Softdig request', 'PERMIT_GPR_OR_SOFT_DIG'),
    ('4. Permit-Pending Bond', 'PERMIT_PENDING_BOND'),
    ('5. Pending Bond', 'PERMIT_PENDING_BOND'),
    ('4. Runner: Submit Permit', 'RUNNER_SUBMIT_PERMIT'),
    ('3. Runner: Submit Permit', 'RUNNER_SUBMIT_PERMIT'),
    ('4. Runner: Pre-con/Pick up', 'RUNNER_PRECON_PICK_UP'),
    ('4. Runner: Precon/Pick up', 'RUNNER_PRECON_PICK_UP'),
    ('3. Runner: Permit Pick up', 'RUNNER_PRECON_PICK_UP'),
    ('3. Runner: Precon/Other', 'RUNNER_PRECON_PICK_UP'),
    ('4. Permit Pending Approval', 'PERMIT_PENDING_APPROVAL'),
    ('4. Permit Approved - Pending issuance', 'PERMIT_APPROVED_PENDING_ISSUANCE'),
    ('4. Permit Approved', 'PERMIT_APPROVED'),
    ('3. Permit Approved', 'PERMIT_APPROVED'),
    ('4. Permit Expired', 'PERMIT_EXPIRED'),
    ('4. Permit Process by others', 'PERMIT_PROCESS_BY_OTHERS'),
    ('3. Permit Process by others', 'PERMIT_PROCESS_BY_OTHERS'),
    ('4. Permit Cancelled', 'PERMIT_CANCELLED'),
    ('3. Permit Cancelled', 'PERMIT_CANCELLED'),
    ('4. Permit Closed', 'PERMIT_CLOSED'),
    ('3. Permit Closed', 'PERMIT_CLOSED'),
    ('4. No Permit Required', 'NO_PERMIT_REQUIRED'),
    ('7. Design MOT Required', 'DESIGN_MOT_REQUIRED'),
    ('5. Design MOT Process', 'DESIGN_MOT_PROCESS'),
    ('7. Design MOT Process', 'DESIGN_MOT_PROCESS'),
    ('5. Design MOT Needs QC', 'DESIGN_MOT_NEEDS_QC'),
    ('7. Design MOT Need QC', 'DESIGN_MOT_NEEDS_QC'),
    ('5. Design MOT Revision', 'DESIGN_MOT_REVISION'),
    ('7. Design MOT Revision', 'DESIGN_MOT_REVISION'),
    ('5. Design MOT on Hold', 'DESIGN_MOT_ON_HOLD'),
    ('7. Design MOT on Hold', 'DESIGN_MOT_ON_HOLD'),
    ('5. Design MOT Completed', 'DESIGN_MOT_COMPLETED'),
    ('7. Design MOT Completed', 'DESIGN_MOT_COMPLETED'),
    ('6. Permit - MOT Process', 'PERMIT_MOT_PROCESS'),
    ('3. Permit - MOT Process', 'PERMIT_MOT_PROCESS'),
    ('6. Permit - MOT Revision', 'PERMIT_MOT_REVISION'),
    ('3. Permit - MOT Revision', 'PERMIT_MOT_REVISION'),
    ('6. Permit - MOT Pending Approval', 'PERMIT_MOT_PENDING_APPROVAL'),
    ('6. Permit - MOT Approved', 'PERMIT_MOT_APPROVED'),
    ('3. Permit - MOT Approved', 'PERMIT_MOT_APPROVED'),
    ('6. Permit - MOT  By others', 'PERMIT_MOT_BY_OTHERS'),
    ('3. Permit - MOT  By others', 'PERMIT_MOT_BY_OTHERS'),
    ('7. As-Built Required', 'AS_BUILT_REQUIRED'),
    ('4. As-Built Required', 'AS_BUILT_REQUIRED'),
    ('7. As-Built on Hold', 'AS_BUILT_ON_HOLD'),
    ('4. As-Built on hold', 'AS_BUILT_ON_HOLD'),
    ('7. As-Built QC', 'AS_BUILT_QC'),
    ('4. As-Built QC', 'AS_BUILT_QC'),
    ('7. As-Built Revision', 'AS_BUILT_REVISION'),
    ('4. As-Built Revision', 'AS_BUILT_REVISION'),
    ('7. As-Built (S&S)', 'AS_BUILT_S_S'),
    ('4. As-Built (S&S)', 'AS_BUILT_S_S'),
    ('7. As-Built Completed', 'AS_BUILT_COMPLETED'),
    ('4. As-Built Completed', 'AS_BUILT_COMPLETED'),
    ('8. Close - Permit Process', 'CLOSE_PERMIT_PROCESS'),
    ('3. Permit Closing Process', 'CLOSE_PERMIT_PROCESS'),
    ('8. Close - Pending Approval', 'CLOSE_PENDING_APPROVAL'),
    ('8. Close - Permit Closed', 'CLOSE_PERMIT_CLOSED'),
    ('8. Process completed', 'PROCESS_COMPLETED'),
    ('9. Permit Extension', 'PERMIT_EXTENSION_PROCESS'),
    ('9. Permit Extension - Process', 'PERMIT_EXTENSION_PROCESS'),
    ('9. Permit Extension - Completed', 'PERMIT_EXTENSION_COMPLETED'),
    ('9. Permit Reapplication', 'PERMIT_REAPPLICATION'),
    ('9. Permit Reopening', 'PERMIT_REOPENING'),
    ('9. Ticket - Process', 'TICKET_PROCESS'),
    ('TICKET - COORDINATION', 'TICKET_PROCESS'),
    ('9. Ticket - Completed', 'TICKET_COMPLETED'),
    ('COMPLETE', 'COMPLETE'),
    ('CANCELLED', 'CANCELLED'),
    ('CANCEL', 'CANCELLED'),
    ('CANCELLED - NO PERMIT REQUIRED', 'CANCELLED'),
    ('IN PROGRESS', 'IN_PROGRESS'),
    ('IN PERMITTING', 'IN_PERMITTING'),
    ('NO PERMIT REQUIRED', 'NO_PERMIT_REQUIRED_LEGACY'),
    ('NO PERMIT REQUIRED BY', 'NO_PERMIT_REQUIRED_LEGACY');

-- ─── Qué Project Status acepta cada Type of Project ────────────────
-- project_task tiene una FK compuesta a esta tabla: la base rechaza, por
-- ejemplo, "Permit Approved" en una fila KMV-P.
CREATE TABLE type_of_project_status (
    type_of_project_code  text NOT NULL REFERENCES type_of_project (code),
    project_status_code   text NOT NULL REFERENCES project_status (code),
    PRIMARY KEY (type_of_project_code, project_status_code)
);

INSERT INTO type_of_project_status (type_of_project_code, project_status_code)
SELECT r.type_of_project_code, s.code
FROM (VALUES
    ('P', 'SURVEY'), ('P', 'DESIGN'), ('P', 'PACKAGES'), ('P', 'AS_BUILT'), ('P', 'LEGACY'),
    ('MISC', 'SURVEY'), ('MISC', 'DESIGN'), ('MISC', 'PACKAGES'), ('MISC', 'AS_BUILT'), ('MISC', 'LEGACY'),
    ('MOT', 'DESIGN_MOT'), ('MOT', 'PERMIT_MOT'), ('MOT', 'LEGACY'),
    ('LINE', 'APP'), ('LINE', 'PERMIT'), ('LINE', 'PERMIT_MOT'), ('LINE', 'CLOSE'),
    ('LINE', 'EXTENSION'), ('LINE', 'TICKET'), ('LINE', 'LEGACY'),
    ('PERMIT', 'APP'), ('PERMIT', 'PERMIT'), ('PERMIT', 'PERMIT_MOT'), ('PERMIT', 'CLOSE'),
    ('PERMIT', 'EXTENSION'), ('PERMIT', 'TICKET'), ('PERMIT', 'LEGACY')
) AS r (type_of_project_code, group_code)
JOIN project_status s ON s.group_code = r.group_code;

-- ─── Task (picklist "Task": Jumper, Enterprise, PM LINE…) ──────────
-- category = separadores del picklist: Eng Task / Project Type / Permits Type
CREATE TABLE task (
    code      text PRIMARY KEY,
    name      text NOT NULL UNIQUE,
    category  text NOT NULL CHECK (category IN ('ENG_TASK', 'PROJECT_TYPE', 'PERMITS_TYPE')),
    active    boolean NOT NULL DEFAULT true
);

INSERT INTO task (code, name, category) VALUES
    ('PM_LINE',            'PM LINE',            'ENG_TASK'),
    ('FIBER_DESIGN',       'Fiber Design',       'ENG_TASK'),
    ('PERMIT_DESIGN',      'Permit Design',      'ENG_TASK'),
    ('MOT_DESIGN',         'MOT Design',         'ENG_TASK'),
    ('RELOCATION',         'Relocation',         'PROJECT_TYPE'),
    ('RGB',                'RGB',                'PROJECT_TYPE'),
    ('UWS',                'UWS',                'PROJECT_TYPE'),
    ('RGB_UWS',            'RGB & UWS',          'PROJECT_TYPE'),
    ('GREEN_LINES',        'Green Lines',        'PROJECT_TYPE'),
    ('OVERBUILD',          'Overbuild',          'PROJECT_TYPE'),
    ('DISH',               'Dish',               'PROJECT_TYPE'),
    ('ENTERPRISE',         'Enterprise',         'PROJECT_TYPE'),
    ('JUMPER',             'Jumper',             'PROJECT_TYPE'),
    ('RAPID_2_0',          'Rapid 2.0',          'PROJECT_TYPE'),
    ('VERIZON',            'Verizon',            'PROJECT_TYPE'),
    ('T_MOBILE',           'T-Mobile',           'PROJECT_TYPE'),
    ('SPRINT',             'Sprint',             'PROJECT_TYPE'),
    ('OMNI',               'OMNI',               'PROJECT_TYPE'),
    ('FTTCS',              'FTTCS',              'PROJECT_TYPE'),
    ('AS_BUILT',           'As-built',           'PROJECT_TYPE'),
    ('OSP',                'OSP',                'PROJECT_TYPE'),
    ('FTTH',               'FTTH',               'PROJECT_TYPE'),
    ('ISP',                'ISP',                'PROJECT_TYPE'),
    ('LV',                 'LV',                 'PROJECT_TYPE'),
    ('POWER_SUPPLY',       'Power Supply',       'PROJECT_TYPE'),
    ('SURVEY_CERTIFIED',   'Survey Certified',   'PROJECT_TYPE'),
    ('FRAC_OUT',           'Frac-out',           'PROJECT_TYPE'),
    ('GPR_OR_SOFT_DIG',    'GPR or Soft Dig',    'PROJECT_TYPE'),
    ('S_S',                'S&S',                'PROJECT_TYPE'),
    ('MEETING',            'Meeting',            'PROJECT_TYPE'),
    ('PAYMENTS',           'Payments',           'PROJECT_TYPE'),
    ('PERMITTING_PROCESS', 'Permitting Process', 'PERMITS_TYPE'),
    ('MOT_PROCESS',        'MOT Process',        'PERMITS_TYPE');

CREATE TABLE task_alias (
    alias      text PRIMARY KEY,
    task_code  text NOT NULL REFERENCES task (code)
);
CREATE UNIQUE INDEX task_alias_normalized_uq ON task_alias (normalize_text(alias));

-- "KMV - MEETING" y "KMV - PAYMENTS" se resuelven solos: la comparación es normalizada.
INSERT INTO task_alias (alias, task_code) VALUES
    ('PM LINE', 'PM_LINE'),
    ('KMV-Fiber Design', 'FIBER_DESIGN'), ('DBE-Fiber Design', 'FIBER_DESIGN'),
    ('FN-Fiber Design', 'FIBER_DESIGN'), ('Mastec-Fiber Design', 'FIBER_DESIGN'),
    ('KMV-Permit Design', 'PERMIT_DESIGN'), ('DBE-Permit Design', 'PERMIT_DESIGN'),
    ('FN-Permit Design', 'PERMIT_DESIGN'), ('Mastec-Permit Design', 'PERMIT_DESIGN'),
    ('KMV-MOT Design', 'MOT_DESIGN'), ('KMV - MOT', 'MOT_DESIGN'), ('MOT', 'MOT_DESIGN'),
    ('KMV - Relocation', 'RELOCATION'), ('Relocation', 'RELOCATION'),
    ('KMV - RGB', 'RGB'), ('KMV - UWS', 'UWS'), ('KMV - RGB & UWS', 'RGB_UWS'),
    ('KMV - Green Lines', 'GREEN_LINES'), ('KMV - Overbuild', 'OVERBUILD'),
    ('KMV - Dish', 'DISH'),
    ('KMV - Enterprise', 'ENTERPRISE'), ('Enterprise', 'ENTERPRISE'),
    ('KMV - Jumper', 'JUMPER'), ('KMV - Rapid 2.0', 'RAPID_2_0'),
    ('KMV - Verizon', 'VERIZON'), ('Verizon Site', 'VERIZON'),
    ('KMV - T-Mobile', 'T_MOBILE'), ('Sprint Site', 'SPRINT'),
    ('KMV - OMNI', 'OMNI'),
    ('KMV - FTTCS', 'FTTCS'), ('FTTCS', 'FTTCS'),
    ('KMV - As-built', 'AS_BUILT'), ('As-built', 'AS_BUILT'), ('DBE-Asbuilt', 'AS_BUILT'),
    ('KMV - OSP', 'OSP'), ('KMV - FTTH', 'FTTH'),
    ('KMV - ISP', 'ISP'), ('KMV - inside Plan', 'ISP'),
    ('KMV - LV', 'LV'),
    ('KMV - Power Supply', 'POWER_SUPPLY'), ('DBE-Power Supply', 'POWER_SUPPLY'),
    ('KMV - Survey Certified', 'SURVEY_CERTIFIED'), ('KMV - Frac-out', 'FRAC_OUT'),
    ('KMV - GPR or Soft Dig', 'GPR_OR_SOFT_DIG'), ('KMV - S&S', 'S_S'),
    ('KMV - Meeting', 'MEETING'), ('KMV - Payments', 'PAYMENTS'),
    ('KMV - Permitting Process', 'PERMITTING_PROCESS'),
    ('KMV - MOT Process', 'MOT_PROCESS');

-- ─── Quantity items (columnas Total Footage, UG, ISP, Aerial…) ─────
CREATE TABLE quantity_item (
    code               text PRIMARY KEY,
    name               text NOT NULL,
    unit               text,                 -- ft, ea… (confirmar las que quedan NULL)
    smartsheet_column  text NOT NULL UNIQUE,
    active             boolean NOT NULL DEFAULT true   -- false = solo en hojas 2025 o antes
);

INSERT INTO quantity_item (code, name, unit, smartsheet_column, active) VALUES
    ('TOTAL_FOOTAGE',          'Total Footage',          'ft', 'Total Footage',          true),
    ('UG',                     'UG',                     'ft', 'UG',                     true),
    ('UG_PROFILE',             'UG + Profile',           'ft', 'UG + Profile',           true),
    ('ISP',                    'ISP',                    'ft', 'ISP',                    true),
    ('AERIAL',                 'Aerial',                 'ft', 'Aerial',                 true),
    ('CUSTOM_MOT',             'Custom MOT',             NULL, 'Custom MOT',             true),
    ('TYPICAL_MOT',            'TYPICAL MOT',            NULL, 'TYPICAL MOT',            true),
    ('ADDITIONAL_SITE_SURVEY', 'Additional Site Survey', NULL, 'Additional Site Survey', true),
    ('SURVEY_CERTIFIED',       'Survey Certified',       NULL, 'Survey Certified',       true),
    ('TONE_LOCATING',          'Tone Locating',          NULL, 'Tone Locating',          true),
    ('SONDE_FTG',              'Sonde FTG',              'ft', 'Sonde FTG',              true),
    ('GPR',                    'GPR',                    NULL, 'GPR',                    true),
    ('CAD_UPDATE',             'CAD Update',             NULL, 'CAD Update',             true),
    ('CADDING',                'CADDING',                NULL, 'CADDING',                true),
    ('MOT',                    'MOT',                    NULL, 'MOT',                    false),
    ('PLAN_PROFILE_AERIAL',    'Plan & Profile- Aerial', NULL, 'Plan & Profile- Aerial (RR, Hwy, Bridge, etc)', false),
    ('UG_PLANNING_ROUTE_REVIEW','UG -Planning Route Review', NULL, 'UG -Planning Route Review', false),
    ('AE_PLANNING_ROUTE_REVIEW','AE -Planning Route Review', NULL, 'AE -Planning Route Review', false),
    ('QER_AERIAL',             'Qualified Engineering Representative-Aerial', NULL, 'Qualified Engineering Representative-Aerial', false),
    ('QER_UG',                 'Qualified Engineering Representative - Underground', NULL, 'Qualified Engineering Representative - Underground', false),
    ('CIS_AERIAL',             'Construction Inspection Services - Aerial', NULL, 'Construction Inspection Services - Aerial', false),
    ('CIS_UG',                 'Construction Inspection Services - Underground', NULL, 'Construction Inspection Services - Underground', false),
    ('POLE_DATA_COLLECTION',   'Pole Data Collection (Aerial Strand Mapping)', NULL, 'Pole Data Collection (Aerial Strand Mapping', false),
    ('POLE_DATA_COLLECTION_R', 'Pole Data Collection (Aerial Strand Mapping) - (r', NULL, 'Pole Data Collection (Aerial Strand Mapping)  - (r', false),
    ('POLE_LOADING_ANALYSIS',  'Pole Loading Analysis',  NULL, 'Pole Loading Analysis',  false),
    ('JOINT_FIELD_SURVEY_POLE','Coordinate & Conduct Joint Field Survey (per pole)', NULL, 'Coordinate & Conduct Joint Field Survey (per pole', false),
    ('JOINT_FIELD_SURVEY_APP', 'Coordinate & Conduct Joint Field Survey (each application)', NULL, 'Coordinate & Conduct Joint Field Survey (each appl', false),
    ('POST_INSPECTION_AERIAL', 'Post Inspection Survey of Aerial Make-Ready', NULL, 'Post Inspection Survey of Aerial Make-Ready and St', false),
    ('OSP',                    'OSP',                    NULL, 'OSP',                    false),
    ('PROFILE',                'Profile',                NULL, 'Profile',                false),
    ('PLACE_MUTE_TAPE',        'Place a Mute Tape',      NULL, 'Place a Mute Tape',      false),
    ('PROOF_CONDUIT',          'Proof Conduit',          NULL, 'Proof Conduit',          false),
    ('JUMPER_CABLE',           'Jumper Cable',           NULL, 'Jumper Cable',           false);

-- ─── Permit Requirements (equivale a la hoja "Permit Requirements") ─
CREATE TABLE permit_requirement (
    permit_requirement_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    agency_id              bigint NOT NULL REFERENCES agency (agency_id),
    type_of_project_code   text REFERENCES type_of_project (code),
    requirement            text NOT NULL,
    description            text,
    is_mandatory           boolean NOT NULL DEFAULT false,
    reference_fee          numeric(14,2),
    active                 boolean NOT NULL DEFAULT true
);

-- ─── Records Status ────────────────────────────────────────────────
CREATE TABLE records_status (
    code      text PRIMARY KEY,
    name      text NOT NULL UNIQUE,     -- texto de Smartsheet
    is_final  boolean NOT NULL DEFAULT false
);

INSERT INTO records_status (code, name, is_final) VALUES
    ('RECEIVED',              'Received',              true),
    ('NOT_RECEIVED',          'Not Received',          false),
    ('NO_RECORDS',            'No records',            true),
    ('NOT_APPLY',             'Not Appy',              true),
    ('TICKET_COORDINATION',   'Ticket - coordination', false),
    ('EXISTING',              'Existing',              true),
    ('ONLINE',                'Online',                true),
    ('BY_EMAIL',              'By email',              false);

-- Tipo de cada solicitud que hoy se escribe dentro de "Record ID"
CREATE TABLE record_request_type (
    code  text PRIMARY KEY,
    name  text NOT NULL UNIQUE
);

INSERT INTO record_request_type (code, name) VALUES
    ('PRR',            'PRR (Public Records Request)'),
    ('FUTURE_PROJECT', 'Future Project'),
    ('FDOT_RECORDS',   'FDOT Records'),
    ('SURVEY_MAPS',    'Survey Maps'),
    ('OTHER',          'Other');

COMMIT;
