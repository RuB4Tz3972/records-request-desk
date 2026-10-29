-- 01 — Crear la base de datos kmv
-- Ejecutar UNA vez, conectado a la base del sistema "postgres" (no a kmv).
-- Luego: F5 en DBeaver → clic derecho en kmv → SQL Editor → ejecutar 02 a 11 en orden.

CREATE DATABASE kmv
    WITH ENCODING = 'UTF8'
         TEMPLATE = template0;
