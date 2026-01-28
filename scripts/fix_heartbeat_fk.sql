-- PASO DEFINITIVO: Corregir el error de Clave Foránea (Foreign Key).
-- El problema era que "Socio" no es un usuario de "auth.users", sino de "votaciones.perfiles".

-- 1. Borrar la tabla y función anterior para empezar limpio
DROP TABLE IF EXISTS votaciones.presence_heartbeat CASCADE;
DROP FUNCTION IF EXISTS votaciones.registrar_heartbeat;

-- 2. Crear la tabla referenciando a PERFILES, NO a auth.users
CREATE TABLE votaciones.presence_heartbeat (
    user_id UUID PRIMARY KEY REFERENCES votaciones.perfiles(id) ON DELETE CASCADE,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- 3. Habilitar RLS
ALTER TABLE votaciones.presence_heartbeat ENABLE ROW LEVEL SECURITY;

-- 4. Política de Lectura
CREATE POLICY "Ver presencia publica" ON votaciones.presence_heartbeat
    FOR SELECT
    USING (true);

-- 5. Permisos
GRANT ALL ON votaciones.presence_heartbeat TO authenticated, anon;

-- 6. Re-crear la Función RPC (Mismo código, pero ahora funcionará porque la tabla acepta el ID)
CREATE OR REPLACE FUNCTION votaciones.registrar_heartbeat(
    p_user_id UUID, 
    p_metadata JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
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

-- 7. Permisos de Ejecución
GRANT EXECUTE ON FUNCTION votaciones.registrar_heartbeat TO authenticated, anon;
