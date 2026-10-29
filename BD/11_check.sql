-- 11 — Verificación final

-- Tablas y vistas creadas
SELECT table_type, count(*) AS total
FROM information_schema.tables
WHERE table_schema = 'public'
GROUP BY table_type;

-- Catálogos cargados
SELECT 'area' AS catalog, count(*) FROM area
UNION ALL SELECT 'type_of_project', count(*) FROM type_of_project
UNION ALL SELECT 'project_status', count(*) FROM project_status
UNION ALL SELECT 'project_status_alias', count(*) FROM project_status_alias
UNION ALL SELECT 'type_of_project_status', count(*) FROM type_of_project_status
UNION ALL SELECT 'task', count(*) FROM task
UNION ALL SELECT 'quantity_item', count(*) FROM quantity_item
UNION ALL SELECT 'records_status', count(*) FROM records_status
UNION ALL SELECT 'customer', count(*) FROM customer
UNION ALL SELECT 'contractor', count(*) FROM contractor
UNION ALL SELECT 'role', count(*) FROM role;

-- Tablas por área
SELECT
    CASE
        WHEN table_name IN ('design', 'design_mot', 'as_built') THEN '1 DESIGN / MOT'
        WHEN table_name IN ('permit', 'permit_revision', 'records', 'record_request',
                            'design_ticket', 'project_permitting', 'permit_requirement') THEN '2 PERMITTING'
        WHEN table_name = 'invoice' THEN '3 INVOICING'
        WHEN table_name IN ('project', 'project_reference', 'project_task', 'project_task_assignment',
                            'project_task_quantity', 'project_task_status_history', 'qc', 'sonde') THEN '0 CORE'
        ELSE '4 CATALOGS / BASE'
    END AS area,
    string_agg(table_name, ', ' ORDER BY table_name) AS tables
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
GROUP BY 1
ORDER BY 1;

-- Project Status permitidos por Type of Project
SELECT type_of_project_code, count(*) AS allowed_statuses
FROM type_of_project_status
GROUP BY type_of_project_code
ORDER BY type_of_project_code;
