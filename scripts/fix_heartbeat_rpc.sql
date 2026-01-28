-- PASO FINAL: Ejecuta este script para arreglar el error 404 y permisos.

-- 1. Asegurar que la tabla existe (por si falló el anterior)
CREATE TABLE IF NOT EXISTS votaciones.presence_heartbeat (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- 2. Habilitar RLS (Seguridad)
ALTER TABLE votaciones.presence_heartbeat ENABLE ROW LEVEL SECURITY;

-- 3. Limpiar políticas viejas para evitar conflictos
DROP POLICY IF EXISTS "Ver presencia publica" ON votaciones.presence_heartbeat;
DROP POLICY IF EXISTS "Actualizar mi propia presencia" ON votaciones.presence_heartbeat;

-- 4. Crear Política de Lectura (Cualquiera puede ver)
CREATE POLICY "Ver presencia publica" ON votaciones.presence_heartbeat
    FOR SELECT
    USING (true);

-- 5. Dar permisos básicos a la tabla
GRANT ALL ON votaciones.presence_heartbeat TO authenticated, anon;

-- 6. FUNCIÓN RPC (La solución mágica para el error 404/Permisos)
-- Esta función inserta el heartbeat con permisos de administrador, saltándose restricciones.
CREATE OR REPLACE FUNCTION votaciones.registrar_heartbeat(
    p_user_id UUID, 
    p_metadata JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER -- IMPORTANTE: Ejecuta con permisos del creador (admin)
AS $$
BEGIN
    INSERT INTO votaciones.presence_heartbeat (user_id, last_seen, metadata)
    VALUES (p_user_id, NOW(), p_metadata)
    ON CONFLICT (user_id) 
    DO UPDATE SET 
        last_seen = NOW(),
        metadata = p_metadata;
END;
$$;

-- 7. Dar permiso para ejecutar la función
GRANT EXECUTE ON FUNCTION votaciones.registrar_heartbeat TO authenticated, anon;
