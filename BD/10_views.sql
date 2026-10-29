-- 10 — Vistas
-- Las columnas calculadas de Smartsheet ("# Days", estado del proyecto,
-- factura pagada) aquí se calculan; no se guardan.

BEGIN;

-- Filas con su área, grupo de estado y marcas: base para tableros por área
CREATE VIEW v_project_task AS
SELECT
    pt.project_task_id,
    p.tracking_project,
    c.name                  AS customer,
    pt.type_of_project_code,
    tp.name                 AS type_of_project,
    tp.area_code,
    a.name                  AS area,
    a.parent_code           AS parent_area_code,
    t.name                  AS task,
    pt.project_status_code,
    ps.name                 AS project_status,
    ps.group_code           AS project_status_group,
    coalesce(ps.is_final, false)     AS is_final,
    coalesce(ps.is_on_hold, false)   AS is_on_hold,
    coalesce(ps.is_by_others, false) AS is_by_others,
    ag.name                 AS agency,
    pt.priority,
    pt.last_touched_date,
    pt.obs
FROM project_task pt
JOIN project p            ON p.project_id = pt.project_id
JOIN customer c           ON c.customer_id = p.customer_id
JOIN type_of_project tp   ON tp.code = pt.type_of_project_code
JOIN area a               ON a.code = tp.area_code
LEFT JOIN task t          ON t.code = pt.task_code
LEFT JOIN project_status ps ON ps.code = pt.project_status_code
LEFT JOIN agency ag       ON ag.agency_id = pt.agency_id;

-- Estado del proyecto calculado a partir de sus filas, con pendientes por área
CREATE VIEW v_project_summary AS
SELECT
    p.project_id,
    p.tracking_project,
    count(pt.project_task_id)                                         AS tasks,
    count(*) FILTER (WHERE ps.is_final)                               AS tasks_final,
    count(*) FILTER (WHERE pt.project_task_id IS NOT NULL
                       AND NOT coalesce(ps.is_final, false) AND tp.area_code = 'DESIGN')     AS pending_design,
    count(*) FILTER (WHERE pt.project_task_id IS NOT NULL
                       AND NOT coalesce(ps.is_final, false) AND tp.area_code = 'MOT')        AS pending_mot,
    count(*) FILTER (WHERE pt.project_task_id IS NOT NULL
                       AND NOT coalesce(ps.is_final, false) AND tp.area_code = 'PERMITTING') AS pending_permitting,
    CASE
        WHEN count(pt.project_status_code) = 0 THEN 'NEW'
        WHEN bool_or(pt.type_of_project_code = 'P' AND pt.project_status_code = 'CANCELLED') THEN 'CANCELLED'
        WHEN count(*) FILTER (WHERE ps.is_final) = count(pt.project_task_id) THEN 'COMPLETE'
        ELSE 'IN PROGRESS'
    END                                                               AS project_status
FROM project p
LEFT JOIN project_task pt    ON pt.project_id = p.project_id
LEFT JOIN type_of_project tp ON tp.code = pt.type_of_project_code
LEFT JOIN project_status ps  ON ps.code = pt.project_status_code
GROUP BY p.project_id, p.tracking_project;

-- Reemplazo de las columnas "# Days" (mismos nombres que en Smartsheet).
-- Revisa las fórmulas originales y ajusta si alguna difiere.
CREATE VIEW v_project_task_days AS
SELECT
    pt.project_task_id,
    p.tracking_project,
    pt.type_of_project_code,
    pt.project_status_code,
    CASE WHEN d.project_task_id IS NOT NULL
         THEN coalesce(d.design_completed_date, current_date) - p.date_received
    END                                                                         AS project_days,           -- "Project # Days"
    q.qc_days,                                                                                             -- "QC # Days"
    (d.pm_approval_date - d.design_completed_date)                             AS pm_approval_days,        -- "PM Approval Days"
    (d.prepare_packages_completed_date - d.prepare_packages_request_date)      AS prepare_packages_days,   -- "Prepare Packages # Days"
    (s.sonde_received_date - s.sonde_request_date)                             AS sonde_days,              -- "Sonde # Days"
    (r.record_received_date - r.record_request_date)                           AS record_days,             -- "Record # Days"
    (pe.app_returned_from_contractor_date - pe.app_sent_to_contractor_date)    AS app_delay_days_from_contractor,
    CASE WHEN pe.permit_id IS NOT NULL
         THEN coalesce(pe.permit_approved_date, current_date) - pt.submitted_date
    END                                                                         AS permit_days,            -- "Permit # Days"
    (m.design_mot_completed_date - m.design_mot_request_date)                  AS design_mot_days,         -- "Design MOT # Days"
    (ab.as_built_complete_date - ab.asbuilt_received_bore_log_date)            AS as_built_days            -- "As-built # Days"
FROM project_task pt
JOIN project p          ON p.project_id = pt.project_id
LEFT JOIN design d      ON d.project_task_id = pt.project_task_id
LEFT JOIN design_mot m  ON m.project_task_id = pt.project_task_id
LEFT JOIN as_built ab   ON ab.project_task_id = pt.project_task_id
LEFT JOIN permit pe     ON pe.project_task_id = pt.project_task_id
LEFT JOIN records r     ON r.project_task_id = pt.project_task_id
LEFT JOIN sonde s       ON s.project_task_id = pt.project_task_id
LEFT JOIN LATERAL (
    SELECT sum(qc.qc_out_date - qc.qc_in_date) AS qc_days
    FROM qc WHERE qc.project_task_id = pt.project_task_id
) q ON true;

-- ¿Está pagada? (lo que hoy se mira en la hoja)
CREATE VIEW v_invoice_status AS
SELECT
    i.invoice_id,
    p.tracking_project,
    i.invoice_galp, i.invoice_kmv, i.customer_invoice,
    i.invoice_sent_date,
    i.invoice_paid_date,
    (i.invoice_paid_date IS NOT NULL)                                   AS is_paid,
    CASE
        WHEN i.invoice_paid_date IS NOT NULL THEN 'PAID'
        WHEN i.invoice_sent_date IS NOT NULL THEN 'SENT'
        ELSE 'PENDING'
    END                                                                 AS invoice_status,
    (coalesce(i.invoice_paid_date, current_date) - i.invoice_sent_date) AS invoice_days   -- "Invoice # Days"
FROM invoice i
JOIN project p ON p.project_id = i.project_id;

-- Permisos que vencen en los próximos 30 días
CREATE VIEW v_permit_expiring AS
SELECT p.tracking_project, ag.name AS agency, pe.permit_number, pe.permit_expires_date,
       (pe.permit_expires_date - current_date) AS days_left
FROM permit pe
JOIN project_task pt ON pt.project_task_id = pe.project_task_id
JOIN project p       ON p.project_id = pt.project_id
LEFT JOIN agency ag  ON ag.agency_id = pt.agency_id
WHERE pe.permit_expires_date BETWEEN current_date AND current_date + 30;

COMMIT;
