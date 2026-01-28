-- PASO 1: Ejecuta esto en el SQL Editor de Supabase
-- Esto agrega "BLOQUEADO" a la lista de estados válidos.

DO $$
BEGIN
    ALTER TYPE votaciones.estado_usuario ADD VALUE 'BLOQUEADO';
EXCEPTION
    WHEN duplicate_object THEN null; -- Si ya existe, no hace nada
    WHEN OTHERS THEN null; -- Ignora otros errores (por si acaso)
END $$;
