-- AGREGAR 'CANDIDATOS' AL ENUM tipo_pregunta

DO $$
BEGIN
    ALTER TYPE votaciones.tipo_pregunta ADD VALUE 'CANDIDATOS';
EXCEPTION
    WHEN duplicate_object THEN null; -- Si ya existe, no importa
    WHEN OTHERS THEN null;
END $$;
