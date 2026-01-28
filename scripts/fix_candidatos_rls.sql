-- Habilitar RLS en tabla candidatos
ALTER TABLE votaciones.candidatos ENABLE ROW LEVEL SECURITY;

-- Política para que usuarios autenticados puedan leer candidatos
CREATE POLICY "Permitir lectura de candidatos a autenticados" 
ON votaciones.candidatos
FOR SELECT 
USING (auth.role() = 'authenticated');

-- Política para que service_role pueda hacer todo (ya suele estar, pero por si acaso)
-- No es necesario explícito si service_role bypasses RLS, pero bueno.

-- Asegurar que la tabla preguntas y opciones también tengan lectura pública (authenticated)
CREATE POLICY "Permitir lectura de preguntas a autenticados" 
ON votaciones.preguntas
FOR SELECT 
USING (auth.role() = 'authenticated');

CREATE POLICY "Permitir lectura de opciones a autenticados" 
ON votaciones.opciones
FOR SELECT 
USING (auth.role() = 'authenticated');
