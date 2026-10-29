-- 00 — SOLO si ya ejecutaste una versión anterior en la base kmv y NO tiene datos reales.
-- Borra todo el esquema public de kmv. Ejecutar conectado a kmv.
-- Si es la primera vez, sáltate este archivo.

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
