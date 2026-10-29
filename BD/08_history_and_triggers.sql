-- 08 — Historial de Project Status (reemplaza el "Cell History" de Smartsheet)
-- y modified_at automático.

BEGIN;

CREATE TABLE project_task_status_history (
    project_task_status_history_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_task_id                 bigint NOT NULL REFERENCES project_task (project_task_id) ON DELETE CASCADE,
    old_status_code                 text REFERENCES project_status (code),
    new_status_code                 text REFERENCES project_status (code),
    modified_at                     timestamptz NOT NULL DEFAULT now(),
    modified_by                     text NOT NULL DEFAULT current_user
);

CREATE FUNCTION fn_project_task_log_status() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.project_status_code IS NULL THEN
        RETURN NEW;
    END IF;
    IF TG_OP = 'UPDATE' AND NEW.project_status_code IS NOT DISTINCT FROM OLD.project_status_code THEN
        RETURN NEW;
    END IF;

    INSERT INTO project_task_status_history (project_task_id, old_status_code, new_status_code)
    VALUES (NEW.project_task_id,
            CASE WHEN TG_OP = 'UPDATE' THEN OLD.project_status_code END,
            NEW.project_status_code);
    RETURN NEW;
END $$;

CREATE TRIGGER project_task_log_status
    AFTER INSERT OR UPDATE OF project_status_code ON project_task
    FOR EACH ROW EXECUTE FUNCTION fn_project_task_log_status();

CREATE FUNCTION fn_set_modified_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END $$;

CREATE TRIGGER project_set_modified_at
    BEFORE UPDATE ON project
    FOR EACH ROW EXECUTE FUNCTION fn_set_modified_at();

CREATE TRIGGER project_task_set_modified_at
    BEFORE UPDATE ON project_task
    FOR EACH ROW EXECUTE FUNCTION fn_set_modified_at();

COMMIT;
