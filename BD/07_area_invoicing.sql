-- 07 — Área INVOICING
-- Igual que en la hoja: una factura por proyecto, tres casillas y cuatro fechas.
-- "¿Está pagada?" se calcula en v_invoice_status. Si más adelante se factura
-- por cantidad × tarifa, se agrega invoice_line sin tocar esta tabla.

BEGIN;

CREATE TABLE invoice (
    invoice_id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id                   bigint NOT NULL UNIQUE REFERENCES project (project_id),
    invoice_galp                 boolean NOT NULL DEFAULT false,   -- "Invoice? GALP"
    invoice_kmv                  boolean NOT NULL DEFAULT false,   -- "Invoice? KMV"
    customer_invoice             boolean NOT NULL DEFAULT false,   -- "Customer invoice?" (2025: "Invoice? Crown")
    invoice_number               text,
    amount                       numeric(14,2) CHECK (amount >= 0),
    currency                     char(3) NOT NULL DEFAULT 'USD',
    invoice_completed_galp_date  date,     -- "Invoice Completed (Galp)"
    pm_approval_invoice_date     date,
    invoice_sent_date            date,
    invoice_paid_date            date,
    created_at                   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT invoice_dates_ck CHECK
        (invoice_paid_date IS NULL OR invoice_sent_date IS NULL OR invoice_paid_date >= invoice_sent_date)
);

COMMIT;
