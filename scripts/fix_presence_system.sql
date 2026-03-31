-- SISTEMA DE PRESENCIA RESILIENTE (Versión Servidor)
-- Este script centraliza el cálculo de "quién está en línea" en el servidor.

-- 1. Función para obtener usuarios en línea filtrados por empresa
-- Resuelve el problema de desfase horario entre cliente y servidor.
CREATE OR REPLACE FUNCTION votaciones.get_usuarios_en_linea(p_empresa_id UUID)
RETURNS TABLE (user_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Limpieza preventiva: Borrar heartbeats de más de 1 hora para mantener la tabla limpia.
    DELETE FROM votaciones.presence_heartbeat 
    WHERE last_seen < NOW() - INTERVAL '1 hour';

    -- Retornar IDs que han tenido actividad en los últimos 45 segundos según la hora del SERVIDOR.
    RETURN QUERY
    SELECT ph.user_id
    FROM votaciones.presence_heartbeat ph
    JOIN votaciones.perfiles p ON ph.user_id = p.id
    WHERE p.empresa_id = p_empresa_id
      AND ph.last_seen > NOW() - INTERVAL '45 seconds';
END;
$$;

-- 2. Permisos
GRANT EXECUTE ON FUNCTION votaciones.get_usuarios_en_linea TO authenticated;
GRANT EXECUTE ON FUNCTION votaciones.get_usuarios_en_linea TO anon;

-- 3. Asegurar que la función de registro existe y es robusta
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
