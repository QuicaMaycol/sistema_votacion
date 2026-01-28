-- SCRIPT DE "FUERZA BRUTA" PARA PERMISOS
-- Ejecutar esto para descartar problemas de acceso definitivamente

GRANT USAGE ON SCHEMA votaciones TO postgres, authenticated, anon, service_role;

GRANT ALL ON ALL TABLES IN SCHEMA votaciones TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA votaciones TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA votaciones TO anon;

-- Asegurar RLS permisivo para candidatos
ALTER TABLE votaciones.candidatos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura Total Candidatos" ON votaciones.candidatos;

CREATE POLICY "Lectura Total Candidatos" 
ON votaciones.candidatos
FOR SELECT 
USING (true); -- 'true' significa que CUALQUIERA puede leer, sin condicion.

-- Lo mismo para opciones y preguntas por si acaso
DROP POLICY IF EXISTS "Lectura Total Preguntas" ON votaciones.preguntas;
CREATE POLICY "Lectura Total Preguntas" ON votaciones.preguntas FOR SELECT USING (true);

DROP POLICY IF EXISTS "Lectura Total Opciones" ON votaciones.opciones;
CREATE POLICY "Lectura Total Opciones" ON votaciones.opciones FOR SELECT USING (true);
