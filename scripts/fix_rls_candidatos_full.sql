-- SCRIPT PARA ARREGLAR ERROR DE RLS (POSTGREST EXCEPTION 42501)
-- Ejecutar en el SQL Editor de Supabase

-- 1. Asegurar que las tablas tengan RLS habilitado
ALTER TABLE votaciones.candidatos ENABLE ROW LEVEL SECURITY;
ALTER TABLE votaciones.preguntas ENABLE ROW LEVEL SECURITY;
ALTER TABLE votaciones.opciones ENABLE ROW LEVEL SECURITY;

-- 2. Eliminar políticas antiguas si existen para evitar conflictos
DROP POLICY IF EXISTS "Permitir inserción de candidatos a autenticados" ON votaciones.candidatos;
DROP POLICY IF EXISTS "Permitir inserción de preguntas a autenticados" ON votaciones.preguntas;
DROP POLICY IF EXISTS "Permitir inserción de opciones a autenticados" ON votaciones.opciones;

-- 3. Crear políticas de INSERCIÓN para Administradores (usuarios autenticados)
CREATE POLICY "Permitir inserción de candidatos a autenticados" 
ON votaciones.candidatos FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "Permitir inserción de preguntas a autenticados" 
ON votaciones.preguntas FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "Permitir inserción de opciones a autenticados" 
ON votaciones.opciones FOR INSERT 
TO authenticated 
WITH CHECK (true);

-- 4. Asegurar que SELECT siga permitido (Fuerza bruta para asegurar lectura)
DROP POLICY IF EXISTS "Lectura Total Candidatos" ON votaciones.candidatos;
CREATE POLICY "Lectura Total Candidatos" ON votaciones.candidatos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Lectura Total Preguntas" ON votaciones.preguntas;
CREATE POLICY "Lectura Total Preguntas" ON votaciones.preguntas FOR SELECT USING (true);

DROP POLICY IF EXISTS "Lectura Total Opciones" ON votaciones.opciones;
CREATE POLICY "Lectura Total Opciones" ON votaciones.opciones FOR SELECT USING (true);
