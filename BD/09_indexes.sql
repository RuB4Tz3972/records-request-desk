-- 09 — Índices
-- PostgreSQL no indexa las claves foráneas solo; aquí se cubren las que se
-- usan en búsquedas y uniones, más los reportes por área.

BEGIN;

-- Base
CREATE INDEX team_member_person_idx              ON team_member (person_id);
CREATE INDEX team_parent_idx                     ON team (parent_team_id);
CREATE INDEX agency_parent_idx                   ON agency (parent_agency_id);
CREATE INDEX city_county_idx                     ON city (county_id);
CREATE INDEX project_status_group_idx            ON project_status (group_code);

-- Project
CREATE INDEX project_customer_idx                ON project (customer_id);
CREATE INDEX project_contractor_idx              ON project (contractor_id);
CREATE INDEX project_linked_idx                  ON project (linked_project_id);
CREATE INDEX project_purchase_order_idx          ON project (purchase_order);
CREATE INDEX project_reference_value_idx         ON project_reference (value);

-- Project task
CREATE INDEX project_task_project_idx            ON project_task (project_id);
CREATE INDEX project_task_type_status_idx        ON project_task (type_of_project_code, project_status_code);
CREATE INDEX project_task_agency_idx             ON project_task (agency_id);
CREATE INDEX project_task_assignment_person_idx  ON project_task_assignment (person_id) WHERE ended_at IS NULL;
CREATE INDEX project_task_quantity_item_idx      ON project_task_quantity (quantity_item_code);
CREATE INDEX project_task_status_history_idx     ON project_task_status_history (project_task_id, modified_at);
CREATE INDEX qc_project_task_idx                 ON qc (project_task_id);

-- Permitting
CREATE INDEX permit_number_idx                   ON permit (permit_number);
CREATE INDEX permit_expires_idx                  ON permit (permit_expires_date) WHERE permit_expires_date IS NOT NULL;
CREATE INDEX record_request_project_task_idx     ON record_request (project_task_id);
CREATE INDEX record_request_prr_idx              ON record_request (prr_number);
CREATE INDEX design_ticket_number_idx            ON design_ticket (design_ticket);

-- Invoicing
CREATE INDEX invoice_unpaid_idx                  ON invoice (invoice_sent_date) WHERE invoice_paid_date IS NULL;

COMMIT;
