-- MEJORA DE PRESENCIA: DESCONEXIÓN INMEDIATA
-- Este script añade una función para eliminar el rastro de conexión al cerrar sesión.

-- 1. Función para eliminar el heartbeat (Logout)
CREATE OR REPLACE FUNCTION votaciones.eliminar_heartbeat(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM votaciones.presence_heartbeat
    WHERE user_id = p_user_id;
END;
$$;

-- 2. Permisos para ejecutar la función
GRANT EXECUTE ON FUNCTION votaciones.eliminar_heartbeat TO authenticated, anon;

-- 3. (Opcional) Limpieza automática de heartbeats muy viejos (> 10 minutos)
-- Esto ayuda a mantener la tabla liviana si muchos usuarios cierran el navegador sin cerrar sesión.
DELETE FROM votaciones.presence_heartbeat WHERE last_seen < NOW() - INTERVAL '10 minutes';
